#!/bin/bash

# BlueX Browser Proxy Server Setup
# Run this script on both VPS servers to set up proxy functionality

echo "🚀 Setting up BlueX Browser Proxy Server..."

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "🔧 Installing required packages..."
apt install -y nginx nodejs npm curl

# Install Node.js proxy server
echo "📥 Installing Node.js dependencies..."
npm install -g http-proxy-middleware express cors

# Create proxy server directory
mkdir -p /opt/bluex-proxy
cd /opt/bluex-proxy

# Create proxy server script
cat > proxy-server.js << 'EOF'
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 8080;

// Enable CORS for all routes
app.use(cors({
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['*']
}));

// Basic authentication middleware
const authenticate = (req, res, next) => {
    const auth = req.headers['x-proxy-auth'];
    if (!auth) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    try {
        const credentials = Buffer.from(auth, 'base64').toString('ascii');
        const [username, password] = credentials.split(':');

        // Simple authentication (replace with your actual credentials)
        if (username === 'bluex_user' && password === 'BlueXProxy2024!') {
            next();
        } else {
            res.status(401).json({ error: 'Invalid credentials' });
        }
    } catch (e) {
        res.status(401).json({ error: 'Invalid authentication format' });
    }
};

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        server: 'BlueX Proxy',
        timestamp: new Date().toISOString()
    });
});

// Proxy endpoint
app.get('/proxy', authenticate, (req, res) => {
    const targetUrl = req.query.url;

    if (!targetUrl) {
        return res.status(400).json({ error: 'URL parameter required' });
    }

    try {
        const url = new URL(targetUrl);

        // Create proxy middleware
        const proxy = createProxyMiddleware({
            target: `${url.protocol}//${url.host}`,
            changeOrigin: true,
            pathRewrite: {
                '^/proxy': url.pathname + url.search
            },
            onError: (err, req, res) => {
                console.error('Proxy error:', err.message);
                res.status(500).json({ error: 'Proxy error: ' + err.message });
            },
            onProxyReq: (proxyReq, req, res) => {
                // Set headers to appear as normal browser request
                proxyReq.setHeader('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
                proxyReq.setHeader('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8');
                proxyReq.setHeader('Accept-Language', 'en-US,en;q=0.5');
                proxyReq.setHeader('Cache-Control', 'no-cache');

                console.log(`Proxying: ${targetUrl}`);
            }
        });

        proxy(req, res);

    } catch (error) {
        console.error('URL parsing error:', error);
        res.status(400).json({ error: 'Invalid URL format' });
    }
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🌐 BlueX Proxy Server running on port ${PORT}`);
    console.log(`📍 Health check: http://localhost:${PORT}/health`);
    console.log(`🔗 Proxy endpoint: http://localhost:${PORT}/proxy?url=<TARGET_URL>`);
});
EOF

# Install Node.js dependencies
echo "📦 Installing Node.js dependencies..."
npm init -y
npm install express http-proxy-middleware cors

# Create systemd service
echo "⚙️ Creating systemd service..."
cat > /etc/systemd/system/bluex-proxy.service << 'EOF'
[Unit]
Description=BlueX Browser Proxy Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/bluex-proxy
ExecStart=/usr/bin/node proxy-server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx reverse proxy
echo "🔧 Configuring Nginx..."
cat > /etc/nginx/sites-available/bluex-proxy << 'EOF'
server {
    listen 80;
    server_name _;

    location /health {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /proxy {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/bluex-proxy /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Configure firewall
echo "🔥 Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 8080/tcp
ufw --force enable

# Enable and start services
echo "🚀 Starting services..."
systemctl daemon-reload
systemctl enable bluex-proxy
systemctl start bluex-proxy
systemctl restart nginx

# Check service status
echo "✅ Checking service status..."
systemctl status bluex-proxy --no-pager
systemctl status nginx --no-pager

echo ""
echo "🎉 BlueX Proxy Server setup complete!"
echo ""
echo "📋 Server Information:"
echo "  - Proxy Port: 8080"
echo "  - Health Check: http://YOUR_SERVER_IP/health"
echo "  - Proxy Endpoint: http://YOUR_SERVER_IP/proxy?url=TARGET_URL"
echo ""
echo "🔐 Authentication:"
echo "  - Username: bluex_user"
echo "  - Password: BlueXProxy2024!"
echo ""
echo "📝 To test the proxy:"
echo "  curl 'http://YOUR_SERVER_IP/proxy?url=https://google.com' -H 'X-Proxy-Auth: Ymx1ZXhfdXNlcjpCbHVlWFByb3h5MjAyNCE='"
echo ""