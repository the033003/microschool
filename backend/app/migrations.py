from sqlalchemy import inspect, text

from .database import engine


def column_exists(table_name: str, column_name: str) -> bool:
    inspector = inspect(engine)

    return any(
        column["name"] == column_name
        for column in inspector.get_columns(table_name)
    )


def run_dev_migrations() -> None:
    inspector = inspect(engine)
    tables = inspector.get_table_names()

    if "pods" in tables and not column_exists(
        "pods",
        "organization_id",
    ):
        with engine.begin() as connection:
            connection.execute(
                text(
                    "ALTER TABLE pods "
                    "ADD COLUMN organization_id INTEGER"
                )
            )
