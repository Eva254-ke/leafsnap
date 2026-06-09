import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/app_header.dart';
import '../../../components/remote_config_ui.dart';
import '../../../models/diagnose_models.dart';
import '../../../services/diagnose_image_cache.dart';
import '../../../services/diagnose_service.dart';
import '../camera/camera_screen.dart';
import 'diagnose_history_screen.dart';
import 'plant_detail_screen.dart';
import 'issue_detail_screen.dart';

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key, this.initialImage});

  final Object? initialImage;

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen>
    with SingleTickerProviderStateMixin {
  static const double _showcaseCardBaseHeight = 242;
  static const double _showcaseCardShadowBuffer = 38;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  List<DiagnosePlantCard> _plantCards = <DiagnosePlantCard>[];
  List<DiagnoseIssueCard> _issueCards = <DiagnoseIssueCard>[];
  bool _isLoadingShowcase = false;
  String? _showcaseError;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();

    unawaited(_loadCachedShowcase(allowStale: true));
    unawaited(_loadShowcase());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _openCamera() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Camera'),
        builder: (_) => const CameraScreen(),
      ),
    );
  }

  Future<void> _loadCachedShowcase({required bool allowStale}) async {
    try {
      final cachedPlants = await DiagnoseService.instance.getPlantCards(forceRefresh: false);
      final cachedIssues = await DiagnoseService.instance.getIssueCards(forceRefresh: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _plantCards = cachedPlants;
        _issueCards = cachedIssues;
      });
      unawaited(_warmImageCache());
    } catch (_) {
      // Ignore cache loading errors, _loadShowcase will fetch fresh data.
    }
  }

  Future<void> _loadShowcase({bool forceRefresh = false}) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingShowcase = true;
      if (forceRefresh) {
        _showcaseError = null;
      }
    });

    try {
      final plantCards = await DiagnoseService.instance.getPlantCards(forceRefresh: forceRefresh);
      final issueCards = await DiagnoseService.instance.getIssueCards(forceRefresh: forceRefresh);

      if (!mounted) {
        return;
      }

      setState(() {
        _plantCards = plantCards;
        _issueCards = issueCards;
        _showcaseError = null;
      });

      unawaited(_warmImageCache());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _showcaseError = _describeShowcaseError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingShowcase = false;
        });
      }
    }
  }

  bool _hasUsableImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }

    return !normalized.toLowerCase().contains('upgrade_access.jpg');
  }

  String _describeShowcaseError(Object error) {
    if (error is StateError &&
        error.message.toString().contains('PLANT_QUERY_API_KEY')) {
      return 'Plant references are temporarily unavailable right now.';
    }
    if (error is HttpException) {
      return 'Could not refresh references right now. Pull to try again.';
    }
    return 'Could not load references right now. Pull to try again.';
  }

  Future<void> _warmImageCache() async {
    final urls = <String>{
      ..._plantCards
          .map((item) => item.imageUrl)
          .where((url) => _hasUsableImageUrl(url))
          .cast<String>(),
      ..._issueCards
          .map((item) => item.imageUrl)
          .where((url) => _hasUsableImageUrl(url))
          .cast<String>(),
    };

    if (urls.isEmpty) {
      return;
    }

    try {
      await Future.wait(
        urls.map(
          (url) => DiagnoseImageCacheManager.instance.downloadFile(
            url,
            key: url,
          ),
        ),
      );
    } catch (_) {
      // Keep the screen usable even if image prefetching fails.
    }
  }

  int? _safeToInt(double value) {
    if (!value.isFinite || value <= 0) {
      return null;
    }
    return value.round();
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _plantCards.isNotEmpty || _issueCards.isNotEmpty;

    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.diagnose,
      fallbackBackgroundColor: const Color(0xFFF4FBF5),
      fallbackPrimaryColor: const Color(0xFF1D7A43),
      builder: (context, remoteConfig) {
        return Scaffold(
      backgroundColor: remoteConfig.backgroundColor,
      appBar: AppHeader(
        title: 'Diagnose',
        rightActions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  settings: const RouteSettings(name: 'Diagnose History'),
                  builder: (_) => const DiagnoseHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          color: const Color(0xFF1D7A43),
          onRefresh: () => _loadShowcase(forceRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (remoteConfig.banner != null) ...[
                RemoteScreenBanner(
                  banner: remoteConfig.banner!,
                  primaryColor: remoteConfig.primaryColor,
                ),
                const SizedBox(height: 16),
              ],
              _buildHeroCard(),
              const SizedBox(height: 18),
              if (_showcaseError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildInfoBanner(
                    message: _showcaseError!,
                    tone: hasContent ? _BannerTone.warning : _BannerTone.error,
                  ),
                ),
              _buildSectionHeader(
                title: 'Matching Plants',
                subtitle:
                    'Real plant photos you can compare before running a scan.',
              ),
              const SizedBox(height: 12),
              if (_isLoadingShowcase && _plantCards.isEmpty)
                _buildHorizontalSkeleton()
              else if (_plantCards.isEmpty)
                _buildInfoBanner(
                  message:
                      'No plant references are ready yet. Pull to refresh and try again.',
                )
              else
                _buildPlantScroller(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                title: 'Plants With Problems',
                subtitle:
                    'Common issue examples to help you compare spots, pests, and discoloration.',
              ),
              const SizedBox(height: 12),
              if (_isLoadingShowcase && _issueCards.isEmpty)
                _buildHorizontalSkeleton()
              else if (_issueCards.isEmpty)
                _buildInfoBanner(
                  message:
                      'No issue references are ready yet. Pull to refresh and try again.',
                )
              else
                _buildIssueScroller(),
              if (_isLoadingShowcase && hasContent) ...[
                const SizedBox(height: 18),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF1D7A43),
                  backgroundColor: Color(0xFFDDEFE0),
                ),
              ],
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildHeroCard() {
    final heroIssue = _issueCards.isNotEmpty ? _issueCards.first : null;
    final heroImage = heroIssue?.imageUrl ??
        (_plantCards.isNotEmpty ? _plantCards.first.imageUrl : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SizedBox(
              height: 232,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCachedImage(
                    imageUrl: heroImage,
                    width: double.infinity,
                    height: 232,
                    borderRadius: BorderRadius.zero,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.58),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.24),
                            ),
                          ),
                          child: Text(
                            'Visual reference library',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Compare leaves with visual references',
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          heroIssue == null
                              ? 'Helpful examples appear here while you compare color, texture, and spotting.'
                              : '${heroIssue.disease.commonName} gives you a quick symptom reference while you compare your plant.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetricPill(
                      icon: Icons.nature,
                      label: '${_plantCards.length} plant matches',
                    ),
                    _buildMetricPill(
                      icon: Icons.bug_report_outlined,
                      label: '${_issueCards.length} issue cards',
                    ),
                    _buildMetricPill(
                      icon: Icons.compare_arrows_rounded,
                      label: 'Quick compare',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _openCamera,
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: Text(
                      widget.initialImage == null
                          ? 'Auto Diagnose'
                          : 'Continue Diagnose',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D7A43),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F8F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD5E9D9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1D7A43)),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1F2F23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF19231B),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6C7D70),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPlantScroller() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _plantCards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _buildPlantCard(_plantCards[index]),
      ),
    );
  }

  Widget _buildIssueScroller() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _issueCards.length,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _buildIssueCard(_issueCards[index]),
      ),
    );
  }

  Widget _buildPlantCard(DiagnosePlantCard plant) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlantDetailScreen(plant: plant),
          ),
        );
      },
      child: Container(
        width: 188,
        height: _showcaseCardHeight(context),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Hero(
              tag: 'plant_image_${plant.query}',
              child: _buildCachedImage(
                imageUrl: plant.imageUrl,
                width: 188,
                height: 116,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.species.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18211A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant.species.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF708171),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          plant.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF526254),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueCard(DiagnoseIssueCard issue) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => IssueDetailScreen(issue: issue),
      )),
      child: Container(
        width: 194,
        height: _showcaseCardHeight(context),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Stack(
              children: [
                Hero(
                  tag: 'issue_image_${issue.query}',
                  child: _buildCachedImage(
                    imageUrl: issue.imageUrl,
                    width: 194,
                    height: 116,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: _buildCardBadge(
                    issue.badge,
                    background: const Color(0xFF1C2E22),
                    foreground: Colors.white,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.disease.commonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF18211A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.disease.scientificName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF708171),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          issue.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF526254),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _showcaseCardHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final clampedTextScale = switch (textScale) {
      < 1.0 => 1.0,
      > 2.0 => 2.0,
      _ => textScale,
    };

    return _showcaseCardBaseHeight + (clampedTextScale - 1.0) * 72.0;
  }

  Widget _buildCardBadge(
    String label, {
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildHorizontalSkeleton() {
    final cardHeight = _showcaseCardHeight(context);
    return SizedBox(
      height: cardHeight + _showcaseCardShadowBuffer,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 188,
            height: cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Container(
                    height: 126,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F2E9),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 112,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F2E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 10,
                            width: 82,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 10,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 130,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F6F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBanner({
    required String message,
    _BannerTone tone = _BannerTone.neutral,
  }) {
    final Color background;
    final Color border;
    final Color textColor;
    final IconData icon;

    switch (tone) {
      case _BannerTone.warning:
        background = const Color(0xFFFFF7E8);
        border = const Color(0xFFF1D38E);
        textColor = const Color(0xFF6F5206);
        icon = Icons.info_outline_rounded;
      case _BannerTone.error:
        background = const Color(0xFFFFEFEF);
        border = const Color(0xFFF2C4C4);
        textColor = const Color(0xFF8F2E2E);
        icon = Icons.error_outline_rounded;
      case _BannerTone.neutral:
        background = Colors.white;
        border = const Color(0xFFDCE9DD);
        textColor = const Color(0xFF4E6152);
        icon = Icons.cloud_done_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCachedImage({
    required String? imageUrl,
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    if (!_hasUsableImageUrl(imageUrl)) {
      return _imagePlaceholder(
        width: width,
        height: height,
        borderRadius: borderRadius,
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!.trim(),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: DiagnoseImageCacheManager.instance,
        cacheKey: imageUrl.trim(),
        memCacheWidth: width.isFinite ? _safeToInt(width * 2) : null,
        memCacheHeight: height.isFinite ? _safeToInt(height * 2) : null,
        placeholder: (context, url) => _imagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, url, error) => _imagePlaceholder(
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
      ),
    );
  }

  Widget _imagePlaceholder({
    required double width,
    required double height,
    required BorderRadius borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8F4E9),
            Color(0xFFD8EAD9),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.nature,
          size: 34,
          color: Color(0xFF2B7B45),
        ),
      ),
    );
  }
}



enum _BannerTone {
  neutral,
  warning,
  error,
}
