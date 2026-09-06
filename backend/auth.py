from pwdlib import PasswordHash
from jose import jwt
from datetime import datetime, timedelta, timezone
import os
from dotenv import load_dotenv


# Load environment variables
load_dotenv()


# -----------------------------
# Password hashing
# -----------------------------

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str
) -> bool:
    return password_hash.verify(
        plain_password,
        hashed_password
    )


# -----------------------------
# JWT configuration
# -----------------------------

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")


# -----------------------------
# Create JWT token
# -----------------------------

def create_access_token(
    data: dict,
    expires_minutes: int = 60
) -> str:

    if not JWT_SECRET_KEY:
        raise ValueError("JWT_SECRET_KEY is missing from .env")

    to_encode = data.copy()

    expire = datetime.now(timezone.utc) + timedelta(
        minutes=expires_minutes
    )

    to_encode.update({
        "exp": expire
    })

    encoded_jwt = jwt.encode(
        to_encode,
        JWT_SECRET_KEY,
        algorithm=JWT_ALGORITHM
    )

    return encoded_jwt