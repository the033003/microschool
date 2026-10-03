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
