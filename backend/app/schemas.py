from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    role: str = "learner"


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str
    role: str
    active: bool


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class OrganizationCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    slug: str = Field(min_length=2, max_length=80)
    description: Optional[str] = None


class OrganizationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str
    description: Optional[str]
    active: bool


class MembershipResponse(BaseModel):
    id: int
    organization_id: int
    user_id: int
    role: str
    active: bool
    user_name: str
    user_email: str


class InvitationCreate(BaseModel):
    email: EmailStr
    role: str = "member"


class InvitationResponse(BaseModel):
    id: int
    organization_id: int
    email: str
    role: str
    expires_at: str
    token: str


class InvitationAccept(BaseModel):
    token: str


class PodCreate(BaseModel):
    name: str
    description: Optional[str] = None
    guide_id: Optional[int] = None


class CourseCreate(BaseModel):
    title: str
    description: Optional[str] = None
    subject: Optional[str] = None
    grade_level: Optional[str] = None


class LessonCreate(BaseModel):
    title: str
    description: Optional[str] = None
    content: Optional[str] = None
    position: int = 0


class ProgressUpdate(BaseModel):
    completed: bool
    score: Optional[float] = None
