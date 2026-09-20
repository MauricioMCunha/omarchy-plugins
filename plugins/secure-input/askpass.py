#!/usr/bin/env python3
"""Askpass entrypoint bundled with the installed secure-input plugin."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from client import request_secret


def main() -> int:
    socket_path = os.environ.get("SECURE_INPUT_SOCKET")
    token = os.environ.get("SECURE_INPUT_TOKEN")
    if not socket_path or not token:
        return 2
    prompt = sys.argv[1] if len(sys.argv) > 1 else "Password: "
    try:
        result = request_secret(
            Path(socket_path),
            token,
            {
                "pid": os.getpid(),
                "command": os.environ.get("SECURE_INPUT_COMMAND", "sudo"),
                "cwd": os.getcwd(),
                "tty": os.environ.get("SECURE_INPUT_TTY", ""),
                "prompt": prompt,
                "origin": "llm",
                "capability": os.environ.get("SECURE_INPUT_LLM_CAPABILITY", ""),
                "screen": os.environ.get("SECURE_INPUT_SCREEN", ""),
            },
        )
    except (OSError, RuntimeError, ValueError):
        return 1
    if not result.get("ok") or not isinstance(result.get("secret"), str):
        return 1
    sys.stdout.write(result["secret"] + "\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
