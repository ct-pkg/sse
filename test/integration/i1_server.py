#!/usr/bin/env python3
"""Loopback SSE origin for the I-1 integration gate.

Prints "PORT <n>" on stdout, accepts one POST, and writes the scripted body in
separate TCP writes with a short pause so chunk boundaries land inside lines.
Standard library only.
"""

import socket
import sys
import time

CHUNKS = [
    b"\xef", b"\xbb", b"\xbf",
    b"retry: 2500\nid: 7\n",
    b"data: hel", b"lo\n\n",
    b"event: tick\ndata: a\n", b"data: b\n\n",
    b"data: x", b"yz\n\n",
    b"id:\n", b"event: end\ndata: bye\n\n",
    b"data: dropped",
]


def main() -> int:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(1)
    srv.settimeout(10)
    print("PORT %d" % srv.getsockname()[1], flush=True)

    try:
        conn, _ = srv.accept()
    except socket.timeout:
        print("TIMEOUT waiting for the client", file=sys.stderr)
        return 1

    try:
        head = b""
        while b"\r\n\r\n" not in head:
            part = conn.recv(4096)
            if not part:
                print("client closed before the request head", file=sys.stderr)
                return 1
            head += part
        conn.sendall(
            b"HTTP/1.1 200 OK\r\n"
            b"Content-Type: text/event-stream\r\n"
            b"Cache-Control: no-cache\r\n"
            b"Connection: close\r\n\r\n"
        )
        for chunk in CHUNKS:
            conn.sendall(chunk)
            time.sleep(0.04)
    except (BrokenPipeError, ConnectionResetError):
        pass
    finally:
        conn.close()
        srv.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
