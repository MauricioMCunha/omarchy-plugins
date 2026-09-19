"""Cliente local do protocolo secure-input."""

from __future__ import annotations

import json
import socket
from pathlib import Path
from typing import Any


def call(socket_path: Path, token: str, payload: dict[str, Any]) -> dict[str, Any]:
    message = {"token": token, **payload}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.connect(str(socket_path))
        conn.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode())
        line = conn.makefile("rb").readline(16 * 1024 + 1)
    if not line:
        raise RuntimeError("broker encerrou a conexão")
    return json.loads(line)


def request_secret(socket_path: Path, token: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Mantém a conexão aberta até a UI decidir o pedido."""
    message = {"token": token, "type": "request", **payload}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.connect(str(socket_path))
        conn.sendall((json.dumps(message, separators=(",", ":")) + "\n").encode())
        reader = conn.makefile("rb")
        accepted = reader.readline(16 * 1024 + 1)
        if not accepted:
            raise RuntimeError("broker não aceitou a solicitação")
        result = reader.readline(16 * 1024 + 1)
    if not result:
        raise RuntimeError("broker encerrou a solicitação")
    return json.loads(result)
