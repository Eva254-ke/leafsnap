
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
import 'issue_detail_screen.dart';
import 'plant_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colours
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _C {
  static const bg              = Color(0xFFF4FBF5);
  static const brand           = Color(0xFF1D7A43);
  static const brandLight      = Color(0xFFDDEFE0);
  static const textPrimary     = Color(0xFF19231B);
  static const textSecondary   = Color(0xFF6C7D70);
  static const textNote        = Color(0xFF526254);
  static const textScientific  = Color(0xFF708171);
  static const pillBg          = Color(0xFFF2F8F2);
  static const pillBorder      = Color(0xFFD5E9D9);
  static const skeletonDark    = Color(0xFFE8F2E9);
  static const skeletonLight   = Color(0xFFF0F6F0);
  static const placeholderA    = Color(0xFFE8F4E9);
  static const placeholderB    = Color(0xFFD8EAD9);
  static const placeholderIcon = Color(0xFF2B7B45);
  static const badgeBg         = Color(0xFF1C2E22);
  static const warnBg          = Color(0xFFFFF7E8);
  static const warnBorder      = Color(0xFFF1D38E);
  static const warnText        = Color(0xFF6F5206);
  static const errBg           = Color(0xFFFFEFEF);
  static const errBorder       = Color(0xFFF2C4C4);
  static const errText         = Color(0xFF8F2E2E);
  static const neutralBorder   = Color(0xFFDCE9DD);
  static const neutralText     = Color(0xFF4E6152);
}

// ─────────────────────────────────────────────────────────────────────────────
// Text styles
// ─────────────────────────────────────────────────────────────────────────────

abstract final class _T {
  static final sectionTitle    = _inter(20, FontWeight.w700, _C.textPrimary);
  static final sectionSubtitle = _inter(13, FontWeight.w500, _C.textSecondary, height: 1.4);
  static final cardTitle       = _inter(15, FontWeight.w700, const Color(0xFF18211A), height: 1.2);
  static final cardScientific  = _inter(12, FontWeight.w500, _C.textScientific, italic: true);
  static final cardNote        = _inter(11, FontWeight.w500, _C.textNote, height: 1.4);
  static final heroTag         = _inter(12, FontWeight.w700, Colors.white);
  static final heroHeadline    = _inter(26, FontWeight.w700, Colors.white, height: 1.15, spacing: -0.4);
  static final heroBody        = _inter(13, FontWeight.w500, Color(0xEBFFFFFF), height: 1.45);
  static final heroCta         = _inter(15, FontWeight.w700, Colors.white);
  static final metricLabel     = _inter(11, FontWeight.w700, const Color(0xFF1F2F23));
  static final bannerText      = _inter(12, FontWeight.w600, Colors.black, height: 1.45);
  static final badgeLabel      = _inter(11, FontWeight.w700, Colors.white);

