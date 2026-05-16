# Fedora Remote Desktop Ansible Playbook

Transform a fresh Fedora 43+ machine into a full remote desktop with web-based VNC access.

## Features

- **Desktop Environment**: XFCE4 with polished experience (whiskermenu, arc-theme, papirus-icons, power-manager, thunar-archive-plugin, gvfs, google-noto-fonts) and Firefox browser
- **Web-based VNC**: noVNC via nginx reverse proxy with SSL encryption accessible via browser
- **Clipboard Sharing**: Bidirectional clipboard sync between client and remote desktop (TigerVNC built-in)
- **Security Hardened**:
  - SSH key-based authentication (if key present)
  - Root login disabled
  - Firewall configured (only SSH + HTTPS + HTTP open)
  - **nginx rate limiting**: 5 requests/minute/IP to WebSocket endpoint (real-time)
  - **TigerVNC blacklist**: Disabled (relies on nginx + fail2ban — see three-layer protection)
  - **Fail2ban**: Long-term IP banning from nginx access logs (20 connections/10min = 1 hour ban)
- **Three-Layer Brute Force Protection**: nginx rate limiting → fail2ban on nginx logs (real client IP visible)
- **Optional Let's Encrypt**: Set a domain in `vars.yml` for valid HTTPS certificates
- **Automated**: Runs system updates after setup
- **Configurable User**: Set your own non-root username

## Requirements

- Fedora 43+ system
- Root access (or sudo)
- Ansible installed on control node (`pip install ansible` or `dnf install ansible`)

## Quick Start

### One-liner Bootstrap

Run as root on your Fedora machine:

```bash
curl -sSL https://raw.githubusercontent.com/markeast/fedora-vps-to-desktop/main/install.sh | bash
```

The script will:
1. Install Ansible and Git
2. Prompt for username, system password, VNC password, domain (optional), and timezone
3. Clone the playbook to `/opt/vdp`
4. Run the Ansible playbook locally

### Silent / Unattended Install

Set environment variables before running the script to skip all prompts:

```bash
export VDP_USERNAME="myuser"
export VDP_USER_PASSWORD="s3cret"
export VDP_VNC_PASSWORD="vnc123"
export VDP_DOMAIN="vnc.example.com"
export VDP_TIMEZONE="America/New_York"
curl -sSL https://raw.githubusercontent.com/markeast/fedora-vps-to-desktop/main/install.sh | bash
```

All variables are optional — any not set will be prompted interactively.

### Manual Setup (Remote Control Node)

1. Clone/copy files to your control machine
2. Create `inventory.ini` from `example_inventory.ini`:
   ```ini
   [vps]
   your_vps_ip ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
   ```
3. Create `vars.yml` from `example_vars.yml` and populate your values
4. Encrypt sensitive data:
   ```bash
   ansible-vault encrypt vars.yml
   ```
5. Run the playbook:
   ```bash
   ansible-playbook -i inventory.ini -e @vars.yml playbook.yml --ask-vault-pass
   ```

## Access Your Remote Desktop

### Web Interface (noVNC via nginx)

