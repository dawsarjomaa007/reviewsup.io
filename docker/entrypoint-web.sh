#!/bin/sh
set -e

echo "[web] Distributing .env to workspace packages..."
for pkg in apps/api apps/web packages/database packages/api; do
  if [ -f .env ]; then
    cp .env "$pkg/.env"
  fi
done

echo "[web] Waiting for API to be ready on port 5500..."
# Simple loop – no extra dependencies needed
until nc -z api 5500 2>/dev/null; do
  echo "[web] API not ready yet, retrying in 2s..."
  sleep 2
done
echo "[web] API is up!"

echo "[web] Starting Next.js with Turbopack..."
exec pnpm --filter web run dev
