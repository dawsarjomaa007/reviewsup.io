# ==============================================================================
# Base stage – shared by api and web dev targets
# ==============================================================================
FROM node:22.9.0-bookworm-slim AS base

# Prisma requires openssl at generate & runtime
RUN apt-get update && apt-get install -y openssl netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Install pnpm directly (corepack bundled in this Node image is too old to
# verify the signature for pnpm 10.x)
RUN npm install -g pnpm@10.13.1

WORKDIR /app

# --- dependency layer (cached until lockfile / any package.json changes) ------
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./

# Copy every workspace package.json so pnpm can resolve the workspace graph
COPY apps/api/package.json           apps/api/package.json
COPY apps/web/package.json           apps/web/package.json
COPY apps/docs/package.json          apps/docs/package.json
COPY packages/api/package.json       packages/api/package.json
COPY packages/database/package.json  packages/database/package.json
COPY packages/ui/package.json        packages/ui/package.json
COPY packages/embed-react/package.json packages/embed-react/package.json
COPY packages/eslint-config/package.json packages/eslint-config/package.json
COPY packages/jest-config/package.json   packages/jest-config/package.json
COPY packages/tailwind-config/package.json packages/tailwind-config/package.json
COPY packages/typescript-config/package.json packages/typescript-config/package.json

# pnpm 10 blocks lifecycle scripts by default. Approve native modules that
# need postinstall scripts (Prisma engines, esbuild, tailwind oxide, etc.)
# Patch package.json to add the approval list, then install.
RUN node -e " \
  const fs = require('fs'); \
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8')); \
  pkg.pnpm = pkg.pnpm || {}; \
  pkg.pnpm.onlyBuiltDependencies = [ \
    '@nestjs/core', '@parcel/watcher', '@prisma/client', '@prisma/engines', \
    '@tailwindcss/oxide', 'core-js', 'esbuild', 'prisma', 'protobufjs', \
    'puppeteer', 'sharp' \
  ]; \
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');" && \
    pnpm install --frozen-lockfile

# Copy the full source tree (in dev we bind-mount over this anyway)
COPY . .

# ==============================================================================
# dev-api – NestJS in watch mode
# ==============================================================================
FROM base AS dev-api

COPY docker/entrypoint-api.sh /entrypoint.sh
# Convert CRLF to LF (fixes "no such file or directory" on Windows hosts)
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 5500

ENTRYPOINT ["/entrypoint.sh"]

# ==============================================================================
# dev-web – Next.js with Turbopack
# ==============================================================================
FROM base AS dev-web

COPY docker/entrypoint-web.sh /entrypoint.sh
# Convert CRLF to LF (fixes "no such file or directory" on Windows hosts)
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 5510

ENTRYPOINT ["/entrypoint.sh"]
