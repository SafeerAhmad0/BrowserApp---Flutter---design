@echo off
echo 🚀 BlueX Browser VPS Proxy Setup
echo ===============================
echo.

echo 📡 Setting up SECURE proxy on Tokyo server (108.160.139.37)...
echo Enter password when prompted: +Vu9e*]F==5n%-oT
ssh root@108.160.139.37 "apt update -y && apt install -y squid apache2-utils && systemctl stop squid && cat > /etc/squid/squid.conf << 'EOF'
# BlueX Browser SECURE Proxy Configuration
http_port 3128
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm BlueX Browser Secure Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
forwarded_for delete
via off
cache deny all
dns_nameservers 8.8.8.8 8.8.4.4 1.1.1.1
access_log none
cache_store_log none
EOF
htpasswd -cb /etc/squid/passwd root 'BlueX@2024#Secure' && chown proxy:proxy /etc/squid/passwd && chmod 640 /etc/squid/passwd && systemctl start squid && systemctl enable squid && ufw --force reset && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw allow 3128 && ufw --force enable"

echo.
echo 📡 Setting up SECURE proxy on Singapore server (45.76.145.170)...
echo Enter password when prompted: nZ@3oP(tp%XS9(,p
ssh root@45.76.145.170 "apt update -y && apt install -y squid apache2-utils && systemctl stop squid && cat > /etc/squid/squid.conf << 'EOF'
# BlueX Browser SECURE Proxy Configuration
http_port 3128
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm BlueX Browser Secure Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all
forwarded_for delete
via off
cache deny all
dns_nameservers 8.8.8.8 8.8.4.4 1.1.1.1
access_log none
cache_store_log none
EOF
htpasswd -cb /etc/squid/passwd root 'BlueX@2024#Secure' && chown proxy:proxy /etc/squid/passwd && chmod 640 /etc/squid/passwd && systemctl start squid && systemctl enable squid && ufw --force reset && ufw default deny incoming && ufw default allow outgoing && ufw allow ssh && ufw allow 3128 && ufw --force enable"

echo.
echo ✅ Setup complete! Testing connections...
echo.

echo 🧪 Testing Tokyo proxy...
curl -x 108.160.139.37:3128 --connect-timeout 10 https://httpbin.org/ip

echo.
echo 🧪 Testing Singapore proxy...
curl -x 45.76.145.170:3128 --connect-timeout 10 https://httpbin.org/ip

echo.
echo 🎉 If you see IP addresses above, your proxies are working!
echo 📱 Now test in your BlueX Browser app.
echo.
pause