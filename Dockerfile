# ===============================
# Stage 1: Build code-server from source
# ===============================
FROM node:20-bullseye AS builder

# Environment
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git build-essential python3 python3-pip pkg-config libx11-dev libxkbfile-dev libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone code-server repo and build
RUN git clone https://github.com/coder/code-server.git /tmp/code-server \
    && cd /tmp/code-server \
    && npm ci \
    && npm run build \
    && npm run release

# ===============================
# Stage 2: Final image
# ===============================
FROM node:20-bullseye

ENV DEBIAN_FRONTEND=noninteractive
ENV PASSWORD="kira"

# Install system tools
RUN apt-get update && apt-get install -y \
    sudo curl wget vim nano htop unzip zip tree net-tools cron \
    postgresql-client mysql-client mongodb-clients \
    && rm -rf /var/lib/apt/lists/*

# Create coder user
RUN useradd -m -s /bin/bash coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER coder
WORKDIR /home/coder

# Copy built code-server from builder
COPY --from=builder /tmp/code-server/release-* /usr/local/lib/code-server
RUN ln -s /usr/local/lib/code-server/code-server /usr/local/bin/code-server

# Create workspace and backup directories
RUN mkdir -p /home/coder/project \
    && mkdir -p /home/coder/code-server-backups \
    && mkdir -p /home/coder/.config/code-server

# Configure code-server
RUN echo "bind-addr: 0.0.0.0:8080" > /home/coder/.config/code-server/config.yaml \
    && echo "auth: password" >> /home/coder/.config/code-server/config.yaml \
    && echo "password: ${PASSWORD}" >> /home/coder/.config/code-server/config.yaml \
    && echo "cert: false" >> /home/coder/.config/code-server/config.yaml \
    && echo "disable-telemetry: true" >> /home/coder/.config/code-server/config.yaml

# Install useful Node.js dev tools globally
RUN npm install -g \
    nodemon pm2 typescript ts-node eslint prettier serve http-server yarn pnpm create-react-app @nestjs/cli express-generator webpack webpack-cli parcel jest mocha concurrently cross-env

# Install essential VS Code extensions
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

# Setup code-server backup script
RUN echo '#!/bin/bash\n\
DATE=$(date +%F_%H-%M-%S)\n\
BACKUP_DIR="/home/coder/code-server-backups"\n\
mkdir -p "$BACKUP_DIR"\n\
tar -czf "$BACKUP_DIR/project-$DATE.tar.gz" -C /home/coder project\n\
tar -czf "$BACKUP_DIR/config-$DATE.tar.gz" -C /home/coder .config .local\n\
echo "✅ Code-server backup completed at $DATE"\n\
' > /home/coder/backup-codeserver.sh \
    && chmod +x /home/coder/backup-codeserver.sh

# Optional: setup daily cron for automatic backup
RUN echo "0 3 * * * /home/coder/backup-codeserver.sh >> /home/coder/code-server-backups/backup.log 2>&1" | crontab -

# Expose port
EXPOSE 8080

# Set working directory
WORKDIR /home/coder/project

# Start cron + code-server
CMD service cron start && code-server --bind-addr 0.0.0.0:8080 --auth password /home/coder/project
