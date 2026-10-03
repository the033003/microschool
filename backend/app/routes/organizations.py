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
