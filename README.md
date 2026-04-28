# Fedora Remote Desktop Ansible Playbook

Transform a fresh Fedora 43+ VPS into a full remote desktop with web-based VNC access.

## Features

- **Desktop Environment**: XFCE4 with Firefox browser
- **Web-based VNC**: noVNC with SSL encryption accessible via browser
- **Clipboard Sharing**: Bidirectional clipboard sync between client and remote desktop
- **Security Hardened**:
  - SSH key-only authentication
  - Root login disabled
  - Password authentication disabled
  - Firewall configured (only SSH + noVNC ports open)
  - **Fail2ban**: Protects against VNC brute-force attacks (5 failed attempts = 1 hour ban)
- **Automated**: Runs system updates after setup
- **Configurable User**: Set your own non-root username via `vars.yml`

## Requirements

- Fedora 43+ VPS
- Ansible installed on control node (`pip install ansible`)
- SSH access to VPS as `root` (initial setup)
- Your SSH public key

## Quick Start

### 1. Clone/Download Files

Ensure you have these files:
- `playbook.yml` - Main Ansible playbook
- `inventory.ini` - VPS IP configuration
- `vars.yml` - Configuration variables (should be encrypted with vault)

### 2. Configure Inventory

Edit `inventory.ini`:
```ini
[vps]
your_vps_ip ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_rsa
```

Use `ansible_user=root` for the initial run against a fresh Fedora VPS. After the playbook completes, you can update to `ansible_user=your_username`.

### 3. Set Variables

Create `vars.yml` with your configuration:
```yaml
# Configurable non-root user (will be created by playbook)
username: your_username

# Sensitive values - encrypt with: ansible-vault encrypt vars.yml
user_password: "your-user-password"
vnc_password: "your-vnc-password"
ssh_public_key: "ssh-rsa AAAAB3NzaC1yc2E... your@email.com"

# Non-sensitive configuration
novnc_port: 6080
vnc_display_num: 1
vnc_resolution: "1920x1080"
```

Encrypt sensitive data:
```bash
ansible-vault encrypt vars.yml
```

### 4. Initial VPS Setup

Before running the playbook, ensure:
- Root SSH access is available on the VPS
- Your SSH public key is in root's `~/.ssh/authorized_keys`

### 5. Run the Playbook

```bash
ansible-playbook -i inventory.ini -e @vars.yml playbook.yml --ask-vault-pass
```

## Access Your Remote Desktop

### Web Interface (noVNC)
1. Open browser: `https://your_vps_ip:6080/vnc.html`
2. Accept the self-signed certificate warning
3. Click "Connect"
4. Enter VNC password (set in `vars.yml`)
5. Enjoy your XFCE4 desktop with Firefox!

### SSH Access
```bash
ssh your_username@your_vps_ip
```

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `username` | `rocky` | Configurable non-root user created by playbook |
| `user_password` | (required) | Password for the non-root user |
| `vnc_password` | (required) | VNC session password |
| `ssh_public_key` | (required) | Your SSH public key |
| `novnc_port` | 6080 | noVNC web access port |
| `vnc_display_num` | 1 | VNC display number (port = 5900 + display_num) |
| `vnc_resolution` | 1920x1080 | VNC session resolution |

## Fail2ban Protection

The playbook automatically configures fail2ban to protect against VNC brute-force attacks:
- Monitors VNC authentication failures
- Bans IPs after 5 failed attempts
- Ban duration: 1 hour (3600 seconds)
- Monitors port 6080 (noVNC web interface)

Check fail2ban status:
```bash
ssh your_username@your_vps_ip "sudo fail2ban-client status vnc"
```

## Firewall Rules

The playbook configures `firewalld` to allow only:
- **SSH (22/tcp)**: Secure shell access
- **noVNC (6080/tcp)**: Web-based VNC access

All other incoming traffic is denied.

## Services Created

| Service | Description |
|---------|-------------|
| `vncserver-<username>` | TigerVNC server running as configured user |
| `novnc` | Websockify proxy with SSL for noVNC access |
| `fail2ban` | Intrusion prevention with VNC jail active |

## Troubleshooting

### Can't connect to noVNC
```bash
# Check services
ssh your_username@your_vps_ip "systemctl status vncserver-<username> novnc fail2ban"

# Check listening ports
ssh your_username@your_vps_ip "ss -tlnp | grep -E '(5901|6080)'"

# Check fail2ban
ssh your_username@your_vps_ip "sudo fail2ban-client status vnc"
```

### VNC session issues
```bash
# Check VNC logs
ssh your_username@your_vps_ip "cat /home/your_username/.vnc/*.log"
```

### Firefox not found
The playbook installs Firefox via the `@xfce-desktop-environment` group. If missing:
```bash
ssh your_username@your_vps_ip "sudo dnf install firefox"
```

## File Structure

```
.
├── playbook.yml          # Main Ansible playbook
├── inventory.ini        # VPS connection details
├── vars.yml            # Configuration (encrypted with vault)
├── example_vars.yml    # Template for vars.yml
├── example_inventory.ini # Template for inventory.ini
└── README.md          # This file
```

## Security Notes

- This playbook disables password authentication for SSH - ensure your SSH key works before running
- Root login is disabled after playbook completion
- The configured user has passwordless sudo access
- Self-signed SSL certificate is valid for 365 days
- Only necessary ports are exposed through the firewall

## License

MIT License - Use freely for personal and commercial projects.

## Contributing

Issues and pull requests welcome at your repository.
