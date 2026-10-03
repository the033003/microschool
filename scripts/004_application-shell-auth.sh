#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="004_application-shell-auth"
BACKUP_DIR="$ROOT/backups/$BUILD"

mkdir -p "$BACKUP_DIR"

echo "Creating pre-build backup..."

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
    cp "$ROOT/PROJECT_STATUS.md" "$BACKUP_DIR/PROJECT_STATUS-before.md"
fi

echo "Updating authentication..."

cat > backend/app/auth.py <<'PY'
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import secrets

from jose import jwt

from .config import settings


ALGORITHM = "HS256"
PBKDF2_ITERATIONS = 600_000


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)

    derived = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        PBKDF2_ITERATIONS,
    )

    return (
        f"pbkdf2_sha256${PBKDF2_ITERATIONS}$"
        f"{salt.hex()}${derived.hex()}"
    )


def verify_password(
    plain_password: str,
    password_hash: str,
) -> bool:
    try:
        algorithm, iterations, salt_hex, hash_hex = (
            password_hash.split("$")
        )

        if algorithm != "pbkdf2_sha256":
            return False

        derived = hashlib.pbkdf2_hmac(
            "sha256",
            plain_password.encode("utf-8"),
            bytes.fromhex(salt_hex),
            int(iterations),
        )

        return hmac.compare_digest(
            derived.hex(),
            hash_hex,
        )
    except (ValueError, TypeError):
        return False


def create_access_token(user_id: int) -> str:
    expires = datetime.now(timezone.utc) + timedelta(hours=24)

    payload = {
        "sub": str(user_id),
        "exp": expires,
    }

    return jwt.encode(
        payload,
        settings.secret_key,
        algorithm=ALGORITHM,
    )
PY

cat > backend/app/dependencies.py <<'PY'
from typing import Callable

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from .auth import ALGORITHM
from .config import settings
from .database import get_db
from .models import User


oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/api/auth/login"
)


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired authentication credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[ALGORITHM],
        )

        user_id = payload.get("sub")

        if not user_id:
            raise credentials_error

        user_id = int(user_id)

    except (JWTError, ValueError, TypeError):
        raise credentials_error

    user = db.query(User).filter(
        User.id == user_id
    ).first()

    if not user or not user.active:
        raise credentials_error

    return user


def require_roles(*roles: str) -> Callable:
    def dependency(
        current_user: User = Depends(get_current_user),
    ) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )

        return current_user

    return dependency
PY

cat > backend/app/schemas.py <<'PY'
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: str = "learner"


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: str
    active: bool

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


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
PY

cat > backend/app/routes/auth.py <<'PY'
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from ..auth import create_access_token, hash_password, verify_password
from ..database import get_db
from ..dependencies import get_current_user
from ..models import User
from ..schemas import TokenResponse, UserCreate, UserResponse


router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


PUBLIC_ROLES = {"learner", "parent"}


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    user_data: UserCreate,
    db: Session = Depends(get_db),
):
    existing = (
        db.query(User)
        .filter(User.email == user_data.email.lower())
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail="An account with this email already exists",
        )

    if user_data.role not in PUBLIC_ROLES:
        raise HTTPException(
            status_code=400,
            detail="That account type requires an invitation",
        )

    user = User(
        name=user_data.name.strip(),
        email=user_data.email.lower(),
        password_hash=hash_password(user_data.password),
        role=user_data.role,
        active=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = (
        db.query(User)
        .filter(User.email == form_data.username.lower())
        .first()
    )

    if not user or not verify_password(
        form_data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is inactive",
        )

    return {
        "access_token": create_access_token(user.id),
        "token_type": "bearer",
        "user": user,
    }


@router.get(
    "/me",
    response_model=UserResponse,
)
def me(
    current_user: User = Depends(get_current_user),
):
    return current_user
PY

cat > backend/app/routes/learners.py <<'PY'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import require_roles
from ..models import User


router = APIRouter(
    prefix="/api/learners",
    tags=["learners"],
)


@router.get("/")
def list_learners(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "guide",
            "organization_admin",
            "platform_admin",
        )
    ),
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
PY

cat > backend/app/routes/pods.py <<'PY'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import require_roles
from ..models import Pod, User
from ..schemas import PodCreate


router = APIRouter(
    prefix="/api/pods",
    tags=["pods"],
)


@router.get("/")
def list_pods(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "guide",
            "organization_admin",
            "platform_admin",
        )
    ),
):
    return db.query(Pod).all()


@router.post("/")
def create_pod(
    pod_data: PodCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "guide",
            "organization_admin",
            "platform_admin",
        )
    ),
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
PY

cat > backend/app/routes/courses.py <<'PY'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import require_roles
from ..models import Course, Lesson, User
from ..schemas import CourseCreate, LessonCreate


router = APIRouter(
    prefix="/api/courses",
    tags=["courses"],
)


@router.get("/")
def list_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "learner",
            "parent",
            "guide",
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
):
    return db.query(Course).filter(
        Course.active == True
    ).all()


