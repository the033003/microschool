from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .database import Base, engine

from .routes import (
    auth,
    courses,
    learners,
    pods,
    progress,
)


Base.metadata.create_all(bind=engine)


app = FastAPI(
    title="Microschool Learning Platform",
    version="0.1.0",
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth.router)
app.include_router(learners.router)
app.include_router(pods.router)
app.include_router(courses.router)
app.include_router(progress.router)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "application": "Microschool",
    }


frontend_path = (
    Path(__file__).resolve().parents[2]
    / "frontend"
)

app.mount(
    "/",
    StaticFiles(
        directory=frontend_path,
        html=True,
    ),
    name="frontend",
)
