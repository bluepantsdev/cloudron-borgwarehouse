#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# cloudron-publish.sh — Wrapper for publishing to Cloudron community registry
#
# This script:
#   1. Adds the current version to CloudronVersions.json
#   2. Handles release notes and version metadata
#   3. Commits the updated versions file
#   4. Reminds about distributing the versions file
#
# Note: This script should be run AFTER a successful cloudron-build.sh and after
#       manually adding release notes to CloudronVersions.json if desired.
#
# Usage:
#   ./cloudron-publish.sh
#
# Prerequisites:
#   - cloudron CLI installed and authenticated
#   - cloudron build has been run and image pushed to registry
#
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Color codes for output ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ── File paths ────────────────────────────────────────────────────────────────
MANIFEST_FILE="CloudronManifest.json"
VERSIONS_FILE="CloudronVersions.json"
CONFIG_FILE="deployment.config"

# ── Functions ─────────────────────────────────────────────────────────────────

# Load deployment configuration
load_deployment_config() {
    # Set defaults
    REGISTRY_IMAGE_BASE="registry.korpit.net/borgwarehouse"
    
    # Load from config file if it exists
    if [ -f "${CONFIG_FILE}" ]; then
        REGISTRY_IMAGE_BASE=$(grep "^REGISTRY_IMAGE_BASE=" "${CONFIG_FILE}" | cut -d'=' -f2 | tr -d '"' || echo "registry.korpit.net/borgwarehouse")
    fi
}

# Find installed app by manifest ID, returns "<app-id> <location>" when found
find_installed_app_by_manifest_id() {
    local manifest_id="$1"

    cloudron list 2>/dev/null | awk -v manifest_id="${manifest_id}" '
        NR > 2 && $3 ~ ("^" manifest_id "@") {
            print $1 " " $2;
            exit
        }
    '
}

# ── Main script ───────────────────────────────────────────────────────────────

# Get app name from manifest
APP_TITLE=$(jq -r '.title' "${MANIFEST_FILE}" 2>/dev/null || echo "App")

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Cloudron Publish Wrapper                         ║${NC}"
echo -e "${BLUE}║                  ${APP_TITLE}                                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if required commands are available
if ! command -v cloudron &> /dev/null; then
    echo -e "${RED}Error: cloudron CLI is not installed.${NC}"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed. Please install jq first.${NC}"
    exit 1
fi

# Load deployment configuration (for potential future use)
load_deployment_config

# Get current version from manifest
CURRENT_VERSION=$(jq -r '.version' "${MANIFEST_FILE}")

if [ -z "${CURRENT_VERSION}" ] || [ "${CURRENT_VERSION}" = "null" ]; then
    echo -e "${RED}Error: Could not extract version from ${MANIFEST_FILE}${NC}"
    exit 1
fi

echo -e "${BLUE}Publishing version: ${CURRENT_VERSION}${NC}"
echo

