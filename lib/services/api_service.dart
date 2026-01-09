import 'package:dio/dio.dart';

class ApiService {
  final Dio _dio = Dio();

  // Base URL configuration
  final String baseUrl = 'https://api-gis.fidev.web.id/api';

  // Callback for token expiration (to be set by AuthProvider)
  Future<String?> Function()? onTokenExpired;
  String? _accessToken;

  ApiService() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 && onTokenExpired != null) {
            try {
              // Attempt to regenerate token
              final newToken = await onTokenExpired!();
              if (newToken != null) {
                // Update token
                setToken(newToken);
                // Update header for the retry
                e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                // Retry the request
                final response = await _dio.fetch(e.requestOptions);
                return handler.resolve(response);
              }
            } catch (error) {
              // If regeneration fails, continue with original error
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  void setToken(String? token) {
    _accessToken = token;
  }

  // Register User
  Future<Response> register(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/auth/register', data: data);
      return response;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Registration failed');
    }
  }

  // Login User
  Future<Response> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return response;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Login failed');
    }
  }

  // Get Posts (Keeping existing method for reference, can be removed if unused)
  Future<List<dynamic>> getPosts() async {
    try {
      final response = await _dio.get('/posts');
      return response.data;
    } catch (e) {
      throw Exception('Failed to load posts: $e');
    }
  }
}
