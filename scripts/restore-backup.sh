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

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "sqlite3 is required to validate the backup before restore." >&2
    exit 1
fi

INTEGRITY_RESULT="$(sqlite3 "$BACKUP_SOURCE" 'PRAGMA integrity_check;' 2>/dev/null || true)"
if [[ "$INTEGRITY_RESULT" != "ok" ]]; then
    echo "Backup integrity check failed: $BACKUP_SOURCE" >&2
    echo "$INTEGRITY_RESULT" >&2
    exit 1
fi

REQUIRED_TABLES=(
    projects
    entries
    entries_fts
    app_settings
    execution_logs
    grdb_migrations
)

for table_name in "${REQUIRED_TABLES[@]}"; do
    TABLE_EXISTS="$(sqlite3 "$BACKUP_SOURCE" "SELECT COUNT(*) FROM sqlite_master WHERE type IN ('table', 'view') AND name = '$table_name';" 2>/dev/null || true)"
    if [[ "$TABLE_EXISTS" != "1" ]]; then
        echo "Backup schema validation failed: missing required table '$table_name'." >&2
        exit 1
    fi
done

DEFAULT_PROJECT_COUNT="$(sqlite3 "$BACKUP_SOURCE" "SELECT COUNT(*) FROM projects WHERE is_default = 1;" 2>/dev/null || true)"
if [[ -z "$DEFAULT_PROJECT_COUNT" || "$DEFAULT_PROJECT_COUNT" -lt 1 ]]; then
    echo "Backup schema validation failed: no default project found." >&2
    exit 1
fi

CURRENT_PROJECT_REFERENCE_COUNT="$(sqlite3 "$BACKUP_SOURCE" "
    SELECT COUNT(*)
    FROM app_settings
    INNER JOIN projects ON projects.id = app_settings.value
    WHERE app_settings.key = 'current_project_id'
      AND TRIM(COALESCE(app_settings.value, '')) != '';
" 2>/dev/null || true)"
if [[ -z "$CURRENT_PROJECT_REFERENCE_COUNT" || "$CURRENT_PROJECT_REFERENCE_COUNT" -lt 1 ]]; then
    echo "Backup schema validation failed: current_project_id is missing, empty, or points to a non-existent project." >&2
    exit 1
fi

if pgrep -x "PromptPanel" >/dev/null 2>&1; then
    echo "PromptPanel is running. Quit the app before restoring a backup." >&2
    exit 1
fi

mkdir -p "$APP_SUPPORT_DIR"
chmod 700 "$APP_SUPPORT_DIR"

TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RECOVERY_DIR="${APP_SUPPORT_DIR}/Recovery/manual-restore-${TIMESTAMP}"

if [[ -e "$DATABASE_PATH" || -e "${DATABASE_PATH}-wal" || -e "${DATABASE_PATH}-shm" ]]; then
    mkdir -p "$RECOVERY_DIR"
    chmod 700 "$RECOVERY_DIR"
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
