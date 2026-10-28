import 'charger_model.dart';

/// Returns only an identifier supplied by QR scanning or charger metadata.
/// A model name alone is not unique enough to scope an inspection to a charger.
String? chargerIdentityKey(ChargerModel? charger) {
  if (charger == null) return null;
  final serial = charger.serialNumber?.trim();
  if (serial != null && serial.isNotEmpty) return 'serial:$serial';
  final qr = charger.rawQrIdentifier?.trim();
  if (qr != null && qr.isNotEmpty) return 'qr:$qr';
  return null;
}

/// Returns the underlying real identifier value for API request contracts.
String? chargerIdentifierValue(ChargerModel? charger) {
  if (charger == null) return null;
  final serial = charger.serialNumber?.trim();
  if (serial != null && serial.isNotEmpty) return serial;
  final qr = charger.rawQrIdentifier?.trim();
  if (qr != null && qr.isNotEmpty) return qr;
  return null;
}