@router.post("/")
def create_course(
    course_data: CourseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
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
    current_user: User = Depends(
        require_roles(
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
):
    course = db.query(Course).filter(
        Course.id == course_id
    ).first()

    if not course:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=404,
            detail="Course not found",
        )

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
PY

cat > backend/app/routes/progress.py <<'PY'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import get_current_user
from ..models import LearnerProgress, User
from ..schemas import ProgressUpdate


router = APIRouter(
    prefix="/api/progress",
    tags=["progress"],
)


@router.get("/{learner_id}")
def learner_progress(
    learner_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if (
        current_user.id != learner_id
        and current_user.role
        not in {
            "guide",
            "organization_admin",
            "platform_admin",
        }
    ):
        raise HTTPException(
            status_code=403,
            detail="You do not have access to this learner's progress",
        )

    return (
        db.query(LearnerProgress)
        .filter(
            LearnerProgress.learner_id == learner_id
        )
        .all()
    )


@router.put("/{learner_id}/{lesson_id}")
def update_progress(
    learner_id: int,
    lesson_id: int,
    progress_data: ProgressUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.id != learner_id:
        raise HTTPException(
            status_code=403,
            detail="You can only update your own progress",
        )

    progress = (
        db.query(LearnerProgress)
        .filter(
            LearnerProgress.learner_id == learner_id,
            LearnerProgress.lesson_id == lesson_id,
        )
        .first()
    )

    if not progress:
        progress = LearnerProgress(
            learner_id=learner_id,
            lesson_id=lesson_id,
            attempts=0,
        )
        db.add(progress)

    progress.completed = progress_data.completed
    progress.score = progress_data.score
    progress.attempts += 1

    db.commit()
    db.refresh(progress)

    return progress
PY

cat > backend/app/main.py <<'PY'
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
    title="Microschool Platform",
    version="0.2.0",
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
app.include_router(learners.router)
app.include_router(pods.router)
app.include_router(courses.router)
app.include_router(progress.router)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "application": "Microschool",
        "version": "0.2.0",
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
PY

cat > frontend/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >
    <meta
        name="description"
        content="Microschool platform"
    >
    <title>Microschool</title>
    <link rel="stylesheet" href="/styles.css">
</head>

<body>
    <div id="app"></div>

    <script src="/app.js"></script>
</body>
</html>
HTML

cat > frontend/app.js <<'JS'
const state = {
    token: localStorage.getItem("microschool_token"),
    user: null,
    page: "home",
    courses: [],
};


async function api(url, options = {}) {
    const headers = {
        ...(options.headers || {}),
    };

    if (state.token) {
        headers.Authorization = `Bearer ${state.token}`;
    }

    if (
        options.body &&
        typeof options.body !== "string"
    ) {
        headers["Content-Type"] = "application/json";
        options.body = JSON.stringify(options.body);
    }

    const response = await fetch(url, {
        ...options,
        headers,
    });

    if (!response.ok) {
        let message = "Something went wrong.";

        try {
            const data = await response.json();
            message = data.detail || message;
        } catch (_) {
            // Keep the default message.
        }

        throw new Error(message);
    }

    return response.json();
}


function escapeHTML(value) {
    return String(value ?? "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#039;");
}


function render() {
    if (!state.user) {
        renderAuth();
        return;
    }

    renderApp();
}


function renderAuth() {
    document.getElementById("app").innerHTML = `
        <main class="auth-page">
            <section class="auth-panel">
                <div class="brand-mark">M</div>

                <p class="eyebrow">MICROSCHOOL PLATFORM</p>

                <h1>Build a learning environment that fits your people.</h1>

                <p class="auth-intro">
                    A shared platform for learners, families, guides,
                    organizations, and the people who create resources.
                </p>

                <div class="auth-card">
                    <div class="auth-tabs">
                        <button
                            class="tab active"
                            data-auth-tab="login"
                        >
                            Sign in
                        </button>

                        <button
                            class="tab"
                            data-auth-tab="register"
                        >
                            Create account
                        </button>
                    </div>

                    <form id="auth-form">
                        <div id="auth-fields"></div>

                        <button
                            class="primary-button full-width"
                            type="submit"
                        >
                            <span id="auth-submit">Sign in</span>
                        </button>

                        <p
                            id="auth-error"
                            class="form-error"
                            hidden
                        ></p>
                    </form>
                </div>
            </section>
        </main>
    `;

    let mode = "login";

    const fields = document.getElementById("auth-fields");
    const tabs = document.querySelectorAll("[data-auth-tab]");
    const form = document.getElementById("auth-form");
    const submit = document.getElementById("auth-submit");
    const error = document.getElementById("auth-error");

    function updateForm() {
        tabs.forEach(tab => {
            tab.classList.toggle(
                "active",
                tab.dataset.authTab === mode
            );
        });

        if (mode === "login") {
            fields.innerHTML = `
                <label>
                    Email
                    <input
                        name="email"
                        type="email"
                        autocomplete="email"
                        required
                    >
                </label>

                <label>
                    Password
                    <input
                        name="password"
                        type="password"
                        autocomplete="current-password"
                        required
                    >
                </label>
            `;

            submit.textContent = "Sign in";
        } else {
            fields.innerHTML = `
                <label>
                    Name
                    <input
                        name="name"
                        type="text"
                        autocomplete="name"
                        required
                    >
                </label>

                <label>
                    Email
                    <input
                        name="email"
                        type="email"
                        autocomplete="email"
                        required
                    >
                </label>

                <label>
                    I am joining as
                    <select name="role">
                        <option value="learner">Learner</option>
                        <option value="parent">Parent</option>
                    </select>
                </label>

                <label>
                    Password
                    <input
                        name="password"
                        type="password"
                        autocomplete="new-password"
                        minlength="8"
                        required
                    >
                </label>
            `;

            submit.textContent = "Create account";
        }

        error.hidden = true;
    }

    tabs.forEach(tab => {
        tab.addEventListener("click", () => {
            mode = tab.dataset.authTab;
            updateForm();
        });
    });

    form.addEventListener("submit", async event => {
        event.preventDefault();

        const data = new FormData(form);
        error.hidden = true;
        submit.textContent = "Working...";

        try {
            if (mode === "login") {
                const body = new URLSearchParams();

                body.set("username", data.get("email"));
                body.set("password", data.get("password"));

                const result = await fetch(
                    "/api/auth/login",
                    {
                        method: "POST",
                        headers: {
                            "Content-Type":
                                "application/x-www-form-urlencoded",
                        },
                        body,
                    }
                );

                if (!result.ok) {
                    const payload = await result.json();
                    throw new Error(
                        payload.detail || "Unable to sign in."
                    );
                }

                const payload = await result.json();

                state.token = payload.access_token;
                state.user = payload.user;

                localStorage.setItem(
                    "microschool_token",
                    state.token
                );

                render();
                return;
            }

            const payload = await api(
                "/api/auth/register",
                {
                    method: "POST",
                    body: {
                        name: data.get("name"),
                        email: data.get("email"),
                        password: data.get("password"),
                        role: data.get("role"),
                    },
                }
            );

            const loginBody = new URLSearchParams();
            loginBody.set("username", data.get("email"));
            loginBody.set("password", data.get("password"));

            const loginResult = await fetch(
                "/api/auth/login",
                {
                    method: "POST",
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded",
                    },
                    body: loginBody,
                }
            );

            if (!loginResult.ok) {
                throw new Error(
                    "Account created, but automatic sign-in failed."
                );
            }

            const loginPayload = await loginResult.json();

            state.token = loginPayload.access_token;
            state.user = loginPayload.user;

            localStorage.setItem(
                "microschool_token",
                state.token
            );

            render();
        } catch (err) {
            error.textContent = err.message;
            error.hidden = false;
            submit.textContent =
                mode === "login"
                    ? "Sign in"
                    : "Create account";
        }
    });

    updateForm();
}


function navigationForRole(role) {
    const base = [
        ["home", "Overview"],
        ["learning", "Learning"],
        ["resources", "Resources"],
    ];

    if (
        role === "guide" ||
        role === "organization_admin" ||
        role === "platform_admin"
    ) {
        base.push(["people", "People"]);
    }

    if (
        role === "organization_admin" ||
        role === "platform_admin"
    ) {
        base.push(["organization", "Organization"]);
    }

    return base;
}


function renderApp() {
    const navigation = navigationForRole(
        state.user.role
    );

    document.getElementById("app").innerHTML = `
        <div class="app-shell">
            <aside class="sidebar">
                <div class="sidebar-brand">
                    <div class="brand-mark small">M</div>

                    <div>
                        <strong>Microschool</strong>
                        <span>Platform</span>
                    </div>
                </div>

                <nav class="sidebar-nav">
                    ${navigation.map(([id, label]) => `
                        <button
                            class="nav-item ${
                                state.page === id
                                    ? "active"
                                    : ""
                            }"
                            data-page="${id}"
                        >
                            ${label}
                        </button>
                    `).join("")}
                </nav>

                <div class="sidebar-bottom">
                    <div class="user-mini">
                        <div class="avatar">
                            ${escapeHTML(
                                state.user.name
                                    .charAt(0)
                                    .toUpperCase()
                            )}
                        </div>

                        <div>
                            <strong>
                                ${escapeHTML(state.user.name)}
                            </strong>

                            <span>
                                ${formatRole(state.user.role)}
                            </span>
                        </div>
                    </div>

                    <button
                        class="logout-button"
                        id="logout"
                    >
                        Sign out
                    </button>
                </div>
            </aside>

            <div class="main-shell">
                <header class="topbar">
                    <div>
                        <span class="topbar-label">
                            ${pageLabel(state.page)}
                        </span>
                    </div>

                    <div class="topbar-user">
                        ${escapeHTML(state.user.email)}
                    </div>
                </header>

                <main class="content">
                    <div id="page-content"></div>
                </main>
            </div>
        </div>
    `;

    document
        .querySelectorAll("[data-page]")
        .forEach(button => {
            button.addEventListener("click", () => {
                state.page = button.dataset.page;
                renderApp();
            });
        });

    document
        .getElementById("logout")
        .addEventListener("click", logout);

    renderPage();
}


function pageLabel(page) {
    return {
        home: "Overview",
        learning: "Learning",
        resources: "Resources",
        people: "People",
        organization: "Organization",
    }[page] || "Microschool";
}


function formatRole(role) {
    return role
        .replaceAll("_", " ")
        .replace(/\b\w/g, letter =>
            letter.toUpperCase()
        );
}


async function renderPage() {
    const container =
        document.getElementById("page-content");

    if (state.page === "home") {
        renderHome(container);
        return;
    }

    if (state.page === "learning") {
        await renderLearning(container);
        return;
    }

    if (state.page === "resources") {
        renderResources(container);
        return;
    }

    if (state.page === "people") {
        await renderPeople(container);
        return;
    }

    if (state.page === "organization") {
        renderOrganization(container);
        return;
    }

    renderHome(container);
}


function renderHome(container) {
    const role = state.user.role;

    let heading = "Welcome back.";
    let description =
        "Your platform workspace is ready.";

    if (role === "learner") {
        heading = `Welcome back, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your learning workspace is where your current work, progress, and resources will come together.";
    }

    if (role === "parent") {
        heading = `Welcome, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your family workspace will bring together learning progress, schedules, resources, and communication.";
    }

    if (role === "guide") {
        heading = `Welcome, ${escapeHTML(
            state.user.name
        )}.`;

        description =
            "Your guide workspace will bring together pods, learners, attendance, assignments, and resources.";
    }

    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">
                    ${formatRole(state.user.role)}
                </p>

                <h1>${heading}</h1>

                <p>${description}</p>
            </div>
        </section>

        <section class="dashboard-grid">
            <article class="dashboard-card">
                <span class="card-label">Learning</span>
                <h2>My learning</h2>
                <p>
                    Courses, activities, progress, and
                    the next things to work on.
                </p>

                <button
                    class="text-button"
                    data-page="learning"
                >
                    Open learning →
                </button>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Resources</span>
                <h2>Resource library</h2>
                <p>
                    Reusable platform resources will live
                    here instead of being hardcoded into the app.
                </p>

                <button
                    class="text-button"
                    data-page="resources"
                >
                    Browse resources →
                </button>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Account</span>
                <h2>Your workspace</h2>
                <p>
                    Signed in as
                    ${escapeHTML(state.user.email)}.
                </p>
            </article>
        </section>

        <section class="section-heading">
            <div>
                <p class="eyebrow">PLATFORM STATUS</p>
                <h2>Core platform</h2>
            </div>
        </section>

        <section class="status-grid">
            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Identity</strong>
                    <span>Connected</span>
                </div>
            </div>

            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Content system</strong>
                    <span>Foundation ready</span>
                </div>
            </div>

            <div class="status-item">
                <span class="status-dot"></span>
                <div>
                    <strong>Learning system</strong>
                    <span>Foundation ready</span>
                </div>
            </div>
        </section>
    `;

    container
        .querySelectorAll("[data-page]")
        .forEach(button => {
            button.addEventListener("click", () => {
                state.page = button.dataset.page;
                renderApp();
            });
        });
}


async function renderLearning(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">LEARNING</p>
                <h1>My learning</h1>
                <p>
                    Learning content will be supplied through
                    the platform's content system.
                </p>
            </div>
        </section>

        <section class="empty-panel">
            <div class="empty-icon">+</div>

            <h2>No learning assigned yet</h2>

            <p>
                Courses, units, lessons, activities, and
                assessments will appear here when they are
                provided by an organization or content creator.
            </p>
        </section>
    `;

    try {
        state.courses = await api("/api/courses/");

        if (state.courses.length === 0) {
            return;
        }

        container.querySelector(".empty-panel").outerHTML = `
            <section class="content-list">
                ${state.courses.map(course => `
                    <article class="content-card">
                        <div>
                            <span class="card-label">
                                ${escapeHTML(
                                    course.subject ||
                                    "Learning"
                                )}
                            </span>

                            <h2>
                                ${escapeHTML(course.title)}
                            </h2>

                            <p>
                                ${escapeHTML(
                                    course.description ||
                                    "No description provided."
                                )}
                            </p>
                        </div>

                        <button class="secondary-button">
                            Open
                        </button>
                    </article>
                `).join("")}
            </section>
        `;
    } catch (error) {
        container.querySelector(
            ".empty-panel"
        ).innerHTML = `
            <h2>Learning is temporarily unavailable</h2>
            <p>${escapeHTML(error.message)}</p>
        `;
    }
}


function renderResources(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">RESOURCE LIBRARY</p>
                <h1>Resources</h1>
                <p>
                    A shared home for guides, playbooks,
                    templates, articles, and other platform content.
                </p>
            </div>

            <button class="secondary-button">
                Browse all
            </button>
        </section>

        <section class="resource-grid">
            <article class="resource-card">
                <span class="resource-type">
                    Platform
                </span>
                <h2>Microschool resources</h2>
                <p>
                    Site-created guides and operational
                    resources will be published here.
                </p>
            </article>

            <article class="resource-card">
                <span class="resource-type">
                    Community
                </span>
                <h2>Community resources</h2>
                <p>
                    Approved resources created by
                    participating people and organizations.
                </p>
            </article>

            <article class="resource-card">
                <span class="resource-type">
                    Organization
                </span>
                <h2>Organization resources</h2>
                <p>
                    Private resources shared by your
                    organization.
                </p>
            </article>
        </section>
    `;
}


async function renderPeople(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">PEOPLE</p>
                <h1>Learners</h1>
                <p>
                    People connected to the guide or organization
                    workspace.
                </p>
            </div>
        </section>

        <section class="empty-panel" id="people-panel">
            <h2>Loading learners...</h2>
        </section>
    `;

    try {
        const learners =
            await api("/api/learners/");

        const panel =
            document.getElementById("people-panel");

        if (learners.length === 0) {
            panel.innerHTML = `
                <div class="empty-icon">+</div>
                <h2>No learners yet</h2>
                <p>
                    Learners will appear here when they
                    join an organization or pod.
                </p>
            `;

            return;
        }

        panel.outerHTML = `
            <section class="people-list">
                ${learners.map(learner => `
                    <article class="person-row">
                        <div class="avatar">
                            ${escapeHTML(
                                learner.name
                                    .charAt(0)
                                    .toUpperCase()
                            )}
                        </div>

                        <div>
                            <strong>
                                ${escapeHTML(learner.name)}
                            </strong>

                            <span>
                                ${escapeHTML(learner.email)}
                            </span>
                        </div>
                    </article>
                `).join("")}
            </section>
        `;
    } catch (error) {
        document.getElementById(
            "people-panel"
        ).innerHTML = `
            <h2>Unable to load learners</h2>
            <p>${escapeHTML(error.message)}</p>
        `;
    }
}


function renderOrganization(container) {
    container.innerHTML = `
        <section class="page-heading">
            <div>
                <p class="eyebrow">ORGANIZATION</p>
                <h1>Organization workspace</h1>
                <p>
                    Organization setup, members, pods,
                    permissions, and configuration will live here.
                </p>
            </div>
        </section>

        <section class="dashboard-grid">
            <article class="dashboard-card">
                <span class="card-label">Structure</span>
                <h2>Pods</h2>
                <p>
                    Create and manage the groups that make
                    up an organization.
                </p>
            </article>

            <article class="dashboard-card">
                <span class="card-label">People</span>
                <h2>Members</h2>
                <p>
                    Manage organization membership and roles.
                </p>
            </article>

            <article class="dashboard-card">
                <span class="card-label">Access</span>
                <h2>Permissions</h2>
                <p>
                    Control what different people can create,
                    manage, review, and publish.
                </p>
            </article>
        </section>
    `;
}


function logout() {
    state.token = null;
    state.user = null;
    localStorage.removeItem("microschool_token");
    render();
}


async function initialize() {
    if (!state.token) {
        render();
        return;
    }

    try {
        state.user = await api("/api/auth/me");
        render();
    } catch (_) {
        state.token = null;
        localStorage.removeItem("microschool_token");
        render();
    }
}


initialize();
JS

cat > frontend/styles.css <<'CSS'
:root {
    --bg: #f6f7f9;
    --surface: #ffffff;
    --surface-soft: #f1f3f6;
    --text: #17202b;
    --muted: #6d7785;
    --border: #e2e6eb;
    --accent: #1d4ed8;
    --accent-dark: #173ea8;
    --success: #198754;
    --sidebar: #111827;
    --sidebar-muted: #9ca3af;
    --shadow: 0 12px 35px rgba(16, 24, 40, 0.07);
}


* {
    box-sizing: border-box;
}


html,
body {
    margin: 0;
    min-height: 100%;
}


body {
    background: var(--bg);
    color: var(--text);
    font-family:
        Inter,
        ui-sans-serif,
        system-ui,
        -apple-system,
        BlinkMacSystemFont,
        "Segoe UI",
        sans-serif;
}


button,
input,
select {
    font: inherit;
}


button {
    cursor: pointer;
}


.auth-page {
    min-height: 100vh;
    display: grid;
    place-items: center;
    padding: 32px 20px;
    background:
        radial-gradient(
            circle at top left,
            rgba(29, 78, 216, 0.08),
            transparent 34%
        ),
        var(--bg);
}


.auth-panel {
    width: min(100%, 520px);
}


.brand-mark {
    width: 46px;
    height: 46px;
    display: grid;
    place-items: center;
    border-radius: 13px;
    background: var(--sidebar);
    color: white;
    font-weight: 800;
    font-size: 1.25rem;
}


.brand-mark.small {
    width: 36px;
    height: 36px;
    border-radius: 10px;
    font-size: 1rem;
}


.eyebrow {
    margin: 0 0 10px;
    color: var(--muted);
    font-size: 0.72rem;
    font-weight: 800;
    letter-spacing: 0.12em;
    text-transform: uppercase;
}


.auth-panel > .eyebrow {
    margin-top: 26px;
}


.auth-panel h1 {
    margin: 0;
    max-width: 600px;
    font-size: clamp(2rem, 5vw, 3.4rem);
    line-height: 1.05;
    letter-spacing: -0.04em;
}


.auth-intro {
    color: var(--muted);
    line-height: 1.7;
    font-size: 1rem;
    margin: 20px 0 28px;
}


.auth-card {
    padding: 24px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 18px;
    box-shadow: var(--shadow);
}


.auth-tabs {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4px;
    padding: 4px;
    margin-bottom: 22px;
    background: var(--surface-soft);
    border-radius: 10px;
}


.tab {
    border: 0;
    background: transparent;
    color: var(--muted);
    padding: 10px;
    border-radius: 7px;
}


.tab.active {
    background: var(--surface);
    color: var(--text);
    box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
}


form label {
    display: grid;
    gap: 8px;
    margin-bottom: 16px;
    color: #374151;
    font-size: 0.88rem;
    font-weight: 650;
}


input,
select {
    width: 100%;
    border: 1px solid var(--border);
    border-radius: 9px;
    background: white;
    color: var(--text);
    padding: 12px 13px;
    outline: none;
}


input:focus,
select:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 3px rgba(29, 78, 216, 0.1);
}


