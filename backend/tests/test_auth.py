from app.auth import (
    create_access_token,
    hash_password,
    verify_password,
)


def test_password_hash_round_trip():
    password = "test-password-123"

    password_hash = hash_password(password)

    assert password_hash != password
    assert verify_password(password, password_hash)
    assert not verify_password(
        "wrong-password",
        password_hash,
    )


def test_access_token_is_created():
    token = create_access_token(123)

    assert isinstance(token, str)
    assert len(token) > 20
