#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="006_organization-data-isolation"
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

cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS-before.md"

cat > backend/app/migrations.py <<'PY'
from sqlalchemy import inspect, text

from .database import engine


def column_exists(table_name: str, column_name: str) -> bool:
    inspector = inspect(engine)

    return any(
        column["name"] == column_name
        for column in inspector.get_columns(table_name)
    )


def run_dev_migrations() -> None:
    inspector = inspect(engine)
    tables = inspector.get_table_names()

    if "pods" in tables and not column_exists(
        "pods",
        "organization_id",
    ):
        with engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE pods "
                    "ADD COLUMN organization_id INTEGER"
                )
            )
PY

cat > backend/app/models.py <<'PY'
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
    UniqueConstraint,
)

from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
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


class Organization(Base):
    __tablename__ = "organizations"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(
        String,
        nullable=False,
    )

    slug = Column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    description = Column(Text)

    active = Column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class OrganizationMembership(Base):
    __tablename__ = "organization_memberships"

    id = Column(Integer, primary_key=True, index=True)

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=False,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    role = Column(
        String,
        nullable=False,
        default="member",
    )

    active = Column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )

    organization = relationship("Organization")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint(
            "organization_id",
            "user_id",
            name="uq_organization_membership",
        ),
    )


class OrganizationInvitation(Base):
    __tablename__ = "organization_invitations"

    id = Column(Integer, primary_key=True, index=True)

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=False,
    )

    invited_by_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    email = Column(
        String,
        nullable=False,
        index=True,
    )

    role = Column(
        String,
        nullable=False,
        default="member",
    )

    token_hash = Column(
        String,
        unique=True,
        nullable=False,
    )

    expires_at = Column(
        DateTime,
        nullable=False,
    )

    accepted_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )

    organization = relationship("Organization")
    invited_by = relationship("User")


class Pod(Base):
    __tablename__ = "pods"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=True,
        index=True,
    )

    name = Column(
        String,
        nullable=False,
    )

    description = Column(Text)

    guide_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
    )

    organization = relationship("Organization")
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
PY

cat > backend/app/routes/learners.py <<'PY'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import (
    OrganizationMembership,
    User,
)
from ..permissions import require_organization_capability

router = APIRouter(
    prefix="/api/learners",
    tags=["learners"],
)


