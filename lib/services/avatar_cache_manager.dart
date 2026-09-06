import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AvatarCacheManager {
  static const String key = 'avatarCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 20,
    ),
  );
}
