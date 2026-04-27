#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
PACKAGE_ROOT="$REPO_ROOT"
APP_NAME="PromptPanel"
CONFIGURATION="release"
OUTPUT_ROOT="${REPO_ROOT}/dist"
SIGN_IDENTITY="none"
ARCHIVE=1
SHORT_VERSION_OVERRIDE=""
BUILD_VERSION_OVERRIDE=""
SPARKLE_FEED_URL=""
SPARKLE_PUBLIC_ED_KEY=""
BUNDLE_IDENTIFIER=""
DISPLAY_NAME_OVERRIDE=""

usage() {
    cat <<'EOF'
Usage: scripts/build-app.sh [options]

Options:
  --debug                 Build a debug app instead of release.
  --output-dir <path>     Output directory for the generated app and zip.
  --sign-identity <id>    codesign identity. Use "none" to skip signing.
  --no-archive            Skip zip archive creation.
  --short-version <ver>   Override CFBundleShortVersionString in the packaged app.
  --build-version <ver>   Override CFBundleVersion in the packaged app.
  --bundle-identifier <id>
                          Override CFBundleIdentifier in the packaged app.
  --display-name <name>   Override CFBundleDisplayName and CFBundleName.
  --sparkle-feed-url <u>  Inject SUFeedURL into the packaged app's Info.plist.
  --sparkle-public-ed-key Inject SUPublicEDKey into the packaged app's Info.plist.
  --help                  Show this help message.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            CONFIGURATION="debug"
            shift
            ;;
        --output-dir)
            OUTPUT_ROOT="$2"
            shift 2
            ;;
        --sign-identity)
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --no-archive)
            ARCHIVE=0
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
        --bundle-identifier)
            BUNDLE_IDENTIFIER="$2"
            shift 2
            ;;
        --display-name)
            DISPLAY_NAME_OVERRIDE="$2"
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
            echo "Unknown option: $1" >&2
            usage >&2
            exit 64
            ;;
    esac
done

if [[ ! -d "$PACKAGE_ROOT" ]]; then
    echo "Package root not found: $PACKAGE_ROOT" >&2
    exit 1
fi

mkdir -p "$OUTPUT_ROOT"

echo "Building ${APP_NAME} (${CONFIGURATION})..."
swift build --package-path "$PACKAGE_ROOT" -c "$CONFIGURATION"
BIN_DIR="$(swift build --package-path "$PACKAGE_ROOT" -c "$CONFIGURATION" --show-bin-path)"

codesign_path() {
    local target_path="$1"
    local runtime_mode="${2:-off}"
    local stable_designated_requirement="${3:-off}"
    local args=(--force)

    if [[ "$SIGN_IDENTITY" == "none" ]]; then
        args+=(--sign -)
        if [[ "$stable_designated_requirement" == "on" ]]; then
            args+=(
                --identifier "$BUNDLE_IDENTIFIER"
                --requirements "=designated => identifier \"$BUNDLE_IDENTIFIER\""
            )
        fi
    else
        args+=(--timestamp --sign "$SIGN_IDENTITY")
        if [[ "$runtime_mode" == "runtime" ]]; then
            args+=(--options runtime)
        fi
    fi

    codesign "${args[@]}" "$target_path"
}

sign_framework_contents() {
    local framework_path="$1"
    local helper_paths=()
    local helper_path

    while IFS= read -r helper_path; do
        helper_paths+=("$helper_path")
    done < <(
        {
            find "$framework_path" -mindepth 1 -type d \( -name '*.app' -o -name '*.xpc' -o -name '*.framework' \) -print
            find "$framework_path" -mindepth 1 -type f \( -name '*.dylib' -o -name 'Autoupdate' \) -print
        } | awk '{ print length($0), $0 }' | sort -rn | cut -d' ' -f2-
    )

    for helper_path in "${helper_paths[@]}"; do
        case "$helper_path" in
            *.app|*.xpc|*/Autoupdate)
                codesign_path "$helper_path" runtime
                ;;
            *)
                codesign_path "$helper_path"
                ;;
        esac
    done

    codesign_path "$framework_path"
}

