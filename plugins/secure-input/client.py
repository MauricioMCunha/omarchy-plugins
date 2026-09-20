"""Cliente mínimo do protocolo Unix local do Secure Input."""

from __future__ import annotations

import json
import socket
from pathlib import Path
from typing import Any

SOCKET_TIMEOUT = 5.0
MAX_LINE = 16 * 1024


def call(socket_path: Path, token: str, payload: dict[str, Any]) -> dict[str, Any]:
    message = {"token": token, **payload}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.settimeout(SOCKET_TIMEOUT)
        conn.connect(str(socket_path))
        conn.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode())
        line = conn.makefile("rb").readline(MAX_LINE + 1)
    if len(line) > MAX_LINE:
        raise RuntimeError("resposta do broker excede o limite")
    if not line:
        raise RuntimeError("broker encerrou a conexão")
    return json.loads(line)


def request_secret(socket_path: Path, token: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Create a request and keep the connection open until the UI decides."""
    message = {"token": token, "type": "request", **payload}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.settimeout(SOCKET_TIMEOUT)
        conn.connect(str(socket_path))
        conn.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode())
        reader = conn.makefile("rb")
        accepted = reader.readline(MAX_LINE + 1)
        if not accepted:
            raise RuntimeError("broker não aceitou a solicitação")
        result = reader.readline(MAX_LINE + 1)
    if len(accepted) > MAX_LINE or len(result) > MAX_LINE:
        raise RuntimeError("resposta do broker excede o limite")
    if not result:
        raise RuntimeError("broker encerrou a solicitação")
    return json.loads(result)
