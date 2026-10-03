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
