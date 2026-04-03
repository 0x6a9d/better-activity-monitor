#!/usr/bin/env python3
import struct
import sys
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TYPE_BY_SIZE = {
    16: "icp4",
    32: "icp5",
    64: "icp6",
    128: "ic07",
    256: "ic08",
    512: "ic09",
    1024: "ic10",
}


def chunk(icon_type: str, data: bytes) -> bytes:
    return icon_type.encode("ascii") + struct.pack(">I", len(data) + 8) + data


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: pngs_to_icns.py <iconset_dir> <output.icns>", file=sys.stderr)
        return 1

    iconset_dir = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    chunks = []

    for size, icon_type in TYPE_BY_SIZE.items():
        png_path = iconset_dir / f"{size}.png"
        if not png_path.is_file():
            print(f"missing required PNG: {png_path}", file=sys.stderr)
            return 1

        data = png_path.read_bytes()
        if not data.startswith(PNG_SIGNATURE):
            print(f"not a PNG file: {png_path}", file=sys.stderr)
            return 1

        chunks.append(chunk(icon_type, data))

    payload = b"".join(chunks)
    output_path.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
