#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
PACKAGE_ROOT="${REPO_ROOT}/PromptPanel"
OUTPUT_ROOT="${REPO_ROOT}/dist/release-readiness"
SIGN_IDENTITY="none"
PUBLIC_DISTRIBUTION=0
SKIP_SMOKE_LAUNCH=0
SHORT_VERSION_OVERRIDE=""
BUILD_VERSION_OVERRIDE=""
SPARKLE_FEED_URL=""
SPARKLE_PUBLIC_ED_KEY=""
SMOKE_TIMEOUT_SECONDS=12

usage() {
    cat <<'EOF'
Usage: scripts/release-readiness.sh [options]

Runs the local release-readiness checks for PromptPanel:
  1. validate shell script syntax
  2. build the Swift package
  3. run swift test
  4. build a release .app and zip
  5. verify code signatures
  6. smoke-launch the built app with isolated data directories
  7. hand off the signed archive to notarization via scripts/notarize-app.sh when needed

Options:
  --output-dir <path>          Output directory for the release bundle.
  --sign-identity <id>         codesign identity passed to build-app.sh.
  --public-distribution        Fail if the build still uses ad-hoc signing or this machine lacks xctest.
  --skip-smoke-launch          Skip the isolated startup smoke check.
  --short-version <ver>        Override CFBundleShortVersionString.
  --build-version <ver>        Override CFBundleVersion.
  --sparkle-feed-url <url>     Inject SUFeedURL into the packaged app.
  --sparkle-public-ed-key <k>  Inject SUPublicEDKey into the packaged app.
  --help                       Show this help message.
EOF
}

log_info() {
    printf '[release-readiness] %s\n' "$1"
}

log_warn() {
    printf '[release-readiness][warn] %s\n' "$1" >&2
}

fail() {
    printf '[release-readiness][error] %s\n' "$1" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --sign-identity)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --public-distribution)
            PUBLIC_DISTRIBUTION=1
            shift
            ;;
        --skip-smoke-launch)
            SKIP_SMOKE_LAUNCH=1
            shift
            ;;
        --short-version)
            SHORT_VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --build-version)
            BUILD_VERSION_OVERRIDE="$2"
            shift 2
            ;;
        --sparkle-feed-url)
            SPARKLE_FEED_URL="$2"
            shift 2
            ;;
        --sparkle-public-ed-key)
            SPARKLE_PUBLIC_ED_KEY="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "Unknown option: $1"
            ;;
    esac
done

if [[ ! -d "$PACKAGE_ROOT" ]]; then
    fail "Package root not found: $PACKAGE_ROOT"
fi

