#!/usr/bin/env bash

set -e

PROJECT_ROOT=/home/luke/Documents/Software/microschool/

echo "Creating Microschool project structure..."
echo "Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

mkdir -p \
    backend/app/routes \
    backend/tests \
    frontend \
    scripts \
    data

touch \
    backend/app/__init__.py \
    backend/app/main.py \
    backend/app/config.py \
    backend/app/database.py \
    backend/app/models.py \
    backend/app/schemas.py \
    backend/app/auth.py \
    backend/app/routes/__init__.py \
    backend/app/routes/auth.py \
    backend/app/routes/learners.py \
    backend/app/routes/pods.py \
    backend/app/routes/courses.py \
    backend/app/routes/progress.py \
    backend/tests/test_health.py \
    frontend/index.html \
    frontend/app.js \
    frontend/styles.css \
    .env.example \
    .gitignore \
    README.md \
    run.sh

echo ""
echo "Project files created."
echo ""
echo "Next step:"
echo "    ./scripts/fill-files.sh"