.primary-button,
.secondary-button {
    border-radius: 9px;
    padding: 11px 16px;
    font-weight: 700;
}


.primary-button {
    border: 1px solid var(--accent);
    background: var(--accent);
    color: white;
}


.primary-button:hover {
    background: var(--accent-dark);
}


.secondary-button {
    border: 1px solid var(--border);
    background: white;
    color: var(--text);
}


.full-width {
    width: 100%;
}


.form-error {
    color: #b42318;
    font-size: 0.88rem;
    margin: 14px 0 0;
}


.app-shell {
    min-height: 100vh;
    display: flex;
}


.sidebar {
    width: 248px;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    padding: 20px 14px;
    background: var(--sidebar);
    color: white;
}


.sidebar-brand {
    display: flex;
    align-items: center;
    gap: 11px;
    padding: 4px 8px 28px;
}


.sidebar-brand strong,
.sidebar-brand span {
    display: block;
}


.sidebar-brand strong {
    font-size: 0.95rem;
}


.sidebar-brand span {
    margin-top: 2px;
    color: var(--sidebar-muted);
    font-size: 0.74rem;
}


.sidebar-nav {
    display: grid;
    gap: 4px;
}


.nav-item {
    border: 0;
    background: transparent;
    color: var(--sidebar-muted);
    text-align: left;
    padding: 11px 12px;
    border-radius: 8px;
}


