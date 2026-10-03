#!/usr/bin/env python3
"""Create private test configuration; never prints generated credentials."""
import argparse
import os
from pathlib import Path
import secrets

PG_IMAGE = "docker.io/library/postgres@sha256:639ab7ceb90e13123085b741fb31ef493fba25463002f6da665352e7b534b652"
PG_IMAGE_ID = "sha256:248efd5e58cd743f2a0e0daec8ea4649e5580145ec2a12e2345bc710d4a77201"


def write_private(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as file:
        file.write(text)


def configure(root, otp_exp=300):
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    config = root / "config"
    config.mkdir(mode=0o700, exist_ok=True)
    if (config / "auth.env").exists():
        raise SystemExit("Configuration already exists; preserve credentials and data.")
    admin, auth, cloud, jwt = [secrets.token_hex(32) for _ in range(4)]
    write_private(config / "postgres.env", f"POSTGRES_PASSWORD={admin}\n")
    write_private(config / "init.sql", f"""CREATE ROLE pgauth LOGIN PASSWORD '{auth}';
CREATE ROLE pgcloud LOGIN PASSWORD '{cloud}';
CREATE DATABASE pgauth OWNER pgauth;
CREATE DATABASE pgcloud OWNER pgcloud;
ALTER ROLE pgauth IN DATABASE pgauth SET search_path = auth, public;
\\connect pgauth
CREATE SCHEMA auth AUTHORIZATION pgauth;
""")
    # The container's postgres user must read this bind mount. Its parent remains
    # mode 0700, so other host users cannot access generated credentials.
    (config / "init.sql").chmod(0o644)
    write_private(config / "api.env", f"DATABASE_URL=postgres://pgcloud:{cloud}@127.0.0.1:15432/pgcloud?sslmode=disable\nAUTH_URL=http://127.0.0.1:19999\nLISTEN_ADDR=127.0.0.1:18080\nGOMEMLIMIT=192MiB\n")
    auth_env = {
        "DATABASE_URL": f"postgres://pgauth:{auth}@127.0.0.1:15432/pgauth?sslmode=disable",
        "GOTRUE_DB_DRIVER": "postgres", "GOTRUE_DB_NAMESPACE": "auth",
        "GOTRUE_DB_MAX_POOL_SIZE": "5", "GOTRUE_API_HOST": "127.0.0.1",
        "PORT": "19999", "API_EXTERNAL_URL": "http://127.0.0.1:18080",
        "GOTRUE_SITE_URL": "http://127.0.0.1:18080", "GOTRUE_JWT_SECRET": jwt,
        "GOTRUE_JWT_EXP": "900", "GOTRUE_JWT_AUD": "authenticated",
        "GOTRUE_JWT_DEFAULT_GROUP_NAME": "authenticated",
        "GOTRUE_EXTERNAL_EMAIL_ENABLED": "true", "GOTRUE_EXTERNAL_PHONE_ENABLED": "false",
        "GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED": "false",
        "GOTRUE_MAILER_AUTOCONFIRM": "false", "GOTRUE_MAILER_OTP_EXP": str(otp_exp),
        "GOTRUE_MAILER_OTP_LENGTH": "6", "GOTRUE_PASSWORD_MIN_LENGTH": "10",
        "GOTRUE_SMTP_HOST": "127.0.0.1", "GOTRUE_SMTP_PORT": "11025",
        "GOTRUE_SMTP_ADMIN_EMAIL": "noreply@project-graph.test",
        "GOTRUE_SMTP_SENDER_NAME": "Project Graph Test", "GOTRUE_SMTP_MAX_FREQUENCY": "60s",
        "GOTRUE_MAILER_TEMPLATES_CONFIRMATION": "http://127.0.0.1:18080/templates/confirmation",
        "GOTRUE_MAILER_TEMPLATES_RECOVERY": "http://127.0.0.1:18080/templates/recovery",
        "GOTRUE_RATE_LIMIT_EMAIL_SENT": "100", "GOTRUE_RATE_LIMIT_HEADER": "X-Forwarded-For",
        "GOTRUE_SECURITY_REFRESH_TOKEN_ROTATION_ENABLED": "true",
        "GOTRUE_SECURITY_REFRESH_TOKEN_REUSE_INTERVAL": "5",
        "GOMEMLIMIT": "192MiB",
    }
    write_private(config / "auth.env", "".join(f"{key}={value}\n" for key, value in auth_env.items()))
    write_private(config / "mailpit.env", "MP_SMTP_BIND_ADDR=127.0.0.1:11025\nMP_UI_BIND_ADDR=127.0.0.1:18025\nMP_DATABASE=" + str(root / "mailpit.db") + "\nMP_MAX_MESSAGES=200\nMP_DISABLE_VERSION_CHECK=true\n")
    return root


def install_units(root):
    root = Path(root).resolve()
    if " " in str(root):
        raise SystemExit("Use a path without spaces for this test installer.")
    units = Path("/etc/systemd/system")
    pg = f"""[Unit]
Description=Project Graph test PostgreSQL
After=network.target

[Service]
Restart=on-failure
RestartSec=5
ExecStartPre=-/usr/bin/podman rm -f pg-cloud-postgres
ExecStart=/usr/bin/podman run --pull=never --name pg-cloud-postgres --memory=512m --cpus=1 --env-file {root}/config/postgres.env -p 127.0.0.1:15432:5432 -v pg-cloud-postgres:/var/lib/postgresql/data -v {root}/config/init.sql:/docker-entrypoint-initdb.d/init.sql:ro,Z {PG_IMAGE_ID} postgres -c shared_buffers=64MB -c max_connections=30 -c work_mem=2MB
ExecStop=/usr/bin/podman stop -t 10 pg-cloud-postgres
TimeoutStartSec=120
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
"""
    (units / "pg-cloud-postgres.service").write_text(pg)
    for name, executable, env in [("mailpit", "mailpit", "mailpit"), ("auth", "auth", "auth"), ("api", "project-graph-cloud", "api")]:
        unit = f"""[Unit]
Description=Project Graph test {name}
After=network.target pg-cloud-postgres.service
Requires=pg-cloud-postgres.service

[Service]
WorkingDirectory={root}
EnvironmentFile={root}/config/{env}.env
ExecStart={root}/bin/{executable}{' serve' if name == 'auth' else ''}
{f'ExecStartPre={root}/bin/auth migrate' if name == 'auth' else ''}
Restart=on-failure
RestartSec=3
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths={root}
MemoryMax=256M
TasksMax=128

[Install]
WantedBy=multi-user.target
"""
        (units / f"pg-cloud-{name}.service").write_text(unit)


def read_env(path):
    return dict(line.split("=", 1) for line in Path(path).read_text().splitlines() if line and not line.startswith("#"))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root")
    parser.add_argument("--otp-exp", type=int, default=300)
    parser.add_argument("--install-systemd", action="store_true")
    args = parser.parse_args()
    root = configure(args.root, args.otp_exp)
    if args.install_systemd:
        install_units(root)
    print("Private test configuration created at", root / "config")
