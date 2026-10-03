#!/usr/bin/env python3
"""Download pinned Linux x86_64 runtimes and verify upstream release digests."""
import argparse
import hashlib
from pathlib import Path
import tarfile
import urllib.request

RELEASES = [
    ("auth", "https://github.com/supabase/auth/releases/download/v2.197.0/auth-v2.197.0-amd64.tar.xz", "b5c2991d1df760c9b099c1c2395a94bd1c2f83ed58901934921997179dc9f7ea"),
    ("mailpit", "https://github.com/axllent/mailpit/releases/download/v1.31.4/mailpit-linux-amd64.tar.gz", "30942c4605c2ca8b9f759b1bb4e3ab6a12bdfdf66e5c94644ec2c75ac41e88e7"),
]


def download(root):
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    for name, url, digest in RELEASES:
        archive = root / url.rsplit("/", 1)[1]
        if not archive.exists():
            with urllib.request.urlopen(url, timeout=60) as response:
                archive.write_bytes(response.read())
        if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
            raise SystemExit("Checksum mismatch: " + name)
        with tarfile.open(archive) as tar:
            member = tar.getmember(name)
            with tar.extractfile(member) as source:
                (root / name).write_bytes(source.read())
            (root / name).chmod(0o755)
        print(name, "release checksum verified")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime_dir")
    download(parser.parse_args().runtime_dir)
