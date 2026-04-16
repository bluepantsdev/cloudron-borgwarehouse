# Cloudron app - Borg Warehouse

## Entrypoint Scripts

| File | Used by | Purpose |
|------|---------|---------|
| `start.sh` | Cloudron | Thin wrapper — Cloudron calls this at startup; it delegates immediately to `docker/docker-bw-init.sh` |
| `docker/docker-bw-init.sh` | Docker (standalone) & Cloudron | All real init logic: creates data directories, validates SSH/repo mounts, auto-generates secrets, gets SSH fingerprints, and launches supervisord (sshd + Node server + rsyslogd) |

Both paths run the same code. For Docker standalone, the `Dockerfile` sets `ENTRYPOINT` directly to `docker-bw-init.sh`. For Cloudron, `start.sh` is the entry point and calls `docker-bw-init.sh` itself.

## Local Development & Testing

### One-time setup

```bash
cp .env.test .env
mkdir -p test-data/{config,ssh,repos,ssh-host,logs,tmp}
chmod 700 test-data/ssh test-data/repos
touch test-data/ssh/authorized_keys && chmod 600 test-data/ssh/authorized_keys
```

### Build and start

```bash
docker compose up --build
```

Open the app at **http://localhost:3000** — default credentials are `admin` / `admin`.

### Subsequent runs

```bash
docker compose up
```

Use `--build` only when you've made code changes.

### Stop

```bash
docker compose down
```

### Full reset (wipe all state)

```bash
docker compose down && rm -rf test-data/
```

Then re-run the one-time setup commands above.