1. Open browser: `https://your_server_ip` (or `https://vnc.yourdomain.com` if configured)
2. Accept the self-signed certificate warning (unless using Let's Encrypt with a domain)
3. Click "Connect"
4. Enter VNC password
5. Enjoy your XFCE4 desktop with Firefox!

### SSH Access

```bash
ssh your_username@your_server_ip
```

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `username` | (required) | Configurable non-root user created by playbook |
| `user_password` | auto-generated | Password for the non-root user |
| `vnc_password` | (required) | VNC session password |
| `novnc_port` | 6080 | noVNC backend port (internal, only localhost) |
| `vnc_display_num` | 1 | VNC display number (port = 5900 + display_num) |
| `vnc_resolution` | 1920x1080 | VNC session resolution |
| `nginx_ssl_port` | 443 | nginx HTTPS listen port |
| `domain` | `""` | Optional domain for Let's Encrypt (e.g. `vnc.example.com`) |
| `letsencrypt_email` | `""` | Optional email for Let's Encrypt registration |
| `timezone` | UTC | System timezone |

## Three-Layer Brute Force Protection

The playbook configures three complementary layers of protection:

| Layer | Mechanism | Rate | Type |
|-------|-----------|------|------|
| 1 | **nginx `limit_req`** | 5 requests/min/IP to `/websockify` | Real-time |
| 2 | **TigerVNC blacklist** | Disabled (`-UseBlacklist=0` — nginx proxy means all connections appear as localhost) | N/A |
| 3 | **Fail2ban on nginx logs** | 20 connections/10min → 1 hr ban | Log-based |

Fail2ban monitors nginx access logs for `/websockify` WebSocket connections and bans IPs at the HTTPS port (443). Unlike the old VNC-based approach, this sees the real client IP (not `127.0.0.1` from the websockify proxy).

Check fail2ban status:
```bash
ssh your_username@your_server_ip "sudo fail2ban-client status novnc"
```

## Firewall Rules

The playbook configures `firewalld` to allow only:

- **SSH (22/tcp)**: Secure shell access
- **HTTPS (443/tcp)**: nginx reverse proxy for noVNC (full TLS)
- **HTTP (80/tcp)**: Redirects to HTTPS and serves Let's Encrypt ACME challenges

The noVNC backend port (`{{ novnc_port }}`) is bound to localhost only and not exposed through the firewall. All other incoming traffic is denied.

## Services Created

| Service | Description |
|---------|-------------|
| `vncserver-<username>` | TigerVNC server running as configured user (with built-in blacklist disabled) |
| `novnc` | Websockify WebSocket proxy (local only, no TLS) |
| `nginx` | Reverse proxy serving noVNC static files, WebSocket proxy, TLS termination, rate limiting |
| `fail2ban` | Intrusion prevention with noVNC jail monitoring nginx access logs |

## Troubleshooting

### Can't connect to noVNC

```bash
# Check services
systemctl status vncserver-<username> novnc nginx fail2ban

# Check listening ports (nginx on 443, VNC on 5901, websockify on 127.0.0.1:6080)
ss -tlnp | grep -E '(5901|6080|:443)'

# Check fail2ban
sudo fail2ban-client status novnc
```

### VNC session issues

```bash
# Check VNC logs (TigerVNC 1.15+ location)
cat /home/your_username/.config/tigervnc/localhost:1.log
```

### Firefox not found

The playbook installs Firefox. If missing:
```bash
sudo dnf install firefox
```

## File Structure

```
/opt/vdp/
├── playbook.yml          # Main Ansible playbook
├── inventory.ini         # Local connection config
├── vars.yml             # Configuration (generated by install.sh)
├── install.sh           # Bootstrap script
├── example_vars.yml     # Template for vars.yml
├── example_inventory.ini # Template for inventory.ini
└── README.md           # This file
```

## Optional: Custom Domain & Let's Encrypt

By default the playbook generates a self-signed certificate (valid for 365 days). To use a valid Let's Encrypt certificate:

1. Point your domain's DNS A record to your server IP
2. Rerun the playbook with `domain` set in `vars.yml`:
   ```yaml
   domain: "vnc.example.com"
   ```
3. Or re-run `install.sh` and answer "y" when asked about domain

Certbot will obtain a certificate via the webroot method on port 80, and the nginx config updates to serve the Let's Encrypt certs. Auto-renewal is enabled via `certbot.timer`.

**Without a domain**: Uses self-signed certificate. Access via `https://your_server_ip`.

## Security Notes

- SSH password authentication is disabled only when an SSH key is detected in `authorized_keys`
- Root login is disabled after playbook completion
- The configured user has passwordless sudo access
- Self-signed SSL certificate is valid for 365 days (Let's Encrypt certs valid for 90 days, auto-renewed)
- Only necessary ports are exposed through the firewall

## License

MIT License - Use freely for personal and commercial projects.

## Contributing

Issues and pull requests welcome.
