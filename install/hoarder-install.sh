#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/MickLesk/Proxmox_DEV/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  python3 \
  g++ \
  build-essential \
  curl \
  sudo \
  gnupg \
  ca-certificates \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Node.js"
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" >/etc/apt/sources.list.d/nodesource.list
$STD apt-get update
$STD apt-get install -y nodejs
msg_ok "Installed Node.js"

msg_info "Installing Hoarder"
ENV_FILE=/etc/hoarder/hoarder.env
mkdir -p /var/lib/hoarder 
mkdir -p /etc/hoarder 

# Download and extract the latest release
cd /opt
RELEASE=$(curl -s https://api.github.com/repos/hoarder-app/hoarder/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
wget -q "https://github.com/hoarder-app/hoarder/archive/refs/tags/v${RELEASE}.zip"
unzip -q v${RELEASE}.zip
mv hoarder-${RELEASE} /opt/hoarder

# Install dependencies
cd /opt/hoarder
corepack enable
export PUPPETEER_SKIP_DOWNLOAD="true"
cd /opt/hoarder/apps/web && pnpm install --frozen-lockfile
cd /opt/hoarder/apps/workers && pnpm install --frozen-lockfile

# Build the web app
cd /opt/hoarder/apps/web
pnpm exec next build --experimental-build-mode compile

echo "${RELEASE}" >"/opt/Hoarder_version.txt"
HOARDER_SECRET="$(openssl rand -base64 32 | cut -c1-24)"
MEILI_SECRET="$(openssl rand -base64 36)"
echo "" >>~/hoarder.creds && chmod 600 ~/hoarder.creds
echo -e "NextAuth Secret: $HOARDER_SECRET" >>~/hoarder.creds
echo -e "Meilisearch Master Key: $MEILI_SECRET" >>~/hoarder.creds

# Prepare the environment file
cat <<EOF >$ENV_FILE
NEXTAUTH_SECRET="$(openssl rand -base64 36)"
DATA_DIR="/var/lib/hoarder"
MEILI_ADDR="http://127.0.0.1:7700"
MEILI_MASTER_KEY="$(openssl rand -base64 36)"
NEXTAUTH_URL="http://localhost:3000"
NODE_ENV=production
EOF
msg_ok "Installed Hoarder"

msg_info "Creating Services"
cat <<EOF >/etc/systemd/system/hoarder-web.service
[Unit]
Description=Hoarder Web
After=network.target

[Service]
ExecStart=pnpm start
WorkingDirectory=/opt/hoarder/apps/web
Restart=always
RestartSec=10

EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >/etc/systemd/system/hoarder-workers.service
[Unit]
Description=Hoarder Workers
After=network.target

[Service]
ExecStart=pnpm start:prod
WorkingDirectory=/opt/hoarder/apps/workers
Restart=always
RestartSec=10

EnvironmentFile=$ENV_FILE

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hoarder-web.service
systemctl enable -q --now hoarder-workers.service
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
rm -R /tmp/hoarder
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"