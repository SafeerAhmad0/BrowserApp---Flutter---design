#!/bin/bash

# Simple Squid Proxy Setup for VPS
# Run this on both Tokyo (108.160.139.37) and Singapore (45.76.145.170) servers

echo "🚀 Setting up Squid Proxy Server..."

# Update system
apt update && apt upgrade -y

# Install Squid proxy server
apt install -y squid

# Backup original config
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create simple Squid configuration
cat > /etc/squid/squid.conf << 'EOF'
# Basic Squid Configuration for BlueX Browser

# Port configuration
http_port 3128

# Access control
acl localnet src 0.0.0.0/0
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports

# Allow access from anywhere (for your app)
http_access allow localnet
http_access allow localhost

# Deny all other access
http_access deny all

# Disable caching for dynamic content
cache deny all

# Hide server identity
via off
forwarded_for delete

# Disable logs for privacy
access_log none
cache_log /dev/null

# DNS settings
dns_nameservers 8.8.8.8 8.8.4.4
EOF

# Configure firewall
ufw allow 22/tcp
ufw allow 3128/tcp
ufw --force enable

# Start and enable Squid
systemctl restart squid
systemctl enable squid

# Check status
systemctl status squid

echo ""
echo "✅ Squid Proxy setup complete!"
echo ""
echo "📋 Server Information:"
echo "  - Proxy Address: $(curl -s ifconfig.me):3128"
echo "  - Protocol: HTTP"
echo "  - Authentication: None"
echo ""
echo "🧪 Test your proxy:"
echo "  curl -x $(curl -s ifconfig.me):3128 https://httpbin.org/ip"
echo ""
echo "🔧 To check logs:"
echo "  journalctl -u squid -f"
echo ""