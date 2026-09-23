class ChargerModel {
  ChargerModel({
    required this.id,
    required this.manufacturer,
    required this.model,
    required this.location,
    required this.health,
    required this.status,
  });

  final String id;
  final String manufacturer;
  final String model;
  final String location;
  final int health;
  final String status;

  factory ChargerModel.demo() {
    return ChargerModel(
      id: 'CX-001',
      manufacturer: 'ABB',
      model: 'Terra 54',
      location: 'North Bay Hub',
      health: 94,
      status: 'Healthy',
    );
  }
}
