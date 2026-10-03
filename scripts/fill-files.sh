#!/usr/bin/env bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_ROOT"

echo "Writing project files..."

cat > backend/requirements.txt <<'EOF'
fastapi
uvicorn[standard]
sqlalchemy
pydantic
pydantic-settings
python-jose[cryptography]
passlib[bcrypt]
python-multipart
pytest
httpx
EOF


cat > backend/app/__init__.py <<'EOF'
EOF


cat > backend/app/config.py <<'EOF'
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "Microschool"
    secret_key: str = "change-this-secret"
    database_url: str = "sqlite:///./data/microschool.db"

    class Config:
        env_file = ".env"


settings = Settings()
EOF


cat > backend/app/database.py <<'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from .config import settings


connect_args = {}

if settings.database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}


engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()
EOF


cat > backend/app/models.py <<'EOF'
from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)

    email = Column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    password_hash = Column(String, nullable=False)

    role = Column(
        String,
        nullable=False,
        default="learner",
    )

    active = Column(Boolean, default=True)

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class Pod(Base):
    __tablename__ = "pods"

    id = Column(Integer, primary_key=True)

    name = Column(String, nullable=False)

    description = Column(Text)

    guide_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
    )

    guide = relationship("User")

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class PodMember(Base):
    __tablename__ = "pod_members"

    id = Column(Integer, primary_key=True)

    pod_id = Column(
        Integer,
        ForeignKey("pods.id"),
        nullable=False,
    )

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    joined_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class Course(Base):
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True)

    title = Column(String, nullable=False)

    description = Column(Text)

    subject = Column(String)

    grade_level = Column(String)

    active = Column(Boolean, default=True)


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True)

    course_id = Column(
        Integer,
        ForeignKey("courses.id"),
        nullable=False,
    )

    title = Column(String, nullable=False)

    description = Column(Text)

    content = Column(Text)

    position = Column(Integer, default=0)


class LearnerProgress(Base):
    __tablename__ = "learner_progress"

    id = Column(Integer, primary_key=True)

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    lesson_id = Column(
        Integer,
        ForeignKey("lessons.id"),
        nullable=False,
    )

    completed = Column(Boolean, default=False)

    score = Column(Float, nullable=True)

    attempts = Column(Integer, default=0)

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True)

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    date = Column(
        DateTime,
        default=datetime.utcnow,
    )

    present = Column(Boolean, default=True)

    notes = Column(Text)
EOF


cat > backend/app/schemas.py <<'EOF'
from typing import Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    role: str = "learner"


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: str

    class Config:
        from_attributes = True


class PodCreate(BaseModel):
    name: str
    description: Optional[str] = None
    guide_id: Optional[int] = None


class CourseCreate(BaseModel):
    title: str
    description: Optional[str] = None
    subject: Optional[str] = None
    grade_level: Optional[str] = None


class LessonCreate(BaseModel):
    title: str
    description: Optional[str] = None
    content: Optional[str] = None
    position: int = 0


class ProgressUpdate(BaseModel):
    completed: bool
    score: Optional[float] = None
EOF


cat > backend/app/auth.py <<'EOF'
from datetime import datetime, timedelta

from jose import jwt
from passlib.context import CryptContext

from .config import settings


ALGORITHM = "HS256"

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(
    plain_password: str,
    password_hash: str,
) -> bool:
    return pwd_context.verify(
        plain_password,
        password_hash,
    )


def create_access_token(user_id: int) -> str:
    expires = datetime.utcnow() + timedelta(hours=24)

    payload = {
        "sub": str(user_id),
        "exp": expires,
    }

    return jwt.encode(
        payload,
        settings.secret_key,
        algorithm=ALGORITHM,
    )
EOF


cat > backend/app/routes/__init__.py <<'EOF'
EOF


cat > backend/app/routes/auth.py <<'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import hash_password
from ..database import get_db
from ..models import User
from ..schemas import UserCreate, UserResponse


router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


@router.post(
    "/register",
    response_model=UserResponse,
)
def register(
    user_data: UserCreate,
    db: Session = Depends(get_db),
):
    existing = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        )

    user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(
            user_data.password
        ),
        role=user_data.role,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user
EOF


cat > backend/app/routes/learners.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User


router = APIRouter(
    prefix="/api/learners",
    tags=["learners"],
)


@router.get("/")
def list_learners(
    db: Session = Depends(get_db),
):
    learners = (
        db.query(User)
        .filter(User.role == "learner")
        .all()
    )

    return [
        {
            "id": learner.id,
            "name": learner.name,
            "email": learner.email,
        }
        for learner in learners
    ]
EOF


cat > backend/app/routes/pods.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Pod
from ..schemas import PodCreate


router = APIRouter(
    prefix="/api/pods",
    tags=["pods"],
)


@router.get("/")
def list_pods(
    db: Session = Depends(get_db),
):
    return db.query(Pod).all()


