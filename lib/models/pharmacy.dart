class PrescriptionItem {
  const PrescriptionItem({
    required this.medicationCode,
    required this.genericName,
    required this.strength,
    required this.doseForm,
    required this.quantity,
    required this.instructions,
    this.brandName,
    this.substitutionAllowed = true,
  });

  final String medicationCode;
  final String genericName;
  final String? brandName;
  final String strength;
  final String doseForm;
  final int quantity;
  final String instructions;
  final bool substitutionAllowed;
}

class PharmacyOffer {
  const PharmacyOffer({
    required this.pharmacyId,
    required this.pharmacyName,
    required this.medicationCode,
    required this.genericName,
    required this.strength,
    required this.doseForm,
    required this.availableQuantity,
    required this.price,
    required this.currency,
    required this.updatedAt,
    this.brandName,
    this.requiresPharmacistReview = false,
  });

  final String pharmacyId;
  final String pharmacyName;
  final String medicationCode;
  final String genericName;
  final String? brandName;
  final String strength;
  final String doseForm;
  final int availableQuantity;
  final num price;
  final String currency;
  final DateTime updatedAt;
  final bool requiresPharmacistReview;
}

class PharmacyMatch {
  const PharmacyMatch({
    required this.offer,
    required this.isExact,
    required this.reason,
  });

  final PharmacyOffer offer;
  final bool isExact;
  final String reason;
}
