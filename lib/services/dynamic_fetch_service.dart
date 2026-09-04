import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config_service.dart';
import '../models/car_model.dart';
import 'car_api_service.dart';

class DynamicFetchService {
  late final GenerativeModel _model;
  final CarApiService _carApiService = CarApiService();

  DynamicFetchService() {
    _model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: ConfigService.geminiApiKey,
    );
  }

  Future<CarModel?> fetchCarFromAI(String searchQuery) async {
    try {
      final prompt = '''
      You are a Malaysian car expert. 
      The user searched for "$searchQuery".
      Identify the real car being searched for and return a JSON object with its details.
      
      CRITICAL INSTRUCTION 1: YOU MUST BE EXTREMELY STRICT. If the user's search query "$searchQuery" is a joke, a metaphor, a random word, or does NOT explicitly name a real car brand or model (e.g. "little pony", "apple", "fastest thing"), YOU MUST REJECT IT and return EXACTLY this JSON:
      {"error": "not_a_car"}
      DO NOT guess metaphorical meanings. Only accept clear automotive queries.
      
      CRITICAL INSTRUCTION 2 FOR IMAGES:
      The `make` and `model` values you provide MUST exactly match the official English Wikipedia article title for the car.
      - For example, if the user searches "honda civic 1.5 turbo", you must return `make`: "Honda", `model`: "Civic". 
      - DO NOT include trims, engine sizes, years, or variants in the model name (e.g., NO "Axia 1.0 G", just "Axia").
      - This is because the app will automatically fetch the image from `https://en.wikipedia.org/wiki/{make}_{model}`.

      If it is a valid car, return ONLY valid JSON matching this structure:
      {
        "make": "String (e.g. Proton, Perodua, Honda, Toyota)",
        "model": "String (Wikipedia exact model name, e.g. X50, Myvi, Civic, Model 3)",
        "price": "Number (Estimated price in RM for new/latest model)",
        "fuel_type": "String (Petrol, Diesel, Hybrid, or EV)",
        "engine_cc": "Number (Engine capacity in cc, use 0 for EV)",
        "fuel_consumption": "Number (L/100km, or kWh/100km for EV)",
        "motor_power": "Number (Horsepower / PS)",
        "is_ev": "Boolean (true if fully electric)"
      }
      Do not include markdown blocks like ```json. Just return the raw JSON.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);
      if (response.text == null || response.text!.isEmpty) return null;

      String jsonText = response.text!.trim();

      if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
      if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
      if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);
      
      final Map<String, dynamic> data = json.decode(jsonText.trim());
      
      if (data.containsKey('error') && data['error'] == 'not_a_car') {
        throw Exception('not_a_car');
      }
      
      String make = data['make']?.toString() ?? 'Unknown';
      String model = data['model']?.toString() ?? 'Unknown';
      
      final supabase = Supabase.instance.client;
      

      final existingResponse = await supabase
          .from('cars')
          .select()
          .ilike('make', make)
          .ilike('model', model)
          .maybeSingle();
          
      if (existingResponse != null) {
        debugPrint('Car $make $model already exists in database. Reusing.');
        return CarModel.fromJson(existingResponse);
      }
      
      String? imageUrl = await _carApiService.fetchCarImageUrl(make, model);


      imageUrl ??= 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&q=80&w=800';

      final car = CarModel(
        make: make,
        model: model,
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        fuelType: data['fuel_type']?.toString() ?? 'Petrol',
        engineCC: (data['engine_cc'] as num?)?.toInt() ?? 0,
        isEV: (data['is_ev'] as bool?) ?? false,
        fuelConsumption: (data['fuel_consumption'] as num?)?.toDouble() ?? 6.0,
        motorPower: (data['motor_power'] as num?)?.toDouble() ?? 0.0,
        imageUrl: imageUrl,
      );

      final map = car.toSupabaseMap();
      map.remove('motor_power');
      
      final insertResponse = await supabase.from('cars').insert(map).select().single();
      final savedCar = CarModel.fromJson(insertResponse);
      
      final cachedCars = await _carApiService.getCachedCars();
      cachedCars.add(savedCar);
      await _carApiService.saveCarsToCache(cachedCars);

      return savedCar;
    } catch (e) {
      debugPrint('AI Fetch Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') || 
          errorStr.contains('clientexception') || 
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection')) {
        throw Exception('no_internet');
      }
      if (errorStr.contains('not_a_car')) {
        rethrow;
      }
      return null;
    }
  }

  Future<CarModel?> fetchCarFromImage(Uint8List imageBytes, String mimeType) async {
    try {
      final prompt = '''
      You are a Malaysian car expert.
      Identify the car in this image and return a JSON object with its details.
      
      CRITICAL INSTRUCTION 1: If the image DOES NOT clearly contain a car, or you cannot identify any car, YOU MUST return EXACTLY this JSON:
      {"error": "not_a_car"}
      
      CRITICAL INSTRUCTION 2 FOR IMAGES:
      The `make` and `model` values you provide MUST exactly match the official English Wikipedia article title for the car.
      - DO NOT include trims, engine sizes, years, or variants in the model name (e.g., NO "Axia 1.0 G", just "Axia").
      - This is because the app will automatically fetch the image from Wikipedia.

      If a car is detected, return ONLY valid JSON matching this structure:
      {
        "make": "String (e.g. Proton, Perodua, Honda, Toyota)",
        "model": "String (Wikipedia exact model name, e.g. X50, Myvi, Civic, Model 3)",
        "price": "Number (Estimated price in RM for new/latest model)",
        "fuel_type": "String (Petrol, Diesel, Hybrid, or EV)",
        "engine_cc": "Number (Engine capacity in cc, use 0 for EV)",
        "fuel_consumption": "Number (L/100km, or kWh/100km for EV)",
        "motor_power": "Number (Horsepower / PS)",
        "is_ev": "Boolean (true if fully electric)"
      }
      Do not include markdown blocks like ```json. Just return the raw JSON.
      ''';

      final visionModel = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: ConfigService.geminiApiKey,
      );

      final response = await visionModel.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, imageBytes)
        ])
      ]);
      
      if (response.text == null || response.text!.isEmpty) return null;

      String jsonText = response.text!.trim();
      if (jsonText.startsWith('```json')) jsonText = jsonText.substring(7);
      if (jsonText.startsWith('```')) jsonText = jsonText.substring(3);
      if (jsonText.endsWith('```')) jsonText = jsonText.substring(0, jsonText.length - 3);
      
      final Map<String, dynamic> data = json.decode(jsonText.trim());
      
      if (data.containsKey('error') && data['error'] == 'not_a_car') {
        throw Exception('not_a_car');
      }
      
      String make = data['make']?.toString() ?? 'Unknown';
      String model = data['model']?.toString() ?? 'Unknown';
      
      final supabase = Supabase.instance.client;
      
      final existingResponse = await supabase
          .from('cars')
          .select()
          .ilike('make', make)
          .ilike('model', model)
          .maybeSingle();
          
      if (existingResponse != null) {
        debugPrint('Car $make $model already exists in database. Reusing.');
        return CarModel.fromJson(existingResponse);
      }
      
      String? imageUrl = await _carApiService.fetchCarImageUrl(make, model);
      imageUrl ??= 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&q=80&w=800';

      final car = CarModel(
        make: make,
        model: model,
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        fuelType: data['fuel_type']?.toString() ?? 'Petrol',
        engineCC: (data['engine_cc'] as num?)?.toInt() ?? 0,
        isEV: (data['is_ev'] as bool?) ?? false,
        fuelConsumption: (data['fuel_consumption'] as num?)?.toDouble() ?? 6.0,
        motorPower: (data['motor_power'] as num?)?.toDouble() ?? 0.0,
        imageUrl: imageUrl,
      );

      final map = car.toSupabaseMap();
      map.remove('motor_power');
      
      final insertResponse = await supabase.from('cars').insert(map).select().single();
      final savedCar = CarModel.fromJson(insertResponse);
      
      final cachedCars = await _carApiService.getCachedCars();
      cachedCars.add(savedCar);
      await _carApiService.saveCarsToCache(cachedCars);

      return savedCar;
    } catch (e) {
      debugPrint('AI Image Fetch Error: $e');
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('socketexception') || 
          errorStr.contains('clientexception') || 
          errorStr.contains('failed host lookup') ||
          errorStr.contains('network') ||
          errorStr.contains('connection')) {
        throw Exception('no_internet');
      }
      if (errorStr.contains('not_a_car')) {
        rethrow;
      }
      return null;
    }
  }
}
