ARG UID=1000
ARG GID=1000

FROM node:22-bookworm-slim AS base

# Build stage
FROM base AS deps

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci --omit=dev

FROM base AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules

COPY . .

RUN sed -i "s/images:/output: 'standalone',images:/" next.config.js

RUN npm run build

# Run stage
FROM base AS runner

ARG UID
ARG GID

ENV NODE_ENV=production
ENV HOSTNAME=

# Install dependencies and fix GPG key issue for bookworm-backports
RUN apt-get update && \
    apt-get install -y wget gnupg && \
    wget -O - https://ftp-master.debian.org/keys/release-12.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/debian-bookworm-release.gpg && \
    echo 'deb http://deb.debian.org/debian bookworm-backports main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y \
        supervisor curl jq jc borgbackup/bookworm-backports openssh-server rsyslog && \
    apt-get purge -y wget gnupg && \
    apt-get autoremove -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Use the existing 'node' user (UID 1000, GID 1000) instead of creating a new one
RUN cp /etc/ssh/moduli /home/node/

WORKDIR /home/node/app

COPY --from=builder --chown=node:node /app/docker/docker-bw-init.sh /app/LICENSE ./
COPY --from=builder --chown=node:node /app/helpers/shells ./helpers/shells
COPY --from=builder --chown=node:node /app/.next/standalone ./
COPY --from=builder --chown=node:node /app/public ./public
COPY --from=builder --chown=node:node /app/.next/static ./.next/static
COPY --from=builder --chown=node:node /app/docker/supervisord.conf ./
COPY --from=builder --chown=node:node /app/docker/rsyslog.conf /etc/rsyslog.conf
COPY --from=builder --chown=node:node /app/docker/sshd_config ./

USER node

EXPOSE 3000 22

ENTRYPOINT ["./docker-bw-init.sh"]
