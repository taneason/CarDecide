import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';
import 'car_api_service.dart';

class DataService {
  final String _dataCatalogueUrl = 'https://api.data.gov.my/data-catalogue';
  final _supabase = Supabase.instance.client;
  final CarApiService _carApiService = CarApiService();

  /// Fetches the latest fuel prices from data.gov.my
  Future<Map<String, dynamic>> fetchLatestFuelPrices() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDataString = prefs.getString('fuel_prices_data');
    final cachedTimestamp = prefs.getInt('fuel_prices_timestamp') ?? 0;

    // Cache valid for 12 hours (43200000 milliseconds)
    final bool isCacheValid = (DateTime.now().millisecondsSinceEpoch - cachedTimestamp) < 43200000;

    if (cachedDataString != null && isCacheValid) {
      try {
        return Map<String, dynamic>.from(json.decode(cachedDataString));
      } catch (e) {
        debugPrint('Error parsing cached fuel prices: $e');
      }
    }

    try {
      final url = '$_dataCatalogueUrl?id=fuelprice';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Filter for 'level' series type to get actual prices, not weekly changes
        final levelData = data.where((item) => item['series_type'] == 'level').toList();
        
        if (levelData.isNotEmpty) {
          // The API returns chronological order, so the last is the latest
          final latest = levelData.last;
          final result = {
            'RON95 (Floating)': _parseDouble(latest['ron95']),
            'RON97': _parseDouble(latest['ron97']),
            'Diesel (Peninsular)': _parseDouble(latest['diesel']),
            'Diesel (Sbh/Swk)': _parseDouble(latest['diesel_eastmsia']),
            'RON95 (BUDI 95)': _parseDouble(latest['ron95_budi95']),
            'RON95 (SKPS)': _parseDouble(latest['ron95_skps']),
            'Diesel (SKDS)': _parseDouble(latest['diesel_skds']),
            'Diesel (BUDI)': _parseDouble(latest['diesel_budi']),
            '_date': latest['date'] ?? '', 
          };

          // Save to cache
          await prefs.setString('fuel_prices_data', json.encode(result));
          await prefs.setInt('fuel_prices_timestamp', DateTime.now().millisecondsSinceEpoch);

          return result;
        }
      }
    } catch (e) {
      debugPrint('Error fetching fuel prices from network: $e');
    }

    // Network failed, try to use expired cache as a fallback to prevent crash
    if (cachedDataString != null) {
      try {
        return Map<String, dynamic>.from(json.decode(cachedDataString));
      } catch (_) {}
    }

    // Ultimate Fallback
    return {
      'RON95 (Floating)': 3.82,
      'RON97': 4.30,
      'Diesel (Peninsular)': 3.35,
      'Diesel (Sbh/Swk)': 2.15,
      'RON95 (BUDI 95)': 1.99,
      'RON95 (SKPS)': 2.05,
      'Diesel (SKDS)': 2.15,
      'Diesel (BUDI)': 2.10,
      '_date': '',
    };
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    return (value as num).toDouble();
  }

  /// Fetches car data using Cache-First strategy to minimize API usage
  /// Priority:
  /// 1. Local Persistent Cache File (Instant 0ms, 0 API quota)
  /// 2. Remote Supabase Database
  /// 3. Local bundled assets/data/cars.json
  Future<List<CarModel>> fetchCars({bool forceRefresh = false}) async {
    // 1. LOCAL PERSISTENT CACHE (Tier 1)
    if (!forceRefresh) {
      final cachedCars = await _carApiService.getCachedCars();
      if (cachedCars.isNotEmpty) {
        final healed = _carApiService.healCarImages(cachedCars);
        return healed;
      }
    }

    List<CarModel> carList = [];

    // 2. FETCH FROM SUPABASE (Tier 2)
    try {
      final List<dynamic> supabaseData = await _supabase
          .from('cars')
          .select()
          .order('make', ascending: true)
          .timeout(const Duration(seconds: 4));

      if (supabaseData.isNotEmpty) {
        carList = supabaseData.map((e) => CarModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('Supabase car fetch failed or table not found: $e');
    }

    // 3. FALLBACK TO ASSET JSON (Tier 3)
    if (carList.isEmpty) {
      try {
        final String response = await rootBundle.loadString('assets/data/cars.json');
        final List<dynamic> data = json.decode(response);
        carList = data.map((e) => CarModel.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (e) {
        debugPrint('Fallback JSON failed: $e');
        return [];
      }
    }

    // Always heal images to ensure 100% accurate pictures for all models
    carList = _carApiService.healCarImages(carList);

    // Save healed cars to local persistent storage immediately
    await _carApiService.saveCarsToCache(carList);

    // Save/Sync directly to your Supabase database in background
    saveCarsToSupabase(carList);

    return carList;
  }

  /// Saves the complete list of cars with accurate photos directly into Supabase database
  Future<void> saveCarsToSupabase(List<CarModel> cars) async {
    try {
      // First, get existing cars to avoid duplicates since there's no unique constraint
      final existingData = await _supabase.from('cars').select('make, model');
      final existingKeys = existingData.map((e) => '${e['make']}_${e['model']}').toSet();

      final newCars = cars.where((c) => !existingKeys.contains('${c.make}_${c.model}')).toList();
      
      if (newCars.isNotEmpty) {
        final List<Map<String, dynamic>> records = newCars.map((c) {
          final map = c.toSupabaseMap();
          map.remove('motor_power'); // Ensure motor_power is not sent as it doesn't exist in schema
          return map;
        }).toList();
        
        await _supabase.from('cars').insert(records);
        debugPrint('Successfully saved ${newCars.length} NEW cars to Supabase database!');
      } else {
        debugPrint('All cars already exist in Supabase, no new inserts needed.');
      }
    } catch (e) {
      debugPrint('Supabase save failed (Check permissions or connection): $e');
    }
  }

  /// Backward-compatible method returning a list of dynamic maps
  Future<List<Map<String, dynamic>>> fetchCarsAsMap() async {
    final cars = await fetchCars();
    return cars.map((c) => c.toJson()).toList();
  }

  /// Force a fresh sync & image enrichment
  Future<List<CarModel>> forceSyncAndEnrichImages({void Function(int, int)? onProgress}) async {
    final baseCars = await fetchCars(forceRefresh: true);
    final enriched = await _carApiService.enrichCarsWithImages(baseCars, onProgress: onProgress);
    await saveCarsToSupabase(enriched);
    return enriched;
  }

  /// FACTORY RESET: Deletes all cars in Supabase and local cache, then reseeds from clean JSON.
  Future<void> factoryResetDatabase() async {
    try {
      debugPrint('Starting Factory Reset...');
      // 1. Delete all records from Supabase (by matching make not equal to 'IMPOSSIBLE_VALUE')
      await _supabase.from('cars').delete().neq('make', 'IMPOSSIBLE_VALUE');
      
      // 2. Clear local cache file
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('car_data_last_sync_timestamp');
      
      // 3. Load from freshly cleaned local JSON
      final String response = await rootBundle.loadString('assets/data/cars.json');
      final List<dynamic> data = json.decode(response);
      List<CarModel> carList = data.map((e) => CarModel.fromJson(Map<String, dynamic>.from(e))).toList();
      
      // 4. Run through the healer to ensure 320px
      carList = _carApiService.healCarImages(carList);
      
      // 5. Force insert into Supabase
      final List<Map<String, dynamic>> records = carList.map((c) {
        final map = c.toSupabaseMap();
        map.remove('motor_power');
        return map;
      }).toList();
      await _supabase.from('cars').insert(records);
      
      // 6. Save to local cache
      await _carApiService.saveCarsToCache(carList);
      debugPrint('Factory Reset Complete! Inserted ${records.length} clean cars.');
    } catch (e) {
      debugPrint('Factory Reset Error: $e');
    }
  }
}

