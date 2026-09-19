#!/usr/bin/env python3
"""Broker Unix-socket mínimo para o protótipo secure-input.

O broker mantém o segredo somente durante a resposta da solicitação. Ele não
faz logging do payload secreto e invalida cada pedido após um único consumo.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import socket
import stat
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


MAX_LINE = 16 * 1024
DEFAULT_TIMEOUT = 30.0


@dataclass
class PendingRequest:
    request_id: str
    nonce: str
    created_at: float
    expires_at: float
    metadata: dict[str, Any]
    delivered: bool = False
    decision_event: threading.Event = field(default_factory=threading.Event)
    secret: str | None = None
    error: str | None = None


class Broker:
    def __init__(self, socket_path: Path, session_token: str, llm_capability: str, timeout: float) -> None:
        self.socket_path = socket_path
        self.session_token = session_token
        self.llm_capability = llm_capability
        self.timeout = timeout
        self.pending: dict[str, PendingRequest] = {}
        self.lock = threading.Lock()
        self.stop_event = threading.Event()

    def serve(self) -> None:
        self.socket_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.socket_path.unlink()
        except FileNotFoundError:
            pass
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
            server.bind(str(self.socket_path))
            os.chmod(self.socket_path, stat.S_IRUSR | stat.S_IWUSR)
            server.listen(16)
            cleanup = threading.Thread(target=self._cleanup_loop, daemon=True)
            cleanup.start()
            print(f"secure-input broker ouvindo em {self.socket_path}", flush=True)
            while not self.stop_event.is_set():
                try:
                    server.settimeout(1.0)
                    conn, _ = server.accept()
                except socket.timeout:
                    continue
                threading.Thread(target=self._handle, args=(conn,), daemon=True).start()
        try:
            self.socket_path.unlink()
        except FileNotFoundError:
            pass

    def _handle(self, conn: socket.socket) -> None:
        with conn:
            reader = conn.makefile("rb")
            line = reader.readline(MAX_LINE + 1)
            if not line or len(line) > MAX_LINE:
                return
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                self._send(conn, {"ok": False, "error": "invalid_message"})
                return
            if not secrets.compare_digest(str(message.get("token", "")), self.session_token):
                self._send(conn, {"ok": False, "error": "unauthorized"})
                return
            kind = message.get("type")
            if kind == "request":
                if not self._valid_llm_origin(message):
                    self._send(conn, {"ok": False, "error": "invalid_llm_origin"})
                    return
                self._create_request(conn, message)
            elif kind == "approve":
                self._approve(conn, message)
            elif kind == "cancel":
                self._cancel(conn, message)
            elif kind == "pending":
                self._pending(conn)
            else:
                self._send(conn, {"ok": False, "error": "unknown_type"})

    def _valid_llm_origin(self, message: dict[str, Any]) -> bool:
        return (
            message.get("origin") == "llm"
            and secrets.compare_digest(str(message.get("capability", "")), self.llm_capability)
        )

    def _create_request(self, conn: socket.socket, message: dict[str, Any]) -> None:
        metadata = {
            "pid": int(message.get("pid", 0)),
            "command": str(message.get("command", ""))[:1000],
            "cwd": str(message.get("cwd", ""))[:1000],
            "tty": str(message.get("tty", ""))[:300],
            "prompt": str(message.get("prompt", "Password: "))[:300],
            "screen": str(message.get("screen", ""))[:200],
        }
        request = PendingRequest(
            request_id=uuid.uuid4().hex,
            nonce=secrets.token_urlsafe(24),
            created_at=time.time(),
            expires_at=time.time() + self.timeout,
            metadata=metadata,
        )
        with self.lock:
            self.pending[request.request_id] = request
        self._send(
            conn,
            {
                "ok": True,
                "request_id": request.request_id,
                "nonce": request.nonce,
                "expires_at": request.expires_at,
            },
        )
        request.decision_event.wait(self.timeout + 1.0)
        with self.lock:
            secret = request.secret
            error = request.error or "expired"
            self.pending.pop(request.request_id, None)
        if secret is not None:
            self._send(conn, {"ok": True, "secret": secret})
        else:
            self._send(conn, {"ok": False, "error": error})

    def _pending(self, conn: socket.socket) -> None:
        now = time.time()
        with self.lock:
            items = [
                {
                    "request_id": r.request_id,
                    "nonce": r.nonce,
                    **r.metadata,
                    "expires_at": r.expires_at,
                }
                for r in self.pending.values()
                if not r.delivered and r.expires_at > now
            ]
        self._send(conn, {"ok": True, "requests": items})

    def _approve(self, conn: socket.socket, message: dict[str, Any]) -> None:
        request_id = str(message.get("request_id", ""))
        nonce = str(message.get("nonce", ""))
        secret = message.get("secret")
        with self.lock:
            request = self.pending.get(request_id)
            valid = (
                request is not None
                and not request.delivered
                and request.nonce == nonce
                and request.expires_at > time.time()
                and isinstance(secret, str)
                and len(secret) <= 4096
            )
            if valid:
                request.delivered = True
                request.secret = secret
                request.decision_event.set()
        if not valid:
            self._send(conn, {"ok": False, "error": "invalid_or_expired_request"})
            return
        # O segredo só é retornado nesta resposta e nunca é escrito pelo broker.
        self._send(conn, {"ok": True})

    def _cancel(self, conn: socket.socket, message: dict[str, Any]) -> None:
        request_id = str(message.get("request_id", ""))
        with self.lock:
            request = self.pending.get(request_id)
            removed = request is not None and not request.delivered
            if removed:
                request.delivered = True
                request.error = "cancelado_pelo_usuario"
                request.decision_event.set()
        self._send(conn, {"ok": removed})

    def _cleanup_loop(self) -> None:
        while not self.stop_event.wait(1.0):
            now = time.time()
            with self.lock:
                expired = [rid for rid, req in self.pending.items() if req.expires_at <= now]
                for rid in expired:
                    request = self.pending.get(rid)
                    if request and not request.delivered:
                        request.delivered = True
                        request.error = "expired"
                        request.decision_event.set()

    @staticmethod
    def _send(conn: socket.socket, payload: dict[str, Any]) -> None:
        try:
            conn.sendall((json.dumps(payload, separators=(",", ":")) + "\n").encode())
        except OSError:
            # O cliente pode ter cancelado a conexão após receber o aceite.
            pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--socket", type=Path, required=True)
    parser.add_argument("--token", default=None)
    parser.add_argument("--llm-capability", default=None)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    args = parser.parse_args()
    token = args.token or os.environ.get("SECURE_INPUT_TOKEN")
    capability = args.llm_capability or os.environ.get("SECURE_INPUT_LLM_CAPABILITY")
    if not token or not capability:
        parser.error("use --token/SECURE_INPUT_TOKEN e --llm-capability/SECURE_INPUT_LLM_CAPABILITY")
    Broker(args.socket, token, capability, max(1.0, min(args.timeout, 300.0))).serve()


if __name__ == "__main__":
    main()
