import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/billing_service.dart';

class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({
    super.key,
    this.headline,
    this.subhead,
    this.scanLimit = 3,
    this.scansUsed,
  });

  final String? headline;
  final String? subhead;
  final int scanLimit;
  final int? scansUsed;

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  int _selectedPlanIndex = 1;

  @override
  void initState() {
    super.initState();
    BillingService.instance.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final headline = widget.headline ?? 'Unlock Premium Scans';
    final subhead = widget.subhead ??
        'Get unlimited identifications, priority processing, and rich care insights.';
    final scansUsed = widget.scansUsed;
    final scanLimit = widget.scanLimit;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F0C),
      body: Stack(
        children: [
          const _PaywallBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF132C1B),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFF2F6B42)),
                        ),
                        child: Text(
                          'Premium',
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF9BE7B0),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ValueListenableBuilder<BillingState>(
                    valueListenable: BillingService.instance.state,
                    builder: (context, billingState, _) {
                      final monthlyProduct = BillingService.instance.monthlyProduct;
                      final yearlyProduct = BillingService.instance.yearlyProduct;
                      final productsReady = monthlyProduct != null || yearlyProduct != null;

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        children: [
                      const SizedBox(height: 12),
                      Text(
                        headline,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subhead,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      if (scansUsed != null) ...[
                        const SizedBox(height: 16),
                        _UsageMeter(scansUsed: scansUsed, scanLimit: scanLimit),
                      ],
                      if (billingState.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _InfoBanner(message: billingState.errorMessage!),
                      ],
                      const SizedBox(height: 24),
                      _BenefitTile(
                        title: 'Unlimited scans',
                        subtitle: 'Identify plants as often as you need without waiting.',
                        icon: Icons.all_inclusive,
                      ),
                      const SizedBox(height: 12),
                      _BenefitTile(
                        title: 'Priority processing',
                        subtitle: 'Jump the queue with faster recognition results.',
                        icon: Icons.bolt,
                      ),
                      const SizedBox(height: 12),
                      _BenefitTile(
                        title: 'Deep care insights',
                        subtitle: 'Seasonal care guidance, issues, and reminders.',
                        icon: Icons.spa_outlined,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Choose your plan',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (billingState.isLoading)
                        const _LoadingCard()
                      else if (!productsReady) ...[
                        _PlanOption(
                          title: 'Monthly',
                          price: '\$3.99',
                          note: 'Billed every month, cancel anytime.',
                          isSelected: _selectedPlanIndex == 0,
                          badge: 'Flexible',
                          onTap: () => setState(() => _selectedPlanIndex = 0),
                        ),
                        const SizedBox(height: 12),
                        _PlanOption(
                          title: 'Yearly',
                          price: '\$24.99',
                          note: 'Best value, 2 months free.',
                          isSelected: _selectedPlanIndex == 1,
                          badge: 'Best value',
                          onTap: () => setState(() => _selectedPlanIndex = 1),
                        ),
                      ] else ...[
                        if (monthlyProduct != null)
                          _PlanOption(
                            title: 'Monthly',
                            price: monthlyProduct.price,
                            note: 'Billed every month, cancel anytime.',
                            isSelected: _selectedPlanIndex == 0,
                            badge: 'Flexible',
                            onTap: () => setState(() => _selectedPlanIndex = 0),
                          ),
                        if (monthlyProduct != null && yearlyProduct != null)
                          const SizedBox(height: 12),
                        if (yearlyProduct != null)
                          _PlanOption(
                            title: 'Yearly',
                            price: yearlyProduct.price,
                            note: 'Best value, 2 months free.',
                            isSelected: _selectedPlanIndex == 1,
                            badge: 'Best value',
                            onTap: () => setState(() => _selectedPlanIndex = 1),
                          ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: billingState.isLoading
                              ? null
                              : () async {
                                  final product = _selectedPlanIndex == 0
                                      ? monthlyProduct
                                      : yearlyProduct ?? monthlyProduct;
                                  if (product == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Plan unavailable right now.'),
                                      ),
                                    );
                                    return;
                                  }
                                  await BillingService.instance.purchase(product);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4AE28F),
                            foregroundColor: const Color(0xFF0A0F0C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Continue'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          await BillingService.instance.restorePurchases();
                        },
                        child: Text(
                          'Restore purchase',
                          style: GoogleFonts.inter(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Cancel anytime in your store settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                        ],
                      );
                    },
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

class _PaywallBackground extends StatelessWidget {
  const _PaywallBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0F0C), Color(0xFF0E1C14), Color(0xFF0B2415)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -60,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF3BFFD0), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF1F6F49), Color(0x00000000)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2F25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF132C1B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF7BE2A5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.4,
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

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.title,
    required this.price,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.badge,
  });

  final String title;
  final String price;
  final String note;
  final bool isSelected;
  final VoidCallback onTap;
  final String badge;

  @override
  Widget build(BuildContext context) {
    final highlightColor = isSelected ? const Color(0xFF4AE28F) : const Color(0xFF1C2A21);
    final background = isSelected ? const Color(0xFF14261C) : const Color(0xFF101613);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: highlightColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: highlightColor, width: 2),
                color: isSelected ? highlightColor : Colors.transparent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: highlightColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.inter(
                            color: highlightColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note,
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF151C18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF26352B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111A15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2F25)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Loading plans from Google Play...',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageMeter extends StatelessWidget {
  const _UsageMeter({
    required this.scansUsed,
    required this.scanLimit,
  });

  final int scansUsed;
  final int scanLimit;

  @override
  Widget build(BuildContext context) {
    final clampedUsed = scansUsed.clamp(0, scanLimit);
    final progress = scanLimit == 0 ? 1.0 : clampedUsed / scanLimit;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111A15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C2A21)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free scans used today',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF1C2A21),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF4AE28F)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$clampedUsed of $scanLimit daily scans used',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