  static TextStyle _inter(
    double size,
    FontWeight weight,
    Color color, {
    double? height,
    double? spacing,
    bool italic = false,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: spacing,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner tone
// ─────────────────────────────────────────────────────────────────────────────

enum _Tone { neutral, warning, error }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class DiagnoseScreen extends StatefulWidget {
  const DiagnoseScreen({super.key, this.initialImage});

  final Object? initialImage;

  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen>
    with SingleTickerProviderStateMixin {
  static const double _kCardBase   = 242;
  static const double _kShadowBuf  = 38;
  static const double _kCardWidth  = 188;
  static const double _kImageH     = 116;

  late final AnimationController _anim;
  late final Animation<double>   _fade;

  List<DiagnosePlantCard> _plants = [];
  List<DiagnoseIssueCard> _issues = [];
  bool   _loading = false;
  String? _error;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    unawaited(_fetch(silent: true));
    unawaited(_fetch());
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetch({bool forceRefresh = false, bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() { _loading = true; if (forceRefresh) _error = null; });

    try {
      final plants = await DiagnoseService.instance.getPlantCards(forceRefresh: forceRefresh);
      final issues = await DiagnoseService.instance.getIssueCards(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() { _plants = plants; _issues = issues; if (!silent) _error = null; });
      unawaited(_warmCache());
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = _describe(e));
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _warmCache() async {
    final urls = <String>{
      ..._plants.map((p) => p.imageUrl).where(_usable).cast<String>(),
      ..._issues.map((i) => i.imageUrl).where(_usable).cast<String>(),
    };
    if (urls.isEmpty) return;
    try {
      await Future.wait(
        urls.map((u) => DiagnoseImageCacheManager.instance.downloadFile(u, key: u)),
      );
    } catch (_) {}
  }

  static bool _usable(String? v) {
    final s = v?.trim();
    return s != null && s.isNotEmpty && !s.toLowerCase().contains('upgrade_access.jpg');
  }

  String _describe(Object e) {
    if (e is StateError && e.message.contains('PLANT_QUERY_API_KEY')) {
      return 'Plant references are temporarily unavailable.';
    }
    if (e is HttpException) return 'Could not refresh. Pull to try again.';
    return 'Could not load references. Pull to try again.';
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openCamera() => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'Camera'),
      builder: (_) => const CameraScreen(),
    ),
  );

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'Diagnose History'),
      builder: (_) => const DiagnoseHistoryScreen(),
    ),
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _cardH(BuildContext ctx) {
    final s = MediaQuery.textScalerOf(ctx).scale(1.0).clamp(1.0, 2.0);
    return _kCardBase + (s - 1.0) * 72.0;
  }

  bool get _hasContent => _plants.isNotEmpty || _issues.isNotEmpty;

  int? _toInt(double v) => (v.isFinite && v > 0) ? v.round() : null;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RemoteConfigBuilder(
      screenId: RemoteConfigScreens.diagnose,
      fallbackBackgroundColor: _C.bg,
      fallbackPrimaryColor: _C.brand,
      builder: (context, rc) => Scaffold(
        backgroundColor: rc.backgroundColor,
        appBar: AppHeader(
          title: 'Diagnose',
          rightActions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              onPressed: _openHistory,
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fade,
          child: RefreshIndicator(
            color: _C.brand,
            onRefresh: () => _fetch(forceRefresh: true),
            child: _buildBody(context, rc),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext ctx, dynamic rc) {
    final cardH = _cardH(ctx);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (rc.banner != null) ...[
          RemoteScreenBanner(banner: rc.banner!, primaryColor: rc.primaryColor),
          const SizedBox(height: 16),
        ],

        // Hero
        _HeroCard(
          plants: _plants,
          issues: _issues,
          onTap: _openCamera,
          continueLbl: widget.initialImage != null,
        ),
        const SizedBox(height: 20),

        // Error banner
        if (_error != null) ...[
          _Banner(
            message: _error!,
            tone: _hasContent ? _Tone.warning : _Tone.error,
          ),
          const SizedBox(height: 16),
        ],

        // Plants section
        _SectionHeader(
          title: 'Matching plants',
          subtitle: 'Real photos to compare before running a scan.',
        ),
        const SizedBox(height: 12),
        if (_loading && _plants.isEmpty)
          _Skeleton(cardH: cardH)
        else if (_plants.isEmpty)
          const _Banner(message: 'No plant references yet. Pull to refresh.')
        else
          _PlantRow(plants: _plants, cardH: cardH, context: ctx),

        const SizedBox(height: 24),

        // Issues section
        _SectionHeader(
          title: 'Plants with problems',
          subtitle: 'Compare spots, pests, and discolouration.',
        ),
        const SizedBox(height: 12),
        if (_loading && _issues.isEmpty)
          _Skeleton(cardH: cardH)
        else if (_issues.isEmpty)
          const _Banner(message: 'No issue references yet. Pull to refresh.')
        else
          _IssueRow(issues: _issues, cardH: cardH, context: ctx),

        // Background refresh indicator
        if (_loading && _hasContent) ...[
          const SizedBox(height: 20),
          const LinearProgressIndicator(
            minHeight: 2,
            color: _C.brand,
            backgroundColor: _C.brandLight,
          ),
        ],
      ],
    );
  }

  // ── Plant row ──────────────────────────────────────────────────────────────

  Widget _PlantRow({
    required List<DiagnosePlantCard> plants,
    required double cardH,
    required BuildContext context,
  }) {
    return SizedBox(
      height: cardH + _kShadowBuf,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: plants.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = plants[i];
          return _Card(
            imageUrl: p.imageUrl,
            heroTag: 'plant_${p.query}',
            title: p.species.commonName,
            subtitle: p.species.scientificName,
            note: p.note,
            cardH: cardH,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: p)),
            ),
          );
        },
      ),
    );
  }

  // ── Issue row ──────────────────────────────────────────────────────────────

  Widget _IssueRow({
    required List<DiagnoseIssueCard> issues,
    required double cardH,
    required BuildContext context,
  }) {
    return SizedBox(
      height: cardH + _kShadowBuf,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: issues.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final iss = issues[i];
          return _Card(
            imageUrl: iss.imageUrl,
            heroTag: 'issue_${iss.query}',
            title: iss.disease.commonName,
            subtitle: iss.disease.scientificName,
            note: iss.note,
            cardH: cardH,
            badge: iss.badge,
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(builder: (_) => IssueDetailScreen(issue: iss)),
            ),
          );
        },
      ),
    );
  }

  // ── Shared card ────────────────────────────────────────────────────────────

  Widget _Card({
    required String? imageUrl,
    required String heroTag,
    required String title,
    required String subtitle,
    required String note,
    required double cardH,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: _kCardWidth,
        height: cardH,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image slot
            Stack(
              children: [
                Hero(
                  tag: heroTag,
                  child: _CachedImage(
                    url: imageUrl,
                    width: _kCardWidth,
                    height: _kImageH,
                    radius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(badge, style: _T.badgeLabel),
                    ),
                  ),
              ],
            ),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _T.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _T.cardScientific),
                    const SizedBox(height: 7),
                    Expanded(
                      child: Text(note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _T.cardNote),
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

  // ── Cached image ───────────────────────────────────────────────────────────

  Widget _CachedImage({
    required String? url,
    required double width,
    required double height,
    required BorderRadius radius,
  }) {
    if (!_usable(url)) return _placeholder(width, height, radius);
    final trimmed = url!.trim();
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: trimmed,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheManager: DiagnoseImageCacheManager.instance,
        cacheKey: trimmed,
        memCacheWidth: _toInt(width * 2),
        memCacheHeight: _toInt(height * 2),
        placeholder: (_, __) => _placeholder(width, height, radius),
        errorWidget: (_, __, ___) => _placeholder(width, height, radius),
      ),
    );
  }

  Widget _placeholder(double w, double h, BorderRadius r) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.placeholderA, _C.placeholderB],
          ),
        ),
        child: const Center(
          child: Icon(Icons.nature_outlined, size: 30, color: _C.placeholderIcon),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.plants,
    required this.issues,
    required this.onTap,
    required this.continueLbl,
  });

  final List<DiagnosePlantCard> plants;
  final List<DiagnoseIssueCard> issues;
  final VoidCallback onTap;
  final bool continueLbl;

  @override
  Widget build(BuildContext context) {
    final heroIssue  = issues.isNotEmpty ? issues.first : null;
    final heroUrl    = heroIssue?.imageUrl ??
        (plants.isNotEmpty ? plants.first.imageUrl : null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image band ──────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  _BgImage(url: heroUrl),

                  // Gradient scrim — softer, two-stop
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),

                  // Text overlay
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22)),
                          ),
                          child: Text('Visual reference library', style: _T.heroTag),
                        ),
                        const Spacer(),
                        Text(
                          'Compare leaves\nwith visual references',
                          style: _T.heroHeadline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heroIssue == null
                              ? 'Helpful examples appear while you compare colour, texture, and spotting.'
                              : '${heroIssue.disease.commonName} — a quick symptom reference while you compare.',
                          style: _T.heroBody,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metric pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(icon: Icons.eco_outlined,
                        label: '${plants.length} plant matches'),
                    _Pill(icon: Icons.healing_outlined,
                        label: '${issues.length} issue cards'),
                    _Pill(icon: Icons.center_focus_weak_rounded,
                        label: 'Quick compare'),
                  ],
                ),
                const SizedBox(height: 16),
                // CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      continueLbl ? 'Continue diagnose' : 'Auto diagnose',
                      style: _T.heroCta,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
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
}

