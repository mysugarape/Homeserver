#!/usr/bin/env bash

==============================================================================

Homeserver Installation Script for Debian 12 (Bookworm)

Included Services: Docker, CUPS (Printserver), Tailscale, aaPanel

==============================================================================

set -e

Colors for output

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

Ensure the script is run as root

if [ "$EUID" -ne 0 ]; then
echo -e "${RED}[ERROR] This script must be run as root (or with sudo).${NC}"
exit 1
fi

Determine the actual non-root user who called sudo

ACTUAL_USER="${SUDO_USER:-$USER}"

if [ "$ACTUAL_USER" = "root" ]; then
echo -e "${YELLOW}[WARNING] Running directly as root. Non-root user privileges for Docker/CUPS won't be assigned automatically to a standard user.${NC}"
fi

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}        Debian 12 Homeserver Installation${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "Target User for Group Assignments: ${GREEN}${ACTUAL_USER}${NC}"
echo ""

sleep 2

------------------------------------------------------------------------------

Phase 1: System Update & Essential Packages

------------------------------------------------------------------------------

echo -e "${GREEN}[1/5] Updating system packages and installing essentials...${NC}"
apt update && apt upgrade -y
apt install -y 

curl 

wget 

gnupg 

lsb-release 

sudo 

ca-certificates 

git 

net-tools 

logrotate

------------------------------------------------------------------------------

Phase 2: Docker & Container Environment Setup

------------------------------------------------------------------------------

echo -e "${GREEN}[2/5] Setting up Docker and Docker Compose...${NC}"

Add official Docker GPG key & repository

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg

echo 

"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian 

$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

Configure Docker daemon log rotation (max 10m size, max 3 files)

mkdir -p /etc/docker
cat < /etc/docker/daemon.json
{
"log-driver": "json-file",
"log-opts": {
"max-size": "10m",
"max-file": "3"
}
}
EOF

Add user to docker group

if [ "$ACTUAL_USER" != "root" ]; then
usermod -aG docker "$ACTUAL_USER"
echo -e "${GREEN}User '${ACTUAL_USER}' added to group 'docker'.${NC}"
fi

systemctl restart docker

------------------------------------------------------------------------------

Phase 3: Printserver (CUPS & Avahi) Setup

------------------------------------------------------------------------------

echo -e "${GREEN}[3/5] Installing and configuring CUPS Printserver...${NC}"
apt install -y cups cups-client cups-bsd avahi-daemon

Add user to lpadmin group

if [ "$ACTUAL_USER" != "root" ]; then
usermod -aG lpadmin "$ACTUAL_USER"
echo -e "${GREEN}User '${ACTUAL_USER}' added to group 'lpadmin'.${NC}"
fi

Configure CUPS for network listening & admin access from LAN

cp /etc/cups/cupsd.conf /etc/cups/cupsd.conf.bak

Update Listen directive to listen on all interfaces at port 631

sed -i 's/^Listen localhost:631/Listen *:631/' /etc/cups/cupsd.conf
if ! grep -q "^Listen *:631" /etc/cups/cupsd.conf; then
echo "Listen *:631" >> /etc/cups/cupsd.conf
fi

Allow LAN access to main location, admin location, and configuration

cupsctl --remote-admin --remote-any --share-printers

Ensure Avahi & CUPS services are running

systemctl enable avahi-daemon cups
systemctl restart avahi-daemon cups

------------------------------------------------------------------------------

Phase 4: Tailscale VPN Setup

------------------------------------------------------------------------------

echo -e "${GREEN}[4/5] Setting up Tailscale Repository and Installing Client...${NC}"

mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /etc/apt/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

apt update
apt install -y tailscale

------------------------------------------------------------------------------

Phase 5: aaPanel Installation (Interactive)

------------------------------------------------------------------------------

echo -e "${GREEN}[5/5] Launching aaPanel Installer...${NC}"
echo -e "${YELLOW}Please respond to any prompts shown by the aaPanel setup script below.${NC}"
sleep 2

Execute official aaPanel script

URL="https://www.aapanel.com/script/install_7.0_en.sh"
if curl -sSO "$URL"; then
bash install_7.0_en.sh aapanel
rm -f install_7.0_en.sh
else
echo -e "${RED}[ERROR] Failed to download aaPanel installer script.${NC}"
fi

------------------------------------------------------------------------------

Phase 6: Information Gathering & Final Summary Banner

------------------------------------------------------------------------------

Retrieve IP Address and Hostname

PRIMARY_IP=$(hostname -I | awk '{print $1}')
HOSTNAME_STR=$(hostname)

Extract aaPanel credentials if available

AAPANEL_INFO=""
if [ -f /www/server/panel/default.pl ]; then
AAPANEL_INFO=$(cat /www/server/panel/default.pl)
fi

echo -e "\n\n"
echo -e "${BLUE}=================================================================${NC}"
echo -e "${GREEN}             HOMESERVER INSTALLATION COMPLETE${NC}"
echo -e "${BLUE}=================================================================${NC}"
echo ""
echo -e "${YELLOW}[1] System Info:${NC}"
echo -e "    - Hostname:   ${GREEN}${HOSTNAME_STR}${NC}"
echo -e "    - Local IP:   ${GREEN}${PRIMARY_IP}${NC}"
echo ""
echo -e "${YELLOW}[2] CUPS Printserver Webinterface:${NC}"
echo -e "    - Local URL:  ${GREEN}http://${PRIMARY_IP}:631${NC} or${GREEN}http://${HOSTNAME_STR}.local:631${NC}"
echo ""
echo -e "${YELLOW}[3] aaPanel Control Panel:${NC}"
if [ -n "$AAPANEL_INFO" ]; then
echo -e "    - Panel Access Info: ${GREEN}${AAPANEL_INFO}${NC}"
echo -e "    - Note: Run ${YELLOW}bt default${YELLOW} in terminal to re-display or reset login info."
else
echo -e "    - Run command ${GREEN}bt default${NC} to view your aaPanel URL, username, and password."
fi
echo ""
echo -e "${YELLOW}[4] Tailscale Setup:${NC}"
echo -e "    - Connect to your Tailscale network by running:"
echo -e "      ${GREEN}sudo tailscale up${NC}"
echo ""
echo -e "${YELLOW}[5] Fritzbox / Network Configuration Tip:${NC}"
echo -e "    - Open your Fritzbox dashboard (${GREEN}http://fritz.box${NC})."
echo -e "    - Go to ${BLUE}Home Network -> Network${NC}, locate this device (${HOSTNAME_STR})."
echo -e "    - Check the box: ${GREEN}\"Always assign this network device the same IPv4 address\"${NC}."
echo ""
echo -e "${BLUE}=${NC}"
echo -e "If you were logged in as user '${ACTUAL_USER}', please log out and back in"
echo -e "to apply group permissions for Docker and CUPS (lpadmin)."
echo -e "${BLUE}=${NC}\n"
