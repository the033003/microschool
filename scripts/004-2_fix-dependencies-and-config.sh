#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="004-2_fix-dependencies-and-config"
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

cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS-before.md"

cat > backend/requirements.txt <<'REQ'
fastapi
uvicorn[standard]
sqlalchemy
pydantic[email]
pydantic-settings
python-jose[cryptography]
python-multipart
pytest
httpx
REQ

cat > backend/app/config.py <<'PY'
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"

DATA_DIR.mkdir(
    parents=True,
    exist_ok=True,
)


class Settings(BaseSettings):
    app_name: str = "Microschool"
    secret_key: str = "change-this-secret"

    database_url: str = (
        f"sqlite:///{DATA_DIR / 'microschool.db'}"
    )

    model_config = SettingsConfigDict(
        env_file=PROJECT_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
PY

cat >> PROJECT_STATUS.md <<'STATUS'

## Build 004.2 — Dependency and Configuration Cleanup

Date: 2026-10-03

Changes:

- Added email-validator through the pydantic[email] dependency.
- Added python-multipart for FastAPI form-based authentication.
- Removed the deprecated Pydantic class-based Config syntax.
- Migrated Settings configuration to SettingsConfigDict.
- Kept the database path anchored to the project root.
- Replaced the previous dependency list with the dependencies actually
  required by the current application.

Known:

- The installed Starlette/httpx combination may still report a
  TestClient deprecation warning. This will be addressed separately
  after the application test suite is executing successfully.
STATUS

cp "$0" "$BACKUP_DIR/$BUILD.sh"
cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS.md"

echo ""
echo "Installing updated dependencies..."
echo ""

source "$ROOT/.venv/bin/activate"

pip install -r backend/requirements.txt

echo ""
echo "Running tests..."
echo ""

(
    cd "$ROOT/backend"
    pytest -q
)

echo ""
echo "Build 004.2 complete."
echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
