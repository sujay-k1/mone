import json
import requests
from typing import Any, Dict


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

    response = requests.post(OLLAMA_URL, json=payload, timeout=300)
    response.raise_for_status()

    content = response.json()["message"]["content"]

    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        raise ValueError(f"Model did not return valid JSON:\n{content}") from e