#!/usr/bin/env python3
"""Run isolated real PostgreSQL/Auth/Mailpit integration tests, then clean up."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time
import urllib.request

from configure import PG_IMAGE, configure, read_env


def ready(url):
    for _ in range(120):
        try:
            with urllib.request.urlopen(url, timeout=1) as response:
                if response.status == 200:
                    return
        except Exception:
            time.sleep(.25)
    raise RuntimeError("Service did not become ready: " + url)


def run(runtime):
    runtime = Path(runtime).resolve()
    name = "pg-cloud-e2e-" + str(os.getpid())
    processes = []
    with tempfile.TemporaryDirectory(prefix="pg-cloud-e2e-") as directory:
        root = configure(directory, otp_exp=30)
        config = root / "config"
        logs = open(root / "runtime.log", "w+")
        try:
            subprocess.run(["podman", "run", "-d", "--name", name, "--env-file", str(config / "postgres.env"), "-p", "127.0.0.1:15432:5432", "-v", str(config / "init.sql") + ":/docker-entrypoint-initdb.d/init.sql:ro,Z", PG_IMAGE], check=True, stdout=subprocess.DEVNULL)
            for _ in range(120):
                result = subprocess.run(["podman", "exec", name, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if result.returncode == 0:
                    break
                time.sleep(.25)
            else:
                raise RuntimeError("PostgreSQL did not start")
            subprocess.run([str(runtime / "auth"), "migrate"], cwd=runtime, env={**os.environ, **read_env(config / "auth.env")}, stdout=logs, stderr=logs, check=True)
            for executable, env in [("mailpit", "mailpit"), ("auth", "auth"), ("project-graph-cloud", "api")]:
                command = [str(runtime / executable)] + (["serve"] if executable == "auth" else [])
                process = subprocess.Popen(command, cwd=runtime, env={**os.environ, **read_env(config / (env + ".env"))}, stdout=logs, stderr=logs)
                processes.append(process)
            ready("http://127.0.0.1:18080/healthz")
            ready("http://127.0.0.1:19999/health")
            ready("http://127.0.0.1:18025/api/v1/messages")
            subprocess.run(["python3", str(Path(__file__).parent / "e2e.py")], check=True, env={**os.environ, "EXPIRE_WAIT": "31"})
            # Simulate a real auth outage after the success path.
            processes[1].terminate()
            processes[1].wait(timeout=10)
            request = urllib.request.Request("http://127.0.0.1:18080/v1/auth/login", b'{"email":"outage@example.test","password":"long-password"}', {"Content-Type": "application/json"})
            try:
                urllib.request.urlopen(request, timeout=10)
                raise AssertionError("Auth outage did not fail")
            except urllib.error.HTTPError as error:
                assert error.code == 503
            ready("http://127.0.0.1:18080/healthz")
            print("PASS auth disconnect returns 503; API remains responsive")
        except Exception:
            subprocess.run(["podman", "logs", name], check=False)
            logs.flush()
            logs.seek(0)
            # Auth logs can contain test emails; all credentials are synthetic.
            print(logs.read()[-8000:])
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
            subprocess.run(["podman", "rm", "-f", "-v", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            logs.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime_dir")
    run(parser.parse_args().runtime_dir)
