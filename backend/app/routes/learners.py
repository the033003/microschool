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
