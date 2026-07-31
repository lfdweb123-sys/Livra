enum UserRole { client, driver, vendor, admin }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'driver':
      return UserRole.driver;
    case 'vendor':
      return UserRole.vendor;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.client;
  }
}

class UserModel {
  final String uid;
  final UserRole role;
  final String phone;
  final String name;
  final String? email;
  final String? photoUrl;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.role,
    required this.phone,
    required this.name,
    this.email,
    this.photoUrl,
    this.isActive = true,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
        uid: uid,
        role: roleFromString(map['role']),
        phone: map['phone'] ?? '',
        name: map['name'] ?? '',
        email: map['email'],
        photoUrl: map['photoUrl'],
        isActive: map['isActive'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'role': role.name,
        'phone': phone,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'isActive': isActive,
      };
}
