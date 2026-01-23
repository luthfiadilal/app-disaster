import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/auth_response_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  UserModel? _user;
  UserModel? get user => _user;

  String? _token;
  String? get token => _token;

  // Store credentials for auto-login (regenerate token)
  String? _cachedEmail;
  String? _cachedPassword;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // SharedPreferences keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _emailKey = 'cached_email';
  static const String _passwordKey = 'cached_password';

  AuthProvider() {
    _apiService.onTokenExpired = regenerateToken;
  }

  /// Initialize auth state from persistent storage
  Future<void> initializeAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load token
      _token = prefs.getString(_tokenKey);

      // Load user data using JSON
      final userJson = prefs.getString(_userKey);
      if (userJson != null && userJson.isNotEmpty) {
        try {
          final userMap = jsonDecode(userJson) as Map<String, dynamic>;
          _user = UserModel.fromJson(userMap);
          debugPrint('[AuthProvider] User loaded: ${_user!.email}');
        } catch (e) {
          debugPrint('[AuthProvider] Error parsing user data: $e');
          // Clear corrupted data
          await prefs.remove(_userKey);
        }
      }

      // Load cached credentials
      _cachedEmail = prefs.getString(_emailKey);
      _cachedPassword = prefs.getString(_passwordKey);

      // Set token in API service if available
      if (_token != null) {
        _apiService.setToken(_token);
        debugPrint(
          '[AuthProvider] Token loaded from storage: ${_token?.substring(0, 10)}...',
        );
      } else {
        debugPrint('[AuthProvider] No token found in storage');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Error initializing auth: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Save auth data to persistent storage
  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
        debugPrint(
          '[AuthProvider] Token saved: ${_token!.substring(0, 10)}...',
        );
      }

      if (_user != null) {
        // Use JSON encoding for proper serialization
        final userMap = _user!.toJson();
        final userString = jsonEncode(userMap);
        await prefs.setString(_userKey, userString);
        debugPrint('[AuthProvider] User data saved: ${_user!.email}');
      }

      if (_cachedEmail != null) {
        await prefs.setString(_emailKey, _cachedEmail!);
      }

      if (_cachedPassword != null) {
        await prefs.setString(_passwordKey, _cachedPassword!);
      }

      debugPrint('[AuthProvider] Auth data saved to storage successfully');
    } catch (e) {
      debugPrint('[AuthProvider] Error saving auth data: $e');
    }
  }

  /// Clear auth data from persistent storage
  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_emailKey);
      await prefs.remove(_passwordKey);
      debugPrint('Auth data cleared from storage');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }

  /// Attempts to re-login using cached credentials to get a new token.
  Future<String?> regenerateToken() async {
    if (_cachedEmail != null && _cachedPassword != null) {
      try {
        // Call login API silently
        final response = await _apiService.login(
          _cachedEmail!,
          _cachedPassword!,
        );
        final authResponse = AuthResponseModel.fromJson(response.data);

        if (authResponse.success && authResponse.token != null) {
          _token = authResponse.token;
          _apiService.setToken(_token);
          notifyListeners();
          return _token;
        }
      } catch (e) {
        // Re-login failed
        debugPrint('Token regeneration failed: $e');
        return null;
      }
    }
    return null;
  }

  Future<bool> register(UserModel userModel) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.register(userModel.toJson());
      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success) {
        _user = authResponse.user;
        _token = authResponse.token;
        _apiService.setToken(_token);

        // Cache credentials if available
        _cachedEmail = userModel.email;
        _cachedPassword = userModel.password;

        // Save to persistent storage
        await _saveAuthData();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);
      final authResponse = AuthResponseModel.fromJson(response.data);

      if (authResponse.success) {
        _user = authResponse.user;
        _token = authResponse.token;
        _apiService.setToken(_token);

        // Cache credentials
        _cachedEmail = email;
        _cachedPassword = password;

        // Save to persistent storage
        await _saveAuthData();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _cachedEmail = null;
    _cachedPassword = null;
    _apiService.setToken(null);

    // Clear from persistent storage
    await _clearAuthData();

    notifyListeners();
  }

  /// Fetches the latest user profile data
  Future<void> fetchProfile() async {
    try {
      final userData = await _apiService.getProfile();
      _user = UserModel.fromJson(userData);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      rethrow;
    }
  }

  /// Updates user profile
  Future<bool> updateProfile(
    Map<String, dynamic> data,
    String? imagePath,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.updateProfile(data, imagePath);

      if (response.statusCode == 200) {
        // Refresh profile data after successful update
        await fetchProfile();

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
