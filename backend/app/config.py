from pathlib import Path

from pydantic_settings import BaseSettings


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"

DATA_DIR.mkdir(parents=True, exist_ok=True)


class Settings(BaseSettings):
    app_name: str = "Microschool"
    secret_key: str = "change-this-secret"

    database_url: str = (
        f"sqlite:///{DATA_DIR / 'microschool.db'}"
    )

    class Config:
        env_file = PROJECT_ROOT / ".env"


settings = Settings()
