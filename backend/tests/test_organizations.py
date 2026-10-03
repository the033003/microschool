from fastapi.testclient import TestClient

from app.auth import create_access_token, hash_password
from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import User


client = TestClient(app)


def setup_function():
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == "org-test@example.com")
        .first()
    )

    if not user:
        user = User(
            name="Organization Tester",
            email="org-test@example.com",
            password_hash=hash_password("test-password-123"),
            role="learner",
            active=True,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    db.close()


def auth_headers():
    db = SessionLocal()

    user = (
        db.query(User)
        .filter(User.email == "org-test@example.com")
        .first()
    )

    token = create_access_token(user.id)

    db.close()

    return {
        "Authorization": f"Bearer {token}",
    }


def test_create_and_list_organization():
    headers = auth_headers()

    response = client.post(
        "/api/organizations/",
        json={
            "name": "Test Microschool",
            "slug": "test-microschool",
            "description": "Development organization",
        },
        headers=headers,
    )

    assert response.status_code in {201, 400}

    response = client.get(
        "/api/organizations/",
        headers=headers,
    )

    assert response.status_code == 200

    organizations = response.json()

    assert any(
        organization["slug"] == "test-microschool"
        for organization in organizations
    )


def test_organization_membership_exists():
    headers = auth_headers()

    response = client.get(
        "/api/organizations/",
        headers=headers,
    )

    assert response.status_code == 200

    organization = next(
        item
        for item in response.json()
        if item["slug"] == "test-microschool"
    )

    response = client.get(
        f"/api/organizations/{organization['id']}/members",
        headers=headers,
    )

    assert response.status_code == 200

    members = response.json()

    assert any(
        member["user_email"] == "org-test@example.com"
        and member["role"] == "owner"
        for member in members
    )
