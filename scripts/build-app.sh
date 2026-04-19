#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
PACKAGE_ROOT="${REPO_ROOT}/PromptPanel"
APP_NAME="PromptPanel"
CONFIGURATION="release"
OUTPUT_ROOT="${REPO_ROOT}/dist"
SIGN_IDENTITY="none"
ARCHIVE=1
SHORT_VERSION_OVERRIDE=""
BUILD_VERSION_OVERRIDE=""

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

APP_PATH="${OUTPUT_ROOT}/${APP_NAME}.app"
CONTENTS_DIR="${APP_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR"

cp "${PACKAGE_ROOT}/PromptPanel/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable ${APP_NAME}" "${CONTENTS_DIR}/Info.plist"
if [[ -n "$SHORT_VERSION_OVERRIDE" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${SHORT_VERSION_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
fi
if [[ -n "$BUILD_VERSION_OVERRIDE" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_VERSION_OVERRIDE}" "${CONTENTS_DIR}/Info.plist"
fi

cp "${BIN_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

for bundle_path in "${BIN_DIR}"/*.bundle(N); do
    cp -R "$bundle_path" "${APP_PATH}/"
done

if [[ "$SIGN_IDENTITY" != "none" ]]; then
    echo "Signing app with identity: ${SIGN_IDENTITY}"
    codesign --force --sign "$SIGN_IDENTITY" "${MACOS_DIR}/${APP_NAME}"
    codesign --force --sign "$SIGN_IDENTITY" "${APP_PATH}"
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
