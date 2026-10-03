from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import Course, Lesson
from ..schemas import CourseCreate, LessonCreate


router = APIRouter(
    prefix="/api/courses",
    tags=["courses"],
)


@router.get("/")
def list_courses(
    db: Session = Depends(get_db),
):
    return db.query(Course).all()


@router.post("/")
def create_course(
    course_data: CourseCreate,
    db: Session = Depends(get_db),
):
    course = Course(
        title=course_data.title,
        description=course_data.description,
        subject=course_data.subject,
        grade_level=course_data.grade_level,
    )

    db.add(course)
    db.commit()
    db.refresh(course)

    return course


@router.post("/{course_id}/lessons")
def create_lesson(
    course_id: int,
    lesson_data: LessonCreate,
    db: Session = Depends(get_db),
):
    lesson = Lesson(
        course_id=course_id,
        title=lesson_data.title,
        description=lesson_data.description,
        content=lesson_data.content,
        position=lesson_data.position,
    )

    db.add(lesson)
    db.commit()
    db.refresh(lesson)

    return lesson
