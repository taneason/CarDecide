import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car_model.dart';

class CarApiService {
  static const String _cacheFileName = 'car_cache.json';
  static const String _prefLastSyncKey = 'car_data_last_sync_timestamp';

  final _supabase = Supabase.instance.client;

  static const Map<String, String> _apiHeaders = {
    'User-Agent': 'CarDecideApp/1.0 (contact@cardecide.my; Flutter/Android)',
    'Accept': 'application/json',
  };

  static const Map<String, String> masterCarImages = {
    'perodua_bezza': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/2020_Perodua_Bezza_1.3_AV_%28facelift%29_in_Penang%2C_Malaysia.jpg/800px-2020_Perodua_Bezza_1.3_AV_%28facelift%29_in_Penang%2C_Malaysia.jpg',
    'perodua_myvi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/2018_Perodua_Myvi_1.5_Advance_in_Penang%2C_Malaysia.jpg/800px-2018_Perodua_Myvi_1.5_Advance_in_Penang%2C_Malaysia.jpg',
    'perodua_axia': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/2023_Perodua_Axia_1.0_AV_in_Penang%2C_Malaysia.jpg/800px-2023_Perodua_Axia_1.0_AV_in_Penang%2C_Malaysia.jpg',
    'perodua_ativa': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/2021_Perodua_Ativa_1.0_AV_in_Penang%2C_Malaysia.jpg/800px-2021_Perodua_Ativa_1.0_AV_in_Penang%2C_Malaysia.jpg',
    'perodua_alza': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/2022_Perodua_Alza_1.5_AV_in_Penang%2C_Malaysia.jpg/800px-2022_Perodua_Alza_1.5_AV_in_Penang%2C_Malaysia.jpg',
    'perodua_aruz': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/2019_Perodua_Aruz_1.5_AV_in_Penang%2C_Malaysia.jpg/800px-2019_Perodua_Aruz_1.5_AV_in_Penang%2C_Malaysia.jpg',
    'proton_saga': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/2019_Proton_Saga_Premium_AT_1.3_front_view_%28facelift%29.jpg/800px-2019_Proton_Saga_Premium_AT_1.3_front_view_%28facelift%29.jpg',
    'proton_x50': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/2020_Proton_X50_1.5_TGDi_Flagship_in_Penang%2C_Malaysia.jpg/800px-2020_Proton_X50_1.5_TGDi_Flagship_in_Penang%2C_Malaysia.jpg',
    'proton_x70': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/2020_Proton_X70_Premium_2WD_1.8_in_Penang%2C_Malaysia.jpg/800px-2020_Proton_X70_Premium_2WD_1.8_in_Penang%2C_Malaysia.jpg',
    'proton_s70': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/2023_Proton_S70_1.5T_Flagship_in_Penang%2C_Malaysia.jpg/800px-2023_Proton_S70_1.5T_Flagship_in_Penang%2C_Malaysia.jpg',
    'proton_persona': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/2019_Proton_Persona_1.6_Premium_CVT_%28facelift%29_in_Penang%2C_Malaysia.jpg/800px-2019_Proton_Persona_1.6_Premium_CVT_%28facelift%29_in_Penang%2C_Malaysia.jpg',
    'proton_iriz': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/2019_Proton_Iriz_1.6_Executive_CVT_%28facelift%29_in_Penang%2C_Malaysia.jpg/800px-2019_Proton_Iriz_1.6_Executive_CVT_%28facelift%29_in_Penang%2C_Malaysia.jpg',
    'toyota_vios': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/2023_Toyota_Vios_1.5_G_in_Penang%2C_Malaysia.jpg/800px-2023_Toyota_Vios_1.5_G_in_Penang%2C_Malaysia.jpg',
    'toyota_yaris': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/2019_Toyota_Yaris_1.5_G_in_Penang%2C_Malaysia.jpg/800px-2019_Toyota_Yaris_1.5_G_in_Penang%2C_Malaysia.jpg',
    'toyota_corolla cross': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1d/2022_Toyota_Corolla_Cross_Hybrid_1.8_in_Penang%2C_Malaysia.jpg/800px-2022_Toyota_Corolla_Cross_Hybrid_1.8_in_Penang%2C_Malaysia.jpg',
    'toyota_hilux': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Toyota_Hilux_Double_Cab_2.4_D-4D_4WD_Comfort_%28VIII%2C_Facelift%29_%E2%80%93_f_12042021.jpg/800px-Toyota_Hilux_Double_Cab_2.4_D-4D_4WD_Comfort_%28VIII%2C_Facelift%29_%E2%80%93_f_12042021.jpg',
    'toyota_camry': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ac/2019_Toyota_Camry_2.5V_in_Penang%2C_Malaysia.jpg/800px-2019_Toyota_Camry_2.5V_in_Penang%2C_Malaysia.jpg',
    'honda_city': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/2020_Honda_City_1.5_V_in_Penang%2C_Malaysia.jpg/800px-2020_Honda_City_1.5_V_in_Penang%2C_Malaysia.jpg',
    'honda_civic': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/2022_Honda_Civic_RS_1.5_in_Penang%2C_Malaysia.jpg/800px-2022_Honda_Civic_RS_1.5_in_Penang%2C_Malaysia.jpg',
    'honda_hr-v': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/90/2022_Honda_HR-V_1.5_Turbo_RS_in_Penang%2C_Malaysia.jpg/800px-2022_Honda_HR-V_1.5_Turbo_RS_in_Penang%2C_Malaysia.jpg',
    'honda_cr-v': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2024_Honda_CR-V_1.5_Turbo_in_Penang%2C_Malaysia.jpg/800px-2024_Honda_CR-V_1.5_Turbo_in_Penang%2C_Malaysia.jpg',
    'honda_wr-v': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/2023_Honda_WR-V_1.5_RS_in_Penang%2C_Malaysia.jpg/800px-2023_Honda_WR-V_1.5_RS_in_Penang%2C_Malaysia.jpg',
    'mazda_cx-5': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/2017_Mazda_CX-5_2.0_GLS_in_Penang%2C_Malaysia.jpg/800px-2017_Mazda_CX-5_2.0_GLS_in_Penang%2C_Malaysia.jpg',
    'mazda_3 sedan': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/2019_Mazda3_Sedan_2.0_High_Plus_in_Penang%2C_Malaysia.jpg/800px-2019_Mazda3_Sedan_2.0_High_Plus_in_Penang%2C_Malaysia.jpg',
    'byd_atto 3': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/ca/2022_BYD_Atto_3_Extended_Range_in_Penang%2C_Malaysia.jpg/800px-2022_BYD_Atto_3_Extended_Range_in_Penang%2C_Malaysia.jpg',
    'byd_dolphin': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/2023_BYD_Dolphin_Premium_Extended_in_Penang%2C_Malaysia.jpg/800px-2023_BYD_Dolphin_Premium_Extended_in_Penang%2C_Malaysia.jpg',
    'byd_seal': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/2024_BYD_Seal_Premium_in_Penang%2C_Malaysia.jpg/800px-2024_BYD_Seal_Premium_in_Penang%2C_Malaysia.jpg',
    'tesla_model 3': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/2019_Tesla_Model_3_Performance_AWD_Front.jpg/800px-2019_Tesla_Model_3_Performance_AWD_Front.jpg',
    'tesla_model y': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/db/2022_Tesla_Model_Y_RWD_Front.jpg/800px-2022_Tesla_Model_Y_RWD_Front.jpg',
    'gwm_ora good cat': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Ora_Hao_Mao_001.jpg/800px-Ora_Hao_Mao_001.jpg',
    'chery_omoda e5': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Chery_Omoda_E5_in_Malaysia.jpg/800px-Chery_Omoda_E5_in_Malaysia.jpg',
    'smart_#1': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Smart_1_Pro%2B_IAA_2023_1X7A0307.jpg/800px-Smart_1_Pro%2B_IAA_2023_1X7A0307.jpg',
    'chery_omoda 5': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e0/Chery_Omoda_5_in_Penang%2C_Malaysia.jpg/800px-Chery_Omoda_5_in_Penang%2C_Malaysia.jpg',
    'chery_tiggo 8 pro': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Chery_Tiggo_8_Pro_in_Penang%2C_Malaysia.jpg/800px-Chery_Tiggo_8_Pro_in_Penang%2C_Malaysia.jpg',
    'bmw_ix1': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/BMW_iX1_xDrive30_M_Sport_1X7A0932.jpg/800px-BMW_iX1_xDrive30_M_Sport_1X7A0932.jpg',
    'mercedes_eqb': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Mercedes-Benz_EQB_300_4MATIC_IAA_2021_1X7A0168.jpg/800px-Mercedes-Benz_EQB_300_4MATIC_IAA_2021_1X7A0168.jpg',
    'nissan_almera': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/2020_Nissan_Almera_1.0_Turbo_VLT_in_Penang%2C_Malaysia.jpg/800px-2020_Nissan_Almera_1.0_Turbo_VLT_in_Penang%2C_Malaysia.jpg',
    'mitsubishi_xpander': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/2020_Mitsubishi_Xpander_1.5_in_Penang%2C_Malaysia.jpg/800px-2020_Mitsubishi_Xpander_1.5_in_Penang%2C_Malaysia.jpg',
  };


