import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

import 'constants/app_constants.dart';
import 'services/config_service.dart';

const String _defaultSupabaseUrl = 'https://nvfirkvoanegxbnycesj.supabase.co';
const String _defaultSupabaseAnonKey = 'sb_publishable_0EXms7Cps158LZfOPnuOWw_Gs_zElgJ';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("--- App Startup Sequence Initiated ---");

  try {
    String? url;
    String? anonKey;
    try {
      await dotenv.load(fileName: ".env");
      url = dotenv.env['SUPABASE_URL'];
      anonKey = dotenv.env['SUPABASE_ANON_KEY'];
    } catch (_) {
      debugPrint("Notice: .env not found locally. Using default secure publishable credentials.");
    }

    await Supabase.initialize(
      url: url ?? _defaultSupabaseUrl,
      anonKey: anonKey ?? _defaultSupabaseAnonKey,
    );
    debugPrint("Supabase: Initialization successful.");


    await ConfigService.initialize();
  } catch (e) {
    debugPrint("Startup Initialization Error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'CarDecide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
        ),
      ),
      home: session != null ? MainScreen() : const LoginScreen(),
    );
  }
}
