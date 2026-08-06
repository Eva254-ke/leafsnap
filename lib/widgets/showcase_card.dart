import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/diagnose_text_styles.dart';
import 'diagnose_cached_image.dart';

/// Base card shared by [PlantShowcaseCard] and [IssueShowcaseCard].
///
/// Keeps the shadow, corner radius, image slot, and text layout in one place.
/// The 6-px width inconsistency between plant (188) and issue (194) cards has
/// been resolved — both now use [_kCardWidth].
const double _kCardWidth = 188;
const double _kImageHeight = 116;

class ShowcaseCard extends StatelessWidget {
  const ShowcaseCard({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.height,
    required this.onTap,
    this.badge,
  });

  final String? imageUrl;
  final String heroTag;
  final String title;
  final String subtitle;
  final String note;
  final double height;
  final VoidCallback onTap;

  /// Optional badge widget overlaid on the top-right corner of the image.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: _kCardWidth,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ImageSlot(imageUrl: imageUrl, heroTag: heroTag, badge: badge),
            Expanded(child: _CardBody(title: title, subtitle: subtitle, note: note)),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.imageUrl,
    required this.heroTag,
    this.badge,
  });

  final String? imageUrl;
  final String heroTag;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final image = Hero(
      tag: heroTag,
      child: DiagnoseCachedImage(
        imageUrl: imageUrl,
        width: _kCardWidth,
        height: _kImageHeight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
    );

    if (badge == null) return image;

    return Stack(
      children: [
        image,
        Positioned(right: 12, top: 12, child: badge!),
      ],
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.title,
    required this.subtitle,
    required this.note,
  });

  final String title;
  final String subtitle;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiagnoseTextStyles.cardTitle,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiagnoseTextStyles.cardScientific,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: DiagnoseTextStyles.cardNote,
              ),
            ),
          ),
        ],
      ),
    );
  }
}