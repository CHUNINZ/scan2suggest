import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/network_discovery.dart';

class ApiService {
  
  static String? _token;
  
  // Initialize token from storage
  static Future<void> initializeToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }
  
  // Test connection to backend with automatic network discovery
  static Future<bool> testConnection() async {
    if (ApiConfig.enableLogging) {
      print('🔍 Starting network discovery...');
    }
    
    // First try automatic network discovery
    try {
      String? discoveredUrl = await NetworkDiscovery.discoverBackendUrl();
      
      if (discoveredUrl != null) {
        ApiConfig.setWorkingBaseUrl(discoveredUrl);
        if (ApiConfig.enableLogging) {
          print('✅ Auto-discovered backend at: $discoveredUrl');
        }
        return true;
      }
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('⚠️ Network discovery failed, trying predefined URLs: $e');
      }
    }
    
    // Fallback to predefined URLs
    for (String testUrl in ApiConfig.possibleBaseUrls) {
      try {
        if (ApiConfig.enableLogging) {
          print('🔍 Testing connection to: $testUrl');
        }
        
        final response = await http.get(
          Uri.parse('$testUrl/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(ApiConfig.connectionTimeout);
        
        if (ApiConfig.enableLogging) {
          print('📡 Connection test response: ${response.statusCode}');
        }
        
        if (response.statusCode == 200) {
          ApiConfig.setWorkingBaseUrl(testUrl);
          return true;
        }
        
      } catch (e) {
        if (ApiConfig.enableLogging) {
          print('❌ Connection test failed for $testUrl: $e');
        }
        continue;
      }
    }
    
    if (ApiConfig.enableLogging) {
      print('❌ All connection attempts failed');
    }
    return false;
  }
  
  // Save token to storage
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
  }
  
  // Clear token from storage
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
  }
  
  // Get headers with authentication
  static Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  // Get headers for multipart requests
  static Map<String, String> _getMultipartHeaders() {
    final headers = <String, String>{};
    
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    
    return headers;
  }
  
  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (ApiConfig.enableLogging) {
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');
    }
    
    try {
      final data = json.decode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      } else {
        String errorMessage = data['message'] ?? 'An error occurred';
        
        // Handle specific error cases with user-friendly messages
        if (response.statusCode == 400) {
          if (errorMessage.toLowerCase().contains('validation')) {
            errorMessage = 'Please check your input and try again';
          } else if (errorMessage.toLowerCase().contains('email')) {
            errorMessage = 'Please enter a valid email address';
          }
          // Keep original message for other 400 errors
        } else if (response.statusCode == 401) {
          // Keep original message for incorrect password
        } else if (response.statusCode == 404) {
          // Keep original message for account not found
        } else if (response.statusCode == 500) {
          errorMessage = 'Server error. Please try again later';
        }
        
        throw ApiException(
          message: errorMessage,
          statusCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      
      throw ApiException(
        message: 'Failed to parse server response: $e',
        statusCode: response.statusCode,
        errors: null,
      );
    }
  }
  
  // Authentication APIs
  
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    if (ApiConfig.enableLogging) {
      print('🔐 Attempting login for: $email');
    }
    
    // Ensure we have a working connection before attempting login
    bool connectionEstablished = await testConnection();
    if (!connectionEstablished) {
      throw ApiException(
        message: 'Unable to connect to server. Please check your internet connection.',
        statusCode: 0,
        errors: null,
      );
    }
    
    if (ApiConfig.enableLogging) {
      print('🌐 API URL: ${ApiConfig.safeBaseUrl}/auth/login');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/login'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.timeout);
      
      final data = _handleResponse(response);
      
      if (data['token'] != null) {
        await saveToken(data['token']);
        if (ApiConfig.enableLogging) {
          print('✅ Login successful, token saved');
        }
      }
      
      return data;
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('❌ Login error: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'code': code,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Email verified successfully',
          'token': data['token'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Email verification failed',
        };
      }
    } catch (e) {
      print('Email verification error: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
      };
    }
  }

  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/resend-verification'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
        }),
      );

      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Verification code sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to resend verification code',
        };
      }
    } catch (e) {
      print('Resend verification error: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
      };
    }
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (ApiConfig.enableLogging) {
      print('📝 Registering user: $email');
      print('🌐 API URL: ${ApiConfig.safeBaseUrl}/auth/register');
    }
    
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/register'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
        }),
      ).timeout(ApiConfig.timeout);
      
      final data = _handleResponse(response);
      
      if (ApiConfig.enableLogging) {
        print('✅ Registration successful');
      }
      
      // Save token if registration includes it
      if (data['token'] != null) {
        await saveToken(data['token']);
        if (ApiConfig.enableLogging) {
          print('✅ Registration token saved');
        }
      }
      
      return data;
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('❌ Registration error: $e');
      }
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      if (ApiConfig.enableLogging) {
        print('🔄 Sending forgot password request for: $email');
      }
      
      // Ensure we have a working connection
      bool connectionEstablished = await testConnection();
      if (!connectionEstablished) {
        throw ApiException(
          message: 'Unable to connect to server. Please check your internet connection.',
          statusCode: 0,
          errors: null,
        );
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/forgot-password'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({'email': email}),
      ).timeout(ApiConfig.timeout);

      if (ApiConfig.enableLogging) {
        print('📡 Forgot password response status: ${response.statusCode}');
        print('📡 Forgot password response body: ${response.body}');
      }

      final data = _handleResponse(response);
      
      if (ApiConfig.enableLogging) {
        print('✅ Forgot password request completed');
      }
      
      return data;
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('❌ Forgot password error: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> verifyResetCode(String email, String code, String newPassword) async {
    try {
      if (ApiConfig.enableLogging) {
        print('🔄 Verifying reset code for: $email');
      }
      
      final response = await http.post(
        Uri.parse('${ApiConfig.safeBaseUrl}/auth/verify-reset-code'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      ).timeout(ApiConfig.timeout);

      if (ApiConfig.enableLogging) {
        print('📡 Verify reset code response status: ${response.statusCode}');
        print('📡 Verify reset code response body: ${response.body}');
      }

      final data = _handleResponse(response);
      
      // Save token if provided
      if (data['token'] != null) {
        await saveToken(data['token']);
        if (ApiConfig.enableLogging) {
          print('✅ Password reset successful, token saved');
        }
      }
      
      return data;
    } catch (e) {
      if (ApiConfig.enableLogging) {
        print('❌ Verify reset code error: $e');
      }
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.safeBaseUrl}/auth/me'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> logout() async {
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/auth/logout'),
      headers: _getHeaders(),
    );
    
    await clearToken();
    return _handleResponse(response);
  }
  
  // User APIs
  static Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? bio,
    String? location,
    Map<String, dynamic>? preferences,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.safeBaseUrl}/users/profile'),
      headers: _getHeaders(),
      body: json.encode({
        'name': name,
        'bio': bio,
        'location': location,
        'preferences': preferences,
      }),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.safeBaseUrl}/users/upload-avatar'),
    );
    
    request.headers.addAll(_getMultipartHeaders());
    request.files.add(
      await http.MultipartFile.fromPath('profileImage', imageFile.path),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }
  
  // Recipe APIs
  static Future<Map<String, dynamic>> getRecipes({
    int page = 1,
    int limit = 10,
    String? category,
    String? difficulty,
    String? search,
    String? creatorId,
    String sort = 'createdAt',
    String order = 'desc',
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sort': sort,
      'order': order,
    };
    
    if (category != null) queryParams['category'] = category;
    if (difficulty != null) queryParams['difficulty'] = difficulty;
    if (search != null) queryParams['search'] = search;
    if (creatorId != null) queryParams['creator'] = creatorId;
    
    final uri = Uri.parse('${ApiConfig.safeBaseUrl}/recipes').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(uri, headers: _getHeaders(includeAuth: false));
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getRecipe(String recipeId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.safeBaseUrl}/recipes/$recipeId'),
      headers: _getHeaders(includeAuth: false),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> createRecipe({
    required String title,
    required String description,
    required String category,
    required String difficulty,
    required int prepTime,
    required int cookTime,
    required int servings,
    required List<Map<String, dynamic>> ingredients,
    required List<Map<String, dynamic>> instructions,
    List<File>? images,
    Map<String, dynamic>? nutrition,
    List<String>? tags,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.safeBaseUrl}/recipes'),
    );
    
    request.headers.addAll(_getMultipartHeaders());
    
    // Add text fields
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['category'] = category;
    request.fields['difficulty'] = difficulty;
    request.fields['prepTime'] = prepTime.toString();
    request.fields['cookTime'] = cookTime.toString();
    request.fields['servings'] = servings.toString();
    request.fields['ingredients'] = json.encode(ingredients);
    request.fields['instructions'] = json.encode(instructions);
    
    if (nutrition != null) {
      request.fields['nutrition'] = json.encode(nutrition);
    }
    
    if (tags != null) {
      request.fields['tags'] = json.encode(tags);
    }
    
    // Add image files
    if (images != null) {
      for (final image in images) {
        // Get file extension to determine mime type
        final extension = image.path.split('.').last.toLowerCase();
        String mimeType = 'image/jpeg'; // default
        
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (extension == 'gif') {
          mimeType = 'image/gif';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        }
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'recipeImages',
            image.path,
            contentType: MediaType.parse(mimeType),
          ),
        );
      }
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> likeRecipe(String recipeId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/recipes/$recipeId/like'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> bookmarkRecipe(String recipeId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/recipes/$recipeId/bookmark'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> rateRecipe({
    required String recipeId,
    required int rating,
    String? review,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/recipes/$recipeId/rate'),
      headers: _getHeaders(),
      body: json.encode({
        'rating': rating,
        'review': review,
      }),
    );
    
    return _handleResponse(response);
  }
  
  // Scanning APIs
  static Future<Map<String, dynamic>> analyzeImage({
    required File imageFile,
    required String scanType, // 'food' or 'ingredient'
  }) async {
    if (ApiConfig.enableLogging) {
      print('📤 Preparing image upload...');
      print('📂 Image path: ${imageFile.path}');
      print('📊 Image size: ${await imageFile.length()} bytes');
    }
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.getUrl('scan/analyze')}'),
    );
    
    request.headers.addAll(_getMultipartHeaders());
    request.fields['scanType'] = scanType;
    
    // Add image file with explicit MIME type
    final multipartFile = await http.MultipartFile.fromPath(
      'scanImage', 
      imageFile.path,
      contentType: MediaType('image', 'jpeg'), // Explicitly set MIME type
    );
    
    if (ApiConfig.enableLogging) {
      print('📎 Multipart file created:');
      print('  - Field name: ${multipartFile.field}');
      print('  - Filename: ${multipartFile.filename}');
      print('  - Content type: ${multipartFile.contentType}');
      print('  - Length: ${multipartFile.length}');
    }
    
    request.files.add(multipartFile);
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getScanResult(String scanId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/result/$scanId'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getScanHistory({
    int page = 1,
    int limit = 10,
    String? scanType,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    if (scanType != null) queryParams['scanType'] = scanType;
    
    final uri = Uri.parse('${ApiConfig.safeBaseUrl}/scan/history').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(uri, headers: _getHeaders());
    return _handleResponse(response);
  }

  // Confirm detection result and get recipe
  static Future<Map<String, dynamic>> confirmDetection({
    required String scanId,
    required String foodName,
    required bool isCorrect,
  }) async {
    if (ApiConfig.enableLogging) {
      print('✅ Confirming detection: $foodName (correct: $isCorrect)');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/confirm'),
      headers: _getHeaders(),
      body: json.encode({
        'scanId': scanId,
        'foodName': foodName,
        'isCorrect': isCorrect,
      }),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }

  // Manual food input when detection is wrong
  static Future<Map<String, dynamic>> manualFoodInput({
    required String foodName,
    String? scanId,
  }) async {
    if (ApiConfig.enableLogging) {
      print('✏️ Manual food input: $foodName');
    }
    
    final body = {'foodName': foodName};
    if (scanId != null) body['scanId'] = scanId;
    
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/manual-input'),
      headers: _getHeaders(),
      body: json.encode(body),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }

  // Get recipe for a specific food
  static Future<Map<String, dynamic>> getRecipeByName(String foodName) async {
    if (ApiConfig.enableLogging) {
      print('🍳 Getting recipe for: $foodName');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/recipe/${Uri.encodeComponent(foodName)}'),
      headers: _getHeaders(),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }

  // Ingredient scanning APIs
  static Future<Map<String, dynamic>> scanIngredients({
    required File imageFile,
  }) async {
    if (ApiConfig.enableLogging) {
      print('🥬 Scanning ingredients...');
      print('📂 Image path: ${imageFile.path}');
      print('📊 Image size: ${await imageFile.length()} bytes');
    }
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.getUrl('scan/ingredients')}'),
    );
    
    request.headers.addAll(_getMultipartHeaders());
    
    // Add image file
    final multipartFile = await http.MultipartFile.fromPath(
      'scanImage', 
      imageFile.path,
      contentType: MediaType('image', 'jpeg'),
    );
    
    request.files.add(multipartFile);
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    return _handleResponse(response);
  }

  // Get recipe suggestions based on ingredients
  static Future<Map<String, dynamic>> getRecipeSuggestions({
    required List<Map<String, dynamic>> ingredients,
  }) async {
    if (ApiConfig.enableLogging) {
      print('🍳 Getting recipe suggestions for ingredients: ${ingredients.map((i) => i['name']).join(', ')}');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/recipe-suggestions'),
      headers: _getHeaders(),
      body: json.encode({
        'ingredients': ingredients,
      }),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }

  // Get full recipe details for a suggested recipe
  static Future<Map<String, dynamic>> getRecipeDetails(String recipeName) async {
    if (ApiConfig.enableLogging) {
      print('📖 Getting recipe details for: $recipeName');
    }
    
    final response = await http.get(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/recipe-details/${Uri.encodeComponent(recipeName)}'),
      headers: _getHeaders(),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }

  // Generate shopping list for missing ingredients
  static Future<Map<String, dynamic>> generateShoppingList({
    required List<Map<String, dynamic>> selectedRecipes,
    required List<Map<String, dynamic>> userIngredients,
  }) async {
    if (ApiConfig.enableLogging) {
      print('🛒 Generating shopping list...');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/scan/shopping-list'),
      headers: _getHeaders(),
      body: json.encode({
        'selectedRecipes': selectedRecipes,
        'userIngredients': userIngredients,
      }),
    ).timeout(ApiConfig.timeout);
    
    return _handleResponse(response);
  }
  
  // Social APIs
  static Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.safeBaseUrl}/social/follow/$userId'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getSocialFeed({
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };
    
    final uri = Uri.parse('${ApiConfig.safeBaseUrl}/social/feed').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(uri, headers: _getHeaders());
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> getTrendingRecipes({
    int page = 1,
    int limit = 10,
    String timeframe = 'week',
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'timeframe': timeframe,
    };
    
    final uri = Uri.parse('${ApiConfig.safeBaseUrl}/social/trending').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(uri, headers: _getHeaders(includeAuth: false));
    return _handleResponse(response);
  }
  
  // Notification APIs
  static Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'unreadOnly': unreadOnly.toString(),
    };
    
    final uri = Uri.parse('${ApiConfig.safeBaseUrl}/notifications').replace(
      queryParameters: queryParams,
    );
    
    final response = await http.get(uri, headers: _getHeaders());
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.safeBaseUrl}/notifications/$notificationId/read'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
  
  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    final response = await http.put(
      Uri.parse('${ApiConfig.safeBaseUrl}/notifications/read-all'),
      headers: _getHeaders(),
    );
    
    return _handleResponse(response);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic errors;
  
  ApiException({
    required this.message,
    required this.statusCode,
    this.errors,
  });
  
  @override
  String toString() {
    return message;
  }
}
