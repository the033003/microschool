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
