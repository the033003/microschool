from fastapi.testclient import TestClient

from app.auth import create_access_token, hash_password
from app.database import SessionLocal
from app.main import app
from app.models import (
    Organization,
    OrganizationMembership,
    User,
)

client = TestClient(app)


def create_user(
    name,
    email,
    role="learner",
):
    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == email)
        .first()
    )

    if not user:
        user = User(
            name=name,
            email=email,
            password_hash=hash_password("test-password-123"),
            role=role,
            active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    db.close()

    return user.id


def create_organization(
    name,
    slug,
    user_id,
):
    db = SessionLocal()

    organization = (
        db.query(Organization)
        .filter(Organization.slug == slug)
        .first()
    )

    if not organization:
        organization = Organization(
            name=name,
            slug=slug,
            active=True,
        )
        db.add(organization)
        db.flush()

    membership = (
        db.query(OrganizationMembership)
        .filter(
            OrganizationMembership.organization_id
            == organization.id,
            OrganizationMembership.user_id
            == user_id,
        )
        .first()
    )

    if not membership:
        db.add(
            OrganizationMembership(
                organization_id=organization.id,
                user_id=user_id,
                role="owner",
                active=True,
            )
        )

    db.commit()
    organization_id = organization.id
    db.close()

    return organization_id


def headers_for(user_id):
    return {
        "Authorization": (
            f"Bearer {create_access_token(user_id)}"
        )
    }


def test_organization_learners_are_isolated():
    owner_a = create_user(
        "Org A Owner",
        "isolation-owner-a@example.com",
    )

    owner_b = create_user(
        "Org B Owner",
        "isolation-owner-b@example.com",
    )

    learner_a = create_user(
        "Org A Learner",
        "isolation-learner-a@example.com",
    )

    learner_b = create_user(
        "Org B Learner",
        "isolation-learner-b@example.com",
    )

    organization_a = create_organization(
        "Isolation Organization A",
        "isolation-org-a",
        owner_a,
    )

    organization_b = create_organization(
        "Isolation Organization B",
        "isolation-org-b",
        owner_b,
    )

    db = SessionLocal()

    for organization_id, learner_id in [
        (organization_a, learner_a),
        (organization_b, learner_b),
    ]:
        existing = (
            db.query(OrganizationMembership)
            .filter(
                OrganizationMembership.organization_id
                == organization_id,
                OrganizationMembership.user_id
                == learner_id,
            )
            .first()
        )

        if not existing:
            db.add(
                OrganizationMembership(
                    organization_id=organization_id,
                    user_id=learner_id,
                    role="member",
                    active=True,
                )
            )

    db.commit()
    db.close()

    response = client.get(
        f"/api/learners/organization/{organization_a}",
        headers=headers_for(owner_a),
    )

    assert response.status_code == 200

    emails = {
        learner["email"]
        for learner in response.json()
    }

    assert "isolation-learner-a@example.com" in emails
    assert "isolation-learner-b@example.com" not in emails

    response = client.get(
        f"/api/learners/organization/{organization_b}",
        headers=headers_for(owner_b),
    )

    assert response.status_code == 200

    emails = {
        learner["email"]
        for learner in response.json()
    }

    assert "isolation-learner-b@example.com" in emails
    assert "isolation-learner-a@example.com" not in emails


def test_non_member_cannot_read_organization_learners():
    outsider = create_user(
        "Isolation Outsider",
        "isolation-outsider@example.com",
    )

    owner = create_user(
        "Protected Org Owner",
        "isolation-protected-owner@example.com",
    )

    organization_id = create_organization(
        "Protected Organization",
        "isolation-protected",
        owner,
    )

    response = client.get(
        f"/api/learners/organization/{organization_id}",
        headers=headers_for(outsider),
    )

    assert response.status_code == 403


def test_pod_creation_is_organization_scoped():
    owner = create_user(
        "Pod Owner",
        "isolation-pod-owner@example.com",
    )

    organization_id = create_organization(
        "Pod Organization",
        "isolation-pod-org",
        owner,
    )

    response = client.post(
        f"/api/pods/organization/{organization_id}",
        json={
            "name": "Development Pod",
            "description": "Organization-scoped test pod",
        },
        headers=headers_for(owner),
    )

    assert response.status_code == 200
    assert response.json()["organization_id"] == organization_id

    response = client.get(
        f"/api/pods/organization/{organization_id}",
        headers=headers_for(owner),
    )

    assert response.status_code == 200

    assert any(
        pod["name"] == "Development Pod"
        for pod in response.json()
    )