.nav-item:hover,
.nav-item.active {
    background: rgba(255, 255, 255, 0.09);
    color: white;
}


.sidebar-bottom {
    margin-top: auto;
}


.user-mini {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 14px 8px;
    border-top: 1px solid rgba(255, 255, 255, 0.08);
}


.avatar {
    width: 36px;
    height: 36px;
    flex: 0 0 36px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: #e7ebf0;
    color: #334155;
    font-weight: 800;
}


.user-mini strong,
.user-mini span {
    display: block;
}


.user-mini strong {
    max-width: 140px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: 0.84rem;
}


.user-mini span {
    margin-top: 2px;
    color: var(--sidebar-muted);
    font-size: 0.7rem;
}


.logout-button {
    width: 100%;
    border: 1px solid rgba(255, 255, 255, 0.1);
    background: transparent;
    color: var(--sidebar-muted);
    border-radius: 8px;
    padding: 9px;
}


.logout-button:hover {
    color: white;
    background: rgba(255, 255, 255, 0.06);
}


.main-shell {
    min-width: 0;
    flex: 1;
}


.topbar {
    height: 68px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 32px;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
}


.topbar-label {
    font-size: 0.86rem;
    font-weight: 750;
}


.topbar-user {
    color: var(--muted);
    font-size: 0.8rem;
}


