# Multi-stage build for optimized image
FROM node:20-bullseye as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Clone and build code-server from official repository
WORKDIR /tmp
RUN git clone https://github.com/coder/code-server.git \
    && cd code-server \
    && yarn install --frozen-lockfile \
    && yarn build \
    && yarn build:vscode \
    && yarn release:standalone

# Production stage
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=20 \
    PASSWORD=kira \
    TZ=UTC

# Create coder user first
RUN groupadd --gid 1000 coder \
    && useradd --uid 1000 --gid coder --shell /bin/bash --create-home coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Install essential system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    build-essential \
    ca-certificates \
    gnupg \
    # Essential editors and utilities
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    # For Node.js native modules
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and package managers
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# Copy code-server from builder stage
COPY --from=builder /tmp/code-server/release-standalone/code-server-*-linux-amd64 /usr/local/lib/code-server
RUN ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

# Switch to coder user
USER coder
WORKDIR /home/coder

# Install Node.js development tools
RUN npm install -g \
    # Express and web frameworks
    express-generator \
    @nestjs/cli \
    create-react-app \
    # Development tools
    nodemon \
    pm2 \
    concurrently \
    cross-env \
    # Code quality tools
    eslint \
    prettier \
    jshint \
    # Testing frameworks
    jest \
    mocha \
    # Build tools
    webpack \
    webpack-cli \
    parcel \
    # Useful utilities
    http-server \
    live-server \
    json-server

# Create workspace and config directories
RUN mkdir -p /home/coder/workspace \
    && mkdir -p /home/coder/.config/code-server

# Configure code-server
RUN echo "bind-addr: 0.0.0.0:8080" > /home/coder/.config/code-server/config.yaml \
    && echo "auth: password" >> /home/coder/.config/code-server/config.yaml \
    && echo "password: ${PASSWORD}" >> /home/coder/.config/code-server/config.yaml \
    && echo "cert: false" >> /home/coder/.config/code-server/config.yaml \
    && echo "disable-telemetry: true" >> /home/coder/.config/code-server/config.yaml

# Install essential VS Code extensions for web development
RUN code-server --install-extension ms-vscode.vscode-typescript-next \
    && code-server --install-extension esbenp.prettier-vscode \
    && code-server --install-extension ms-vscode.vscode-json \
    && code-server --install-extension ms-vscode.vscode-css \
    && code-server --install-extension ms-vscode.vscode-html \
    && code-server --install-extension dbaeumer.vscode-eslint \
    && code-server --install-extension formulahendry.auto-rename-tag \
    && code-server --install-extension christian-kohler.path-intellisense \
    && code-server --install-extension bradlc.vscode-tailwindcss \
    && code-server --install-extension ms-vscode.live-server \
    && code-server --install-extension ritwickdey.liveserver \
    && code-server --install-extension ms-vscode.vscode-emmet \
    && code-server --install-extension vincaslt.highlight-matching-tag \
    && code-server --install-extension pranaygp.vscode-css-peek \
    && code-server --install-extension zignd.html-css-class-completion \
    && code-server --install-extension ecmel.vscode-html-css \
    && code-server --install-extension github.copilot \
    && code-server --install-extension pkief.material-icon-theme \
    && code-server --install-extension zhuangtongfa.material-theme

# Set up useful aliases for web development
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias serve="http-server -p 3000"' >> ~/.bashrc \
    && echo 'alias dev="nodemon app.js"' >> ~/.bashrc \
    && echo 'alias start="npm start"' >> ~/.bashrc \
    && echo 'alias test="npm test"' >> ~/.bashrc \
    && echo 'alias build="npm run build"' >> ~/.bashrc

# Create project templates for common setups
RUN mkdir -p /home/coder/templates/express-basic \
    && mkdir -p /home/coder/templates/html-starter \
    && mkdir -p /home/coder/templates/vanilla-js

