import json
from typing import Any, Dict

import requests


OLLAMA_URL = "http://localhost:11434/api/chat"


def call_ollama_json(
    model: str,
    system: str,
    user: str,
    schema: Dict[str, Any],
    temperature: float = 0.4,
) -> Dict[str, Any]:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "stream": False,
        "format": schema,
        "options": {
            "temperature": temperature,
        },
    }

    try:
        response = requests.post(OLLAMA_URL, json=payload, timeout=300)
    except requests.RequestException as exc:
        raise RuntimeError(
            "Could not reach Ollama at http://localhost:11434. "
            "Make sure the Ollama server is running and the model is available."
        ) from exc

    response.raise_for_status()

    body = response.json()
    try:
        content = body["message"]["content"]
    except KeyError as exc:
        raise ValueError(f"Unexpected Ollama response body: {body}") from exc

    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"Model did not return valid JSON:\n{content}") from e
