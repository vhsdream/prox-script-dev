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

msg_info "Installing Rust" 
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -q -y &
RUST_INSTALL_PID=$!
while kill -0 $RUST_INSTALL_PID 2> /dev/null; do
    echo "Warte auf die Installation von Rust..."
    sleep 5
done
if [ $? -eq 0 ]; then
    $STD source "$HOME/.cargo/env"
    msg_ok "Rust installed successfully" 
else
    msg_error "Error while installing Rust"
    exit 1
fi

msg_info "Install Wastebin" 
cd /opt
$STD git clone https://github.com/matze/wastebin
cd wastebin
$STD cargo run --release > /opt/wastebin/wastebin.log 2>&1 &
while ! grep -q "Finished release" /opt/wastebin/wastebin.log; do
    sleep 10
done
msg_ok "Wastebin Installed successfully"


msg_info "Set up service"
cat <<EOF >/etc/systemd/system/wastebin.service
[Unit]
Description=Start Wastebin Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/wastebin
ExecStart=/root/.cargo/bin/cargo run --release > /opt/wastebin/wastebin.log 2>&1

[Install]
WantedBy=multi-user.target
EOF
$STD sudo systemctl daemon-reload
$STD sudo systemctl start wastebin
msg_ok "Created Services"

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get autoremove
$STD apt-get autoclean
msg_ok "Cleaned"
