FROM node:24-trixie-slim

# Bump via: docker build --build-arg PI_VERSION=x.y.z .
ARG PI_VERSION=1.4.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl git ripgrep \
    && rm -rf /var/lib/apt/lists/*

# uv (latest), installed system-wide so it is on PATH for every user.
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
    && uv --version

# Python 3.14 managed by uv. Installed under /opt and exposed on PATH so
# `python`, `python3`, and `python3.14` all resolve to it.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
RUN uv python install 3.14 \
    && ln -sf "$(uv python find 3.14)" /usr/local/bin/python3.14 \
    && ln -sf /usr/local/bin/python3.14 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3.14 /usr/local/bin/python

# uv cache and project venvs often land on different filesystems/mounts in the
# sandbox, where hardlinking fails; copying is the safe default.
ENV UV_LINK_MODE=copy

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@${PI_VERSION}
