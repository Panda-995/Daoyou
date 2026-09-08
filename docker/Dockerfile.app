# syntax=docker/dockerfile:1
FROM oven/bun:1.3.13 AS builder
WORKDIR /app
COPY package.json bun.lock bunfig.toml ./
RUN bun install --frozen-lockfile
COPY . .
RUN bun run build:server \
    && bun build docker/migrate.mjs --target=bun --outfile=dist/migrate.js

FROM oven/bun:1.3.13 AS runtime
WORKDIR /app
ENV NODE_ENV=production PORT=3000
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/drizzle ./drizzle
COPY --from=builder /app/drizzle-auth ./drizzle-auth
COPY --from=builder /app/LICENSE ./LICENSE
EXPOSE 3000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=12 CMD bun -e "fetch('http://127.0.0.1:3000/api/health-check').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["bun", "run", "dist/index.js"]
