from deployment_analyzer import redact_sensitive_data


def test_redacts_sensitive_values():
    text = "password=secret123 Authorization: Bearer abc123 DATABASE_URL=postgres://user:pass@db"

    redacted = redact_sensitive_data(text)

    assert "secret123" not in redacted
    assert "abc123" not in redacted
    assert "user:pass" not in redacted
    assert "[REDACTED]" in redacted


def test_caps_prompt_input_length():
    assert len(redact_sensitive_data("x" * 20_000)) == 12_000


def test_redacts_quoted_json_secrets():
    text = '{"password":"json-secret","DATABASE_URL":"postgresql://user:pass@db/ideas"}'

    redacted = redact_sensitive_data(text)

    assert "json-secret" not in redacted
    assert "user:pass" not in redacted
    assert redacted.count("[REDACTED]") == 2
