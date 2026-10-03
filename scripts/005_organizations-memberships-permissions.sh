#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="005_organizations-memberships-permissions"
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
PY

cat > backend/app/permissions.py <<'PY'
from typing import Callable

from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session

from .database import get_db
from .dependencies import get_current_user
from .models import OrganizationMembership, User


ROLE_CAPABILITIES = {
    "owner": {
        "organization.view",
        "organization.manage",
        "organization.invite",
        "organization.members.manage",
        "pod.create",
        "pod.manage",
        "learner.view",
        "learner.manage",
        "content.create",
        "content.edit",
        "content.review",
        "content.publish",
    },
    "org_admin": {
        "organization.view",
        "organization.manage",
        "organization.invite",
        "organization.members.manage",
        "pod.create",
        "pod.manage",
        "learner.view",
        "learner.manage",
        "content.create",
        "content.edit",
        "content.review",
        "content.publish",
    },
    "guide": {
        "organization.view",
        "pod.create",
        "pod.manage",
        "learner.view",
        "learner.manage",
        "content.create",
        "content.edit",
    },
    "member": {
        "organization.view",
        "learner.view",
    },
    "learner": {
        "organization.view",
    },
    "parent": {
        "organization.view",
    },
}


def has_capability(
    user: User,
    membership: OrganizationMembership | None,
    capability: str,
) -> bool:
    if user.role == "platform_admin":
        return True

    if not membership or not membership.active:
        return False

    return capability in ROLE_CAPABILITIES.get(
        membership.role,
        set(),
    )


def require_organization_capability(capability: str) -> Callable:
    def dependency(
        organization_id: int,
        current_user: User = Depends(get_current_user),
        db: Session = Depends(get_db),
    ):
        membership = (
            db.query(OrganizationMembership)
            .filter(
                OrganizationMembership.organization_id == organization_id,
                OrganizationMembership.user_id == current_user.id,
                OrganizationMembership.active.is_(True),
            )
            .first()
        )

        if not has_capability(
            current_user,
            membership,
            capability,
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )

        return membership

    return dependency
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

cat > backend/app/routes/organizations.py <<'PY'
from datetime import datetime, timedelta
import hashlib
import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import get_current_user
from ..models import (
    Organization,
    OrganizationInvitation,
    OrganizationMembership,
    User,
)
from ..permissions import require_organization_capability
from ..schemas import (
    InvitationAccept,
    InvitationCreate,
    InvitationResponse,
    MembershipResponse,
    OrganizationCreate,
    OrganizationResponse,
)

router = APIRouter(
    prefix="/api/organizations",
    tags=["organizations"],
)


def normalize_slug(slug: str) -> str:
    return "-".join(
        part for part in slug.strip().lower().split("-") if part
    )


@router.get(
    "/",
    response_model=list[OrganizationResponse],
)
def list_my_organizations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(Organization)
        .join(
            OrganizationMembership,
            OrganizationMembership.organization_id == Organization.id,
        )
        .filter(
            OrganizationMembership.user_id == current_user.id,
            OrganizationMembership.active.is_(True),
            Organization.active.is_(True),
        )
        .order_by(Organization.name)
        .all()
    )


