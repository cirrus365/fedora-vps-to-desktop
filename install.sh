#!/bin/bash
set -e

REPO_URL="https://github.com/cirrus365/fedora-vps-to-desktop"
INSTALL_DIR="/opt/vdp"

# Silent mode: VDP_USERNAME, VDP_USER_PASSWORD, VDP_VNC_PASSWORD, VDP_DOMAIN, VDP_TIMEZONE
USERNAME="${VDP_USERNAME:-}"
USER_PASSWORD="${VDP_USER_PASSWORD:-}"
VNC_PASSWORD="${VDP_VNC_PASSWORD:-}"
DOMAIN="${VDP_DOMAIN:-}"
TIMEZONE="${VDP_TIMEZONE:-UTC}"

echo "Fedora Virtual Desktop Playbook Installer"
echo "========================================="

echo "[1/5] Installing Ansible and Git..."
dnf install -y ansible git

echo "[2/5] Configuring your desktop..."

if [ -z "$USERNAME" ]; then
    read -p "System username: " USERNAME </dev/tty
fi

if [ -z "$USER_PASSWORD" ]; then
    read -s -p "System password (blank = auto-generate): " USER_PASSWORD </dev/tty
    echo ""
fi

if [ -z "$VNC_PASSWORD" ]; then
    read -s -p "VNC desktop password: " VNC_PASSWORD </dev/tty
    echo ""
    while [ -z "$VNC_PASSWORD" ]; do
        read -s -p "VNC password (required): " VNC_PASSWORD </dev/tty
        echo ""
    done
fi

if [ -z "$DOMAIN" ]; then
    read -p "Configure domain for Let's Encrypt? (y/N): " HAS_DOMAIN </dev/tty
    if [[ "$HAS_DOMAIN" =~ ^[Yy] ]]; then
        read -p "  Domain name: " DOMAIN </dev/tty
    fi
fi

if [ -z "$TIMEZONE" ]; then
    read -p "Timezone [UTC]: " TIMEZONE </dev/tty
    TIMEZONE="${TIMEZONE:-UTC}"
fi

if [ -z "$USER_PASSWORD" ]; then
    USER_PASSWORD=$(openssl rand -base64 24)
fi

echo "[3/5] Cloning playbook..."
if [ ! -d "$INSTALL_DIR" ]; then
    git clone "$REPO_URL" "$INSTALL_DIR"
else
    echo "  $INSTALL_DIR already exists, pulling latest..."
    git -C "$INSTALL_DIR" pull
fi

echo "[4/5] Generating configuration..."
cat > "$INSTALL_DIR/vars.yml" <<EOF
username: "$USERNAME"
user_password: "$USER_PASSWORD"
vnc_password: "$VNC_PASSWORD"
timezone: "$TIMEZONE"
novnc_port: 6080
vnc_display_num: 1
vnc_resolution: "1920x1080"
nginx_ssl_port: 443
EOF
if [ -n "$DOMAIN" ]; then
    echo "domain: $DOMAIN" >> "$INSTALL_DIR/vars.yml"
fi

cat > "$INSTALL_DIR/inventory.ini" <<EOF
[vps]
localhost ansible_connection=local
EOF

echo "[5/5] Running playbook... (this may take a few minutes)"
cd "$INSTALL_DIR"
ansible-playbook -i inventory.ini playbook.yml

echo ""
echo "Done! Your desktop is ready."
if [ -z "$DOMAIN" ]; then
    echo "Access at: https://YOUR-VPS-IP"
else
    echo "Access at: https://$DOMAIN"
fi
echo "System password (for su / local login): $USER_PASSWORD"