# Express basic template
RUN cd /home/coder/templates/express-basic \
    && echo '{\
  "name": "express-app",\
  "version": "1.0.0",\
  "description": "Basic Express.js application",\
  "main": "app.js",\
  "scripts": {\
    "start": "node app.js",\
    "dev": "nodemon app.js"\
  },\
  "dependencies": {\
    "express": "^4.18.2"\
  },\
  "devDependencies": {\
    "nodemon": "^3.0.1"\
  }\
}' > package.json \
    && echo 'const express = require("express");\
const app = express();\
const PORT = process.env.PORT || 3000;\
\
app.use(express.static("public"));\
app.use(express.json());\
\
app.get("/", (req, res) => {\
  res.send("Hello World!");\
});\
\
app.listen(PORT, () => {\
  console.log(`Server running on http://localhost:${PORT}`);\
});' > app.js \
    && mkdir -p public \
    && echo '<!DOCTYPE html>\
<html>\
<head>\
  <title>Express App</title>\
  <link rel="stylesheet" href="style.css">\
</head>\
<body>\
  <h1>Welcome to Express!</h1>\
  <script src="script.js"></script>\
</body>\
</html>' > public/index.html \
    && echo 'body { font-family: Arial, sans-serif; margin: 40px; }\
h1 { color: #333; }' > public/style.css \
    && echo 'console.log("Express app loaded!");' > public/script.js

# HTML starter template
RUN cd /home/coder/templates/html-starter \
    && echo '<!DOCTYPE html>\
<html lang="en">\
<head>\
  <meta charset="UTF-8">\
  <meta name="viewport" content="width=device-width, initial-scale=1.0">\
  <title>HTML Starter</title>\
  <link rel="stylesheet" href="style.css">\
</head>\
<body>\
  <header>\
    <h1>Welcome to HTML Starter</h1>\
  </header>\
  <main>\
    <p>Start building your website here!</p>\
  </main>\
  <script src="script.js"></script>\
</body>\
</html>' > index.html \
    && echo '* { margin: 0; padding: 0; box-sizing: border-box; }\
body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }\
header { background: #333; color: white; padding: 1rem; text-align: center; }\
main { padding: 2rem; }' > style.css \
    && echo 'document.addEventListener("DOMContentLoaded", function() {\
  console.log("Page loaded!");\
});' > script.js

# Set working directory
WORKDIR /home/coder/workspace

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

# Create startup script
USER root
RUN echo '#!/bin/bash\n\
echo "🚀 Code-Server for Node.js Web Development"\n\
echo "📁 Workspace: /home/coder/workspace"\n\
echo "🔐 Password: $PASSWORD"\n\
echo "🌐 Access: http://localhost:8080"\n\
echo ""\n\
echo "📦 Installed Tools:"\n\
echo "  • Node.js $(node --version)"\n\
echo "  • npm $(npm --version)"\n\
echo "  • yarn $(yarn --version)"\n\
echo "  • Express Generator"\n\
echo "  • Nodemon, PM2"\n\
echo "  • ESLint, Prettier"\n\
echo "  • Jest, Mocha"\n\
echo "  • Live Server"\n\
echo ""\n\
echo "📋 Quick Commands:"\n\
echo "  • serve      → Start HTTP server on port 3000"\n\
echo "  • dev        → Start nodemon with app.js"\n\
echo "  • npm start  → Run npm start"\n\
echo ""\n\
echo "📁 Templates available in ~/templates/"\n\
echo "  • express-basic   → Basic Express.js setup"\n\
echo "  • html-starter    → HTML/CSS/JS starter"\n\
echo ""\n\
echo "🎯 Ready for web development!"\n\
echo ""\n\
exec gosu coder code-server --bind-addr 0.0.0.0:8080 --auth password /home/coder/workspace\n\
' > /usr/local/bin/start-codeserver.sh \
    && chmod +x /usr/local/bin/start-codeserver.sh

# Install gosu for better user switching
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

# Set environment for password
ENV PASSWORD=kira

# Start code-server
CMD ["/usr/local/bin/start-codeserver.sh"]
