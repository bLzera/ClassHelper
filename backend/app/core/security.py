from datetime import datetime, timedelta, timezone
from typing import Any

from jose import jwt

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30


def create_access_token(data: dict[str, Any], secret_key: str) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["exp"] = expire
    encoded = jwt.encode(to_encode, secret_key, algorithm=ALGORITHM)
    return str(encoded)


def decode_access_token(token: str, secret_key: str) -> dict[str, Any]:
    payload: dict[str, Any] = jwt.decode(token, secret_key, algorithms=[ALGORITHM])
    return payload
