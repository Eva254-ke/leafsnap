import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/diagnose_image_cache.dart';
import '../../../theme/app_colors.dart';

/// Renders a cached network image with a consistent placeholder.
///
/// URL validation (null / empty / sentinel filename) now lives in the service
/// layer. This widget simply treats a null [imageUrl] as "show placeholder".
class DiagnoseCachedImage extends StatelessWidget {
  const DiagnoseCachedImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.trim().isEmpty) {
      return _Placeholder(width: width, height: height, borderRadius: borderRadius);
    }

    final trimmed = url.trim();
    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: DiagnoseImageCacheManager.instance,
        cacheKey: trimmed,
        memCacheWidth: _safeToInt(width * 2),
        memCacheHeight: _safeToInt(height * 2),
        placeholder: (_, __) =>
            _Placeholder(width: width, height: height, borderRadius: borderRadius),
        errorWidget: (_, __, ___) =>
            _Placeholder(width: width, height: height, borderRadius: borderRadius),
      ),
    );
  }

  static int? _safeToInt(double value) {
    if (!value.isFinite || value <= 0) return null;
    return value.round();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.placeholderGradientStart,
            AppColors.placeholderGradientEnd,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.nature, size: 34, color: AppColors.placeholderIcon),
      ),
    );
  }
}