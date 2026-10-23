FROM node:24-trixie-slim

# Bump via: docker build --build-arg PI_VERSION=x.y.z .
ARG PI_VERSION=1.4.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}
