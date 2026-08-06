import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/diagnose_text_styles.dart';

enum BannerTone { neutral, warning, error }

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.neutral,
  });

  final String message;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final style = _StyleForTone.of(tone);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 18, color: style.textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: DiagnoseTextStyles.bannerText.copyWith(color: style.textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleForTone {
  const _StyleForTone({
    required this.background,
    required this.border,
    required this.textColor,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color textColor;
  final IconData icon;

  factory _StyleForTone.of(BannerTone tone) {
    return switch (tone) {
      BannerTone.warning => const _StyleForTone(
          background: AppColors.bannerWarningBackground,
          border: AppColors.bannerWarningBorder,
          textColor: AppColors.bannerWarningText,
          icon: Icons.info_outline_rounded,
        ),
      BannerTone.error => const _StyleForTone(
          background: AppColors.bannerErrorBackground,
          border: AppColors.bannerErrorBorder,
          textColor: AppColors.bannerErrorText,
          icon: Icons.error_outline_rounded,
        ),
      BannerTone.neutral => const _StyleForTone(
          background: AppColors.cardBackground,
          border: AppColors.bannerNeutralBorder,
          textColor: AppColors.bannerNeutralText,
          icon: Icons.cloud_done_outlined,
        ),
    };
  }
}