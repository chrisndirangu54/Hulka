import '../models/pharmacy.dart';

class PharmacyMatchingService {
  const PharmacyMatchingService();

  List<PharmacyMatch> match(
    PrescriptionItem prescribed,
    Iterable<PharmacyOffer> offers,
  ) {
    final matches = <PharmacyMatch>[];

    for (final offer in offers) {
      final exactCode = offer.medicationCode == prescribed.medicationCode;
      final sameGeneric =
          offer.genericName.toLowerCase() == prescribed.genericName.toLowerCase();
      final sameStrength =
          offer.strength.toLowerCase() == prescribed.strength.toLowerCase();
      final sameForm =
          offer.doseForm.toLowerCase() == prescribed.doseForm.toLowerCase();

      if (exactCode && sameStrength && sameForm) {
        matches.add(PharmacyMatch(
          offer: offer,
          isExact: true,
          reason: 'Exact prescribed medicine and formulation.',
        ));
        continue;
      }

      if (prescribed.substitutionAllowed &&
          sameGeneric &&
          sameStrength &&
          sameForm) {
        matches.add(PharmacyMatch(
          offer: offer,
          isExact: false,
          reason:
              'Generic-equivalent candidate; pharmacist review is required before substitution.',
        ));
      }
    }

    matches.sort((a, b) {
      if (a.isExact != b.isExact) return a.isExact ? -1 : 1;
      return a.offer.price.compareTo(b.offer.price);
    });
    return matches;
  }
}