@router.get(
    "/organization/{organization_id}",
)
def list_organization_learners(
    organization_id: int,
    membership=Depends(
        require_organization_capability("learner.view")
    ),
    db: Session = Depends(get_db),
):
    learners = (
        db.query(User)
        .join(
            OrganizationMembership,
            OrganizationMembership.user_id == User.id,
        )
        .filter(
            OrganizationMembership.organization_id == organization_id,
            OrganizationMembership.active.is_(True),
            User.role == "learner",
            User.active.is_(True),
        )
        .order_by(User.name)
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
from ..models import Pod, User
from ..permissions import require_organization_capability
from ..schemas import PodCreate

router = APIRouter(
    prefix="/api/pods",
    tags=["pods"],
)


@router.get(
    "/organization/{organization_id}",
)
def list_organization_pods(
    organization_id: int,
    membership=Depends(
        require_organization_capability("organization.view")
    ),
    db: Session = Depends(get_db),
):
    return (
        db.query(Pod)
        .filter(
            Pod.organization_id == organization_id,
        )
        .order_by(Pod.name)
        .all()
    )


@router.post(
    "/organization/{organization_id}",
)
def create_organization_pod(
    organization_id: int,
    pod_data: PodCreate,
    membership=Depends(
        require_organization_capability("pod.create")
    ),
    db: Session = Depends(get_db),
):
    pod = Pod(
        organization_id=organization_id,
        name=pod_data.name.strip(),
        description=pod_data.description,
        guide_id=pod_data.guide_id,
    )

    db.add(pod)
    db.commit()
    db.refresh(pod)

    return pod
PY

cat > backend/app/schemas.py <<'PY'
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: str = "learner"


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str
    role: str
    active: bool


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class OrganizationCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    slug: str = Field(min_length=2, max_length=80)
    description: Optional[str] = None


class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str
    description: Optional[str]
    active: bool


class MembershipResponse(BaseModel):
    id: int
    organization_id: int
    user_id: int
    role: str
    active: bool
    user_name: str
    user_email: str


class InvitationCreate(BaseModel):
    email: EmailStr
    role: str = "member"


class InvitationResponse(BaseModel):
    id: int
    organization_id: int
    email: str
    role: str
    expires_at: str
    token: str


class InvitationAccept(BaseModel):
    token: str


class PodCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
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

cat > backend/app/main.py <<'PY'
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
PY

cat > backend/tests/test_organization_isolation.py <<'PY'
from fastapi.testclient import TestClient

from app.auth import create_access_token, hash_password
from app.database import SessionLocal
from app.main import app
from app.models import (
    Organization,
    OrganizationMembership,
    User,
)

client = TestClient(app)


def create_user(
    name,
    email,
    role="learner",
):
    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        user = User(
            name=name,
            email=email,
            password_hash=hash_password("test-password-123"),
            role=role,
            active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    db.close()

    return user.id


def create_organization(
    name,
    slug,
    user_id,
):
    db = SessionLocal()

    organization = (
        db.query(Organization)
        .filter(Organization.slug == slug)
        .first()
    )

    if not organization:
        organization = Organization(
            name=name,
            slug=slug,
            active=True,
        )
        db.add(organization)
        db.flush()

    membership = (
        db.query(OrganizationMembership)
        .filter(
            OrganizationMembership.organization_id
            == organization.id,
            OrganizationMembership.user_id
            == user_id,
        )
        .first()
    )

    if not membership:
        db.add(
            OrganizationMembership(
                organization_id=organization.id,
                user_id=user_id,
                role="owner",
                active=True,
            )
        )

    db.commit()
    organization_id = organization.id
    db.close()

    return organization_id


def headers_for(user_id):
    return {
        "Authorization": (
            f"Bearer {create_access_token(user_id)}"
        )
    }


def test_organization_learners_are_isolated():
    owner_a = create_user(
        "Org A Owner",
        "isolation-owner-a@example.com",
    )

    owner_b = create_user(
        "Org B Owner",
        "isolation-owner-b@example.com",
    )

    learner_a = create_user(
        "Org A Learner",
        "isolation-learner-a@example.com",
    )

    learner_b = create_user(
        "Org B Learner",
        "isolation-learner-b@example.com",
    )

    organization_a = create_organization(
        "Isolation Organization A",
        "isolation-org-a",
        owner_a,
    )

    organization_b = create_organization(
        "Isolation Organization B",
        "isolation-org-b",
        owner_b,
    )

    db = SessionLocal()

    for organization_id, learner_id in [
        (organization_a, learner_a),
        (organization_b, learner_b),
    ]:
        existing = (
            db.query(OrganizationMembership)
            .filter(
                OrganizationMembership.organization_id
                == organization_id,
                OrganizationMembership.user_id
                == learner_id,
            )
            .first()
        )

        if not existing:
            db.add(
                OrganizationMembership(
                    organization_id=organization_id,
                    user_id=learner_id,
                    role="member",
                    active=True,
                )
            )

    db.commit()
    db.close()

    response = client.get(
        f"/api/learners/organization/{organization_a}",
        headers=headers_for(owner_a),
    )

    assert response.status_code == 200

    emails = {
        learner["email"]
        for learner in response.json()
    }

    assert "isolation-learner-a@example.com" in emails
    assert "isolation-learner-b@example.com" not in emails

    response = client.get(
        f"/api/learners/organization/{organization_b}",
        headers=headers_for(owner_b),
    )

    assert response.status_code == 200

    emails = {
        learner["email"]
        for learner in response.json()
    }

    assert "isolation-learner-b@example.com" in emails
    assert "isolation-learner-a@example.com" not in emails


def test_non_member_cannot_read_organization_learners():
    outsider = create_user(
        "Isolation Outsider",
        "isolation-outsider@example.com",
    )

    owner = create_user(
        "Protected Org Owner",
        "isolation-protected-owner@example.com",
    )

    organization_id = create_organization(
        "Protected Organization",
        "isolation-protected",
        owner,
    )

    response = client.get(
        f"/api/learners/organization/{organization_id}",
        headers=headers_for(outsider),
    )

    assert response.status_code == 403


def test_pod_creation_is_organization_scoped():
    owner = create_user(
        "Pod Owner",
        "isolation-pod-owner@example.com",
    )

    organization_id = create_organization(
        "Pod Organization",
        "isolation-pod-org",
        owner,
    )

    response = client.post(
        f"/api/pods/organization/{organization_id}",
        json={
            "name": "Development Pod",
            "description": "Organization-scoped test pod",
        },
        headers=headers_for(owner),
    )

    assert response.status_code == 200
    assert response.json()["organization_id"] == organization_id

    response = client.get(
        f"/api/pods/organization/{organization_id}",
        headers=headers_for(owner),
    )

    assert response.status_code == 200

    assert any(
        pod["name"] == "Development Pod"
        for pod in response.json()
    )
PY

cat >> PROJECT_STATUS.md <<'STATUS'

## Build 006 — Organization Data Isolation

Date: 2026-10-03

### Added

- Organization-scoped learner API.
- Organization-scoped pod API.
- Organization ID on pods.
- Organization membership enforcement on learner access.
- Organization membership enforcement on pod access.
- Development SQLite migration for the new pod organization column.
- Cross-organization isolation tests.
- Non-member authorization test.
- Application version 0.3.1.

### Important architecture change

Organization boundaries are now enforced at the data-access layer for learners
and pods.

The application must not treat a user's global role as sufficient access to
organization-owned data.

The intended access path is:

User
→ OrganizationMembership
→ Organization-owned resource

### Compatibility

Existing development SQLite databases are migrated automatically for the new
Pod.organization_id column.

The column is temporarily nullable so existing development data is not
destroyed.

Before production deployment, this field should become required after a
proper migration system is introduced and existing records are assigned to
organizations.

### Remaining

- Add organization-aware frontend workspace.
- Add member management UI.
- Add invitation UI.
- Add pod management UI.
- Add organization-aware learner management UI.
- Connect pod membership to organization membership.
- Replace remaining global learner/pod assumptions.
- Introduce production migrations.
- Resolve remaining TestClient/httpx deprecation warning.
STATUS

cp "$0" "$BACKUP_DIR/$BUILD.sh"
cp "$ROOT/PROJECT_STATUS.md" "$BACKUP_DIR/PROJECT_STATUS.md"

echo ""
echo "Installing dependencies..."
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
echo "Build 006 complete."
echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
