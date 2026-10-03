from typing import Optional

from pydantic import BaseModel


class UserCreate(BaseModel):
    name: str
    email: str
    password: str
    role: str = "learner"


class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    role: str

    class Config:
        from_attributes = True


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
