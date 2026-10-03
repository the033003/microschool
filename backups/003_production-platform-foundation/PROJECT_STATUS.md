# Microschool Platform — Project Status

## Project

A plug-and-play platform for operating and building microschools.

The platform itself does NOT provide a fixed educational curriculum.

The platform provides:

- Identity and authentication
- Organizations and microschools
- Pods
- Learners
- Guides
- Parents
- Permissions
- Learning and content infrastructure
- Resource discovery
- Assignments and progress tracking
- Attendance
- Content authoring
- Content review and publishing
- Notifications
- Reporting
- Extensible modules and integrations

Educational content, guides, playbooks, parent resources, courses,
activities, templates, and other materials are created by authorized
people and organizations and plugged into the platform.

---

## Current Architecture

### Backend

- Python
- FastAPI
- SQLAlchemy
- SQLite for development
- PostgreSQL planned for production
- JWT authentication foundation
- pytest

### Frontend

Currently:

- HTML
- CSS
- JavaScript

The frontend is currently a basic prototype and is being replaced
with a real application interface.

### Runtime

Development command:

    ./run.sh

Application:

    http://127.0.0.1:8000

API documentation:

    http://127.0.0.1:8000/docs

---

# Current State

## Working

- Project structure exists.
- Python virtual environment can be created.
- Dependencies install.
- FastAPI application exists.
- SQLAlchemy models exist.
- SQLite database is used.
- Basic health endpoint exists.
- Basic CRUD APIs exist for:
  - learners
  - pods
  - courses
  - lessons
  - progress
- Basic frontend exists.
- Database path uses the project-root data directory.
- Project backup convention established.
- Project status and AI/developer handoff document established.

## Known Problems

### Authentication

Current authentication is incomplete.

Needs:

- Login
- Secure password hashing
- Access tokens
- Token validation
- Protected API routes
- Role and permission enforcement
- Session handling
- Logout
- Password reset architecture

The existing Passlib/bcrypt implementation should be replaced or
modernized because the current dependency combination is not suitable
for the long-term application.

### Frontend

Current frontend is a prototype.

Needs to become:

- Application shell
- Login
- Role-aware navigation
- Learner dashboard
- Guide dashboard
- Parent dashboard
- Organization/admin dashboard
- Learning interface
- Resource library
- Content authoring interface
- Responsive/mobile-friendly UI
- Proper loading states
- Proper error states
- Proper empty states

### Data Model

Current models are too simple.

The system needs first-class concepts for:

- Users
- Organizations
- Organization memberships
- Roles
- Permissions
- Pods
- Pod memberships
- Courses
- Units
- Skills
- Lessons
- Activities
- Assessments
- Assignments
- Learner mastery
- Activity attempts
- Attendance
- Notes
- Resources
- Content versions
- Content publishing
- Notifications
- Audit logs

---

# Product Architecture

The core platform should be separated from the content.

PLATFORM CORE

- Identity
- Organizations
- Permissions
- Content
- Search
- Notifications
- Audit Logs

MODULES

- Learning
- Pods
- Attendance
- Assignments
- Assessments
- Messaging
- Reports
- Resource Library

The platform should allow content to be plugged into these systems.

---

# Content Model

Content is not hardcoded into the application.

Potential content types:

- Course
- Unit
- Skill
- Lesson
- Activity
- Assessment
- Guide
- Playbook
- Article
- Resource
- Template
- Video
- External link

Content should contain metadata such as:

- Title
- Description
- Author
- Organization
- Type
- Audience
- Subject
- Age/grade range
- Tags
- Status
- Visibility
- Version
- Created date
- Updated date

---

# Content Publishing

Content needs a controlled workflow:

DRAFT
  ↓
SUBMITTED
  ↓
IN REVIEW
  ↓
CHANGES REQUESTED
  ↓
APPROVED
  ↓
PUBLISHED
  ↓
ARCHIVED

Authors should not automatically have permission to publish platform-wide
content.

---

# Content Ownership

There are three important scopes.

## Platform

Content created by the site team.

Examples:

- How to start a microschool
- Guide training
- Parent resources
- Platform documentation
- General templates

## Organization

Private content belonging to a microschool or organization.

Examples:

- Internal handbook
- Organization schedules
- Internal activities
- Organization assignments

## Community

Approved content contributed by other users or organizations.

---

# Roles

Roles should eventually be permission-based rather than relying on
hardcoded role checks.

Potential roles:

- Platform Admin
- Content Admin
- Content Editor
- Content Author
- Organization Admin
- Guide
- Learner
- Parent

Permissions should look like:

