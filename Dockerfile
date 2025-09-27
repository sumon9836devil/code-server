# Stage 1: Base image
FROM debian:bullseye AS base

ENV DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=22 \
    CODE_SERVER_DIR=/usr/local/lib/code-server \
    PASSWORD=kira

# Install system dependencies
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    pkg-config \
    libx11-dev \
    libxkbfile-dev \
    libsecret-1-dev \
    vim \
    nano \
    htop \
    unzip \
    zip \
    tree \
    net-tools \
    cron \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Build code-server from GitHub
FROM base AS builder

WORKDIR /tmp/code-server-build

# Clone latest code-server repo into new folder
RUN git clone https://github.com/coder/code-server.git .

# Build code-server using npm
RUN npm install --legacy-peer-deps \
    && npm run build \
    && npm run release

# Stage 3: Final image
FROM base

# Copy built code-server from builder
COPY --from=builder /tmp/code-server-build/release-linux-amd64/ $CODE_SERVER_DIR/
RUN ln -s $CODE_SERVER_DIR/code-server /usr/local/bin/code-server

# Create coder user
RUN groupadd --gid 1000 coder \
    && useradd --uid 1000 --gid coder --shell /bin/bash --create-home coder \
    && mkdir -p /etc/sudoers.d \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Switch to coder user
USER coder
WORKDIR /home/coder

# Configure code-server
RUN mkdir -p /home/coder/.config/code-server
RUN echo "bind-addr: 0.0.0.0:8080" > /home/coder/.config/code-server/config.yaml \
    && echo "auth: password" >> /home/coder/.config/code-server/config.yaml \
    && echo "password: ${PASSWORD}" >> /home/coder/.config/code-server/config.yaml \
    && echo "cert: false" >> /home/coder/.config/code-server/config.yaml \
    && echo "disable-telemetry: true" >> /home/coder/.config/code-server/config.yaml

# Install global Node.js tools
RUN npm install -g \
    nodemon \
    pm2 \
    concurrently \
    cross-env \
    typescript \
    eslint \
    prettier \
    jest \
    mocha \
    webpack \
    webpack-cli \
    parcel \
    http-server \
    live-server \
    json-server \
    @nestjs/cli \
    create-react-app \
    express-generator

# Install useful VS Code extensions
RUN code-server --install-extension ms-vscode.vscode-typescript-next \
    && code-server --install-extension esbenp.prettier-vscode \
    && code-server --install-extension dbaeumer.vscode-eslint \
    && code-server --install-extension formulahendry.auto-rename-tag \
    && code-server --install-extension christian-kohler.path-intellisense \
    && code-server --install-extension bradlc.vscode-tailwindcss \
    && code-server --install-extension ritwickdey.liveserver \
    && code-server --install-extension vincaslt.highlight-matching-tag \
    && code-server --install-extension pranaygp.vscode-css-peek \
    && code-server --install-extension zignd.html-css-class-completion \
    && code-server --install-extension ecmel.vscode-html-css \
    && code-server --install-extension pkief.material-icon-theme \
    && code-server --install-extension zhuangtongfa.material-theme

# Set working directory
WORKDIR /home/coder/workspace
RUN mkdir -p /home/coder/workspace

# Expose port
EXPOSE 8080

# Start code-server
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password", "/home/coder/workspace"]
