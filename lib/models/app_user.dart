import '../core/health_domain.dart';

class AppUser {
  const AppUser({required this.id, required this.email, required this.displayName, required this.role, this.organizationId, this.verified = false});
  final String id;
  final String email;
  final String displayName;
  final HulkaRole role;
  final String? organizationId;
  final bool verified;

  factory AppUser.fromJson(String id, Map<String, dynamic> json) => AppUser(
    id: id,
    email: (json['email'] as String?) ?? '',
    displayName: (json['displayName'] as String?) ?? '',
    role: HulkaRole.values.firstWhere((r) => r.name == json['role'], orElse: () => HulkaRole.patient),
    organizationId: json['organizationId'] as String?,
    verified: json['verified'] == true,
  );
}
