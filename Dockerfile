# Use the official code-server image
FROM codercom/code-server:latest

# Clear existing ENTRYPOINT
ENTRYPOINT []

# Environment variables
ENV PASSWORD="@kira"
ENV SUDO_PASSWORD="@kira"
ENV NODE_VERSION=lts

# Switch to root for installations
USER root

# Allow coder user to use sudo without password
RUN echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install essential tools and Node.js LTS
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    nano \
    htop \
    unzip \
    zip \
    build-essential \
    python3 \
    python3-pip \
    tmux \
    ca-certificates \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest yarn pnpm typescript eslint nodemon pm2 \
    && node -v \
    && npm -v

# Switch to coder user
USER coder
WORKDIR /home/coder

# Create workspace
RUN mkdir -p /home/coder/workspace

# Expose default code-server port
EXPOSE 8080

# Start code-server
CMD ["sh", "-c", "code-server --bind-addr 0.0.0.0:${PORT:-8080} --auth password /home/coder/workspace"]
