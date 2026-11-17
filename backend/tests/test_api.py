def test_health_check(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "connected"}


def test_ideas_can_be_created_and_listed(client):
    created = client.post("/api/ideas", json={"content": "Build a reliable pipeline"})

    assert created.status_code == 201
    saved_idea = created.json()
    assert saved_idea["content"] == "Build a reliable pipeline"
    assert saved_idea["id"] > 0
    assert saved_idea["created_at"]

    listed = client.get("/api/ideas")
    assert listed.status_code == 200
    assert listed.json() == [saved_idea]


def test_idea_content_is_trimmed(client):
    response = client.post("/api/ideas", json={"content": "  useful idea  "})

    assert response.status_code == 201
    assert response.json()["content"] == "useful idea"


def test_blank_idea_is_rejected(client):
    response = client.post("/api/ideas", json={"content": "   "})

    assert response.status_code == 422


def test_idea_over_1000_characters_is_rejected(client):
    response = client.post("/api/ideas", json={"content": "x" * 1001})

    assert response.status_code == 422
