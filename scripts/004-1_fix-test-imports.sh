#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="004-1_fix-test-imports"
BACKUP_DIR="$ROOT/backups/$BUILD"

mkdir -p "$BACKUP_DIR"

echo "Creating pre-fix backup..."

tar \
    --exclude='./.venv' \
    --exclude='./__pycache__' \
    --exclude='./*/__pycache__' \
    --exclude='./data/*.db' \
    --exclude='./backups' \
    --exclude='./.git' \
    -czf "$BACKUP_DIR/project-before-$BUILD.tar.gz" \
    .

if [ -f "$ROOT/PROJECT_STATUS.md" ]; then
    cp "$ROOT/PROJECT_STATUS.md" \
        "$BACKUP_DIR/PROJECT_STATUS-before.md"
fi

cat > backend/tests/conftest.py <<'PY'
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))
PY

cat >> PROJECT_STATUS.md <<'STATUS'

## Build 004.1 — Test Import Fix

Date: 2026-10-03

Changes:

- Added pytest configuration through backend/tests/conftest.py.
- Ensured the backend package is available on the test import path.
- Fixed test collection when pytest is executed from backend/.
- No application behavior was changed.

Known warning:

- Current FastAPI/Starlette test setup reports a deprecation warning
  regarding the installed httpx version. This does not currently
  prevent tests from running, but the test dependency stack should be
  modernized during the next dependency cleanup.
STATUS

cp "$0" "$BACKUP_DIR/$BUILD.sh"
cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS.md"

echo ""
echo "Running tests..."
echo ""

source "$ROOT/.venv/bin/activate"

(
    cd "$ROOT/backend"
    pytest -q
)

echo ""
echo "Build 004.1 complete."
echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
