#!/bin/sh
set -e

echo "[api] Distributing .env to workspace packages..."
for pkg in apps/api apps/web packages/database packages/api; do
  if [ -f .env ]; then
    cp .env "$pkg/.env"
  fi
done

echo "[api] Running prisma generate..."
pnpm --filter @reviewsup/database run db:generate

echo "[api] Running prisma migrate deploy..."
pnpm --filter @reviewsup/database run db:migrate:deploy

echo "[api] Building @reviewsup/api types package..."
pnpm --filter @reviewsup/api run build

echo "[api] Starting @reviewsup/api watcher in background..."
pnpm --filter @reviewsup/api run dev &

echo "[api] Starting NestJS in watch mode..."
exec pnpm --filter api run dev