.content {
    width: min(1200px, 100%);
    margin: 0 auto;
    padding: 38px 32px 70px;
}


.page-heading {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 24px;
    margin-bottom: 30px;
}


.page-heading h1 {
    margin: 0;
    font-size: clamp(2rem, 4vw, 2.8rem);
    line-height: 1.05;
    letter-spacing: -0.035em;
}


.page-heading p:not(.eyebrow) {
    max-width: 650px;
    margin: 12px 0 0;
    color: var(--muted);
    line-height: 1.6;
}


.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
}


.dashboard-card,
.resource-card {
    padding: 22px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 14px;
}


.dashboard-card h2,
.resource-card h2 {
    margin: 8px 0;
    font-size: 1.05rem;
}


.dashboard-card p,
.resource-card p {
    color: var(--muted);
    line-height: 1.55;
    font-size: 0.9rem;
}


.card-label,
.resource-type {
    color: var(--muted);
    font-size: 0.7rem;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}


.text-button {
    margin-top: 8px;
    border: 0;
    padding: 0;
    background: transparent;
    color: var(--accent);
    font-weight: 750;
}


.section-heading {
    margin: 46px 0 16px;
}


.section-heading h2 {
    margin: 0;
}


.status-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
}


.status-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 16px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
}


.status-item strong,
.status-item span:last-child {
    display: block;
}


