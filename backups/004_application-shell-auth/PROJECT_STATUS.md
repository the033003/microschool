# Microschool Platform — Project Status

## Project

A plug-and-play platform for operating and building microschools.

The platform does NOT provide a fixed educational curriculum.

The platform provides the systems that allow people and organizations
to operate microschools and plug reusable content into them.

Core responsibilities:

- Identity and authentication
- Organizations and microschools
- Pods
- Learners
- Guides
- Parents
- Permissions
- Learning infrastructure
- Resource discovery
- Assignments and progress
- Attendance
- Content authoring
- Content review and publishing
- Notifications
- Reporting
- Extensible modules and integrations

Educational content is supplied by authorized people and organizations.

---

# Current Architecture

## Backend

- Python
- FastAPI
- SQLAlchemy
- SQLite for development
- PostgreSQL planned for production
- JWT authentication
- PBKDF2-SHA256 password hashing
- pytest

## Frontend

- HTML
- CSS
- JavaScript
- Single-page application shell
- Role-aware navigation
- Token-based authentication state

## Runtime

Development:

    ./run.sh

Application:

    http://127.0.0.1:8000

API documentation:

    http://127.0.0.1:8000/docs

---

# Current State

## Working

- FastAPI application
- SQLite database
- Project-root database path
- Health endpoint
- User registration
- User login
- JWT access tokens
- Current-user endpoint
- Secure password hashing without Passlib/bcrypt
- Authentication dependency
- Basic role-based API protection
- Learner API
- Pod API
- Course API
- Lesson API
- Progress API
- Real application shell
- Responsive sidebar/navigation
- Login screen
- Registration screen
- Learner dashboard foundation
- Parent dashboard foundation
- Guide dashboard foundation
- Organization dashboard foundation
- Resource library foundation
- Learning page foundation
- People page foundation
- Sign out
- Authentication tests
- Build backup system

## Important Current Limitation

Public registration currently allows only:

- learner
- parent

Guide, organization administrator, content author, content editor,
content administrator, and platform administrator accounts require
an invitation or administrative creation.

The invitation and administration system is not implemented yet.

---

# Product Architecture

The platform is divided into:

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

Content and platform functionality must remain separate.

---

# Content Architecture

Content is data, not application logic.

Supported/planned content types include:

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

Content metadata should include:

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

Planned workflow:

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

Authors should not automatically be able to publish platform-wide
content.

---

# Content Ownership

## Platform

Created by the site team.

Examples:

- Microschool startup guides
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

Approved content contributed by outside people or organizations.

---

# Roles

Planned roles:

- Platform Admin
- Content Admin
- Content Editor
- Content Author
- Organization Admin
- Guide
- Learner
- Parent

Permissions should eventually be explicit capabilities rather than
scattered role checks.

Examples:

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

# Current User Experiences

## Learner

Implemented foundation:

- Sign in
- Account creation
- Overview
- Learning
- Resources
- Account/sign out

Planned:

- Current activity
- Assignments
- Progress
- Pod
- Schedule
- Notifications

Primary question:

What should I do next?

## Parent

Implemented foundation:

- Sign in
- Account creation
- Overview
- Learning
- Resources
- Account/sign out

Planned:

- Child overview
- Learning progress
- Assignments
- Attendance
- Schedule
- Resources
- Guide communication

Primary question:

How is my child doing and what are they working on?

## Guide

UI foundation exists but guide account creation/invitation does not
exist yet.

Planned:

- Dashboard
- Pods
- Learners
- Attendance
- Assignments
- Progress
- Notes
- Resources
- Schedule

Primary question:

Which learners need attention and what should I do?

## Organization Admin

UI foundation exists.

Planned:

- Organization setup
- Members
- Pods
- Guides
- Permissions
- Organization content
- Reports
- Settings

## Platform Admin

Planned:

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
- [x] Project status document
- [x] Backup convention
- [x] Authentication
- [x] Password hashing
- [x] JWT access tokens
- [x] Current-user endpoint
- [x] Basic API authorization
- [x] Application shell
- [x] Responsive navigation
- [ ] Organizations
- [ ] Organization memberships
- [ ] Roles
- [ ] Permissions
- [ ] Invitations

## Phase 2 — Real UI

Status: IN PROGRESS

- [x] Login
- [x] Registration
- [x] Navigation
- [x] Learner dashboard foundation
- [x] Parent dashboard foundation
- [x] Guide dashboard foundation
- [x] Admin/organization dashboard foundation
- [x] Responsive layout
- [x] Loading states
- [x] Error states
- [x] Empty states
- [ ] Real guide workspace
- [ ] Real parent-child relationships
- [ ] Real organization workspace

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

- [ ] Resource library backend
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

The initial recommendation system should be deterministic and
rule-based.

AI can assist later but should not become the authoritative source
of learner state.

## Phase 7 — Production Hardening

- [ ] PostgreSQL
- [ ] Database migrations
- [ ] Security review
- [ ] Authorization review
- [ ] Audit logging
- [ ] Automated tests
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
6. Significant schema changes need a migration strategy.
7. Every significant build/change gets a backup.
8. Reproducible changes get a numbered script under scripts/.
9. Update this file whenever architecture, current state, known issues,
   or roadmap changes.
10. Do not delete working functionality without documenting the change.
11. Prefer small, testable modules.
12. Another developer or AI should be able to understand the project
    from this file without relying on conversation history.
13. Do not create educational curriculum unless explicitly requested.
14. The platform is the product; educational content is pluggable data.
15. Public users must not be able to self-assign privileged roles.

---

# Backup Convention

Backups live under:

    backups/

Each build receives a numbered directory:

    backups/NNN_short-build-name/

Build scripts use the same numbering:

    scripts/NNN_short-build-name.sh

Each build backup should contain:

- Project snapshot from immediately before the build
- Build script used for the build
- Project status from before the build

The current build number is 004.

---

# Change Log

## Build 004 — Application Shell and Authentication

Date: 2026-10-03

Changes:

- Replaced Passlib/bcrypt authentication with standard-library
  PBKDF2-SHA256 password hashing.
- Added JWT authentication flow.
- Added login endpoint.
- Added protected current-user endpoint.
- Added authentication dependency.
- Added basic role-based API authorization.
- Restricted public registration to learner and parent accounts.
- Rebuilt frontend as a real application shell.
- Added responsive sidebar navigation.
- Added role-aware navigation.
- Added learner workspace foundation.
- Added parent workspace foundation.
- Added guide workspace foundation.
- Added organization workspace foundation.
- Added resource library foundation.
- Added learning workspace foundation.
- Added people workspace foundation.
- Added sign-out behavior.
- Added authentication tests.
- Updated platform status and roadmap.

Next build:

Organizations, memberships, invitations, and real role/permission
management.

