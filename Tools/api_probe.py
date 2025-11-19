#!/usr/bin/env python3
"""
Lightweight, extendable probe for the HypeM API.

Starts with auth; add more steps by appending functions to STEPS below.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zlib
from dataclasses import dataclass
from typing import Dict, Optional, Tuple


DEFAULT_USER_AGENT = "com.hypem.hyperadio/2.8.9 (iPadOS)"
LOG_CAPTURED_USER_AGENT = "com.hypem.hyperadio/2.8.9 (unknown, iPadOS 26.1, iPad, Scale/1.000000)"
try:
    import requests

    HAS_REQUESTS = True
except Exception:
    HAS_REQUESTS = False


def http_request(
    url: str,
    method: str = "GET",
    headers: Optional[Dict[str, str]] = None,
    data: Optional[Dict[str, str]] = None,
    timeout: float = 5.0,
    transport: str = "requests",
) -> Tuple[int, bytes, Dict[str, str], float]:
    """Perform an HTTP request with urlencoded body support and return status/body/headers/elapsed."""
    if transport == "requests":
        if not HAS_REQUESTS:
            raise RuntimeError("requests not available; install it or pick --transport urllib")
        start = time.time()
        resp = requests.request(method=method, url=url, headers=headers or {}, data=data, timeout=timeout)
        elapsed = time.time() - start
        return resp.status_code, resp.content, {k.lower(): v for k, v in resp.headers.items()}, elapsed

    headers = headers or {}
    body_bytes = None
    if data is not None:
        body_bytes = urllib.parse.urlencode(data).encode("utf-8")
        headers.setdefault("Content-Type", "application/x-www-form-urlencoded")

    req = urllib.request.Request(url, data=body_bytes, headers=headers, method=method)
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = resp.getcode()
            response_headers = {k.lower(): v for k, v in resp.headers.items()}
            raw_body = resp.read()
    except urllib.error.HTTPError as e:
        status = e.code
        response_headers = {k.lower(): v for k, v in e.headers.items()}
        raw_body = e.read()
    except urllib.error.URLError as e:
        raise RuntimeError(f"Request error: {e.reason}") from e
    elapsed = time.time() - start

    if response_headers.get("content-encoding", "").lower() == "gzip":
        try:
            raw_body = zlib.decompress(raw_body, 16 + zlib.MAX_WBITS)
        except zlib.error:
            pass  # leave raw bytes intact if unzip fails

    return status, raw_body, response_headers, elapsed


@dataclass
class Context:
    hm_token: Optional[str] = None


def standard_headers(args: argparse.Namespace) -> Dict[str, str]:
    return {
        "User-Agent": args.user_agent,
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Accept-Encoding": "gzip",
        "Connection": "keep-alive",
    }


def print_response(label: str, status: int, elapsed: float, body: bytes) -> None:
    body_str = body.decode("utf-8", errors="replace")
    print(f"[{label}] status={status} elapsed={elapsed:.2f}s")
    print(f"[{label}] raw response body:\n{body_str}")
    try:
        parsed = json.loads(body_str)
        print(f"[{label}] parsed JSON: {json.dumps(parsed, indent=2)}")
    except json.JSONDecodeError:
        print(f"[{label}] non-JSON response")


def step_auth(args: argparse.Namespace, ctx: Context) -> None:
    url = urllib.parse.urljoin(args.base, "get_token")
    headers = standard_headers(args)
    headers["Content-Type"] = "application/x-www-form-urlencoded"
    payload = {
        "username": args.username,
        "password": args.password,
        "key": args.api_key,
        "device_id": args.device_id,
    }
    status, body, _, elapsed = http_request(
        url, method="POST", headers=headers, data=payload, timeout=args.timeout, transport=args.transport
    )
    print_response("auth", status, elapsed, body)
    try:
        parsed = json.loads(body.decode("utf-8", errors="replace"))
        ctx.hm_token = parsed.get("hm_token")
    except Exception:
        ctx.hm_token = None


def step_motd(args: argparse.Namespace, ctx: Context) -> None:
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, "motd") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("motd", status, elapsed, body)


def step_whats_new(args: argparse.Namespace, ctx: Context) -> None:
    params = {"key": args.api_key, "count": args.whats_new_count, "page": args.whats_new_page}
    url = urllib.parse.urljoin(args.base, "whats_new") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("whats_new", status, elapsed, body)


def step_popular(args: argparse.Namespace, ctx: Context) -> None:
    params = {
        "mode": args.popular_mode,
        "key": args.api_key,
        "count": args.popular_count,
        "page": args.popular_page,
    }
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, "popular") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("popular", status, elapsed, body)


def step_user_profile(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[user] skipping, hm_token missing")
        return
    params = {"key": args.api_key, "hm_token": ctx.hm_token}
    url = urllib.parse.urljoin(args.base, f"users/{args.username}") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("user", status, elapsed, body)


def step_feed_count(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[feed_count] skipping, hm_token missing")
        return
    params = {"key": args.api_key, "hm_token": ctx.hm_token}
    url = urllib.parse.urljoin(args.base, "me/feed/count") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("feed_count", status, elapsed, body)


def step_feed(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[feed] skipping, hm_token missing")
        return
    params = {
        "mode": args.feed_mode,
        "key": args.api_key,
        "count": args.feed_count,
        "hm_token": ctx.hm_token,
        "page": args.feed_page,
    }
    url = urllib.parse.urljoin(args.base, "me/feed") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("feed", status, elapsed, body)


def step_favorites(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[favorites] skipping, hm_token missing")
        return
    params = {
        "key": args.api_key,
        "hm_token": ctx.hm_token,
        "page": args.fav_page,
    }
    url = urllib.parse.urljoin(args.base, "me/favorites") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("favorites", status, elapsed, body)


def step_history(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[history] skipping, hm_token missing")
        return
    params = {
        "key": args.api_key,
        "hm_token": ctx.hm_token,
        "page": args.history_page,
    }
    url = urllib.parse.urljoin(args.base, "me/history") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("history", status, elapsed, body)


def step_ad_status(args: argparse.Namespace, ctx: Context) -> None:
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, "ad_status_balanced") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("ad_status", status, elapsed, body)


def step_blogs(args: argparse.Namespace, ctx: Context) -> None:
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, "blogs") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("blogs", status, elapsed, body)


def step_blog_detail(args: argparse.Namespace, ctx: Context) -> None:
    if args.blog_id is None:
        print("[blog_detail] skipping, no blog_id")
        return
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, f"blogs/{args.blog_id}") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("blog_detail", status, elapsed, body)


def step_blog_tracks(args: argparse.Namespace, ctx: Context) -> None:
    if args.blog_id is None:
        print("[blog_tracks] skipping, no blog_id")
        return
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, f"blogs/{args.blog_id}/tracks") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("blog_tracks", status, elapsed, body)


def step_tracks(args: argparse.Namespace, ctx: Context) -> None:
    params = {
        "mode": args.tracks_mode,
        "key": args.api_key,
        "count": args.tracks_count,
        "page": args.tracks_page,
    }
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, "tracks") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("tracks", status, elapsed, body)


def step_track_blogs(args: argparse.Namespace, ctx: Context) -> None:
    if args.track_id is None:
        print("[track_blogs] skipping, no track_id")
        return
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, f"tracks/{args.track_id}/blogs") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("track_blogs", status, elapsed, body)


def step_tag_tracks(args: argparse.Namespace, ctx: Context) -> None:
    if args.tag_name is None:
        print("[tag_tracks] skipping, no tag_name")
        return
    encoded_tag = urllib.parse.quote(args.tag_name, safe="")
    params = {"key": args.api_key}
    if ctx.hm_token:
        params["hm_token"] = ctx.hm_token
    url = urllib.parse.urljoin(args.base, f"tags/{encoded_tag}/tracks") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("tag_tracks", status, elapsed, body)


def step_playlists(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[playlists] skipping, hm_token missing")
        return
    headers = standard_headers(args)
    for slot in args.playlist_slots:
        params = {"key": args.api_key, "hm_token": ctx.hm_token}
        url = urllib.parse.urljoin(args.base, f"me/playlists/{slot}") + "?" + urllib.parse.urlencode(params)
        status, body, _, elapsed = http_request(
            url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
        )
        print_response(f"playlist_{slot}", status, elapsed, body)


def step_playlist_names(args: argparse.Namespace, ctx: Context) -> None:
    if not ctx.hm_token:
        print("[playlist_names] skipping, hm_token missing")
        return
    params = {
        "key": args.api_key,
        "hm_token": ctx.hm_token,
    }
    url = urllib.parse.urljoin(args.base, "me/playlist_names") + "?" + urllib.parse.urlencode(params)
    headers = standard_headers(args)
    status, body, _, elapsed = http_request(
        url, method="GET", headers=headers, timeout=args.timeout, transport=args.transport
    )
    print_response("playlist_names", status, elapsed, body)


STEPS = [
    ("auth", step_auth),
    ("ad_status", step_ad_status),
    ("motd", step_motd),
    ("whats_new", step_whats_new),
    ("popular", step_popular),
    ("user", step_user_profile),
    ("feed_count", step_feed_count),
    ("feed", step_feed),
    ("favorites", step_favorites),
    ("history", step_history),
    ("playlist_names", step_playlist_names),
    ("playlists", step_playlists),
    ("blogs", step_blogs),
    ("blog_detail", step_blog_detail),
    ("blog_tracks", step_blog_tracks),
    ("tracks", step_tracks),
    ("track_blogs", step_track_blogs),
    ("tag_tracks", step_tag_tracks),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="HypeM API probe (auth + key endpoints).")
    parser.add_argument("--base", default="https://api.hypem.com/v2/", help="Base API URL.")
    parser.add_argument("--user-agent", default=DEFAULT_USER_AGENT, help="User-Agent header.")
    parser.add_argument(
        "--user-agent-log",
        action="store_true",
        help="Use the captured log User-Agent (iPadOS 26.1 signature). Overrides --user-agent.",
    )
    parser.add_argument("--timeout", type=float, default=5.0, help="Per-request timeout seconds.")
    parser.add_argument("--api-key", default=os.getenv("HYPEM_API_KEY"), help="API key (env HYPEM_API_KEY).")
    parser.add_argument("--device-id", default=None, help="Device ID (hex). Defaults to random server-side.")
    parser.add_argument("--steps", nargs="*", default=["auth", "motd", "whats_new", "popular"], help="Steps to run in order.")
    parser.add_argument(
        "--transport",
        default="requests" if HAS_REQUESTS else "urllib",
        choices=["requests", "urllib"],
        help="HTTP transport to use (default: requests if available).",
    )

    parser.add_argument("--username", default=os.getenv("HYPEM_USERNAME"), help="Username (env HYPEM_USERNAME).")
    parser.add_argument("--password", default=os.getenv("HYPEM_PASSWORD"), help="Password (env HYPEM_PASSWORD).")
    parser.add_argument("--popular-mode", default="noremix", help="Popular mode param.")
    parser.add_argument("--popular-count", type=int, default=50, help="Popular count.")
    parser.add_argument("--popular-page", type=int, default=1, help="Popular page.")
    parser.add_argument("--whats-new-count", type=int, default=20, help="Whats_new count.")
    parser.add_argument("--whats-new-page", type=int, default=1, help="Whats_new page.")
    parser.add_argument("--feed-mode", default="all", help="Feed mode param.")
    parser.add_argument("--feed-count", type=int, default=40, help="Feed count param.")
    parser.add_argument("--feed-page", type=int, default=1, help="Feed page param.")
    parser.add_argument("--fav-page", type=int, default=1, help="Favorites page.")
    parser.add_argument("--history-page", type=int, default=1, help="History page.")
    parser.add_argument("--tracks-mode", default="remix", help="Tracks mode param.")
    parser.add_argument("--tracks-count", type=int, default=50, help="Tracks count.")
    parser.add_argument("--tracks-page", type=int, default=1, help="Tracks page.")
    parser.add_argument("--blog-id", default=22324, help="Blog id for detail/tracks steps.")
    parser.add_argument("--track-id", default="35v72", help="Track id for track_blogs.")
    parser.add_argument("--tag-name", default="classic rock", help="Tag name for tag_tracks (will be URL encoded).")
    parser.add_argument(
        "--playlist-slots",
        nargs="*",
        default=["1", "2", "3"],
        help="Playlist slots to fetch (e.g., 1 2 3).",
    )
    args = parser.parse_args()

    if args.user_agent_log:
        args.user_agent = LOG_CAPTURED_USER_AGENT

    missing = [name for name in ["username", "password", "api_key"] if getattr(args, name) is None]
    if missing:
        parser.error(f"Missing required args: {', '.join(missing)} (set env vars HYPEM_USERNAME, HYPEM_PASSWORD, HYPEM_API_KEY)")
    if args.device_id is None:
        # leave empty; API accepts random when absent
        args.device_id = ""
    return args


def main() -> None:
    args = parse_args()
    ctx = Context()
    available = dict(STEPS)
    for name in args.steps:
        step = available.get(name)
        if step is None:
            print(f"Unknown step '{name}'. Available: {', '.join(available.keys())}", file=sys.stderr)
            sys.exit(1)
        print(f"== Running step: {name} ==")
        step(args, ctx)


if __name__ == "__main__":
    main()