.status-item span:last-child {
    margin-top: 3px;
    color: var(--muted);
    font-size: 0.78rem;
}


.status-dot {
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: var(--success);
}


.empty-panel {
    min-height: 300px;
    display: grid;
    place-items: center;
    align-content: center;
    padding: 40px;
    text-align: center;
    background: var(--surface);
    border: 1px dashed #cfd5dd;
    border-radius: 16px;
}


.empty-panel h2 {
    margin: 14px 0 8px;
}


.empty-panel p {
    max-width: 580px;
    color: var(--muted);
    line-height: 1.6;
}


.empty-icon {
    width: 44px;
    height: 44px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: var(--surface-soft);
    color: var(--muted);
    font-size: 1.5rem;
}


.content-list,
.people-list {
    display: grid;
    gap: 10px;
}


.content-card,
.person-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
    padding: 18px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 12px;
}


.content-card p {
    margin-bottom: 0;
    color: var(--muted);
}


.person-row {
    justify-content: flex-start;
}


.person-row strong,
.person-row span {
    display: block;
}


.person-row span {
    margin-top: 3px;
    color: var(--muted);
    font-size: 0.82rem;
}


.resource-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 16px;
}


@media (max-width: 900px) {
    .dashboard-grid,
    .resource-grid,
    .status-grid {
        grid-template-columns: 1fr;
    }

    .sidebar {
        width: 210px;
    }
}


@media (max-width: 700px) {
    .app-shell {
        display: block;
    }

    .sidebar {
        width: 100%;
        min-height: auto;
        padding: 12px;
    }

    .sidebar-brand {
        padding-bottom: 12px;
    }

    .sidebar-nav {
        display: flex;
        overflow-x: auto;
    }

    .nav-item {
        white-space: nowrap;
    }

    .sidebar-bottom {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-top: 10px;
    }

    .user-mini {
        min-width: 0;
        flex: 1;
    }

    .logout-button {
        width: auto;
        padding-inline: 14px;
    }

    .topbar {
        padding: 0 18px;
    }

    .topbar-user {
        display: none;
    }

    .content {
        padding: 28px 18px 50px;
    }

    .page-heading {
        align-items: flex-start;
        flex-direction: column;
    }

    .content-card {
        align-items: flex-start;
        flex-direction: column;
    }
}
CSS

