# Deployment Guide — Borg Warehouse

This guide covers building and deploying the Borg Warehouse Cloudron package.

---

## Quick start

```bash
# Make changes, then:
git commit -am "Update borgwarehouse"
git push origin main

# Build (with version management)
./cloudron-build.sh

# When ready to publish to the community:
./cloudron-publish.sh
```

---

## Version scheme

Cloudron-Borgwarehouse is a **repackaged third-party app**: it wraps [upstream BorgWarehouse](https://github.com/Ravinou/borgwarehouse) and uses the `N.N.N-N` version format:

- `N.N.N` — upstream BorgWarehouse version (e.g. `3.1.2`)
- `-N` — BluePants packaging iteration (`-11` was an earlier packaging release; `-12` is the next; etc.)

Whatever the format, the version must agree across three files. The `cloudron-build.sh`
script verifies this on every run and prompts you to sync any drift before building:

| File | Role |
|---|---|
| `CloudronManifest.json` | `"version"` field |
| `version.txt`           | Authoritative repo-root version file |
| `Dockerfile`            | `org.opencontainers.image.version` label |

---

## Deployment configuration

Edit `deployment.config` to customize your deployment:

```bash
# Docker registry URL where images are pushed
REGISTRY_IMAGE_BASE="registry.korpit.net/borgwarehouse"

# Optional: default app location for one-click deployment
# Leave empty to prompt during build
DEFAULT_APP_LOCATION="borgwarehouse.example.com"
```

---

## One-time infrastructure setup

These steps are infrastructure-wide (shared with the other `cloudron-*` repos under BluePants).
If you've already done them for another repo, skip to **Building the image** below.

### 1. Install the Docker Registry

The Docker Registry app provides a private Docker Registry v2 instance where built images are stored.

**Install via Cloudron admin:**

1. Open your Cloudron admin panel → **App Store**.
2. Search for **Docker Registry** and install it at your chosen domain (e.g. `registry.korpit.net`).
3. Once running, open the app's **Settings** tab and create at least one user:
   - **Username** — e.g. `builder` (used by the build service to push images)
   - **Password** — generate a strong password and save it somewhere safe

**Authenticate your local machine:**

```bash
docker login registry.korpit.net
```

### 2. Install the Docker Builder

The Docker Builder watches a Git repository and automatically builds and pushes Docker images.

**Install via Cloudron admin:**

1. Open your Cloudron admin panel → **App Store**.
2. Install **Docker Builder** at your chosen domain (e.g. `parking.korpit.xyz`).
3. Open the builder's web UI and log in.

**Configure the Cloudron CLI:**

```bash
# Copy the build token from the builder's web UI
cloudron build login --url 'https://parking.korpit.xyz' --build-token <your-build-token>

# Configure this repository to push to your registry
cd /path/to/cloudron-borgwarehouse
cloudron build --repository registry.korpit.net/borgwarehouse --tag init-check
```

### 3. Allow Cloudron to pull from the private registry

```bash
cloudron registry add \
  --registry registry.korpit.net \
  --username <username> \
  --password <password>
```

> Or add credentials in the Cloudron admin under **Settings → Docker Registries**.

---

## Building the image

### Cloudron Build Service (recommended)

```bash
# Run the wrapper — handles version consistency, prompts for a new version,
# updates all three version files, then runs cloudron build.
./cloudron-build.sh
```

The script will:

1. Check that `CloudronManifest.json`, `version.txt`, and the `Dockerfile` label all agree on the current version.
2. Suggest the next version (auto-increment based on the format) and let you accept or override.
3. Update all three files in lockstep.
4. Run `cloudron build --repository registry.korpit.net/borgwarehouse --tag <new-version>`.
5. Detect whether an instance is already installed and offer to deploy/update or install fresh.

**Manual equivalent (no version management):**

```bash
cloudron build --repository registry.korpit.net/borgwarehouse --tag <version>
```

---

## Deployment workflow

### First installation

```bash
./cloudron-build.sh
# When prompted, choose to install and provide subdomain + domain.
```

Or manually:

```bash
cloudron install --app-id borgwarehouse.example.com dev.bluepants.borgwarehouse
```

### Updating an existing installation

```bash
./cloudron-build.sh
# When prompted, choose to deploy to the existing installation.
```

Or manually:

```bash
cloudron update --app borgwarehouse.example.com --image registry.korpit.net/borgwarehouse:<new-version>
```

---

## Publishing to the community

When ready to publish a version for community use:

```bash
# 1. Make sure the version is built and tagged
./cloudron-build.sh

# 2. Publish the version to CloudronVersions.json
./cloudron-publish.sh

# 3. Commit the changes
git add CloudronVersions.json
git commit -m "Publish version <version>"
git push

# 4. Host CloudronVersions.json at a public URL
# Users add the URL in their Cloudron dashboard under Community apps.
```

> If `CloudronVersions.json` does not exist yet, initialise it with
> `cloudron versions init`. The publish wrapper expects this file.

---

## Releasing a new version

### 1. Edit `version.txt`

```bash
echo "<new-version>" > version.txt
```

### 2. Build and deploy

```bash
./cloudron-build.sh
```

The script auto-detects the version in `version.txt`, suggests the next increment,
updates `CloudronManifest.json` and the `Dockerfile` label, builds the image,
and offers to deploy.

### 3. Publish when ready

```bash
./cloudron-publish.sh
```

---

## Automation scripts

### cloudron-build.sh

Wrapper for building with automatic version management.

**Features:**
- Checks version consistency across `CloudronManifest.json`, `version.txt`, `Dockerfile`.
- Auto-increments `N.N.N` and `N.N.N-N` formats.
- Updates all three version files in lockstep.
- Builds the image via the Cloudron build service.
- Detects existing installations and offers to deploy.
- Offers to install on first run.

**Configuration:** Edit `deployment.config` to set `REGISTRY_IMAGE_BASE` and `DEFAULT_APP_LOCATION`.

### cloudron-publish.sh

Wrapper for publishing to the community registry.

**Features:**
- Adds version to `CloudronVersions.json`.
- Handles updates to existing version entries.
- Provides distribution instructions.

---

## Troubleshooting

### Build service authentication failed

```bash
cloudron build login --url 'https://parking.korpit.xyz' --build-token <token>
```

### Cloudron can't pull the image

Verify registry credentials in the Cloudron admin under **Settings → Docker Registries**, or re-add:

```bash
cloudron registry add --registry registry.korpit.net --username <user> --password <pass>
```

### Version mismatch reported

The `cloudron-build.sh` script considers `version.txt` authoritative. If the manifest or Dockerfile drift,
edit `version.txt` to the correct value and re-run the script — it will sync the other two for you.

---

## See also

- [Cloudron packaging docs](https://docs.cloudron.io/packaging/)
- [CloudronManifest.json reference](https://docs.cloudron.io/packaging/manifest)
- [Docker Registry package](https://docs.cloudron.io/packages/docker-registry)
- [Docker Builder package](https://docs.cloudron.io/packages/docker-builder)
