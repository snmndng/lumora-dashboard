# ========================
# Builder stage
# ========================
FROM node:20-alpine AS builder

# Install bash (needed for some npm scripts)
RUN apk --no-cache add bash

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
ENV CI=1
RUN npm ci --legacy-peer-deps

# Copy source files
COPY nginx/ nginx/
COPY assets/ assets/
COPY locale/ locale/
COPY scripts/ scripts/
COPY vite.config.js ./
COPY tsconfig.json ./
COPY codegen.ts ./
COPY *.d.ts ./
COPY schema.graphql ./
COPY .featureFlags/ .featureFlags/
COPY src/ src/

# Build-time arguments (with defaults)
ARG API_URL=http://localhost:8000/graphql/
ARG APP_MOUNT_URI=/dashboard/
ARG APPS_MARKETPLACE_API_URL=https://apps.saleor.io/api/v2/saleor-apps
ARG EXTENSIONS_API_URL=https://apps.saleor.io/api/v1/extensions
ARG APPS_TUNNEL_URL_KEYWORDS=
ARG STATIC_URL=/dashboard/
ARG SKIP_SOURCEMAPS=true
ARG LOCALE_CODE=EN

# Environment variables (with defaults)
ENV API_URL=${API_URL} \
    APP_MOUNT_URI=${APP_MOUNT_URI} \
    APPS_MARKETPLACE_API_URL=${APPS_MARKETPLACE_API_URL} \
    EXTENSIONS_API_URL=${EXTENSIONS_API_URL} \
    APPS_TUNNEL_URL_KEYWORDS=${APPS_TUNNEL_URL_KEYWORDS} \
    STATIC_URL=${STATIC_URL} \
    SKIP_SOURCEMAPS=${SKIP_SOURCEMAPS} \
    LOCALE_CODE=${LOCALE_CODE}

# Build the dashboard
RUN npm run build

# ========================
# Runner stage
# ========================
FROM nginx:stable-alpine AS runner

WORKDIR /app

# Copy Nginx configuration and env-replacement script
COPY ./nginx/default.conf /etc/nginx/conf.d/default.conf
COPY ./nginx/replace-env-vars.sh /docker-entrypoint.d/50-replace-env-vars.sh

# Copy built dashboard from builder
COPY --from=builder /app/build/ /app/

# Build metadata (with defaults)
ARG COMMIT_ID=dev
ARG PROJECT_VERSION=0.0.1

LABEL \
  org.opencontainers.image.title="saleor/saleor-dashboard" \
  org.opencontainers.image.description="A GraphQL-powered, single-page dashboard application for Saleor." \
  org.opencontainers.image.url="https://saleor.io/" \
  org.opencontainers.image.source="https://github.com/saleor/saleor-dashboard" \
  org.opencontainers.image.revision=$COMMIT_ID \
  org.opencontainers.image.version=$PROJECT_VERSION \
  org.opencontainers.image.authors="Saleor Commerce (https://saleor.io)" \
  org.opencontainers.image.licenses="BSD 3"

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