cat > backend/tests/test_auth.py <<'PY'
from app.auth import (
    create_access_token,
    hash_password,
    verify_password,
)


def test_password_hash_round_trip():
    password = "test-password-123"

    password_hash = hash_password(password)

    assert password_hash != password
    assert verify_password(password, password_hash)
    assert not verify_password(
        "wrong-password",
        password_hash,
    )


def test_access_token_is_created():
    token = create_access_token(123)

    assert isinstance(token, str)
    assert len(token) > 20
PY

cat > PROJECT_STATUS.md <<'STATUS'
# Microschool Platform — Project Status

## Project

A plug-and-play platform for operating and building microschools.

The platform does NOT provide a fixed educational curriculum.

The platform provides the systems that allow people and organizations
to operate microschools and plug reusable content into them.

Core responsibilities:

- Identity and authentication
- Organizations and microschools
- Pods
- Learners
- Guides
- Parents
- Permissions
- Learning infrastructure
- Resource discovery
- Assignments and progress
- Attendance
- Content authoring
- Content review and publishing
- Notifications
- Reporting
- Extensible modules and integrations

Educational content is supplied by authorized people and organizations.

---

# Current Architecture

## Backend

- Python
- FastAPI
- SQLAlchemy
- SQLite for development
- PostgreSQL planned for production
- JWT authentication
- PBKDF2-SHA256 password hashing
- pytest

## Frontend

- HTML
- CSS
- JavaScript
- Single-page application shell
- Role-aware navigation
- Token-based authentication state

## Runtime

Development:

    ./run.sh

Application:

    http://127.0.0.1:8000

API documentation:

    http://127.0.0.1:8000/docs

---

# Current State

## Working

- FastAPI application
- SQLite database
- Project-root database path
- Health endpoint
- User registration
- User login
- JWT access tokens
- Current-user endpoint
- Secure password hashing without Passlib/bcrypt
- Authentication dependency
- Basic role-based API protection
- Learner API
- Pod API
- Course API
- Lesson API
- Progress API
- Real application shell
- Responsive sidebar/navigation
- Login screen
- Registration screen
- Learner dashboard foundation
- Parent dashboard foundation
- Guide dashboard foundation
- Organization dashboard foundation
- Resource library foundation
- Learning page foundation
- People page foundation
- Sign out
- Authentication tests
- Build backup system

## Important Current Limitation

Public registration currently allows only:

- learner
- parent

Guide, organization administrator, content author, content editor,
content administrator, and platform administrator accounts require
an invitation or administrative creation.

The invitation and administration system is not implemented yet.

---

# Product Architecture

The platform is divided into:

PLATFORM CORE

- Identity
- Organizations
- Permissions
- Content
- Search
- Notifications
- Audit Logs

MODULES

- Learning
- Pods
- Attendance
- Assignments
- Assessments
- Messaging
- Reports
- Resource Library

Content and platform functionality must remain separate.

---

# Content Architecture

Content is data, not application logic.

Supported/planned content types include:

- Course
- Unit
- Skill
- Lesson
- Activity
- Assessment
- Guide
- Playbook
- Article
- Resource
- Template
- Video
- External link

Content metadata should include:

- Title
- Description
- Author
- Organization
- Type
- Audience
- Subject
- Age/grade range
- Tags
- Status
- Visibility
- Version
- Created date
- Updated date

---

# Content Publishing

Planned workflow:

DRAFT
  ↓
SUBMITTED
  ↓
IN REVIEW
  ↓
CHANGES REQUESTED
  ↓
APPROVED
  ↓
PUBLISHED
  ↓
ARCHIVED

Authors should not automatically be able to publish platform-wide
content.

---

# Content Ownership

## Platform

Created by the site team.

Examples:

- Microschool startup guides
- Guide training
- Parent resources
- Platform documentation
- General templates

## Organization

Private content belonging to a microschool or organization.

Examples:

- Internal handbook
- Organization schedules
- Internal activities
- Organization assignments

## Community

Approved content contributed by outside people or organizations.

---

# Roles

Planned roles:

- Platform Admin
- Content Admin
- Content Editor
- Content Author
- Organization Admin
- Guide
- Learner
- Parent

Permissions should eventually be explicit capabilities rather than
scattered role checks.

Examples:

- content.create
- content.edit
- content.review
- content.publish
- content.archive
- organization.create
- organization.manage
- pod.create
- pod.manage
- learner.view
- learner.manage
- assignment.create
- assignment.grade

---

# Current User Experiences

## Learner

Implemented foundation:

- Sign in
- Account creation
- Overview
- Learning
- Resources
- Account/sign out

Planned:

- Current activity
- Assignments
- Progress
- Pod
- Schedule
- Notifications

Primary question:

What should I do next?

## Parent

Implemented foundation:

- Sign in
- Account creation
- Overview
- Learning
- Resources
- Account/sign out

Planned:

- Child overview
- Learning progress
- Assignments
- Attendance
- Schedule
- Resources
- Guide communication

Primary question:

How is my child doing and what are they working on?

## Guide

UI foundation exists but guide account creation/invitation does not
exist yet.

Planned:

- Dashboard
- Pods
- Learners
- Attendance
- Assignments
- Progress
- Notes
- Resources
- Schedule

