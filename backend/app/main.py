from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine
from .migrations import run_dev_migrations
from .routes import (
    auth,
    courses,
    learners,
    organizations,
    pods,
    progress,
)

run_dev_migrations()
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Microschool Platform",
    version="0.3.1",
    description=(
        "A plug-and-play platform for operating microschools "
        "and connecting people with reusable learning and "
        "operational resources."
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(organizations.router)
app.include_router(learners.router)
app.include_router(pods.router)
app.include_router(courses.router)
app.include_router(progress.router)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "application": "Microschool",
        "version": "0.3.1",
    }


frontend_path = Path(__file__).resolve().parents[2] / "frontend"

app.mount(
    "/",
    StaticFiles(
        directory=frontend_path,
        html=True,
    ),
    name="frontend",
)
