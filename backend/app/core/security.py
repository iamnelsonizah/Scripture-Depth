from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel
from app.core.config import settings

security = HTTPBearer(auto_error=False)


class AuthUser(BaseModel):
    user_id: str
    email: Optional[str] = None
    role: Optional[str] = None


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> AuthUser:
    """
    Verifies the Supabase JWT access token passed from the mobile client.
    Extracts the user ID ('sub') and authenticated claims.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authorization bearer token required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials

    # Development convenience: Allow testing with dev tokens when secret is placeholder
    if settings.ENVIRONMENT == "development" and settings.SUPABASE_JWT_SECRET == "placeholder-jwt-secret":
        if token.startswith("dev-user-"):
            return AuthUser(user_id=token, email=f"{token}@example.com", role="authenticated")

    try:
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=[settings.SUPABASE_JWT_ALGORITHM],
            options={"verify_aud": False},  # Supabase tokens often use 'authenticated' aud
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token claims: missing sub",
            )
        email: Optional[str] = payload.get("email")
        role: Optional[str] = payload.get("role")
        return AuthUser(user_id=user_id, email=email, role=role)
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Could not validate credentials: {str(exc)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
) -> Optional[AuthUser]:
    """Allows endpoints like Reader to be accessed publicly, but personalizes if authenticated."""
    if not credentials:
        return None
    try:
        return await get_current_user(credentials)
    except HTTPException:
        return None