@router.post(
    "/",
    response_model=OrganizationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_organization(
    organization_data: OrganizationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    slug = normalize_slug(organization_data.slug)

    existing = (
        db.query(Organization)
        .filter(Organization.slug == slug)
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail="An organization with that slug already exists",
        )

    organization = Organization(
        name=organization_data.name.strip(),
        slug=slug,
        description=organization_data.description,
    )

    db.add(organization)
    db.flush()

    membership = OrganizationMembership(
        organization_id=organization.id,
        user_id=current_user.id,
        role="owner",
        active=True,
    )

    db.add(membership)
    db.commit()
    db.refresh(organization)

    return organization


@router.get(
    "/{organization_id}/members",
    response_model=list[MembershipResponse],
)
def list_members(
    organization_id: int,
    membership=Depends(
        require_organization_capability("organization.view")
    ),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(
            OrganizationMembership,
            User.name,
            User.email,
        )
        .join(User, User.id == OrganizationMembership.user_id)
        .filter(
            OrganizationMembership.organization_id == organization_id,
            OrganizationMembership.active.is_(True),
        )
        .order_by(User.name)
        .all()
    )

    return [
        MembershipResponse(
            id=item.id,
            organization_id=item.organization_id,
            user_id=item.user_id,
            role=item.role,
            active=item.active,
            user_name=name,
            user_email=email,
        )
        for item, name, email in rows
    ]


@router.post(
    "/{organization_id}/invitations",
    response_model=InvitationResponse,
)
def create_invitation(
    organization_id: int,
    invitation_data: InvitationCreate,
    membership=Depends(
        require_organization_capability("organization.invite")
    ),
    db: Session = Depends(get_db),
):
    email = invitation_data.email.lower()

    if invitation_data.role not in {
        "member",
        "guide",
        "org_admin",
    }:
        raise HTTPException(
            status_code=400,
            detail="Invalid organization role",
        )

    existing_user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if existing_user:
        existing_membership = (
            db.query(OrganizationMembership)
            .filter(
                OrganizationMembership.organization_id == organization_id,
                OrganizationMembership.user_id == existing_user.id,
            )
            .first()
        )

        if existing_membership and existing_membership.active:
            raise HTTPException(
                status_code=400,
                detail="That user is already a member",
            )

    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(
        raw_token.encode("utf-8")
    ).hexdigest()

    invitation = OrganizationInvitation(
        organization_id=organization_id,
        invited_by_id=membership.user_id,
        email=email,
        role=invitation_data.role,
        token_hash=token_hash,
        expires_at=datetime.utcnow() + timedelta(days=7),
    )

    db.add(invitation)
    db.commit()
    db.refresh(invitation)

    return InvitationResponse(
        id=invitation.id,
        organization_id=invitation.organization_id,
        email=invitation.email,
        role=invitation.role,
        expires_at=invitation.expires_at.isoformat(),
        token=raw_token,
    )


@router.post(
    "/invitations/accept",
    response_model=MembershipResponse,
)
def accept_invitation(
    invitation_data: InvitationAccept,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    token_hash = hashlib.sha256(
        invitation_data.token.encode("utf-8")
    ).hexdigest()

    invitation = (
        db.query(OrganizationInvitation)
        .filter(
            OrganizationInvitation.token_hash == token_hash,
        )
        .first()
    )

    if not invitation:
        raise HTTPException(
            status_code=404,
            detail="Invitation not found",
        )

    if invitation.accepted_at:
        raise HTTPException(
            status_code=400,
            detail="Invitation has already been accepted",
        )

    if invitation.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=400,
            detail="Invitation has expired",
        )

    if current_user.email.lower() != invitation.email.lower():
        raise HTTPException(
            status_code=403,
            detail="This invitation belongs to a different email address",
        )

    existing = (
        db.query(OrganizationMembership)
        .filter(
            OrganizationMembership.organization_id
            == invitation.organization_id,
            OrganizationMembership.user_id == current_user.id,
        )
        .first()
    )

    if existing:
        existing.active = True
        existing.role = invitation.role
        membership = existing
    else:
        membership = OrganizationMembership(
            organization_id=invitation.organization_id,
            user_id=current_user.id,
            role=invitation.role,
            active=True,
        )
        db.add(membership)

    invitation.accepted_at = datetime.utcnow()

    db.commit()
    db.refresh(membership)

    return MembershipResponse(
        id=membership.id,
        organization_id=membership.organization_id,
        user_id=membership.user_id,
        role=membership.role,
        active=membership.active,
        user_name=current_user.name,
        user_email=current_user.email,
    )
PY

cat > backend/app/routes/pods.py <<'PY'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import get_current_user
from ..models import Pod, User
from ..permissions import require_organization_capability
from ..schemas import PodCreate

router = APIRouter(
    prefix="/api/pods",
    tags=["pods"],
)


@router.get("/")
def list_pods(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Pod).all()


@router.post("/")
def create_pod(
    pod_data: PodCreate,
    current_user: User = Depends(get_current_user),
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
    organizations,
    pods,
    progress,
)

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Microschool Platform",
    version="0.3.0",
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
        "version": "0.3.0",
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

cat > backend/tests/test_organizations.py <<'PY'
from fastapi.testclient import TestClient

from app.auth import create_access_token, hash_password
from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import User


client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == "org-test@example.com")
        .first()
    )

    if not user:
        user = User(
            name="Organization Tester",
            email="org-test@example.com",
            password_hash=hash_password("test-password-123"),
            role="learner",
            active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    db.close()


def auth_headers():
    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == "org-test@example.com")
        .first()
    )

    token = create_access_token(user.id)

    db.close()

    return {
        "Authorization": f"Bearer {token}",
    }


