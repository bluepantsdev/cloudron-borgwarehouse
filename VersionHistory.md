# Version History

## 3.1.2-1.3 - 2026-05-11

- Added BluePants deployment workflow: `cloudron-build.sh` (version-managed build wrapper with consistency checks + auto-increment for `N.N.N-N.N` format), `cloudron-publish.sh` (community registry publisher), and `deployment.config`.
- Added `docs/Deployment.md` with comprehensive deployment, build, and publish instructions.
- Updated `README.md` with deployment section pointing at the new workflow.

## 3.1.2-1.2 - 2026-05-11

- Added repo-root `version.txt` and OCI `image.version` Dockerfile label (in the `runner` stage) to enable cross-file version-consistency checks.
- Added OCI `image.title`, `image.description`, and `image.authors` Dockerfile labels for BluePants attribution.

## 3.1.2-1.1 - 2026-05-11

- Standardized CloudronManifest.json to BluePants conventions: canonical key order, moved `manifestVersion` to top, changed `id` from `com.bluepants.borgwarehouse` to `dev.bluepants.borgwarehouse`, set `website` to `https://bluepants.dev` and `contactEmail`/author email to `support@bluepants.dev`.
- Replaced placeholder description ("Borg Warehouse") with real content via `file://DESCRIPTION.md`. Added `changelog: file://VersionHistory.md`. Rewrote `DESCRIPTION.md` (was the boilerplate "Please add the appstore description in markdown format here.") and created this file.
- Replaced placeholder tags `["test", "collaboration"]` with `["backup", "borg", "storage", "ssh"]`.
- Removed unrelated rapgenius.com URL from `mediaLinks`.
- Renamed `borgwarehouse-logo.png` to `logo.png` and stripped the `file://` prefix from the `icon` field.
- Added `minBoxVersion: "7.0.0"` (was missing).
- Migrated single `[0.1.0]` entry from old `CHANGELOG` file to this `VersionHistory.md`.
- Adopted BluePants packaging version scheme `N.N.N-N.N` (upstream-3.1.2, packaging-1.1).

## 3.1.2-1

- Prior release. Initial BluePants packaging of upstream BorgWarehouse 3.1.2.

## 0.1.0

- Initial version (migrated from legacy CHANGELOG file).
