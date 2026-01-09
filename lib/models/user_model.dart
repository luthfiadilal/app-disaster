class UserModel {
  final int? id;
  final String username;
  final String fullName;
  final String email;
  final String? password;
  final String phoneNumber;
  final String gender;
  final String address;
  final String city;
  final String? accountStatus;
  final String? role;
  final String? createdAt;
  final String? avatarUrl;

  UserModel({
    this.id,
    required this.username,
    required this.fullName,
    required this.email,
    this.password,
    required this.phoneNumber,
    required this.gender,
    required this.address,
    required this.city,
    this.accountStatus,
    this.role,
    this.createdAt,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      email: json['email'],
      password:
          json['password'], // Usually not returned for security, but just in case
      phoneNumber: json['phone_number'],
      gender: json['gender'],
      address: json['address'],
      city: json['city'],
      accountStatus: json['account_status'],
      role: json['role'],
      createdAt: json['created_at'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'full_name': fullName,
      'email': email,
      'password': password,
      'phone_number': phoneNumber,
      'gender': gender,
      'address': address,
      'city': city,
    };
  }
}