Primary question:

Which learners need attention and what should I do?

## Organization Admin

UI foundation exists.

Planned:

- Organization setup
- Members
- Pods
- Guides
- Permissions
- Organization content
- Reports
- Settings

## Platform Admin

Planned:

- Organizations
- Users
- Content
- Review queue
- Publishing
- Reports
- Permissions
- System settings
- Audit logs

---

# Development Roadmap

## Phase 1 — Platform Foundation

Status: IN PROGRESS

- [x] Basic FastAPI application
- [x] Basic database
- [x] Basic models
- [x] Basic APIs
- [x] Project status document
- [x] Backup convention
- [x] Authentication
- [x] Password hashing
- [x] JWT access tokens
- [x] Current-user endpoint
- [x] Basic API authorization
- [x] Application shell
- [x] Responsive navigation
- [ ] Organizations
- [ ] Organization memberships
- [ ] Roles
- [ ] Permissions
- [ ] Invitations

## Phase 2 — Real UI

Status: IN PROGRESS

- [x] Login
- [x] Registration
- [x] Navigation
- [x] Learner dashboard foundation
- [x] Parent dashboard foundation
- [x] Guide dashboard foundation
- [x] Admin/organization dashboard foundation
- [x] Responsive layout
- [x] Loading states
- [x] Error states
- [x] Empty states
- [ ] Real guide workspace
- [ ] Real parent-child relationships
- [ ] Real organization workspace

## Phase 3 — Learning Platform

- [ ] Courses
- [ ] Units
- [ ] Skills
- [ ] Lessons
- [ ] Activities
- [ ] Assessments
- [ ] Assignments
- [ ] Activity attempts
- [ ] Learner progress

## Phase 4 — Microschool Operations

- [ ] Organizations
- [ ] Pods
- [ ] Guide management
- [ ] Learner management
- [ ] Attendance
- [ ] Notes
- [ ] Schedules
- [ ] Parent access

## Phase 5 — Content Platform

- [ ] Resource library backend
- [ ] Content authoring
- [ ] Drafts
- [ ] Review workflow
- [ ] Publishing
- [ ] Versioning
- [ ] Platform/community/organization scopes
- [ ] Search
- [ ] Tags/categories

## Phase 6 — Mastery System

- [ ] Skills
- [ ] Prerequisites
- [ ] Mastery states
- [ ] Assessment results
- [ ] Recommendation engine
- [ ] Learning paths

The initial recommendation system should be deterministic and
rule-based.

AI can assist later but should not become the authoritative source
of learner state.

## Phase 7 — Production Hardening

- [ ] PostgreSQL
- [ ] Database migrations
- [ ] Security review
- [ ] Authorization review
- [ ] Audit logging
- [ ] Automated tests
- [ ] Monitoring
- [ ] Error tracking
- [ ] Deployment
- [ ] CI/CD
- [ ] Privacy/data-management controls

---

# Development Rules

1. Do not hardcode educational curriculum into application logic.
2. Content must be data-driven.
3. Keep platform functionality separate from content.
4. Use permissions rather than scattered role checks.
5. Organizations must have isolated data.
6. Significant schema changes need a migration strategy.
7. Every significant build/change gets a backup.
8. Reproducible changes get a numbered script under scripts/.
9. Update this file whenever architecture, current state, known issues,
   or roadmap changes.
10. Do not delete working functionality without documenting the change.
11. Prefer small, testable modules.
12. Another developer or AI should be able to understand the project
    from this file without relying on conversation history.
13. Do not create educational curriculum unless explicitly requested.
14. The platform is the product; educational content is pluggable data.
15. Public users must not be able to self-assign privileged roles.

---

# Backup Convention

Backups live under:

    backups/

Each build receives a numbered directory:

    backups/NNN_short-build-name/

Build scripts use the same numbering:

    scripts/NNN_short-build-name.sh

Each build backup should contain:

- Project snapshot from immediately before the build
- Build script used for the build
- Project status from before the build

The current build number is 004.

---

# Change Log

## Build 004 — Application Shell and Authentication

Date: 2026-10-03

Changes:

- Replaced Passlib/bcrypt authentication with standard-library
  PBKDF2-SHA256 password hashing.
- Added JWT authentication flow.
- Added login endpoint.
- Added protected current-user endpoint.
- Added authentication dependency.
- Added basic role-based API authorization.
- Restricted public registration to learner and parent accounts.
- Rebuilt frontend as a real application shell.
- Added responsive sidebar navigation.
- Added role-aware navigation.
- Added learner workspace foundation.
- Added parent workspace foundation.
- Added guide workspace foundation.
- Added organization workspace foundation.
- Added resource library foundation.
- Added learning workspace foundation.
- Added people workspace foundation.
- Added sign-out behavior.
- Added authentication tests.
- Updated platform status and roadmap.

Next build:

Organizations, memberships, invitations, and real role/permission
management.

STATUS

cp "$0" "$BACKUP_DIR/$BUILD.sh"

cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS.md"

echo ""
echo "Running tests..."
echo ""

source "$ROOT/.venv/bin/activate" 2>/dev/null || true

if command -v pytest >/dev/null 2>&1; then
    (
        cd "$ROOT/backend"
        pytest -q
    )
else
    echo "pytest not found. Run ./run.sh first."
fi

echo ""
echo "Build 004 complete."
echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
echo ""
echo "Start:"
echo "  ./run.sh"
echo ""
