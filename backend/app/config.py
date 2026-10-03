from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = PROJECT_ROOT / "data"

DATA_DIR.mkdir(
    parents=True,
    exist_ok=True,
)


class Settings(BaseSettings):
    app_name: str = "Microschool"
    secret_key: str = "change-this-secret"

    database_url: str = (
        f"sqlite:///{DATA_DIR / 'microschool.db'}"
    )

    model_config = SettingsConfigDict(
        env_file=PROJECT_ROOT / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
