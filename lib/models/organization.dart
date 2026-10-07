enum OrganizationType { hospital, clinic, pharmacy, laboratory, insurer, research }

class HealthcareOrganization {
  const HealthcareOrganization({
    required this.id,
    required this.name,
    required this.type,
    required this.countryCode,
    this.facilityCode,
    this.verified = false,
  });

  final String id;
  final String name;
  final OrganizationType type;
  final String countryCode;
  final String? facilityCode;
  final bool verified;
}
