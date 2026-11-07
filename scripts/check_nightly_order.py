"""Keep a late-finishing build from replacing a newer nightly APK."""
import argparse
from pathlib import Path
import re


def should_publish(build_number: int, published_notes: str) -> bool:
    if build_number <= 0:
        raise ValueError("The nightly build number must be positive.")
    if not published_notes.strip():
        return True
    marker = re.search(r"<!-- maia-nightly-build:\s*(\d+)\s*-->", published_notes)
    if marker is None:
        # Existing nightlies predate the machine-readable marker.
        marker = re.search(
            r"^- Version: .+ \(build (\d+)\)\s*$", published_notes, re.MULTILINE
        )
    if marker is None:
        raise ValueError("The published nightly has no readable build number.")
    # A rerun of the same build may need to repair a partial upload.
    return build_number >= int(marker.group(1))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build_number", type=int)
    parser.add_argument("published_notes", type=Path)
    args = parser.parse_args()
    try:
        publish = should_publish(
            args.build_number, args.published_notes.read_text(encoding="utf-8")
        )
    except ValueError as error:
        parser.error(str(error))
    print("publish" if publish else "skip")


if __name__ == "__main__":
    main()