if [[ -n "$SPARKLE_FEED_URL" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    fail "Sparkle feed URL was provided, but SUPublicEDKey is missing."
fi

if [[ -z "$SPARKLE_FEED_URL" && -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    fail "Sparkle public key was provided, but SUFeedURL is missing."
fi

if [[ $PUBLIC_DISTRIBUTION -eq 1 && "$SIGN_IDENTITY" == "none" ]]; then
    fail "Public distribution precheck requires a non-ad-hoc signing identity."
fi

mkdir -p "$OUTPUT_ROOT"

log_info "Validating shell scripts"
zsh -n "${REPO_ROOT}/scripts/build-app.sh"
zsh -n "${REPO_ROOT}/scripts/notarize-app.sh"
zsh -n "${REPO_ROOT}/scripts/restore-backup.sh"
zsh -n "${REPO_ROOT}/scripts/release-readiness.sh"

log_info "Building Swift package"
swift build --package-path "$PACKAGE_ROOT"

TEST_RUNNER_AVAILABLE=0
if xcrun --find xctest >/dev/null 2>&1; then
    TEST_RUNNER_AVAILABLE=1
else
    log_warn "xctest is unavailable on this machine; swift test can only validate the test bundle build."
fi

log_info "Running swift test"
swift test --package-path "$PACKAGE_ROOT"

if [[ $PUBLIC_DISTRIBUTION -eq 1 && $TEST_RUNNER_AVAILABLE -eq 0 ]]; then
    fail "Public distribution precheck failed because xctest is unavailable on this machine."
fi

build_args=(
    --output-dir "$OUTPUT_ROOT"
    --sign-identity "$SIGN_IDENTITY"
)

if [[ -n "$SHORT_VERSION_OVERRIDE" ]]; then
    build_args+=(--short-version "$SHORT_VERSION_OVERRIDE")
fi

if [[ -n "$BUILD_VERSION_OVERRIDE" ]]; then
    build_args+=(--build-version "$BUILD_VERSION_OVERRIDE")
fi

if [[ -n "$SPARKLE_FEED_URL" ]]; then
    build_args+=(--sparkle-feed-url "$SPARKLE_FEED_URL")
fi

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    build_args+=(--sparkle-public-ed-key "$SPARKLE_PUBLIC_ED_KEY")
fi

log_info "Building release app"
"${REPO_ROOT}/scripts/build-app.sh" "${build_args[@]}"

APP_PATH="${OUTPUT_ROOT}/PromptPanel.app"
ZIP_MATCHES=("${OUTPUT_ROOT}"/PromptPanel-*.zip(N))

[[ -d "$APP_PATH" ]] || fail "Built app not found: $APP_PATH"
[[ ${#ZIP_MATCHES[@]} -gt 0 ]] || fail "Built zip archive not found under $OUTPUT_ROOT"

ZIP_PATH="${ZIP_MATCHES[1]}"

log_info "Verifying code signatures"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

UNPACK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/promptpanel-unpacked.XXXXXX")"
cleanup_unpack() {
    rm -rf "$UNPACK_DIR"
}
trap cleanup_unpack EXIT

ditto -x -k "$ZIP_PATH" "$UNPACK_DIR"
codesign --verify --deep --strict --verbose=2 "${UNPACK_DIR}/PromptPanel.app"

if [[ $PUBLIC_DISTRIBUTION -eq 1 ]]; then
    if ! codesign -dvv "$APP_PATH" 2>&1 | grep -q "Authority=Developer ID Application"; then
        fail "Public distribution precheck requires a Developer ID Application signature."
    fi
fi

if [[ $SKIP_SMOKE_LAUNCH -eq 0 ]]; then
    log_info "Running isolated startup smoke check"
    QA_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/promptpanel-ready.XXXXXX")"
    APP_SUPPORT_DIR="${QA_ROOT}/AppSupport"
    LOGS_DIR="${QA_ROOT}/Logs"
    APP_BINARY="${APP_PATH}/Contents/MacOS/PromptPanel"
    APP_LOG="${QA_ROOT}/app.log"

    cleanup_smoke() {
        if [[ -n "${APP_PID:-}" ]] && kill -0 "$APP_PID" >/dev/null 2>&1; then
            kill "$APP_PID" >/dev/null 2>&1 || true
            wait "$APP_PID" >/dev/null 2>&1 || true
        fi
        rm -rf "$QA_ROOT"
    }

    trap 'cleanup_unpack; cleanup_smoke' EXIT

    env \
        PROMPTPANEL_ALLOW_EXISTING_INSTANCE=1 \
        PROMPTPANEL_APP_SUPPORT_DIR="$APP_SUPPORT_DIR" \
        PROMPTPANEL_LOGS_DIR="$LOGS_DIR" \
        "$APP_BINARY" >"$APP_LOG" 2>&1 &
    APP_PID=$!

    DATABASE_PATH="${APP_SUPPORT_DIR}/promptpanel.db"
    BACKUP_DIR="${APP_SUPPORT_DIR}/Backups"
    deadline=$((SECONDS + SMOKE_TIMEOUT_SECONDS))

    while (( SECONDS < deadline )); do
        if [[ -f "$DATABASE_PATH" ]] && [[ -n "$(find "$BACKUP_DIR" -maxdepth 1 -name '*.sqlite' -print -quit 2>/dev/null)" ]]; then
            break
        fi
        sleep 1
    done

    if [[ ! -f "$DATABASE_PATH" ]]; then
        log_warn "Smoke launch log:"
        tail -n 80 "$APP_LOG" >&2 || true
        fail "Smoke launch did not create the database at $DATABASE_PATH"
    fi

    if [[ -z "$(find "$BACKUP_DIR" -maxdepth 1 -name '*.sqlite' -print -quit 2>/dev/null)" ]]; then
        log_warn "Smoke launch log:"
        tail -n 80 "$APP_LOG" >&2 || true
        fail "Smoke launch did not create a startup backup under $BACKUP_DIR"
    fi

    if command -v sqlite3 >/dev/null 2>&1; then
        integrity_result="$(sqlite3 "$DATABASE_PATH" 'PRAGMA integrity_check;' 2>/dev/null || true)"
        [[ "$integrity_result" == "ok" ]] || fail "Smoke-launch database integrity check failed: ${integrity_result:-unknown}"
    else
        log_warn "sqlite3 is unavailable; skipped database integrity verification for the smoke-launch database."
    fi

    cleanup_smoke
    unset APP_PID
fi

log_info "Checks completed successfully"
if [[ $PUBLIC_DISTRIBUTION -eq 1 ]]; then
    log_warn "Public distribution precheck passed. Next run scripts/notarize-app.sh with the signed app, archive, and notarytool keychain profile."
fi
