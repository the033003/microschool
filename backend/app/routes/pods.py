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
