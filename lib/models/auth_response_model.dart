import 'user_model.dart';

class AuthResponseModel {
  final bool success;
  final String message;
  final UserModel? user;
  final String? token;

  AuthResponseModel({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      success: json['success'],
      message: json['message'],
      user: json['data'] != null && json['data']['user'] != null
          ? UserModel.fromJson(json['data']['user'])
          : null,
      token: json['data'] != null ? json['data']['token'] : null,
    );
  }
}
