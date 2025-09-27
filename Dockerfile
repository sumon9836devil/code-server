# Use Ubuntu as base image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=20.x \
    CODE_SERVER_VERSION=4.95.3 \
    PASSWORD=kira \
    TZ=UTC

# Install essential system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    build-essential \
    ca-certificates \
    gnupg \
    vim \
    nano \
    htop \
    tree \
    unzip \
    zip \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and package managers
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# Install global Node.js tools
RUN npm install -g \
    express-generator \
    @nestjs/cli \
    create-react-app \
    nodemon \
    pm2 \
    concurrently \
    cross-env \
    eslint \
    prettier \
    jshint \
    jest \
    mocha \
    webpack \
    webpack-cli \
    parcel \
    http-server \
    live-server \
    json-server

# Download and install pre-built code-server
RUN curl -fsSL https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz \
    | tar -xzC /tmp \
    && mv /tmp/code-server-${CODE_SERVER_VERSION}-linux-amd64 /usr/local/lib/code-server \
    && ln -s /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

# Create coder user
RUN groupadd --gid 1000 coder \
    && useradd --uid 1000 --gid coder --shell /bin/bash --create-home coder \
    && mkdir -p /etc/sudoers.d \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

# Install gosu for user switching
RUN apt-get update && apt-get install -y gosu && rm -rf /var/lib/apt/lists/*

USER coder
WORKDIR /home/coder

# Create workspace and config
RUN mkdir -p /home/coder/workspace \
    && mkdir -p /home/coder/.config/code-server

# Configure code-server
RUN echo "bind-addr: 0.0.0.0:8080" > /home/coder/.config/code-server/config.yaml \
    && echo "auth: password" >> /home/coder/.config/code-server/config.yaml \
    && echo "password: ${PASSWORD}" >> /home/coder/.config/code-server/config.yaml \
    && echo "cert: false" >> /home/coder/.config/code-server/config.yaml \
    && echo "disable-telemetry: true" >> /home/coder/.config/code-server/config.yaml

# Install useful VS Code extensions (skip built-ins that cause errors)
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
    && code-server --install-extension github.copilot \
    && code-server --install-extension pkief.material-icon-theme \
    && code-server --install-extension zhuangtongfa.material-theme

# Aliases
RUN echo 'alias ll="ls -la"' >> ~/.bashrc \
    && echo 'alias serve="http-server -p 3000"' >> ~/.bashrc \
    && echo 'alias dev="nodemon app.js"' >> ~/.bashrc \
    && echo 'alias start="npm start"' >> ~/.bashrc \
    && echo 'alias test="npm test"' >> ~/.bashrc \
    && echo 'alias build="npm run build"' >> ~/.bashrc

# Project templates
RUN mkdir -p /home/coder/templates/express-basic \
    && mkdir -p /home/coder/templates/html-starter

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
app.use(express.static("public"));\
app.use(express.json());\
app.get("/", (req, res) => {\
  res.send("Hello World!");\
});\
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

# Health check (check root, not /healthz)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

USER root
# Startup script
RUN echo '#!/bin/bash\n\
echo "🚀 Code-Server for Node.js Web Development"\n\
echo "📁 Workspace: /home/coder/workspace"\n\
echo "🔐 Password: $PASSWORD"\n\
echo "🌐 Access: http://localhost:8080"\n\
exec gosu coder code-server --bind-addr 0.0.0.0:8080 --auth password /home/coder/workspace\n\
' > /usr/local/bin/start-codeserver.sh \
    && chmod +x /usr/local/bin/start-codeserver.sh

# Default command
CMD ["/usr/local/bin/start-codeserver.sh"]
