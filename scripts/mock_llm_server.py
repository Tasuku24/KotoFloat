#!/usr/bin/env python3
"""Loopback-only fixed API fixture, not an LLM or a translation service.
Never logs request bodies or credentials. Uses only Python's standard library.

ループバック専用の固定応答です。LLMや翻訳サービスではありません。
要求本文や認証情報はログに残しません。Pythonの標準ライブラリだけを使います。
"""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL = "kotofloat-fixture"
OUTPUT = "テスト応答です。実際の翻訳ではありません。"


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args):
        pass

    def respond(self, status, data, content_type="application/json", headers=None):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/unauthorized/"):
            self.respond(401, b'{"error":{"code":"invalid_api_key"}}')
        elif self.path.endswith("/v1/models"):
            self.respond(200, json.dumps({"object": "list", "data": [
                {"id": MODEL, "object": "model", "created": 0, "owned_by": "test-fixture"}
            ]}).encode())
        else:
            self.respond(404, b'{}')

    def do_POST(self):
        if not self.path.endswith("/v1/chat/completions"):
            self.respond(404, b'{}')
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 262144:
                raise ValueError()
            body = json.loads(self.rfile.read(length))
            if body.get("stream") is not True or [m.get("role") for m in body["messages"]] != ["system", "user"]:
                raise ValueError()
        except (ValueError, KeyError, TypeError, AttributeError):
            self.respond(400, b'{"error":{"code":"invalid_request"}}')
            return
        if body.get("model") != MODEL or self.path.startswith("/missing/"):
            self.respond(404, b'{"error":{"code":"model_not_found"}}')
            return
        if self.path.startswith("/redirect/"):
            self.respond(302, b'', headers={"Location": f"http://127.0.0.1:{self.server.server_port}/v1/chat/completions"})
            return
        if self.path.startswith("/malformed/"):
            self.respond(200, b'data: invalid-json\n\n', "text/event-stream")
            return

        def event(content=None, finish=None):
            delta = {} if content is None else {"content": content}
            return ("data: " + json.dumps({"id": "fixture", "object": "chat.completion.chunk", "model": MODEL,
                "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}, ensure_ascii=False) + "\n\n").encode()

        chunks = [event(OUTPUT[:8]), event(OUTPUT[8:])]
        if not self.path.startswith("/broken/"):
            chunks += [event(finish="stop"), b'data: [DONE]\n\n']
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(sum(map(len, chunks))))
        self.end_headers()
        try:
            for chunk in chunks:
                self.wfile.write(chunk)
                self.wfile.flush()
                time.sleep(0.01)
        except (BrokenPipeError, ConnectionResetError):
            pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(json.dumps({"base_url": f"http://127.0.0.1:{server.server_port}/v1"}), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
