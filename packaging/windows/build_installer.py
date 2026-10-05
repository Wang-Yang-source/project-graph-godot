#!/usr/bin/env python3
"""Compile the Windows installer on Linux using pinned NSIS, without Wine."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def toolchain():
    lock = json.loads((HERE / "nsis-toolchain.lock.json").read_text())
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise RuntimeError("Bundled toolchain requires Linux x86_64; use --makensis.")
    for tool in ("rpm2cpio", "cpio"):
        if not shutil.which(tool):
            raise RuntimeError(f"Required host tool missing: {tool}")
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    cache /= f"project-graph-nsis/{lock['version']}-{lock['release']}"
    cache.mkdir(parents=True, exist_ok=True)
    # Always verify inputs, even if the compiler was previously extracted.
    with tempfile.TemporaryDirectory(dir=cache) as temporary:
        staging = Path(temporary)
        for package in lock["packages"]:
            rpm = cache / package["url"].rsplit("/", 1)[1]
            if not rpm.exists():
                download = staging / rpm.name
                with urllib.request.urlopen(package["url"], timeout=60) as source:
                    with download.open("wb") as destination:
                        shutil.copyfileobj(source, destination)
                download.replace(rpm)
            with rpm.open("rb") as archive_input:
                digest = hashlib.file_digest(archive_input, "sha256").hexdigest()
            if digest != package["sha256"]:
                raise RuntimeError(f"SHA-256 mismatch: {rpm}; remove it and retry")
            archive = staging / "package.cpio"
            with archive.open("wb") as destination:
                subprocess.run(["rpm2cpio", str(rpm)], stdout=destination, check=True)
            with archive.open("rb") as source:
                subprocess.run(["cpio", "-idm", "--quiet", "--no-absolute-filenames"],
                               stdin=source, cwd=staging, check=True)
        extracted = cache / "root"
        if extracted.exists():
            shutil.rmtree(extracted)
        (staging / "usr").rename(cache / "usr.new")
        extracted.mkdir()
        (cache / "usr.new").rename(extracted / "usr")
    return extracted / "usr/bin/makensis", extracted / "usr/share/nsis"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="0.1.21")
    parser.add_argument("--export-dir", type=Path, default=ROOT / "builds/windows")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--makensis", type=Path, help="Externally managed NSIS 3.11 compiler")
    parser.add_argument("--nsis-dir", type=Path, help="NSIS data directory for --makensis")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){2}(?:[-+][A-Za-z0-9.-]+)?", args.version):
        parser.error("version must be a semantic version")
    export = args.export_dir.resolve()
    if not (export / "Project Graph.exe").is_file():
        parser.error(f"Missing Godot Windows export: {export / 'Project Graph.exe'}")
    compiler, data = (args.makensis.resolve(), args.nsis_dir) if args.makensis else toolchain()
    env = os.environ.copy()
    if data:
        env["NSISDIR"] = str(data.resolve())
    version = subprocess.check_output([str(compiler), "-VERSION"], env=env, text=True).strip()
    if version != "v3.11":
        parser.error(f"Expected NSIS v3.11, got {version}")
    output = (args.output or ROOT / f"builds/installer/ProjectGraph-Setup-{args.version}-nsis.exe").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([str(compiler), "-V3", f"-DAppVersion={args.version}",
                    f"-DExportDir={export}", f"-DOutputFile={output}",
                    str(HERE / "ProjectGraph.nsi")], cwd=HERE, env=env, check=True)
    with output.open("rb") as artifact:
        digest = hashlib.file_digest(artifact, "sha256").hexdigest()
    output.with_suffix(output.suffix + ".sha256").write_text(f"{digest}  {output.name}\n")
    shutil.copyfile(HERE / "NSIS-3.11-COPYING.txt",
                    output.with_suffix(output.suffix + ".licenses.txt"))
    print(f"Built {output}\nSHA-256: {digest}")


if __name__ == "__main__":
    main()
