@echo off
echo Testing VPS Proxy Servers...
echo.

echo Testing Tokyo Server (108.160.139.37:3128)...
curl -x 108.160.139.37:3128 --connect-timeout 10 --max-time 30 https://httpbin.org/ip
echo.

echo Testing Singapore Server (45.76.145.170:3128)...
curl -x 45.76.145.170:3128 --connect-timeout 10 --max-time 30 https://httpbin.org/ip
echo.

echo Testing Direct Connection (no proxy)...
curl --connect-timeout 10 --max-time 30 https://httpbin.org/ip
echo.

echo Testing Google through Tokyo proxy...
curl -x 108.160.139.37:3128 --connect-timeout 10 --max-time 30 -s https://www.google.com | head -20
echo.

echo Testing Google through Singapore proxy...
curl -x 45.76.145.170:3128 --connect-timeout 10 --max-time 30 -s https://www.google.com | head -20
echo.

echo If you see HTML content above, your proxies are working!
echo If you see timeout or connection errors, your VPS needs proxy setup.
pause