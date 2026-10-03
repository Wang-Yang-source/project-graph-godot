#!/usr/bin/env python3
"""Deploy the private test stack over SSH without changing existing Caddy sites."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile


def run(host, runtime, archive):
    runtime, archive = Path(runtime).resolve(), Path(archive).resolve()
    if host.startswith("-") or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-@" for c in host):
        raise SystemExit("Use an SSH host alias or user@hostname.")
    root = "/opt/project-graph-cloud"
    scripts = Path(__file__).resolve().parent
    artifacts = [runtime / "auth", runtime / "mailpit", runtime / "project-graph-cloud", archive]
    if archive.name != "postgres.tar.gz":
        raise SystemExit("The archive must be named postgres.tar.gz.")
    for path in artifacts:
        if not path.is_file():
            raise SystemExit("Missing build artifact: " + str(path))
    if not (runtime / "licenses").is_dir():
        raise SystemExit("Run collect_licenses.py before deployment.")
    subprocess.run(["ssh", host, "install -d -m 700 " + root + " " + root + "/bin " + root + "/scripts " + root + "/incoming"], check=True)
    subprocess.run(["scp", "-q", *map(str, artifacts), host + ":" + root + "/incoming/"], check=True)
    subprocess.run(["scp", "-q", str(scripts / "configure.py"), str(scripts / "e2e.py"), host + ":" + root + "/scripts/"], check=True)
    subprocess.run(["scp", "-q", "-r", str(runtime / "licenses"), host + ":" + root + "/"], check=True)
    with tempfile.TemporaryDirectory(prefix="pg-cloud-checksums-") as directory:
        checksums = Path(directory) / "checksums.sha256"
        checksums.write_text("".join(hashlib.sha256(path.read_bytes()).hexdigest() + "  " + path.name + "\n" for path in artifacts))
        subprocess.run(["scp", "-q", str(checksums), host + ":" + root + "/incoming/"], check=True)
    command = f"""set -eu
cd {root}/incoming
sha256sum -c checksums.sha256
podman image exists sha256:248efd5e58cd743f2a0e0daec8ea4649e5580145ec2a12e2345bc710d4a77201 || podman load -i postgres.tar.gz
install -m 755 auth mailpit project-graph-cloud {root}/bin/
if test -f {root}/config/auth.env; then
  python3 -c 'import sys; sys.path.insert(0, "{root}/scripts"); from configure import install_units; install_units("{root}")'
else
  python3 {root}/scripts/configure.py {root} --install-systemd
fi
systemctl daemon-reload
systemctl enable pg-cloud-postgres pg-cloud-mailpit pg-cloud-auth pg-cloud-api
systemctl start pg-cloud-postgres
attempt=0
until podman exec pg-cloud-postgres pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  test "$attempt" -lt 60
  sleep 1
done
systemctl restart pg-cloud-mailpit pg-cloud-auth pg-cloud-api
"""
    subprocess.run(["ssh", host, command], check=True)
    print("Private test deployment installed. Use SSH forwarding to access ports 18080 and 18025.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("host")
    parser.add_argument("runtime_dir")
    parser.add_argument("postgres_archive")
    args = parser.parse_args()
    run(args.host, args.runtime_dir, args.postgres_archive)
