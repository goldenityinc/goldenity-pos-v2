// ignore_for_file: constant_identifier_names

enum UserRole {
  SUPER_ADMIN,
  TENANT_ADMIN,
  CASHIER,
  CRM_STAFF,
  WORKSHOP_ADMIN,
  ACCOUNTANT,
}

class UserProfile {
  final String id;
  final String username;
  final UserRole role;
  final String tenantId;
  final String? branchId;

  const UserProfile({
    required this.id,
    required this.username,
    required this.role,
    required this.tenantId,
    this.branchId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'] as String? ?? '';
    final matched = UserRole.values.firstWhere(
      (r) => r.name == rawRole,
      orElse: () => UserRole.CASHIER,
    );
    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: matched,
      tenantId: json['tenantId'] as String? ?? '',
      branchId: json['branchId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role.name,
        'tenantId': tenantId,
        'branchId': branchId,
      };
}