# Check if version already exists in CloudronVersions.json
if [ -f "${VERSIONS_FILE}" ]; then
    EXISTING_VERSION=$(jq -r --arg version "${CURRENT_VERSION}" '
        if type == "array" then
            (map(select(.version == $version))[0].version // "")
        elif type == "object" and has("versions") then
            (if .versions[$version] then $version else "" end)
        else
            ""
        end
    ' "${VERSIONS_FILE}" 2>/dev/null || echo "")
    
    if [ -n "${EXISTING_VERSION}" ]; then
        EXISTING_PUBLISH_STATE=$(jq -r --arg version "${CURRENT_VERSION}" '
            if type == "object" and has("versions") then
                (.versions[$version].publishState // "unknown")
            else
                "unknown"
            end
        ' "${VERSIONS_FILE}" 2>/dev/null || echo "unknown")

        echo -e "${YELLOW}⚠ Version ${CURRENT_VERSION} already exists in ${VERSIONS_FILE}${NC}"
        echo -e "${BLUE}Current publish state: ${EXISTING_PUBLISH_STATE}${NC}"
        read -p "Update the existing version metadata now? [Y/n]: " UPDATE_VERSION
        UPDATE_VERSION=${UPDATE_VERSION:-Y}

        if [[ "${UPDATE_VERSION}" =~ ^[Yy]$ ]]; then
            echo
            echo -e "${BLUE}Running: cloudron versions update --version ${CURRENT_VERSION}${NC}"
            echo
            
            if cloudron versions update --version "${CURRENT_VERSION}"; then
                echo
                echo -e "${GREEN}✓ Version updated successfully!${NC}"
                echo
            else
                echo
                echo -e "${RED}✗ Failed to update version!${NC}"
                exit 1
            fi
        else
            echo
            echo -e "${YELLOW}No versions metadata action taken.${NC}"
            echo -e "${YELLOW}Reason: version ${CURRENT_VERSION} already exists. Choose 'Y' to refresh metadata, or bump version before publishing.${NC}"
            echo
        fi
    else
        echo -e "${BLUE}Adding new version to ${VERSIONS_FILE}...${NC}"
        echo
        echo -e "${BLUE}Running: cloudron versions add${NC}"
        echo
        
        if cloudron versions add; then
            echo
            echo -e "${GREEN}✓ Version added successfully!${NC}"
            echo
        else
            echo
            echo -e "${RED}✗ Failed to add version!${NC}"
            exit 1
        fi
    fi
else
    echo -e "${RED}Error: ${VERSIONS_FILE} not found.${NC}"
    echo -e "${YELLOW}Run 'cloudron versions init' first to initialize the versions file.${NC}"
    exit 1
fi

# Optional deployment to the current Cloudron instance
APP_ID=$(jq -r '.id' "${MANIFEST_FILE}" 2>/dev/null || echo "")
REGISTRY_IMAGE="${REGISTRY_IMAGE_BASE}:${CURRENT_VERSION}"

if [ -z "${APP_ID}" ] || [ "${APP_ID}" = "null" ]; then
    echo -e "${YELLOW}Skipping direct Cloudron deploy: could not read app id from ${MANIFEST_FILE}.${NC}"
    echo
else
    echo -e "${BLUE}Built image for deployment: ${REGISTRY_IMAGE}${NC}"
    read -p "Deploy this image to your Cloudron now? [Y/n]: " DEPLOY_NOW
    DEPLOY_NOW=${DEPLOY_NOW:-Y}

    if [[ "${DEPLOY_NOW}" =~ ^[Yy]$ ]]; then
        FOUND_APP_LINE=$(find_installed_app_by_manifest_id "${APP_ID}" || true)

        if [ -n "${FOUND_APP_LINE}" ]; then
            INSTALLED_APP_ID=$(echo "${FOUND_APP_LINE}" | awk '{print $1}')
            INSTALLED_APP_LOCATION=$(echo "${FOUND_APP_LINE}" | awk '{print $2}')

            echo
            echo -e "${BLUE}Updating installed app ${INSTALLED_APP_LOCATION} (${INSTALLED_APP_ID})...${NC}"

            if cloudron update --app "${INSTALLED_APP_ID}" --image "${REGISTRY_IMAGE}"; then
                echo -e "${GREEN}✓ Cloudron app updated successfully!${NC}"
                echo
            else
                echo -e "${RED}✗ Cloudron app update failed.${NC}"
                echo
            fi
        else
            echo
            echo -e "${YELLOW}No installed app found for manifest id ${APP_ID}.${NC}"

            DEFAULT_LOCATION="${DEFAULT_APP_LOCATION:-}"
            if [ -n "${DEFAULT_LOCATION}" ]; then
                read -p "Install app at location [${DEFAULT_LOCATION}]: " INSTALL_LOCATION
                INSTALL_LOCATION=${INSTALL_LOCATION:-${DEFAULT_LOCATION}}
            else
                read -p "Install app location (e.g., borgwarehouse.example.com): " INSTALL_LOCATION
            fi

            if [ -n "${INSTALL_LOCATION}" ]; then
                echo
                echo -e "${BLUE}Installing app at ${INSTALL_LOCATION} from ${REGISTRY_IMAGE}...${NC}"

                if cloudron install --image "${REGISTRY_IMAGE}" --location "${INSTALL_LOCATION}"; then
                    echo -e "${GREEN}✓ Cloudron app installed successfully!${NC}"
                    echo
                else
                    echo -e "${RED}✗ Cloudron app installation failed.${NC}"
                    echo
                fi
            else
                echo -e "${YELLOW}No install location provided; skipping Cloudron install.${NC}"
                echo
            fi
        fi
    else
        echo
        echo -e "${YELLOW}Skipping direct Cloudron deploy.${NC}"
        echo
    fi
fi

# Display next steps
echo -e "${YELLOW}Next steps:${NC}"
echo
echo "  1. Review the updated ${VERSIONS_FILE}:"
echo "     git diff ${VERSIONS_FILE}"
echo
echo "  2. (Optional) Add release notes to the version entry in ${VERSIONS_FILE}"
echo
echo "  3. Commit the changes:"
echo "     git add ${VERSIONS_FILE}"
echo "     git commit -m \"Publish version ${CURRENT_VERSION}\""
echo "     git push"
echo
echo "  4. (Optional) Deploy directly to your Cloudron from image:"
echo "     cloudron update --app <id-or-location> --image ${REGISTRY_IMAGE_BASE}:${CURRENT_VERSION}"
echo "     # or first install"
echo "     cloudron install --image ${REGISTRY_IMAGE_BASE}:${CURRENT_VERSION} --location <subdomain.domain>"
echo
echo "  5. Distribute the versions file:"
echo "     • Host CloudronVersions.json at a publicly accessible URL"
echo "     • Share the URL: https://your-domain/path/to/CloudronVersions.json"
echo "     • Users can add it in their Cloudron dashboard under Community apps"
echo
echo "  6. (Optional) Post about the release in the Cloudron forum:"
echo "     https://forum.cloudron.io/category/96/app-packaging-development"
echo
