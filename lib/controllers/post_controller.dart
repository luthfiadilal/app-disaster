import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../services/api_service.dart';

class PostController extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Post> _posts = [];
  bool _isLoading = false;
  String? _error;

  List<Post> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchPosts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<dynamic> responseData = await _apiService.getPosts();
      _posts = responseData.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
