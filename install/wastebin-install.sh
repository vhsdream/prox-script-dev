#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck
# Co-Author: MickLesk (Canbiz)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
# Source: https://github.com/matze/wastebin

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies (Patience)"
$STD apt-get install -y --no-install-recommends \
  unzip \
  build-essential \
  curl \
  sudo \
  git \
  make \
  mc
msg_ok "Installed Dependencies"

msg_info "Installing Rust (Patience)" 
$STD curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rustup_installer.sh
$STD sh rustup_installer.sh -q -y
$STD source "$HOME/.cargo/env"
RUST_LOG=warn 
msg_ok "Installed Rust" 

msg_info "Installing Wastebin (Patience)" 
Wastebin=$(wget -q https://github.com/matze/wastebin/releases/latest -O - | grep "title>Release" | cut -d " " -f 4)
cd /opt
$STD wget https://github.com/matze/wastebin/archive/refs/tags/$Wastebin.zip
$STD unzip $Wastebin.zip 
mv wastebin-$Wastebin wastebin 
rm -R $Wastebin.zip 

msg_ok "Installed Wastebin"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/wastebin.service
[Unit]
Description=Start Wastebin Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/wastebin
ExecStart=/root/.cargo/bin/cargo run --release --quiet

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
msg_ok "Created Service"

msg_info "Starting Service (Patience)"
systemctl enable -q --now wastebin.service
while true; do
    systemctl status wastebin
	if ! systemd-cgtop | grep -q 'cargo run --release --quiet'; then
        break
    fi
    sleep 20
done
msg_ok "Service started successfully"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
