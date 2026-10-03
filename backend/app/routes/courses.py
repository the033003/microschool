from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..dependencies import require_roles
from ..models import Course, Lesson, User
from ..schemas import CourseCreate, LessonCreate


router = APIRouter(
    prefix="/api/courses",
    tags=["courses"],
)


@router.get("/")
def list_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "learner",
            "parent",
            "guide",
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
):
    return db.query(Course).filter(
        Course.active == True
    ).all()


@router.post("/")
def create_course(
    course_data: CourseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(
        require_roles(
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
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
    current_user: User = Depends(
        require_roles(
            "content_author",
            "content_editor",
            "content_admin",
            "organization_admin",
            "platform_admin",
        )
    ),
):
    course = db.query(Course).filter(
        Course.id == course_id
    ).first()

    if not course:
        from fastapi import HTTPException

        raise HTTPException(
            status_code=404,
            detail="Course not found",
        )

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
