#!/usr/bin/env python3
"""Print a file as pasteable hex chunks."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


DEFAULT_CHUNK_SIZE = 48 * 1000


def positive_int(value: str) -> int:
    parsed = int(value, 10)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print a file one hex chunk at a time."
    )
    parser.add_argument("file", type=Path, help="Path to the file to chunk.")
    parser.add_argument(
        "--chunk-size",
        type=positive_int,
        default=DEFAULT_CHUNK_SIZE,
        help="Chunk size in bytes. Defaults to 204800 bytes (200 KiB).",
    )
    parser.add_argument(
        "--start",
        type=int,
        default=0,
        help="Zero-based chunk index to start from. Defaults to 0.",
    )
    parser.add_argument(
        "--no-prefix",
        action="store_true",
        help="Print raw hex without the 0x prefix.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    file_path = args.file.expanduser()

    if not file_path.is_file():
        print(f"error: file does not exist or is not a regular file: {file_path}")
        return 1

    if args.start < 0:
        print("error: --start must be zero or greater")
        return 1

    data = file_path.read_bytes()
    chunks = [
        data[i : i + args.chunk_size] for i in range(0, len(data), args.chunk_size)
    ] or [b""]
    digest = hashlib.sha256(data).hexdigest()
    prefix = "" if args.no_prefix else "0x"

    if args.start >= len(chunks):
        print(f"error: --start must be less than total chunks ({len(chunks)})")
        return 1

    print(f"file: {file_path}")
    print(f"size: {len(data)} bytes")
    print(f"sha256: {digest}")
    print(f"chunk size: {args.chunk_size} bytes")
    print(f"chunks: {len(chunks)}")
    print()

    for chunk_index in range(args.start, len(chunks)):
        chunk = chunks[chunk_index]
        print(f"chunk {chunk_index + 1}/{len(chunks)}")
        print(f"chunkIndex: {chunk_index}")
        print(f"sizeBytes: {len(chunk)}")
        print(f"{prefix}{chunk.hex()}")
        print()

        if chunk_index == len(chunks) - 1:
            break

        response = input("Press Enter for next chunk, or q then Enter to quit: ")
        if response.lower() == "q":
            break
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
