#!/usr/bin/env bash

set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$ROOT"

if [ ! -d ".venv" ]; then
    echo "Creating Python virtual environment..."

    python3 -m venv .venv
fi


source .venv/bin/activate


echo "Installing Python dependencies..."

pip install -r backend/requirements.txt


mkdir -p data


echo ""
echo "Starting Microschool..."
echo ""
echo "Open:"
echo "http://127.0.0.1:8000"
echo ""
echo "API documentation:"
echo "http://127.0.0.1:8000/docs"
echo ""


cd backend

uvicorn app.main:app \
    --reload \
    --host 127.0.0.1 \
    --port 8000
