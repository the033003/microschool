from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..auth import hash_password
from ..database import get_db
from ..models import User
from ..schemas import UserCreate, UserResponse


router = APIRouter(
    prefix="/api/auth",
    tags=["auth"],
)


@router.post(
    "/register",
    response_model=UserResponse,
)
def register(
    user_data: UserCreate,
    db: Session = Depends(get_db),
):
    existing = (
        db.query(User)
        .filter(User.email == user_data.email)
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=400,
            detail="Email already registered",
        )

    user = User(
        name=user_data.name,
        email=user_data.email,
        password_hash=hash_password(
            user_data.password
        ),
        role=user_data.role,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user
