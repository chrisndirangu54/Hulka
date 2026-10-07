class ConsentGrant {
  const ConsentGrant({
    required this.id,
    required this.patientId,
    required this.granteeId,
    required this.granteeType,
    required this.scopes,
    required this.purpose,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
  });

  final String id;
  final String patientId;
  final String granteeId;
  final String granteeType;
  final Set<String> scopes;
  final String purpose;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  bool get isActive {
    if (revokedAt != null) return false;
    if (expiresAt == null) return true;
    return expiresAt!.isAfter(DateTime.now());
  }

  bool allows(String scope) => isActive && scopes.contains(scope);

  Map<String, Object?> toJson() => {
        'id': id,
        'patientId': patientId,
        'granteeId': granteeId,
        'granteeType': granteeType,
        'scopes': scopes.toList()..sort(),
        'purpose': purpose,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
        'revokedAt': revokedAt?.toUtc().toIso8601String(),
      };
}