// Background image helper — avoids inline nesting
class _BgImage extends StatelessWidget {
  const _BgImage({required this.url});
  final String? url;

  static bool _usable(String? v) {
    final s = v?.trim();
    return s != null && s.isNotEmpty && !s.toLowerCase().contains('upgrade_access.jpg');
  }

  @override
  Widget build(BuildContext context) {
    if (!_usable(url)) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
          ),
        ),
        child: const Center(
          child: Icon(Icons.nature_outlined, size: 64, color: Color(0x33FFFFFF)),
        ),
      );
    }
    final trimmed = url!.trim();
    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: BoxFit.cover,
      cacheManager: DiagnoseImageCacheManager.instance,
      cacheKey: trimmed,
      placeholder: (_, __) => Container(color: const Color(0xFF2D6A4F)),
      errorWidget: (_, __, ___) => Container(color: const Color(0xFF2D6A4F)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric pill
// ─────────────────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _C.pillBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.pillBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _C.brand),
          const SizedBox(width: 6),
          Text(label, style: _T.metricLabel),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _T.sectionTitle),
        const SizedBox(height: 5),
        Text(subtitle, style: _T.sectionSubtitle),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info banner
// ─────────────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.tone = _Tone.neutral});
  final String message;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, border, color, icon) = switch (tone) {
      _Tone.warning => (_C.warnBg,    _C.warnBorder,    _C.warnText,    Icons.info_outline_rounded),
      _Tone.error   => (_C.errBg,     _C.errBorder,     _C.errText,     Icons.error_outline_rounded),
      _Tone.neutral => (Colors.white, _C.neutralBorder, _C.neutralText, Icons.cloud_done_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: _T.bannerText.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.cardH});
  final double cardH;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardH + 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Container(
          width: 188,
          height: cardH,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                height: 116,
                decoration: const BoxDecoration(
                  color: _C.skeletonDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Bar(h: 13, w: 110, color: _C.skeletonDark),
                    const SizedBox(height: 9),
                    _Bar(h: 10, w: 80,  color: _C.skeletonLight),
                    const SizedBox(height: 13),
                    _Bar(h: 10, w: double.infinity, color: _C.skeletonLight),
                    const SizedBox(height: 7),
                    _Bar(h: 10, w: 120, color: _C.skeletonLight),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.h, required this.w, required this.color});
  final double h, w;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: h,
        width: w,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}