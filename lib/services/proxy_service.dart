import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProxyServer {
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String location;

  ProxyServer({
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'location': location,
  };

  factory ProxyServer.fromJson(Map<String, dynamic> json) => ProxyServer(
    name: json['name'],
    host: json['host'],
    port: json['port'],
    username: json['username'],
    password: json['password'],
    location: json['location'],
  );
}

class ProxyService {
  static final ProxyService _instance = ProxyService._internal();
  factory ProxyService() => _instance;
  ProxyService._internal();

  static const String _proxyEnabledKey = 'proxy_enabled';
  static const String _selectedServerKey = 'selected_proxy_server';

  bool _isProxyEnabled = true; // ALWAYS ENABLED BY DEFAULT
  ProxyServer? _selectedServer;

  // Your VPS servers
  final List<ProxyServer> _servers = [
    ProxyServer(
      name: 'Tokyo Server',
      host: '108.160.139.37',
      port: 3128, // Standard Squid proxy port
      username: 'root',
      password: 'BlueX@2024#Secure', // Updated to secure password
      location: 'Tokyo, Japan',
    ),
    ProxyServer(
      name: 'Singapore Server',
      host: '45.76.145.170',
      port: 3128, // Standard Squid proxy port
      username: 'root',
      password: 'BlueX@2024#Secure', // Updated to secure password
      location: 'Singapore',
    ),
  ];

  List<ProxyServer> get servers => _servers;
  bool get isProxyEnabled => _isProxyEnabled;
  ProxyServer? get selectedServer => _selectedServer;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isProxyEnabled = prefs.getBool(_proxyEnabledKey) ?? true; // DEFAULT TO TRUE

    final serverIndex = prefs.getInt(_selectedServerKey) ?? 0;
    if (serverIndex < _servers.length) {
      _selectedServer = _servers[serverIndex];
    } else {
      _selectedServer = _servers.first; // DEFAULT TO TOKYO SERVER
    }

    // FORCE ENABLE PROXY ON FIRST RUN
    if (!prefs.containsKey(_proxyEnabledKey)) {
      await setProxyEnabled(true);
    }

    // DEBUG: Print initialization status
    print('🔧 PROXY SERVICE INITIALIZED:');
    print('   Proxy Enabled: $_isProxyEnabled');
    print('   Selected Server: ${_selectedServer?.name} (${_selectedServer?.host}:${_selectedServer?.port})');
    print('   Available Servers: ${_servers.length}');
  }

  Future<void> setProxyEnabled(bool enabled) async {
    _isProxyEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proxyEnabledKey, enabled);
  }

  Future<void> selectServer(ProxyServer server) async {
    _selectedServer = server;
    final serverIndex = _servers.indexOf(server);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedServerKey, serverIndex);
  }

  // Check if a website is blocked and needs proxy
  bool isWebsiteBlocked(String url) {
    final blockedDomains = [
      'facebook.com',
      'twitter.com',
      'instagram.com',
      'youtube.com',
      'tiktok.com',
      'telegram.org',
      'whatsapp.com',
      'linkedin.com',
      'reddit.com',
      'tumblr.com',
      'pinterest.com',
      'snapchat.com',
      'discord.com',
      'twitch.tv',
      'xhamster.com', // I see this in your logs
      'pornhub.com',
      'xvideos.com',
      'github.com', // Adding for testing
      'stackoverflow.com', // Adding for testing
    ];

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final domain = uri.host.toLowerCase();
    final isBlocked = blockedDomains.any((blocked) =>
      domain.contains(blocked) || domain.endsWith('.$blocked'));

    // DEBUG: Print to console for testing
    print('🔍 PROXY CHECK: $url');
    print('   Domain: $domain');
    print('   Blocked: $isBlocked');
    print('   Proxy Enabled: $_isProxyEnabled');

    return isBlocked;
  }

  // Get proxy URL for HTTP requests
  String? getProxyUrl() {
    if (!_isProxyEnabled || _selectedServer == null) return null;
    return 'http://${_selectedServer!.username}:${_selectedServer!.password}@${_selectedServer!.host}:${_selectedServer!.port}';
  }

  // Make HTTP request through VPS proxy
  Future<String?> fetchWithProxy(String url) async {
    if (!_isProxyEnabled || _selectedServer == null) {
      // Direct request
      try {
        final response = await http.get(Uri.parse(url));
        return response.body;
      } catch (e) {
        print('❌ DIRECT REQUEST FAILED: $e');
        return null;
      }
    }

    print('🔥 FETCHING WITH PROXY: $url via ${_selectedServer!.host}:${_selectedServer!.port}');

    try {
      // Use HttpClient with HTTP proxy (this is the correct method for Squid proxy)
      final client = HttpClient();

      // Set VPS proxy - use HTTP proxy format for Squid with authentication
      client.findProxy = (Uri uri) {
        return "PROXY ${_selectedServer!.host}:${_selectedServer!.port}";
      };

      // Set proxy authentication
      client.addProxyCredentials(
        _selectedServer!.host,
        _selectedServer!.port,
        'BlueX Browser Secure Proxy', // Realm from squid.conf
        HttpClientBasicCredentials(_selectedServer!.username, _selectedServer!.password),
      );

      // Add timeout
      client.connectionTimeout = const Duration(seconds: 15);
      client.idleTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      request.headers.set('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      request.headers.set('Accept-Language', 'en-US,en;q=0.5');
      request.headers.set('Accept-Encoding', 'gzip, deflate');

      final response = await request.close();

      print('🌐 PROXY RESPONSE STATUS: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        client.close();
        print('✅ PROXY FETCH SUCCESS: ${body.length} characters');
        return body;
      } else {
        print('❌ PROXY RESPONSE ERROR: ${response.statusCode}');
        client.close();
      }
    } catch (e) {
      print('❌ PROXY FETCH FAILED: $e');
    }

    // Fallback to direct request
    print('🔄 FALLING BACK TO DIRECT REQUEST');
    try {
      final response = await http.get(Uri.parse(url));
      print('📡 DIRECT FALLBACK SUCCESS: ${response.statusCode}');
      return response.body;
    } catch (e) {
      print('❌ DIRECT FALLBACK FAILED: $e');
      return null;
    }
  }

  // Get proxy bridge URL for routing through VPS
  String? getProxyBridgeUrl(String originalUrl) {
    if (!_isProxyEnabled || _selectedServer == null) return null;

    try {
      final encoded = Uri.encodeComponent(originalUrl);
      // Use a simple proxy bridge approach through your VPS
      return 'http://${_selectedServer!.host}/proxy?url=$encoded';
    } catch (e) {
      return null;
    }
  }

  // Test proxy connection
  Future<bool> testProxyConnection(ProxyServer server) async {
    try {
      // First test if server responds at all
      final directTest = await http.get(
        Uri.parse('http://${server.host}'),
        headers: {'User-Agent': 'BlueX-Browser/1.0'},
      ).timeout(const Duration(seconds: 5));

      // If server responds, try different proxy ports
      final testPorts = [3128, 8080, 80, 8888, 1080];

      for (final port in testPorts) {
        try {
          final client = HttpClient();
          client.findProxy = (Uri uri) {
            return "PROXY ${server.host}:$port";
          };

          final request = await client.getUrl(Uri.parse('https://httpbin.org/ip'));
          final response = await request.close();

          if (response.statusCode == 200) {
            // Update the working port
            final updatedServer = ProxyServer(
              name: server.name,
              host: server.host,
              port: port,
              username: server.username,
              password: server.password,
              location: server.location,
            );

            client.close();
            return true;
          }
          client.close();
        } catch (e) {
          // Try next port
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Get current IP address (for testing)
  Future<String?> getCurrentIP() async {
    try {
      // Use our proxy fetch method
      final body = await fetchWithProxy('https://httpbin.org/ip');
      if (body != null) {
        final data = json.decode(body);
        return data['origin'];
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }

  // WebView proxy configuration
  Map<String, dynamic>? getWebViewProxyConfig() {
    if (!_isProxyEnabled || _selectedServer == null) return null;

    return {
      'proxyType': 'HTTP',
      'proxyHost': _selectedServer!.host,
      'proxyPort': _selectedServer!.port,
      'proxyUsername': _selectedServer!.username,
      'proxyPassword': _selectedServer!.password,
    };
  }
}