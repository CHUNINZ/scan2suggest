class ApiConfig {
  
  // ========================================
  // 🔧 CHANGE THIS IP ADDRESS WHEN SWITCHING WIFI NETWORKS
  // ========================================
  static const String BACKEND_IP = '192.168.194.185'; // <-- UPDATE THIS IP ONLY
  static const String BACKEND_PORT = '3000';
  
  // Primary backend URL (constructed from IP above)
  static String get primaryBackendUrl => 'http://$BACKEND_IP:$BACKEND_PORT/api';
  
  // Multiple possible server addresses - the app will try each one
  static List<String> get possibleBaseUrls => [
    primaryBackendUrl, // Primary IP from above
    'http://10.0.2.2:$BACKEND_PORT/api', // Android emulator host
    'http://localhost:$BACKEND_PORT/api', // iOS simulator
    'http://192.168.194.185:$BACKEND_PORT/api', // Alternative IP
    'http://192.168.194.169:$BACKEND_PORT/api', // Device subnet with common host
    'http://192.168.192.39:$BACKEND_PORT/api', // Device subnet range
    'http://192.168.192.105:$BACKEND_PORT/api', // Device subnet range
    'http://192.168.0.105:$BACKEND_PORT/api',  // Previous WiFi
    'http://192.168.1.105:$BACKEND_PORT/api',  // Common router IP range
  ];
  
  // Current working base URL (will be set after connection test)
  static String baseUrl = '';
  
  // Initialize baseUrl with primary URL if empty
  static void _initializeBaseUrl() {
    if (baseUrl.isEmpty) {
      baseUrl = primaryBackendUrl;
      if (enableLogging) {
        print('🔧 Initialized baseUrl to: $baseUrl');
      }
    }
  }
  
  // Ensure baseUrl is always initialized
  static String get safeBaseUrl {
    _initializeBaseUrl();
    return baseUrl;
  }
  
  // API timeout settings
  static const Duration timeout = Duration(seconds: 10);
  static const Duration connectionTimeout = Duration(seconds: 5);
  static const int maxRetries = 3;
  
  // Development settings
  static const bool isDevelopment = true;
  static const bool enableLogging = true;
  
  // Get the full API URL for a given endpoint
  static String getUrl(String endpoint) {
    _initializeBaseUrl();
    return '$baseUrl/$endpoint';
  }
  
  // Update the base URL when a working one is found
  static void setWorkingBaseUrl(String workingUrl) {
    baseUrl = workingUrl;
    if (enableLogging) {
      print('✅ Using API base URL: $baseUrl');
    }
  }
  
  // ========================================
  // 📝 INSTRUCTIONS FOR CHANGING WIFI NETWORKS:
  // ========================================
  // 1. Find your backend server's new IP address
  // 2. Update the BACKEND_IP constant above (line 6)
  // 3. Save this file
  // 4. Restart the app
  // 
  // That's it! All API calls will automatically use the new IP address.
  // ========================================
}
