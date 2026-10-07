import 'package:flutter_test/flutter_test.dart';
import 'package:hulka/models/pharmacy.dart';
import 'package:hulka/services/pharmacy_matching_service.dart';

void main() {
  test('exact medication match ranks ahead of generic candidate', () {
    const item = PrescriptionItem(
      medicationCode: 'RX1',
      genericName: 'Examplemol',
      strength: '10 mg',
      doseForm: 'tablet',
      quantity: 10,
      instructions: 'Once daily',
    );
    final offers = [
      PharmacyOffer(
        pharmacyId: 'p2',
        pharmacyName: 'B',
        medicationCode: 'GEN',
        genericName: 'Examplemol',
        strength: '10 mg',
        doseForm: 'tablet',
        availableQuantity: 20,
        price: 5,
        currency: 'KES',
        updatedAt: DateTime(2026),
      ),
      PharmacyOffer(
        pharmacyId: 'p1',
        pharmacyName: 'A',
        medicationCode: 'RX1',
        genericName: 'Examplemol',
        strength: '10 mg',
        doseForm: 'tablet',
        availableQuantity: 20,
        price: 10,
        currency: 'KES',
        updatedAt: DateTime(2026),
      ),
    ];

    final matches = const PharmacyMatchingService().match(item, offers);
    expect(matches.first.isExact, isTrue);
  });
}
