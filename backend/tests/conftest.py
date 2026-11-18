import os
import sys
from pathlib import Path
from urllib.parse import urlparse

test_database_url = os.environ.get("TEST_DATABASE_URL", "sqlite://")
database_name = urlparse(test_database_url).path.lower()
if not test_database_url.startswith("sqlite") and "test" not in database_name:
    raise RuntimeError("TEST_DATABASE_URL must point to a dedicated database with 'test' in its name")
os.environ["DATABASE_URL"] = test_database_url
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import main
import pytest
from database import Base, engine
from fastapi.testclient import TestClient


@pytest.fixture
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with TestClient(main.app) as test_client:
        yield test_client
    main.app.dependency_overrides.clear()
