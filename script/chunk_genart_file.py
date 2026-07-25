import argparse
import hashlib
import subprocess

from pathlib import Path


DEFAULT_CHUNK_SIZE = 48 * 1000
STORE_SCRIPT_CHUNK_SIG = "storeScriptChunk(uint256,uint256,bytes)"
REPO_ROOT = Path(__file__).resolve().parent.parent


def positive_int(value: str) -> int:
    parsed = int(value, 10)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Send a file to a gen art rendering contract one chunk at a time."
    )
    parser.add_argument("file", type=Path, help="Path to the file to chunk.")
    parser.add_argument(
        "--chunk-size",
        type=positive_int,
        default=DEFAULT_CHUNK_SIZE,
        help=f"Chunk size in bytes. Defaults to {DEFAULT_CHUNK_SIZE} bytes.",
    )
    parser.add_argument(
        "--start",
        type=int,
        default=0,
        help="Zero-based chunk index to start from. Defaults to 0.",
    )
    parser.add_argument(
        "cast_args",
        nargs="*",
        help="Extra args for cast send, e.g. -- --account deployer. Defaults to --ledger.",
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

    if args.start >= len(chunks):
        print(f"error: --start must be less than total chunks ({len(chunks)})")
        return 1

    print(f"file: {file_path}")
    print(f"size: {len(data)} bytes")
    print(f"sha256: {digest}")
    print(f"chunk size: {args.chunk_size} bytes")
    print(f"chunks: {len(chunks)}")
    print()

    rpc_url = input("chain (foundry.toml alias or rpc url): ").strip()
    contract = input("rendering contract address: ").strip()
    version = input("script version: ").strip()
    cast_args = args.cast_args or ["--ledger"]
    print()

    for chunk_index in range(args.start, len(chunks)):
        chunk = chunks[chunk_index]
        print(f"chunk {chunk_index + 1}/{len(chunks)}")
        print(f"chunkIndex: {chunk_index}")
        print(f"sizeBytes: {len(chunk)}")

        response = input("Press Enter to send, or q then Enter to quit: ")
        if response.lower() == "q":
            break

        # Run from the repo root so foundry.toml rpc aliases and .env resolve, and
        # without capturing output so ledger/keystore prompts stay interactive.
        result = subprocess.run(
            [
                "cast",
                "send",
                contract,
                STORE_SCRIPT_CHUNK_SIG,
                version,
                str(chunk_index),
                f"0x{chunk.hex()}",
                "--rpc-url",
                rpc_url,
                *cast_args,
            ],
            cwd=REPO_ROOT,
            check=False,
        )
        if result.returncode != 0:
            print(
                f"error: chunk {chunk_index} failed, resume with --start {chunk_index}"
            )
            return 1
        print()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