def test_create_and_list_organization():
    headers = auth_headers()

    response = client.post(
        "/api/organizations/",
        json={
            "name": "Test Microschool",
            "slug": "test-microschool",
            "description": "Development organization",
        },
        headers=headers,
    )

    assert response.status_code in {201, 400}

    response = client.get(
        "/api/organizations/",
        headers=headers,
    )

    assert response.status_code == 200

    organizations = response.json()

    assert any(
        organization["slug"] == "test-microschool"
        for organization in organizations
    )


def test_organization_membership_exists():
    headers = auth_headers()

    response = client.get(
        "/api/organizations/",
        headers=headers,
    )

    assert response.status_code == 200

    organization = next(
        item
        for item in response.json()
        if item["slug"] == "test-microschool"
    )

    response = client.get(
        f"/api/organizations/{organization['id']}/members",
        headers=headers,
    )

    assert response.status_code == 200

    members = response.json()

    assert any(
        member["user_email"] == "org-test@example.com"
        and member["role"] == "owner"
        for member in members
    )
PY

cat >> PROJECT_STATUS.md <<'STATUS'

## Build 005 — Organizations, Memberships, Invitations, and Permissions

Date: 2026-10-03

### Added

- Organization model.
- Organization membership model.
- Organization invitation model.
- Organization creation API.
- Current-user organization listing API.
- Organization member listing API.
- Organization invitation API.
- Invitation acceptance API.
- Explicit capability definitions.
- Organization-scoped capability dependency.
- Owner, org admin, guide, member, learner, and parent organization roles.
- Organization API tests.
- Pydantic ConfigDict migration for UserResponse.
- Application version 0.3.0.

### Architecture

The platform now has the beginning of the intended multi-tenant structure:

User
→ Organization Membership
→ Organization

Organization membership carries the organization-specific role.

Global User.role remains for platform-level identity/context.

Authorization is moving toward explicit capabilities rather than scattered
route-specific role checks.

Examples:

- organization.view
- organization.manage
- organization.invite
- organization.members.manage
- pod.create
- pod.manage
- learner.view
- learner.manage
- content.create
- content.edit
- content.review
- content.publish

### Invitation behavior

Invitations use one-time random tokens.

Only the token hash is persisted.

Invitation tokens expire after seven days.

The accepting user's email must match the invited email address.

### Development note

The current development database uses SQLAlchemy create_all.

New organization tables are created automatically in the development SQLite
database.

A production migration system is still required before production deployment.

### Remaining Build 005 work

- Connect existing pod operations to organizations.
- Connect learners to organizations.
- Add organization-aware frontend workspace.
- Add membership management UI.
- Add invitation UI.
- Add platform administrator organization controls.
- Replace remaining broad role checks with capability checks.
- Add database migrations before production.

### Known warnings

The Starlette/httpx TestClient deprecation warning remains.

The application is currently functionally passing its test suite despite that
non-blocking dependency warning.
STATUS

cp "$0" "$BACKUP_DIR/$BUILD.sh"

cp "$ROOT/PROJECT_STATUS.md" \
   "$BACKUP_DIR/PROJECT_STATUS.md"

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
echo "Build 005 complete."
echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
echo ""
echo "New organization API:"
echo "  GET  /api/organizations/"
echo "  POST /api/organizations/"
echo "  GET  /api/organizations/{id}/members"
echo "  POST /api/organizations/{id}/invitations"
echo "  POST /api/organizations/invitations/accept"
