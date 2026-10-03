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
    UniqueConstraint,
)

from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
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


class Organization(Base):
    __tablename__ = "organizations"

    id = Column(Integer, primary_key=True, index=True)

    name = Column(
        String,
        nullable=False,
    )

    slug = Column(
        String,
        unique=True,
        index=True,
        nullable=False,
    )

    description = Column(Text)

    active = Column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )


class OrganizationMembership(Base):
    __tablename__ = "organization_memberships"

    id = Column(Integer, primary_key=True, index=True)

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=False,
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    role = Column(
        String,
        nullable=False,
        default="member",
    )

    active = Column(
        Boolean,
        default=True,
        nullable=False,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )

    organization = relationship("Organization")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint(
            "organization_id",
            "user_id",
            name="uq_organization_membership",
        ),
    )


class OrganizationInvitation(Base):
    __tablename__ = "organization_invitations"

    id = Column(Integer, primary_key=True, index=True)

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=False,
    )

    invited_by_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
    )

    email = Column(
        String,
        nullable=False,
        index=True,
    )

    role = Column(
        String,
        nullable=False,
        default="member",
    )

    token_hash = Column(
        String,
        unique=True,
        nullable=False,
    )

    expires_at = Column(
        DateTime,
        nullable=False,
    )

    accepted_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
    )

    organization = relationship("Organization")
    invited_by = relationship("User")


class Pod(Base):
    __tablename__ = "pods"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    organization_id = Column(
        Integer,
        ForeignKey("organizations.id"),
        nullable=True,
        index=True,
    )

    name = Column(
        String,
        nullable=False,
    )

    description = Column(Text)

    guide_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=True,
    )

    organization = relationship("Organization")
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
