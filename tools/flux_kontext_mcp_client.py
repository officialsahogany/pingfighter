# -*- coding: utf-8 -*-
"""Small stdio MCP client for the local FLUX Kontext server."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
START_SCRIPT = ROOT / ".claude" / "start_flux_kontext_mcp.ps1"


def _encode_message(payload: dict[str, Any]) -> bytes:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    header = f"Content-Length: {len(body)}\r\n\r\n".encode("ascii")
    return header + body


def _read_exact(stream: Any, size: int) -> bytes:
    data = b""
    while len(data) < size:
        chunk = stream.read(size - len(data))
        if not chunk:
            raise EOFError("Unexpected EOF while reading MCP body")
        data += chunk
    return data


def _read_message(stream: Any) -> dict[str, Any]:
    headers: dict[str, str] = {}
    while True:
        line = stream.readline()
        if not line:
            raise EOFError("Unexpected EOF while reading MCP header")
        if line in (b"\r\n", b"\n"):
            break
        decoded = line.decode("utf-8").strip()
        if ":" in decoded:
            key, value = decoded.split(":", 1)
            headers[key.strip().lower()] = value.strip()

    content_length = int(headers["content-length"])
    body = _read_exact(stream, content_length)
    return json.loads(body.decode("utf-8"))


class McpSession:
    def __init__(self) -> None:
        self.proc = subprocess.Popen(
            [
                "powershell.exe",
                "-NoLogo",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(START_SCRIPT),
            ],
            cwd=str(ROOT),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        if self.proc.stdin is None or self.proc.stdout is None or self.proc.stderr is None:
            raise RuntimeError("Failed to open MCP process pipes")
        self._next_id = 1
        self._stderr_lines: list[str] = []
        self._stderr_thread = threading.Thread(target=self._drain_stderr, daemon=True)
        self._stderr_thread.start()

    def _drain_stderr(self) -> None:
        assert self.proc.stderr is not None
        for raw in self.proc.stderr:
            try:
                self._stderr_lines.append(raw.decode("utf-8", errors="replace").rstrip())
            except Exception:
                self._stderr_lines.append(repr(raw))

    def send_request(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        request_id = self._next_id
        self._next_id += 1
        payload = {
            "jsonrpc": "2.0",
            "id": request_id,
            "method": method,
            "params": params or {},
        }
        assert self.proc.stdin is not None
        self.proc.stdin.write(_encode_message(payload))
        self.proc.stdin.flush()

        while True:
            assert self.proc.stdout is not None
            message = _read_message(self.proc.stdout)
            if message.get("id") == request_id:
                return message

    def send_notification(self, method: str, params: dict[str, Any] | None = None) -> None:
        payload = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params or {},
        }
        assert self.proc.stdin is not None
        self.proc.stdin.write(_encode_message(payload))
        self.proc.stdin.flush()

    def initialize(self) -> dict[str, Any]:
        response = self.send_request(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "codex-local-client", "version": "1.0.0"},
            },
        )
        self.send_notification("notifications/initialized")
        return response

    def close(self) -> None:
        try:
            if self.proc.stdin:
                self.proc.stdin.close()
        except Exception:
            pass
        try:
            self.proc.terminate()
            self.proc.wait(timeout=3)
        except Exception:
            try:
                self.proc.kill()
            except Exception:
                pass

    @property
    def stderr_text(self) -> str:
        return "\n".join(self._stderr_lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list-tools")

    call_parser = subparsers.add_parser("call-tool")
    call_parser.add_argument("--tool", required=True)
    call_parser.add_argument("--args-json", required=True, help="JSON object string or @path to JSON file")

    parsed = parser.parse_args()

    session = McpSession()
    try:
        init_response = session.initialize()
        if parsed.command == "list-tools":
            response = session.send_request("tools/list")
            print(json.dumps({"initialize": init_response, "response": response}, ensure_ascii=False, indent=2))
            return 0

        args_json = parsed.args_json
        if args_json.startswith("@"):
            args_payload = json.loads(Path(args_json[1:]).read_text(encoding="utf-8"))
        else:
            args_payload = json.loads(args_json)

        response = session.send_request(
            "tools/call",
            {
                "name": parsed.tool,
                "arguments": args_payload,
            },
        )
        print(json.dumps({"initialize": init_response, "response": response}, ensure_ascii=False, indent=2))
        return 0
    finally:
        session.close()


if __name__ == "__main__":
    sys.exit(main())
