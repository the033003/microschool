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
