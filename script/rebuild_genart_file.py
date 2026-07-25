import argparse
import hashlib
import json
import subprocess

from pathlib import Path


EVENT_SIG = "GenerativeScriptChunk(uint256,uint256,bytes)"
REPO_ROOT = Path(__file__).resolve().parent.parent


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Rebuild a gen art script from GenerativeScriptChunk logs and compare it "
            "to the original file. Reverse of chunk_genart_file.py."
        )
    )
    parser.add_argument("file", type=Path, help="Path to the original file to compare against.")
    parser.add_argument(
        "--from-block",
        default="0",
        help="Block to start searching from. Defaults to 0.",
    )
    parser.add_argument(
        "--to-block",
        default="latest",
        help="Block to search through. Defaults to latest.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        help="Optional path to write the reassembled script to.",
    )
    parser.add_argument(
        "cast_args",
        nargs="*",
        help="Extra args for cast logs, e.g. -- --etherscan-api-key KEY.",
    )
    return parser.parse_args()


def fetch_logs(rpc_url: str, contract: str, version: int, args: argparse.Namespace) -> list[dict]:
    """Fetch GenerativeScriptChunk logs for a single script version."""
    # Topics are passed as raw 32-byte hex so cast doesn't need the indexed-arg form of the sig.
    result = subprocess.run(
        [
            "cast",
            "logs",
            EVENT_SIG,
            f"0x{version:064x}",
            "--address",
            contract,
            "--from-block",
            args.from_block,
            "--to-block",
            args.to_block,
            "--rpc-url",
            rpc_url,
            "--json",
            *args.cast_args,
        ],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def decode_chunk(data: str) -> bytes:
    """Decode the abi-encoded `bytes chunk` payload from a log's data field."""
    raw = bytes.fromhex(data.removeprefix("0x"))
    if len(raw) < 64:
        raise ValueError(f"log data too short to hold an abi-encoded bytes value: {len(raw)} bytes")
    offset = int.from_bytes(raw[0:32], "big")
    length = int.from_bytes(raw[offset : offset + 32], "big")
    start = offset + 32
    chunk = raw[start : start + length]
    if len(chunk) != length:
        raise ValueError(f"log data truncated: expected {length} bytes, got {len(chunk)}")
    return chunk


def main() -> int:
    args = parse_args()
    file_path = args.file.expanduser()

    if not file_path.is_file():
        print(f"error: file does not exist or is not a regular file: {file_path}")
        return 1

    original = file_path.read_bytes()
    original_digest = hashlib.sha256(original).hexdigest()

    print(f"file: {file_path}")
    print(f"size: {len(original)} bytes")
    print(f"sha256: {original_digest}")
    print()

    rpc_url = input("chain (foundry.toml alias or rpc url): ").strip()
    contract = input("rendering contract address: ").strip()
    version = int(input("script version: ").strip(), 10)
    print()

    logs = fetch_logs(rpc_url, contract, version, args)
    if not logs:
        print(f"error: no GenerativeScriptChunk logs found for version {version}")
        return 1

    # Sort by chain order so a re-sent chunkIndex overwrites the earlier attempt.
    logs.sort(key=lambda log: (int(log["blockNumber"], 16), int(log["logIndex"], 16)))
    chunks: dict[int, bytes] = {}
    for log in logs:
        chunks[int(log["topics"][2], 16)] = decode_chunk(log["data"])

    missing = [i for i in range(max(chunks) + 1) if i not in chunks]
    if missing:
        print(f"error: missing chunk indices: {missing}")
        return 1

    rebuilt = b"".join(chunks[i] for i in sorted(chunks))
    rebuilt_digest = hashlib.sha256(rebuilt).hexdigest()

    print(f"logs: {len(logs)}")
    print(f"chunks: {len(chunks)}")
    print(f"rebuilt size: {len(rebuilt)} bytes")
    print(f"rebuilt sha256: {rebuilt_digest}")
    print()

    if args.out:
        out_path = args.out.expanduser()
        out_path.write_bytes(rebuilt)
        print(f"wrote: {out_path}")

    if rebuilt_digest != original_digest:
        print("MISMATCH: on-chain script does not match the original file")
        return 1

    print("MATCH: on-chain script matches the original file")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