APP_PATH="${OUTPUT_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$FRAMEWORKS_DIR" "$RESOURCES_DIR"

cp "${PACKAGE_ROOT}/Sources/PromptPanel/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${CONTENTS_DIR}/Info.plist"
if [[ -n "$SHORT_VERSION_OVERRIDE" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SHORT_VERSION_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$BUILD_VERSION_OVERRIDE" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_VERSION_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$BUNDLE_IDENTIFIER" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_IDENTIFIER}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$DISPLAY_NAME_OVERRIDE" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${DISPLAY_NAME_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName ${DISPLAY_NAME_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$SPARKLE_FEED_URL" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string ${SPARKLE_FEED_URL}" "${CONTENTS_DIR}/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :SUFeedURL ${SPARKLE_FEED_URL}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_ED_KEY}" "${CONTENTS_DIR}/Info.plist" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${SPARKLE_PUBLIC_ED_KEY}" "${CONTENTS_DIR}/Info.plist"
fi
BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${CONTENTS_DIR}/Info.plist")"

cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

APP_ICON_SRC="${PACKAGE_ROOT}/Sources/PromptPanel/Resources/AppIcon.icns"
if [[ -f "$APP_ICON_SRC" ]]; then
    cp "$APP_ICON_SRC" "${RESOURCES_DIR}/AppIcon.icns"
else
    echo "AppIcon.icns not found at $APP_ICON_SRC" >&2
    exit 1
fi

for bundle_path in "${BIN_DIR}"/*.bundle(N); do
    cp -R "$bundle_path" "${RESOURCES_DIR}/"
done

for framework_path in "${BIN_DIR}"/*.framework(N); do
    cp -R "$framework_path" "${FRAMEWORKS_DIR}/"
done

for dylib_path in "${BIN_DIR}"/*.dylib(N); do
    cp -R "$dylib_path" "${FRAMEWORKS_DIR}/"
done

if [[ -n "$(find "$FRAMEWORKS_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    if ! otool -l "${MACOS_DIR}/${APP_NAME}" | grep -q "@executable_path/../Frameworks"; then
        install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/${APP_NAME}"
    fi
fi

for framework_path in "${FRAMEWORKS_DIR}"/*.framework(N); do
    sign_framework_contents "$framework_path"
done

for dylib_path in "${FRAMEWORKS_DIR}"/*.dylib(N); do
    codesign_path "$dylib_path"
done

if [[ "$SIGN_IDENTITY" != "none" ]]; then
    echo "Signing app with identity: ${SIGN_IDENTITY}"
fi

codesign_path "${APP_PATH}" runtime on

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

if [[ "$SIGN_IDENTITY" == "none" ]]; then
    DESIGNATED_REQUIREMENT="$(codesign -dr - "${APP_PATH}" 2>&1)"
    if ! grep -Fq "designated => identifier \"$BUNDLE_IDENTIFIER\"" <<<"$DESIGNATED_REQUIREMENT"; then
        echo "Ad-hoc signing did not produce the expected stable designated requirement:" >&2
        echo "$DESIGNATED_REQUIREMENT" >&2
        exit 1
    fi
fi

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${CONTENTS_DIR}/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${CONTENTS_DIR}/Info.plist")"

if [[ $ARCHIVE -eq 1 ]]; then
    ARCHIVE_PATH="${OUTPUT_ROOT}/${APP_NAME}-${SHORT_VERSION}+${BUILD_VERSION}-macos.zip"
    rm -f "$ARCHIVE_PATH"
    ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ARCHIVE_PATH"
    echo "Archive created: ${ARCHIVE_PATH}"
fi

echo "App created: ${APP_PATH}"
