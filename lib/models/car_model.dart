class CarModel {
  final String? id;
  final String make;
  final String model;
  final double price;
  final String fuelType;
  final int engineCC;
  final bool isEV;
  final double fuelConsumption;
  final double motorPower;
  final String? imageUrl;
  final int? year;
  final String? transmission;
  final String? bodyType;

  CarModel({
    this.id,
    required this.make,
    required this.model,
    required this.price,
    required this.fuelType,
    required this.engineCC,
    this.isEV = false,
    this.fuelConsumption = 6.0,
    this.motorPower = 0.0,
    this.imageUrl,
    this.year,
    this.transmission,
    this.bodyType,
  });

  String get fullName {
    if (model.toLowerCase().startsWith(make.toLowerCase())) {
      return model;
    }
    return '$make $model';
  }

  factory CarModel.fromJson(Map<String, dynamic> json) {
    final rawIsEV = json['isEV'] ?? json['is_ev'] ?? false;
    final isEvBool = rawIsEV is bool ? rawIsEV : (rawIsEV.toString().toLowerCase() == 'true');
    final fuel = json['fuelType'] ?? json['fuel_type'] ?? (isEvBool ? 'EV' : 'Petrol');

    return CarModel(
      id: json['id']?.toString(),
      make: json['make']?.toString() ?? 'Unknown',
      model: json['model']?.toString() ?? 'Unknown',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      fuelType: fuel.toString(),
      engineCC: (json['engineCC'] ?? json['engine_cc'] as num?)?.toInt() ?? 0,
      isEV: isEvBool,
      fuelConsumption: (json['fuelConsumption'] ?? json['fuel_consumption'] as num?)?.toDouble() ?? (isEvBool ? 15.0 : 6.0),
      motorPower: (json['motorPower'] ?? json['motor_power'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      year: (json['year'] as num?)?.toInt(),
      transmission: json['transmission']?.toString(),
      bodyType: json['bodyType'] ?? json['body_type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'make': make,
      'model': model,
      'price': price,
      'fuelType': fuelType,
      'engineCC': engineCC,
      'isEV': isEV,
      'fuelConsumption': fuelConsumption,
      'motorPower': motorPower,
      'imageUrl': imageUrl,
      'year': year,
      'transmission': transmission,
      'bodyType': bodyType,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'make': make,
      'model': model,
      'price': price,
      'fuel_type': fuelType,
      'engine_cc': engineCC,
      'is_ev': isEV,
      'fuel_consumption': fuelConsumption,
      'image_url': imageUrl,
    };
  }

  CarModel copyWith({
    String? id,
    String? make,
    String? model,
    double? price,
    String? fuelType,
    int? engineCC,
    bool? isEV,
    double? fuelConsumption,
    double? motorPower,
    String? imageUrl,
    int? year,
    String? transmission,
    String? bodyType,
  }) {
    return CarModel(
      id: id ?? this.id,
      make: make ?? this.make,
      model: model ?? this.model,
      price: price ?? this.price,
      fuelType: fuelType ?? this.fuelType,
      engineCC: engineCC ?? this.engineCC,
      isEV: isEV ?? this.isEV,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      motorPower: motorPower ?? this.motorPower,
      imageUrl: imageUrl ?? this.imageUrl,
      year: year ?? this.year,
      transmission: transmission ?? this.transmission,
      bodyType: bodyType ?? this.bodyType,
    );
  }
}