- content.create
- content.edit
- content.review
- content.publish
- content.archive
- organization.create
- organization.manage
- pod.create
- pod.manage
- learner.view
- learner.manage
- assignment.create
- assignment.grade

---

# Planned User Experiences

## Learner

- Home
- My Learning
- Current Activity
- Assignments
- Progress
- My Pod
- Schedule
- Notifications

Primary question:

What should I do next?

## Guide

- Dashboard
- Pod
- Learners
- Attendance
- Assignments
- Progress
- Notes
- Resources
- Schedule

Primary question:

Which learners need attention and what should I do?

## Parent

- Child overview
- Learning progress
- Assignments
- Attendance
- Schedule
- Resources
- Guide communication

Primary question:

How is my child doing and what are they working on?

## Platform/Admin

- Organizations
- Users
- Content
- Review queue
- Publishing
- Reports
- Permissions
- System settings
- Audit logs

---

# Development Roadmap

## Phase 1 — Platform Foundation

Status: IN PROGRESS

- [x] Basic FastAPI application
- [x] Basic database
- [x] Basic models
- [x] Basic APIs
- [x] Basic frontend
- [x] Project status document
- [x] Backup convention
- [ ] Production application shell
- [ ] Authentication
- [ ] Authorization
- [ ] Users
- [ ] Organizations
- [ ] Roles
- [ ] Permissions

## Phase 2 — Real UI

- [ ] Login
- [ ] Navigation
- [ ] Learner dashboard
- [ ] Guide dashboard
- [ ] Parent dashboard
- [ ] Admin dashboard
- [ ] Responsive layout
- [ ] Error/loading/empty states

## Phase 3 — Learning Platform

- [ ] Courses
- [ ] Units
- [ ] Skills
- [ ] Lessons
- [ ] Activities
- [ ] Assessments
- [ ] Assignments
- [ ] Activity attempts
- [ ] Learner progress

## Phase 4 — Microschool Operations

- [ ] Organizations
- [ ] Pods
- [ ] Guide management
- [ ] Learner management
- [ ] Attendance
- [ ] Notes
- [ ] Schedules
- [ ] Parent access

## Phase 5 — Content Platform

- [ ] Resource library
- [ ] Content authoring
- [ ] Drafts
- [ ] Review workflow
- [ ] Publishing
- [ ] Versioning
- [ ] Platform/community/organization scopes
- [ ] Search
- [ ] Tags/categories

## Phase 6 — Mastery System

- [ ] Skills
- [ ] Prerequisites
- [ ] Mastery states
- [ ] Assessment results
- [ ] Recommendation engine
- [ ] Learning paths

Initial recommendation logic should be deterministic and rule-based.

Learner
  ↓
Skill Mastery
  ↓
Prerequisites
  ↓
Recommendation
  ↓
Next Activity

AI assistance can be added later without making AI the core source
of truth.

## Phase 7 — Production Hardening

- [ ] PostgreSQL
- [ ] Database migrations
- [ ] Security review
- [ ] Authorization review
- [ ] Audit logging
- [ ] Automated tests
- [ ] Backups
- [ ] Monitoring
- [ ] Error tracking
- [ ] Deployment
- [ ] CI/CD
- [ ] Privacy/data-management controls

---

# Development Rules

1. Do not hardcode educational curriculum into application logic.
2. Content must be data-driven.
3. Keep platform functionality separate from content.
4. Use permissions rather than scattered role checks.
5. Organizations must have isolated data.
6. Every significant schema change requires a migration strategy.
7. Every significant build/change gets a backup.
8. Reproducible changes should have a script under scripts/.
9. Update this file whenever architecture, current state, known issues,
   or roadmap changes.
10. Do not delete working functionality without documenting the change.
11. Prefer small, testable modules over a single giant implementation.
12. Another developer or AI should be able to read this file and
    understand the current project without relying on conversation history.

---

# Backup Convention

Backups live under:

    backups/

Each build receives its own numbered directory.

Naming convention:

    backups/NNN_short-build-name/

Each build backup should contain:

- Project snapshot from immediately before the build
- The build script used for the build
- A copy of PROJECT_STATUS.md from that build

Build scripts use the same numbering convention:

    scripts/NNN_short-build-name.sh

---

# Change Log

## Build 003 — Production Platform Foundation

Date: 2026-10-03

Changes:

- Added project status and AI/developer handoff document.
- Established backup convention.
- Established reproducible build-script convention.
- Defined platform/content separation.
- Defined initial organization and permission architecture.
- Defined content publishing model.
- Defined content ownership scopes.
- Expanded development roadmap.

Next build:

Production application shell and authentication foundation.

