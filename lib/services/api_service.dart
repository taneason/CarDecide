import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class ApiService {
  static String get _orsApiKey => ConfigService.orsApiKey;

  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      if (query.isEmpty) return [];
      
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1'
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'CarDecide/1.0',
      });

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        print('Nominatim Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Failed to search locations: $e');
      return [];
    }
  }


  Future<String?> getAddressFromCoords(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'CarDecide/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
      return null;
    } catch (e) {
      print('Failed to reverse geocode: $e');
      return null;
    }
  }


  Future<double> getRoadDistance(dynamic origin, dynamic destination) async {
    try {
      final double startLat = origin.latitude;
      final double startLng = origin.longitude;
      final double endLat = destination.latitude;
      final double endLng = destination.longitude;

      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car?'
        'api_key=$_orsApiKey&'
        'start=$startLng,$startLat&'
        'end=$endLng,$endLat'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final double distanceMeters = data['features'][0]['properties']['summary']['distance'];
        return distanceMeters / 1000.0;
      } else {
        print('ORS API Error: ${response.statusCode} - ${response.body}');
        return -1;
      }
    } catch (e) {
      print('Failed to fetch ORS distance: $e');
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> fetchNearbyDealerships(double lat, double lng, {int radius = 5000}) async {
    try {
      final query = '[out:json][timeout:10];nwr["shop"="car"](around:$radius,$lat,$lng);out center 50;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');
      final response = await http.get(uri, headers: {
        'User-Agent': 'CarDecide/1.0',
      }).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;
        return elements.map((e) {
          final tags = e['tags'] ?? {};
          final name = tags['name'] ?? tags['brand'] ?? 'Auto Dealership';
          final brand = tags['brand'] ?? tags['operator'] ?? 'Various';
          
          List<String> addressParts = [];
          if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber']);
          if (tags['addr:street'] != null) addressParts.add(tags['addr:street']);
          if (tags['addr:city'] != null) addressParts.add(tags['addr:city']);
          if (tags['addr:state'] != null) addressParts.add(tags['addr:state']);
          
          String location = addressParts.isNotEmpty 
              ? addressParts.join(', ') 
              : (tags['is_in'] ?? tags['addr:full'] ?? 'Address not available');

          return {
            'name': name,
            'brand': brand,
            'location': location,
            'phone': tags['phone'] ?? tags['contact:phone'] ?? 'Not provided',
            'hours': tags['opening_hours'] ?? 'Not provided',
            'website': tags['website'] ?? tags['contact:website'],
            'lat': e['lat'] ?? e['center']?['lat'] ?? 0.0,
            'lng': e['lon'] ?? e['center']?['lon'] ?? 0.0,
          };
        }).where((d) => d['lat'] != 0.0 && d['lng'] != 0.0).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching dealerships from Overpass: $e');
      return [];
    }
  }
}
