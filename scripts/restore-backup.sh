#!/bin/zsh

set -euo pipefail

APP_SUPPORT_DIR="${PROMPTPANEL_APP_SUPPORT_DIR:-${HOME}/Library/Application Support/PromptPanel}"
DATABASE_PATH="${APP_SUPPORT_DIR}/promptpanel.db"

usage() {
    cat <<'EOF'
Usage: scripts/restore-backup.sh /absolute/path/to/backup.sqlite

Restores the selected backup into the live PromptPanel database location.
The app must be closed before running this script.
EOF
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 64
fi

BACKUP_SOURCE="${1:A}"

if [[ ! -f "$BACKUP_SOURCE" ]]; then
    echo "Backup file not found: $BACKUP_SOURCE" >&2
    exit 1
fi

if pgrep -x "PromptPanel" >/dev/null 2>&1; then
    echo "PromptPanel is running. Quit the app before restoring a backup." >&2
    exit 1
fi

mkdir -p "$APP_SUPPORT_DIR"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RECOVERY_DIR="${APP_SUPPORT_DIR}/Recovery/manual-restore-${TIMESTAMP}"

if [[ -e "$DATABASE_PATH" || -e "${DATABASE_PATH}-wal" || -e "${DATABASE_PATH}-shm" ]]; then
    mkdir -p "$RECOVERY_DIR"
    for suffix in "" "-wal" "-shm"; do
        SOURCE_PATH="${DATABASE_PATH}${suffix}"
        if [[ -e "$SOURCE_PATH" ]]; then
            mv "$SOURCE_PATH" "${RECOVERY_DIR}/"
        fi
    done
    echo "Existing database moved to: ${RECOVERY_DIR}"
fi

cp "$BACKUP_SOURCE" "$DATABASE_PATH"
chmod 600 "$DATABASE_PATH"
rm -f "${DATABASE_PATH}-wal" "${DATABASE_PATH}-shm"

echo "Backup restored to: ${DATABASE_PATH}"
