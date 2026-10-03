from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(String, nullable=False)

    email = Column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    password_hash = Column(String, nullable=False)

    role = Column(
        String,
        nullable=False,
        default="learner",
    )

    active = Column(Boolean, default=True)

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class Pod(Base):
    __tablename__ = "pods"

    id = Column(Integer, primary_key=True)

    name = Column(String, nullable=False)

    description = Column(Text)

    guide_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
    )

    guide = relationship("User")

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class PodMember(Base):
    __tablename__ = "pod_members"

    id = Column(Integer, primary_key=True)

    pod_id = Column(
        Integer,
        ForeignKey("pods.id"),
        nullable=False,
    )

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    joined_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class Course(Base):
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True)

    title = Column(String, nullable=False)

    description = Column(Text)

    subject = Column(String)

    grade_level = Column(String)

    active = Column(Boolean, default=True)


class Lesson(Base):
    __tablename__ = "lessons"

    id = Column(Integer, primary_key=True)

    course_id = Column(
        Integer,
        ForeignKey("courses.id"),
        nullable=False,
    )

    title = Column(String, nullable=False)

    description = Column(Text)

    content = Column(Text)

    position = Column(Integer, default=0)


class LearnerProgress(Base):
    __tablename__ = "learner_progress"

    id = Column(Integer, primary_key=True)

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    lesson_id = Column(
        Integer,
        ForeignKey("lessons.id"),
        nullable=False,
    )

    completed = Column(Boolean, default=False)

    score = Column(Float, nullable=True)

    attempts = Column(Integer, default=0)

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class Attendance(Base):
    __tablename__ = "attendance"

    id = Column(Integer, primary_key=True)

    learner_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    date = Column(
        DateTime,
        default=datetime.utcnow,
    )

    present = Column(Boolean, default=True)

    notes = Column(Text)