@router.post("/")
def create_pod(
    pod_data: PodCreate,
    db: Session = Depends(get_db),
):
    pod = Pod(
        name=pod_data.name,
        description=pod_data.description,
        guide_id=pod_data.guide_id,
    )

    db.add(pod)
    db.commit()
    db.refresh(pod)

    return pod
EOF


cat > backend/app/routes/courses.py <<'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Course, Lesson
from ..schemas import CourseCreate, LessonCreate


router = APIRouter(
    prefix="/api/courses",
    tags=["courses"],
)


@router.get("/")
def list_courses(
    db: Session = Depends(get_db),
):
    return db.query(Course).all()


@router.post("/")
def create_course(
    course_data: CourseCreate,
    db: Session = Depends(get_db),
):
    course = Course(
        title=course_data.title,
        description=course_data.description,
        subject=course_data.subject,
        grade_level=course_data.grade_level,
    )

    db.add(course)
    db.commit()
    db.refresh(course)

    return course


@router.post("/{course_id}/lessons")
def create_lesson(
    course_id: int,
    lesson_data: LessonCreate,
    db: Session = Depends(get_db),
):
    lesson = Lesson(
        course_id=course_id,
        title=lesson_data.title,
        description=lesson_data.description,
        content=lesson_data.content,
        position=lesson_data.position,
    )

    db.add(lesson)
    db.commit()
    db.refresh(lesson)

    return lesson
EOF


cat > backend/app/routes/progress.py <<'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import LearnerProgress
from ..schemas import ProgressUpdate


router = APIRouter(
    prefix="/api/progress",
    tags=["progress"],
)


@router.get("/{learner_id}")
def learner_progress(
    learner_id: int,
    db: Session = Depends(get_db),
):
    return (
        db.query(LearnerProgress)
        .filter(
            LearnerProgress.learner_id
            == learner_id
        )
        .all()
    )


@router.put("/{learner_id}/{lesson_id}")
def update_progress(
    learner_id: int,
    lesson_id: int,
    progress_data: ProgressUpdate,
    db: Session = Depends(get_db),
):
    progress = (
        db.query(LearnerProgress)
        .filter(
            LearnerProgress.learner_id
            == learner_id,
            LearnerProgress.lesson_id
            == lesson_id,
        )
        .first()
    )

    if not progress:
        progress = LearnerProgress(
            learner_id=learner_id,
            lesson_id=lesson_id,
        )

        db.add(progress)

    progress.completed = progress_data.completed
    progress.score = progress_data.score
    progress.attempts += 1

    db.commit()
    db.refresh(progress)

    return progress
EOF


cat > backend/app/main.py <<'EOF'
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
EOF


cat > backend/tests/test_health.py <<'EOF'
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health():
    response = client.get("/api/health")

    assert response.status_code == 200

    assert response.json()["status"] == "ok"
EOF


cat > frontend/index.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">

    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >

    <title>Microschool</title>

    <link
        rel="stylesheet"
        href="/styles.css"
    >
</head>

<body>

<header class="topbar">
    <div class="brand">
        Microschool
    </div>

    <nav>
        <a href="#dashboard">Dashboard</a>
        <a href="#learners">Learners</a>
        <a href="#courses">Courses</a>
        <a href="#pods">Pods</a>
    </nav>
</header>


<main>

<section id="dashboard" class="hero">

    <div>
        <p class="eyebrow">
            PERSONAL LEARNING PLATFORM
        </p>

        <h1>
            Learn at your own pace.
        </h1>

        <p>
            A small learning environment for
            learners, guides, and families.
        </p>
    </div>

</section>


<section class="dashboard-grid">

    <article class="card">
        <h2>Learners</h2>
        <div id="learner-count">Loading...</div>
    </article>

    <article class="card">
        <h2>Pods</h2>
        <div id="pod-count">Loading...</div>
    </article>

    <article class="card">
        <h2>Courses</h2>
        <div id="course-count">Loading...</div>
    </article>

</section>


<section id="learners" class="section">

    <h2>Learners</h2>

    <div id="learners-list">
        Loading...
    </div>

</section>


<section id="courses" class="section">

    <h2>Courses</h2>

    <div id="courses-list">
        Loading...
    </div>

</section>

</main>


<script src="/app.js"></script>

</body>
</html>
EOF


cat > frontend/app.js <<'EOF'
async function getJSON(url) {
    const response = await fetch(url);

    if (!response.ok) {
        throw new Error(
            `Request failed: ${response.status}`
        );
    }

    return response.json();
}


async function loadDashboard() {
    try {
        const learners =
            await getJSON("/api/learners/");

        const pods =
            await getJSON("/api/pods/");

        const courses =
            await getJSON("/api/courses/");


        document.getElementById(
            "learner-count"
        ).textContent = learners.length;


        document.getElementById(
            "pod-count"
        ).textContent = pods.length;


        document.getElementById(
            "course-count"
        ).textContent = courses.length;


        renderLearners(learners);
        renderCourses(courses);

    } catch (error) {
        console.error(error);

        document.getElementById(
            "learners-list"
        ).textContent =
            "Unable to load learners.";

        document.getElementById(
            "courses-list"
        ).textContent =
            "Unable to load courses.";
    }
}


