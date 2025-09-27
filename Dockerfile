# Base image
FROM ubuntu:22.04

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PASSWORD="@kira"
ENV SUDO_PASSWORD="@kira"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl wget git sudo gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates \
    build-essential python3 python3-pip unzip zip nano vim htop net-tools pkg-config libx11-dev libxkbfile-dev libsecret-1-dev \
    && useradd -m coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) + package managers
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g yarn pnpm pm2 nodemon typescript ts-node eslint prettier serve http-server

# Clone and build code-server from source
RUN git clone https://github.com/coder/code-server.git /tmp/code-server \
    && cd /tmp/code-server \
    && yarn install --frozen-lockfile \
    && yarn build \
    && yarn release \
    && mv /tmp/code-server/release-* /usr/local/lib/code-server \
    && ln -s /usr/local/lib/code-server/code-server /usr/local/bin/code-server \
    && rm -rf /tmp/code-server

# Switch to coder user
USER coder
WORKDIR /home/coder/project

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
    && code-server --install-extension GitHub.copilot \
    && code-server --install-extension pkief.material-icon-theme \
    && code-server --install-extension zhuangtongfa.material-theme

# Expose port
EXPOSE 8080

# Start code-server
CMD ["code-server", "--bind-addr", "0.0.0.0:8080", "--auth", "password", "/home/coder/project"]
