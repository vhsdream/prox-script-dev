#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y mc
$STD apt-get install -y lsb-base
$STD apt-get install -y lsb-release
$STD apt-get install -y gnupg2
msg_ok "Installed Dependencies"

msg_info "Setting up Adoptium Repository"
mkdir -p /etc/apt/keyrings
wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | tee /etc/apt/keyrings/adoptium.asc
echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list
$STD apt-get update
msg_ok "Set up Adoptium Repository"

read -r -p "Which Tomcat version would you like to install? (9, 10.1, 11): " version
case $version in
  9)
    TOMCAT_VERSION="9"
    echo "Which LTS Java version would you like to use? (8, 11, 17, 21): "
    read -r jdk_version
    case $jdk_version in
      8)
        msg_info "Installing Temurin JDK 8 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-8-jdk
        msg_ok "Setup Temurin JDK 8 (LTS)"
        ;;
      11)
        msg_info "Installing Temurin JDK 11 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-11-jdk
        msg_ok "Setup Temurin JDK 11 (LTS)"
        ;;
      17)
        msg_info "Installing Temurin JDK 17 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-17-jdk
        msg_ok "Setup Temurin JDK 17 (LTS)"
        ;;
      21)
        msg_info "Installing Temurin JDK 21 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-21-jdk
        msg_ok "Setup Temurin JDK 21 (LTS)"
        ;;
      *)
        echo -e "\e[31m[ERROR] Invalid JDK version selected. Please enter 8, 11, 17 or 21.\e[0m"
        exit 1
        ;;
    esac
    ;;
  10|10.1)
    TOMCAT_VERSION="10.1"
    echo "Which LTS Java version would you like to use? (11, 17): "
    read -r jdk_version
    case $jdk_version in
      11)
        msg_info "Installing Temurin JDK 11 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-11-jdk
        msg_ok "Setup Temurin JDK 11"
        ;;
      17)
        msg_info "Installing Temurin JDK 17 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-17-jdk
        msg_ok "Setup Temurin JDK 17"
        ;;
      21)
        msg_info "Installing Temurin JDK 21 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-21-jdk
        msg_ok "Setup Temurin JDK 21 (LTS)"
        ;;
      *)
        echo -e "\e[31m[ERROR] Invalid JDK version selected. Please enter 11 or 17.\e[0m"
        exit 1
        ;;
    esac
    ;;
  11)
    TOMCAT_VERSION="11"
    echo "Which LTS Java version would you like to use? (17, 21): "
    read -r jdk_version
    case $jdk_version in
      17)
        msg_info "Installing Temurin JDK 17 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-17-jdk
        msg_ok "Setup Temurin JDK 17"
        ;;
      21)
        msg_info "Installing Temurin JDK 21 (LTS) for Tomcat $TOMCAT_VERSION"
        $STD apt-get install -y temurin-21-jdk
        msg_ok "Setup Temurin JDK 21 (LTS)"
        ;;
      *)
        echo -e "\e[31m[ERROR] Invalid JDK version selected. Please enter 17 or 21.\e[0m"
        exit 1
        ;;
    esac

msg_info "Installing Tomcat $TOMCAT_VERSION"

LATEST_VERSION=$(curl -s "https://dlcdn.apache.org/tomcat/tomcat-$TOMCAT_VERSION/" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+(-M[0-9]+)?/' | sort -V | tail -n 1)
LATEST_VERSION=${LATEST_VERSION%/}

TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-$TOMCAT_VERSION/$LATEST_VERSION/bin/apache-tomcat-$LATEST_VERSION.tar.gz"

wget -qO /tmp/tomcat.tar.gz "$TOMCAT_URL"
tar -xzf /tmp/tomcat.tar.gz -C /opt/
ln -s /opt/apache-tomcat-$LATEST_VERSION /opt/tomcat
chown -R $(whoami):$(whoami) /opt/apache-tomcat-$LATEST_VERSION

cat <<EOT > /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=simple
User=$(whoami)
Group=$(whoami)
Environment=JAVA_HOME=/usr/lib/jvm/java-${jdk_version}-openjdk-amd64
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOT

systemctl daemon-reload
systemctl enable tomcat
systemctl start tomcat
msg_ok "Tomcat $LATEST_VERSION installed and started"

msg_info "Cleaning up"
rm -f /tmp/tomcat.tar.gz
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"
