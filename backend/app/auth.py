from datetime import datetime, timedelta

from jose import jwt
from passlib.context import CryptContext

from .config import settings


ALGORITHM = "HS256"

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(
    plain_password: str,
    password_hash: str,
) -> bool:
    return pwd_context.verify(
        plain_password,
        password_hash,
    )


def create_access_token(user_id: int) -> str:
    expires = datetime.utcnow() + timedelta(hours=24)

    payload = {
        "sub": str(user_id),
        "exp": expires,
    }

    return jwt.encode(
        payload,
        settings.secret_key,
        algorithm=ALGORITHM,
    )
