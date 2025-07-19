FROM node:22.12-alpine AS builder

WORKDIR /app

COPY src/filesystem /app
COPY tsconfig.json /tsconfig.json

RUN --mount=type=cache,target=/root/.npm npm install

FROM node:22-alpine AS release

WORKDIR /app

COPY --from=builder /app/src /app/src
COPY --from=builder /app/package.json /app/package.json
COPY --from=builder /app/package-lock.json /app/package-lock.json
COPY --from=builder /app/node_modules /app/node_modules

ENV NODE_ENV=production

ENTRYPOINT ["node", "/app/src/index.js"]
