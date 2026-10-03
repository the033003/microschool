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
