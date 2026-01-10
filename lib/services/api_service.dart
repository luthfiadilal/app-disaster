import 'package:dio/dio.dart';
import '../models/disaster_category_model.dart';
import '../models/disaster_report_model.dart';
import '../models/region_risk_model.dart';

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

  // Get Categories
  Future<List<DisasterCategory>> getCategories() async {
    try {
      final response = await _dio.get('/disaster/categories');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DisasterCategory.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  // Get Posts (Restored)
  Future<List<dynamic>> getPosts() async {
    try {
      final response = await _dio.get('/posts');
      return response.data;
    } catch (e) {
      throw Exception('Failed to load posts: $e');
    }
  }

  // Create Disaster Report
  Future<bool> createDisasterReport(
    Map<String, dynamic> data,
    List<String> imagePaths,
  ) async {
    try {
      final formData = FormData.fromMap(data);

      for (var path in imagePaths) {
        formData.files.add(
          MapEntry(
            'images', // Changed from images[] to match backend upload.array('images')
            await MultipartFile.fromFile(path),
          ),
        );
      }

      final response = await _dio.post('/disaster', data: formData);

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to create report: $e',
      );
    }
  }

  // Get Profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('Failed to load profile');
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to load profile');
    }
  }

  // Update Profile
  Future<Response> updateProfile(
    Map<String, dynamic> data,
    String? imagePath,
  ) async {
    try {
      final formData = FormData.fromMap(data);

      if (imagePath != null && imagePath.isNotEmpty) {
        formData.files.add(
          MapEntry('avatar', await MultipartFile.fromFile(imagePath)),
        );
      }

      final response = await _dio.put('/users/profile', data: formData);
      return response;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to update profile',
      );
    }
  }

  // --- Category Management (Admin) ---

  // Create Category
  Future<bool> createCategory(String name, String? iconPath) async {
    try {
      final formData = FormData.fromMap({'name': name});

      if (iconPath != null && iconPath.isNotEmpty) {
        formData.files.add(
          MapEntry('icon', await MultipartFile.fromFile(iconPath)),
        );
      }

      final response = await _dio.post('/disaster/categories', data: formData);
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to create category',
      );
    }
  }

  // Update Category
  Future<bool> updateCategory(int id, String name, String? iconPath) async {
    try {
      final formData = FormData.fromMap({'name': name});

      if (iconPath != null && iconPath.isNotEmpty) {
        formData.files.add(
          MapEntry('icon', await MultipartFile.fromFile(iconPath)),
        );
      }

      final response = await _dio.put(
        '/disaster/categories/$id',
        data: formData,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to update category',
      );
    }
  }

  // Delete Category
  Future<bool> deleteCategory(int id) async {
    try {
      final response = await _dio.delete('/disaster/categories/$id');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to delete category',
      );
    }
  }

  // --- Disaster Report Management (Admin) ---

  // Get All Disaster Reports
  Future<List<DisasterReport>> getAllDisasterReports() async {
    try {
      final response = await _dio.get('/disaster');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DisasterReport.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to load disaster reports',
      );
    }
  }

  // --- Region Risk & Map ---

  // Get Region Risks
  Future<List<RegionRisk>> getRegionRisks() async {
    try {
      final response = await _dio.get('/disaster/risks');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => RegionRisk.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to load region risks',
      );
    }
  }

  // Get Reports by Region
  Future<List<DisasterReport>> getReportsByRegion(int regionId) async {
    try {
      final response = await _dio.get('/disaster/region/$regionId/reports');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => DisasterReport.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ??
            'Failed to load reports for region $regionId',
      );
    }
  }
}