  Future<String?> fetchCarImageUrl(String make, String model) async {
    final key = '${make.toLowerCase().trim()}_${model.toLowerCase().trim()}';
    if (masterCarImages.containsKey(key)) {
      String url = masterCarImages[key]!;
      return url;
    }

    final formattedTitle = '${make}_$model'.replaceAll(' ', '_');
    try {
      final summaryUrl = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$formattedTitle');
      final response = await http.get(summaryUrl, headers: _apiHeaders).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('thumbnail') && data['thumbnail']['source'] != null) {
          String imgUrl = data['thumbnail']['source'];
          if (imgUrl.startsWith('http') && !imgUrl.endsWith('.svg')) {
            return imgUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Wiki summary failed for $formattedTitle: $e');
    }

    try {
      final modelTitle = model.replaceAll(' ', '_');
      final summaryUrl = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$modelTitle');
      final response = await http.get(summaryUrl, headers: _apiHeaders).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('thumbnail') && data['thumbnail']['source'] != null) {
          String imgUrl = data['thumbnail']['source'];
          if (imgUrl.startsWith('http') && !imgUrl.endsWith('.svg')) {
            return imgUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Wiki model-only summary failed for $model: $e');
    }


    return null;
  }


  List<CarModel> healCarImages(List<CarModel> cars) {
    return cars.map((car) {
      String? safeUrl = car.imageUrl;

      if (safeUrl != null && safeUrl.contains('Chery_Omoda_5') && !car.make.toLowerCase().contains('chery')) {
        safeUrl = null;
      }

      final key = '${car.make.toLowerCase().trim()}_${car.model.toLowerCase().trim()}';
      final bool isInvalid = safeUrl == null || 
          safeUrl.isEmpty || 
          safeUrl.contains('photo-1549399542-7e3f8b79c341');

      if (isInvalid && masterCarImages.containsKey(key)) {
        String masterUrl = masterCarImages[key]!;
        return car.copyWith(imageUrl: masterUrl);
      }
      return car.copyWith(imageUrl: safeUrl);
    }).toList();
  }

  Future<List<CarModel>> getCachedCars() async {
    try {
      final file = await _getLocalCacheFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content);
          final cars = jsonList.map((e) => CarModel.fromJson(Map<String, dynamic>.from(e))).toList();
          
          final staleCount = cars.where((c) => c.imageUrl != null && c.imageUrl!.contains('photo-1549399542-7e3f8b79c341')).length;
          if (staleCount > 2) {
            debugPrint('Detected $staleCount cars with stale legacy placeholder. Invalidating old cache.');
            await file.delete();
            return [];
          }

          final missingTrans = cars.where((c) => c.transmission == null || c.transmission!.isEmpty).length;
          if (missingTrans > 5) {
            debugPrint('Detected $missingTrans cars missing transmission. Invalidating cache to sync from Supabase.');
            await file.delete();
            return [];
          }

          if (cars.isNotEmpty) {
            debugPrint('Loaded ${cars.length} cars from local persistent cache file.');
            return cars;
          }
        }
      }
    } catch (e) {
      debugPrint('Error reading local car cache: $e');
    }
    return [];
  }

  Future<void> saveCarsToCache(List<CarModel> cars) async {
    try {
      final file = await _getLocalCacheFile();
      final jsonString = json.encode(cars.map((c) => c.toJson()).toList());
      await file.writeAsString(jsonString);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefLastSyncKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('Saved ${cars.length} cars to local cache successfully.');
    } catch (e) {
      debugPrint('Error saving cars to local cache: $e');
    }
  }

  Future<File> _getLocalCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_prefLastSyncKey);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
    }
    return null;
  }

  Future<List<CarModel>> enrichCarsWithImages(
    List<CarModel> rawCars, {
    void Function(int current, int total)? onProgress,
  }) async {
    final List<CarModel> enriched = [];
    int total = rawCars.length;

    for (int i = 0; i < total; i++) {
      var car = rawCars[i];
      if (car.imageUrl == null || car.imageUrl!.isEmpty) {
        final scrapedImg = await fetchCarImageUrl(car.make, car.model);
        if (scrapedImg != null) {
          car = car.copyWith(imageUrl: scrapedImg);
        }
      }
      enriched.add(car);
      if (onProgress != null) {
        onProgress(i + 1, total);
      }
    }

    await saveCarsToCache(enriched);

    _syncToSupabaseSilently(enriched);

    return enriched;
  }

  void _syncToSupabaseSilently(List<CarModel> cars) async {
    try {

      for (var car in cars) {
        if (car.imageUrl != null && car.imageUrl!.isNotEmpty) {
           await _supabase.from('cars').update({
             'image_url': car.imageUrl,
           }).eq('make', car.make).eq('model', car.model);
        }
      }
      debugPrint('Supabase cars silently updated with images.');
    } catch (e) {
      debugPrint('Supabase background sync skipped/failed: $e');
    }
  }
}
