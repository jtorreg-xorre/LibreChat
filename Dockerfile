# v0.8.3

# Base node image
FROM node:20-alpine AS node

# Install dependencies
RUN apk add --no-cache jemalloc python3 py3-pip

# Add `uv` for extended MCP support
COPY --from=ghcr.io/astral-sh/uv:0.9.5-python3.12-alpine /usr/local/bin/uv /usr/local/bin/uvx /bin/

# Set environment variable to use jemalloc
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Set configurable max-old-space-size with default
ARG NODE_MAX_OLD_SPACE_SIZE=6144

RUN mkdir -p /app && chown node:node /app
WORKDIR /app

# Cambiamos a root momentáneamente para asegurar la estructura de archivos
USER root

COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node api/package.json ./api/package.json
COPY --chown=node:node client/package.json ./client/package.json
COPY --chown=node:node packages/data-provider/package.json ./packages/data-provider/package.json
COPY --chown=node:node packages/data-schemas/package.json ./packages/data-schemas/package.json
COPY --chown=node:node packages/api/package.json ./packages/api/package.json

RUN \
    # Pre-creamos el archivo .env y el .yaml con permisos correctos
    touch /app/.env && \
    touch /app/librechat.yaml && \
    chown node:node /app/.env /app/librechat.yaml && \
    # Create directories for the volumes
    mkdir -p /app/client/public/images /app/logs /app/uploads && \
    chown -R node:node /app/client/public/images /app/logs /app/uploads && \
    npm config set fetch-retry-maxtimeout 600000 && \
    npm config set fetch-retries 5 && \
    npm config set fetch-retry-mintimeout 15000 && \
    npm ci --no-audit

# Ahora sí, copiamos todo el proyecto (incluyendo tu librechat.yaml ya permitido por el dockerignore)
COPY --chown=node:node . .

USER node

RUN \
    # React client build
    NODE_OPTIONS="--max-old-space-size=${NODE_MAX_OLD_SPACE_SIZE}" npm run frontend; \
    npm prune --production; \
    npm cache clean --force

# Node API setup
EXPOSE 3080
ENV HOST=0.0.0.0
# Forzamos que el backend use el archivo que acabamos de copiar
ENV CONFIG_PATH="/app/librechat.yaml"

CMD ["npm", "run", "backend"]
