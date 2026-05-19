from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    test_database_url: str = ""
    secret_key: str
    google_client_id: str = ""
    google_client_secret: str = ""
    google_redirect_uri: str = "http://localhost:8000/auth/callback"

    model_config = {"env_file": ".env", "case_sensitive": False}


settings = Settings()
