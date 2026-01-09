import 'package:flutter/material.dart';
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

  AuthProvider() {
    _apiService.onTokenExpired = regenerateToken;
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

  void logout() {
    _user = null;
    _token = null;
    _cachedEmail = null;
    _cachedPassword = null;
    _apiService.setToken(null);
    notifyListeners();
  }
}
