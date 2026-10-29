#!/usr/bin/env python3
"""Run background Swift tests with an isolated loopback API fixture.
固定応答サーバーをループバックで起動し、バックグラウンドのSwiftテストを実行します。
"""
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
server = subprocess.Popen([sys.executable, str(root / "scripts/mock_llm_server.py"), "--port", "0"],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
try:
    with selectors.DefaultSelector() as selector:
        selector.register(server.stdout, selectors.EVENT_READ)
        if not selector.select(timeout=5):
            raise RuntimeError("Fixture startup timed out / テスト用サーバーの起動がタイムアウトしました")
    endpoint = json.loads(server.stdout.readline())["base_url"]
    environment = os.environ.copy()
    environment["KOTOFLOAT_TEST_BASE_URL"] = endpoint
    result = subprocess.run(["nice", "-n", "10", "swift", "test", "--jobs", "2", "--skip", "PopupControllerTests"],
                            cwd=root, env=environment)
    sys.exit(result.returncode)
finally:
    server.terminate()
    try:
        server.wait(timeout=5)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    server.stdout.close()
