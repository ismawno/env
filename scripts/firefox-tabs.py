#!/usr/bin/env python3
"""Dump the open tabs of a Firefox-family profile (LibreWolf, Zen, Firefox).

Reads sessionstore-backups/recovery.jsonlz4 (mozlz4) and writes:
  - a Netscape bookmark HTML file, importable by any browser
  - a plain-text listing

Pure stdlib: the LZ4 block decompressor below avoids needing python3Packages.lz4.

Usage: firefox-tabs.py PROFILE_DIR [OUT_PREFIX]
"""

import json
import os
import sys
from html import escape

MAGIC = b"mozLz40\0"


def lz4_block_decompress(src, uncompressed_size):
    """Decode a raw LZ4 block (the format mozlz4 wraps)."""
    dst = bytearray(uncompressed_size)
    s, d, n = 0, 0, len(src)

    while s < n:
        token = src[s]
        s += 1

        length = token >> 4
        if length == 15:
            while True:
                b = src[s]
                s += 1
                length += b
                if b != 255:
                    break
        if length:
            dst[d : d + length] = src[s : s + length]
            s += length
            d += length

        if s >= n:  # last sequence has no match part
            break

        offset = src[s] | (src[s + 1] << 8)
        s += 2
        if offset == 0:
            raise ValueError("corrupt lz4 stream: zero offset")

        length = token & 0x0F
        if length == 15:
            while True:
                b = src[s]
                s += 1
                length += b
                if b != 255:
                    break
        length += 4  # minmatch

        # Overlapping copies are legal and common, so copy byte by byte.
        p = d - offset
        for i in range(length):
            dst[d + i] = dst[p + i]
        d += length

    return bytes(dst[:d])


def read_mozlz4(path):
    with open(path, "rb") as f:
        blob = f.read()
    if not blob.startswith(MAGIC):
        raise ValueError(f"{path}: not a mozlz4 file")
    size = int.from_bytes(blob[8:12], "little")
    return lz4_block_decompress(blob[12:], size)


def find_session(profile):
    candidates = [
        os.path.join(profile, "sessionstore-backups", "recovery.jsonlz4"),
        os.path.join(profile, "sessionstore-backups", "recovery.baklz4"),
        os.path.join(profile, "sessionstore-backups", "previous.jsonlz4"),
        os.path.join(profile, "sessionstore.jsonlz4"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    raise SystemExit(f"no sessionstore found under {profile}")


def collect(session):
    """-> [(window_label, [(title, url), ...]), ...]"""
    out = []
    windows = list(session.get("windows", []))
    windows += list(session.get("_closedWindows", []))
    for i, win in enumerate(windows, 1):
        tabs = []
        for tab in win.get("tabs", []):
            entries = tab.get("entries", [])
            if not entries:
                continue
            idx = max(0, min(tab.get("index", len(entries)) - 1, len(entries) - 1))
            entry = entries[idx]
            url = entry.get("url", "")
            if not url or url.startswith("about:"):
                continue
            tabs.append((entry.get("title") or url, url))
        if tabs:
            out.append((f"Window {i}", tabs))
    return out


def write_html(groups, path):
    lines = [
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
        "<TITLE>Bookmarks</TITLE>",
        "<H1>Bookmarks</H1>",
        "<DL><p>",
        "    <DT><H3>LibreWolf open tabs</H3>",
        "    <DL><p>",
    ]
    for label, tabs in groups:
        lines.append(f"        <DT><H3>{escape(label)}</H3>")
        lines.append("        <DL><p>")
        for title, url in tabs:
            lines.append(
                f'            <DT><A HREF="{escape(url, quote=True)}">{escape(title)}</A>'
            )
        lines.append("        </DL><p>")
    lines += ["    </DL><p>", "</DL><p>", ""]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def write_txt(groups, path):
    with open(path, "w", encoding="utf-8") as f:
        for label, tabs in groups:
            f.write(f"# {label} ({len(tabs)} tabs)\n")
            for title, url in tabs:
                f.write(f"- {title}\n  {url}\n")
            f.write("\n")


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    profile = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else "tabs"

    session = json.loads(read_mozlz4(find_session(profile)))
    groups = collect(session)
    total = sum(len(t) for _, t in groups)

    write_html(groups, prefix + ".html")
    write_txt(groups, prefix + ".txt")
    print(f"{total} tabs across {len(groups)} windows -> {prefix}.html, {prefix}.txt")


if __name__ == "__main__":
    main()
