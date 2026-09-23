// lib/features/chargers/domain/models/charger_model.dart
class ChargerModel {
  final String? manufacturer;
  final String? model;
  final String? type;
  final String? serialNumber;
  final String? rawQrIdentifier;

  const ChargerModel({
    this.manufacturer,
    this.model,
    this.type,
    this.serialNumber,
    this.rawQrIdentifier,
  });

  factory ChargerModel.fromQrString(String qrData) {
    // Basic parsing logic. Assuming a format like:
    // "Manufacturer:BrandX;Model:ModelY;Type:TypeZ;Serial:12345"
    // If not matching, we just store it as raw identifier.
    final data = qrData.trim();
    String? manufacturer;
    String? model;
    String? type;
    String? serialNumber;
    bool hasRecognizedFields = false;

    if (data.contains(';') || data.contains(':')) {
      final parts = data.split(';');
      for (final part in parts) {
        if (part.contains(':')) {
          final keyValue = part.split(':');
          if (keyValue.length == 2) {
            final key = keyValue[0].trim().toLowerCase();
            final value = keyValue[1].trim();
            if (value.isNotEmpty) {
              if (key == 'manufacturer' || key == 'mfg') {
                manufacturer = value;
                hasRecognizedFields = true;
              } else if (key == 'model') {
                model = value;
                hasRecognizedFields = true;
              } else if (key == 'type') {
                type = value;
                hasRecognizedFields = true;
              } else if (key == 'serial' || key == 'sn') {
                serialNumber = value;
                hasRecognizedFields = true;
              }
            }
          }
        }
      }
    }

    if (hasRecognizedFields) {
      return ChargerModel(
        manufacturer: manufacturer,
        model: model,
        type: type,
        serialNumber: serialNumber,
        rawQrIdentifier: data,
      );
    } else {
      // If we couldn't parse structured info, we just treat the whole QR as a raw identifier
      return ChargerModel(rawQrIdentifier: data);
    }
  }

  bool get isRecognized =>
      manufacturer != null ||
      model != null ||
      type != null ||
      serialNumber != null;
}
