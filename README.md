# Cloudron app - Borg Warehouse

A Cloudron package for [BorgWarehouse](https://github.com/Ravinou/borgwarehouse) — a self-hosted web UI for managing BorgBackup repositories. Provision repos, control SSH access for Borg clients, monitor backup status, and receive alerts when backups fall behind.

---

## Deployment

See [docs/Deployment.md](docs/Deployment.md) for full instructions covering one-time infrastructure setup, building, deploying, and publishing to the community.

### Quick workflow

After [one-time infrastructure setup](docs/Deployment.md#one-time-infrastructure-setup):

```bash
# Make changes, then:
git commit -am "Describe the change"
git push origin main

# Build via the Cloudron build service with version management:
./cloudron-build.sh

# When ready to publish to the community:
./cloudron-publish.sh
```

The `cloudron-build.sh` wrapper checks that `CloudronManifest.json`, `version.txt`, and the `Dockerfile` image-version label (in the `runner` stage) all agree, suggests the next version (auto-incrementing the `N.N.N-N` packaging suffix), updates all three files in lockstep, and runs `cloudron build`.

---

## Version scheme

Cloudron-Borgwarehouse uses a Cloudron-compatible repackaged-app format `N.N.N-N`:

- `N.N.N` — upstream BorgWarehouse version (e.g. `3.1.2`)
- `-N` — BluePants packaging iteration (monotonic numeric prerelease)

See [VersionHistory.md](VersionHistory.md) for the per-version changelog.

---

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

