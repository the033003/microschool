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
