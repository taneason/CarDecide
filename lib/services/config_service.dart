import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfigService {
  static String geminiApiKey = '';
  static String orsApiKey = '';

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
      geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      orsApiKey = dotenv.env['ORS_API_KEY'] ?? '';
    } catch (_) {
      debugPrint('ConfigService: No local .env file found. Fetching from Supabase...');
    }

    if (geminiApiKey.isEmpty || orsApiKey.isEmpty) {
      try {
        final response = await Supabase.instance.client
            .from('app_config')
            .select('key, value');

        final List<dynamic> data = response as List<dynamic>;
        for (final item in data) {
          final k = item['key']?.toString();
          final v = item['value']?.toString() ?? '';
          if (k == 'gemini_api_key' && geminiApiKey.isEmpty) {
            geminiApiKey = v;
          } else if (k == 'ors_api_key' && orsApiKey.isEmpty) {
            orsApiKey = v;
          }
        }
        debugPrint('ConfigService: Successfully retrieved API keys from Supabase.');
      } catch (e) {
        debugPrint('ConfigService: Error fetching config from Supabase: ');
      }
    }
  }
}
