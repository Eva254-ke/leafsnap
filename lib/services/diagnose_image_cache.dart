import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class DiagnoseImageCacheManager {
  DiagnoseImageCacheManager._();

  static const String _cacheKey = 'diagnose_image_cache_v1';

  static final CacheManager instance = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 45),
      maxNrOfCacheObjects: 250,
    ),
  );
}
