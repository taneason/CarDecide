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
    final geoapifyKey = ConfigService.geoapifyApiKey;
    if (geoapifyKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://api.geoapify.com/v2/places?categories=commercial.vehicle&filter=circle:$lng,$lat,$radius&bias=proximity:$lng,$lat&limit=50&apiKey=$geoapifyKey',
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final features = data['features'] as List? ?? [];
          final dealers = <Map<String, dynamic>>[];
          for (final f in features) {
            final prop = (f['properties'] as Map<String, dynamic>?) ?? {};
            final geom = (f['geometry'] as Map<String, dynamic>?) ?? {};
            final coords = geom['coordinates'] as List? ?? [];
            final dLat = (prop['lat'] ?? (coords.length > 1 ? coords[1] : 0.0)) as num;
            final dLng = (prop['lon'] ?? (coords.isNotEmpty ? coords[0] : 0.0)) as num;
            if (dLat == 0.0 || dLng == 0.0) continue;

            final comm = (prop['commercial'] as Map<String, dynamic>?) ?? {};
            final raw = (prop['datasource'] as Map<String, dynamic>?)?['raw'] as Map<String, dynamic>? ?? {};
            final commType = (comm['type'] ?? '').toString().toLowerCase();
            final rawShop = (raw['shop'] ?? '').toString().toLowerCase();
            if (commType == 'motorcycle' || commType == 'bicycle' || commType == 'car_parts' ||
                rawShop == 'motorcycle' || rawShop == 'bicycle' || rawShop == 'car_parts') {
              continue;
            }

            final rawName = (prop['name'] ?? '').toString().trim();
            final brand = (prop['brand'] ?? raw['brand'] ?? '').toString().trim();
            final street = (prop['street'] ?? prop['address_line1'] ?? '').toString().trim();
            final operatorName = (prop['operator'] ?? raw['operator'] ?? '').toString().trim();
            final formattedAddress = (prop['formatted'] ?? prop['address_line2'] ?? '').toString().trim();

            final displayName = _formatDealershipName(rawName, brand, street, operatorName);
            if (displayName.isEmpty) continue;

            final contact = (prop['contact'] as Map<String, dynamic>?) ?? {};
            final phone = (contact['phone'] ?? prop['phone'] ?? 'Not provided').toString();
            final hours = (prop['opening_hours'] ?? 'Not provided').toString();
            final website = (contact['website'] ?? prop['website'])?.toString();

            dealers.add({
              'name': displayName,
              'brand': brand.isNotEmpty ? brand : 'Automotive',
              'location': formattedAddress.isNotEmpty ? formattedAddress : 'Address not available',
              'phone': phone,
              'hours': hours,
              'website': website,
              'lat': dLat.toDouble(),
              'lng': dLng.toDouble(),
            });
          }
          if (dealers.isNotEmpty) {
            return dealers;
          }
        }
      } catch (_) {}
    }

    try {
      final query = '[out:json][timeout:15];nwr["shop"="car"](around:$radius,$lat,$lng);out center 40;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}');
      final response = await http.get(uri, headers: {
        'User-Agent': 'CarDecide/1.0',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final elements = data['elements'] as List? ?? [];
        final dealers = <Map<String, dynamic>>[];

        for (final e in elements) {
          final tags = (e['tags'] as Map<String, dynamic>?) ?? {};
          final rawName = (tags['name'] ?? '').toString().trim();
          final rawBrand = (tags['brand'] ?? tags['operator'] ?? '').toString().trim();
          final street = (tags['addr:street'] ?? tags['addr:city'] ?? '').toString().trim();
          final operatorName = (tags['operator'] ?? '').toString().trim();

          final displayName = _formatDealershipName(rawName, rawBrand, street, operatorName);
          if (displayName.isEmpty) continue;

          List<String> addressParts = [];
          if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber'].toString());
          if (tags['addr:street'] != null) addressParts.add(tags['addr:street'].toString());
          if (tags['addr:city'] != null) addressParts.add(tags['addr:city'].toString());
          if (tags['addr:state'] != null) addressParts.add(tags['addr:state'].toString());

          String location = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : (tags['is_in'] ?? tags['addr:full'] ?? 'Address not available').toString();

          final latVal = (e['lat'] ?? e['center']?['lat'] ?? 0.0) as num;
          final lngVal = (e['lon'] ?? e['center']?['lon'] ?? 0.0) as num;
          if (latVal == 0.0 || lngVal == 0.0) continue;

          dealers.add({
            'name': displayName,
            'brand': rawBrand.isNotEmpty ? rawBrand : 'Automotive',
            'location': location,
            'phone': (tags['phone'] ?? tags['contact:phone'] ?? 'Not provided').toString(),
            'hours': (tags['opening_hours'] ?? 'Not provided').toString(),
            'website': (tags['website'] ?? tags['contact:website'])?.toString(),
            'lat': latVal.toDouble(),
            'lng': lngVal.toDouble(),
          });
        }
        return dealers;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  String _formatDealershipName(String rawName, String rawBrand, String street, String operatorName) {
    var name = rawName.replaceAll('\uFFFD', 'e').trim();
    var brand = rawBrand.replaceAll('\uFFFD', 'e').trim();

    final knownBrands = [
      'Perodua', 'Proton', 'Honda', 'Toyota', 'BYD', 'Nissan', 'Mazda',
      'BMW', 'Mercedes-Benz', 'Mercedes', 'Hyundai', 'Kia', 'Peugeot',
      'Volkswagen', 'Volvo', 'Lexus', 'Chery', 'GWM', 'Subaru', 'Suzuki',
      'Mitsubishi', 'Audi', 'Porsche'
    ];

    String detectedBrand = '';
    final combined = '$name $brand'.toLowerCase();
    for (final b in knownBrands) {
      if (combined.contains(b.toLowerCase())) {
        detectedBrand = b;
        break;
      }
    }

    if (name.isEmpty || name.toLowerCase() == 'auto dealership') {
      if (detectedBrand.isNotEmpty && street.isNotEmpty) {
        return '$detectedBrand Showroom - $street';
      } else if (detectedBrand.isNotEmpty) {
        return '$detectedBrand Authorized Centre';
      } else if (brand.isNotEmpty) {
        return '$brand Dealership';
      } else {
        return '';
      }
    }

    for (final b in knownBrands) {
      if (name.toLowerCase() == b.toLowerCase()) {
        if (street.isNotEmpty) {
          return '$name Showroom - $street';
        } else if (operatorName.isNotEmpty) {
          final shortOp = operatorName.split(' ').first;
          return '$name ($shortOp)';
        } else {
          return '$name Authorized Showroom';
        }
      }
    }

    if (name.toLowerCase() == 'perodua showroom' && operatorName.isNotEmpty) {
      final shortOp = operatorName.replaceAll('Sdn Bhd', '').replaceAll('Sdn. Bhd.', '').trim();
      if (shortOp.isNotEmpty) {
        return 'Perodua Showroom ($shortOp)';
      }
    }

    return name;
  }
}
