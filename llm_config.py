"""
Lightweight OpenAI client configuration helper for this project.

Usage:
    from llm_config import get_openai_client
    client, model = get_openai_client()
    resp = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": "Hello"}],
    )

Environment variables (recommended via .env or shell export):
    OPENAI_API_KEY     – required
    OPENAI_MODEL       – optional, defaults to "gpt-5-high"
    OPENAI_BASE_URL    – optional, custom endpoint (e.g., Azure/OpenRouter proxy)
"""

from __future__ import annotations
import os

try:  # lazy import so game can run without the SDK
    from openai import OpenAI  # type: ignore
except Exception:  # pragma: no cover
    OpenAI = None  # type: ignore


def get_openai_client():
    """Return (client, model) configured from environment.

    Raises:
        RuntimeError: when the openai package is not installed or API key missing.
    """
    model = os.getenv("OPENAI_MODEL", "gpt-5-high")
    api_key = os.getenv("OPENAI_API_KEY")
    base_url = os.getenv("OPENAI_BASE_URL")  # optional

    if OpenAI is None:
        raise RuntimeError(
            "openai package not installed. Install with: pip install openai>=1.0.0"
        )
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY is not set. Export it or add to your .env file."
        )

    kwargs = {"api_key": api_key}
    if base_url:
        kwargs["base_url"] = base_url

    client = OpenAI(**kwargs)
    return client, model


def quick_smoketest(prompt: str = "ping") -> str:
    """Small helper to validate that credentials + model are working.

    Returns the assistant text or raises on failure.
    """
    client, model = get_openai_client()
    resp = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.0,
        max_tokens=16,
    )
    return resp.choices[0].message.content or ""