function renderLearners(learners) {
    const container =
        document.getElementById(
            "learners-list"
        );

    if (learners.length === 0) {
        container.innerHTML =
            "<p>No learners yet.</p>";

        return;
    }

    container.innerHTML = learners
        .map(
            learner => `
                <article class="list-item">
                    <strong>${learner.name}</strong>
                    <span>${learner.email}</span>
                </article>
            `
        )
        .join("");
}


function renderCourses(courses) {
    const container =
        document.getElementById(
            "courses-list"
        );

    if (courses.length === 0) {
        container.innerHTML =
            "<p>No courses yet.</p>";

        return;
    }

    container.innerHTML = courses
        .map(
            course => `
                <article class="list-item">
                    <strong>${course.title}</strong>
                    <span>
                        ${course.subject || "General"}
                    </span>
                </article>
            `
        )
        .join("");
}


loadDashboard();
EOF


cat > frontend/styles.css <<'EOF'
* {
    box-sizing: border-box;
}


body {
    margin: 0;

    font-family:
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;

    background: #f5f7fb;

    color: #172033;
}


.topbar {
    display: flex;

    justify-content: space-between;
    align-items: center;

    padding: 18px 32px;

    background: white;

    border-bottom: 1px solid #e4e8ef;
}


.brand {
    font-size: 1.3rem;
    font-weight: 800;
}


nav {
    display: flex;
    gap: 20px;
}


nav a {
    color: #536071;
    text-decoration: none;
}


main {
    max-width: 1100px;

    margin: 0 auto;

    padding: 40px 24px;
}


.hero {
    background: white;

    border-radius: 20px;

    padding: 48px;

    margin-bottom: 24px;

    box-shadow:
        0 10px 30px
        rgba(0, 0, 0, 0.05);
}


.eyebrow {
    font-size: 0.75rem;

    font-weight: 800;

    letter-spacing: 0.1em;

    color: #697586;
}


.hero h1 {
    font-size: 3rem;

    margin: 10px 0;
}


.hero p {
    color: #657083;

    font-size: 1.1rem;
}


.dashboard-grid {
    display: grid;

    grid-template-columns:
        repeat(3, 1fr);

    gap: 20px;
}


.card {
    background: white;

    padding: 24px;

    border-radius: 16px;

    border: 1px solid #e4e8ef;
}


.card h2 {
    font-size: 1rem;

    color: #697586;
}


.card div {
    font-size: 2.5rem;

    font-weight: 800;
}


.section {
    margin-top: 40px;
}


.list-item {
    display: flex;

    justify-content: space-between;

    padding: 18px;

    margin-bottom: 10px;

    background: white;

    border: 1px solid #e4e8ef;

    border-radius: 12px;
}


.list-item span {
    color: #697586;
}


@media (max-width: 700px) {

    .topbar {
        flex-direction: column;
        gap: 16px;
    }

    .dashboard-grid {
        grid-template-columns: 1fr;
    }

    .hero {
        padding: 30px;
    }

    .hero h1 {
        font-size: 2.2rem;
    }

    .list-item {
        flex-direction: column;
        gap: 6px;
    }
}
EOF


cat > .env.example <<'EOF'
SECRET_KEY=replace-this-with-a-random-secret
DATABASE_URL=sqlite:///./data/microschool.db
EOF


cat > .gitignore <<'EOF'
__pycache__/
*.py[cod]
.pytest_cache/

.venv/
venv/
env/

.env

*.db
*.sqlite
*.sqlite3

.DS_Store
EOF


cat > run.sh <<'EOF'
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
EOF


cat > README.md <<'EOF'
# Microschool

A personal learning project for understanding how a microschool learning platform can work.

This project is inspired by general microschool concepts such as:

- small learning communities
- learner-centered progress
- guides/mentors
- individualized learning
- parent visibility
- curriculum and progress tracking

It is not an implementation or reproduction of any proprietary platform.


## Architecture

Frontend:

- HTML
- CSS
- JavaScript

Backend:

- Python
- FastAPI
- SQLAlchemy
- SQLite

Authentication:

- JWT


## Setup

Run:

    ./scripts/create-files.sh

Then:

    ./scripts/fill-files.sh

Then:

    ./run.sh


Open:

    http://127.0.0.1:8000

API documentation:

    http://127.0.0.1:8000/docs


## Development Roadmap

Phase 1:

- users
- roles
- pods
- courses
- lessons
- progress

Phase 2:

- authentication
- dashboards
- assignments
- quizzes
- attendance

Phase 3:

- parent accounts
- learner goals
- notifications
- guide notes

Phase 4:

- individualized learning paths
- analytics
- mastery tracking
- recommendation engine

Phase 5:

- PostgreSQL
- Docker
- production deployment
EOF


chmod +x run.sh

echo ""
echo "All files have been populated."
echo ""
echo "Run:"
echo ""
echo "    ./run.sh"
echo ""
