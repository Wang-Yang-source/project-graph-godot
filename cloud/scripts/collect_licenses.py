#!/usr/bin/env python3
"""Collect pinned build/module and runtime licenses alongside release binaries."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import urllib.request


def collect(root):
    root = Path(root).resolve() / "licenses"
    root.mkdir(parents=True, exist_ok=True)
    metadata = subprocess.check_output(["go", "list", "-deps", "-json", "."], text=True)
    decoder = json.JSONDecoder()
    seen = set()
    while metadata.strip():
        package, end = decoder.raw_decode(metadata.lstrip())
        metadata = metadata.lstrip()[end:]
        module = package.get("Module")
        if not module or module.get("Main") or module["Path"] in seen:
            continue
        seen.add(module["Path"])
        directory = Path(module["Dir"])
        found = False
        for pattern in ("LICENSE*", "COPYING*", "NOTICE*"):
            for source in directory.glob(pattern):
                if source.is_file():
                    target = module["Path"].replace("/", "_") + "@" + module["Version"] + "-" + source.name
                    shutil.copyfile(source, root / target)
                    found = True
        if not found:
            raise SystemExit("Missing module license: " + module["Path"])
    goroot = Path(subprocess.check_output(["go", "env", "GOROOT"], text=True).strip())
    go_license = goroot / "LICENSE"
    if not go_license.exists():
        go_license = Path("/usr/share/licenses/golang/LICENSE")
    if not go_license.exists():
        raise SystemExit("Go runtime license was not found; provide the compiler distribution's LICENSE.")
    shutil.copyfile(go_license, root / "go-LICENSE")
    for name, url in [
        ("supabase-auth-v2.197.0-LICENSE", "https://raw.githubusercontent.com/supabase/auth/v2.197.0/LICENSE"),
        ("mailpit-v1.31.4-LICENSE", "https://raw.githubusercontent.com/axllent/mailpit/v1.31.4/LICENSE"),
    ]:
        with urllib.request.urlopen(url, timeout=30) as response:
            (root / name).write_bytes(response.read())
    print("Third-party license files collected at", root)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime_dir")
    collect(parser.parse_args().runtime_dir)
