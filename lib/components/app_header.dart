import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final List<Widget>? leftActions;
  final List<Widget>? rightActions;

  const AppHeader({
    Key? key,
    required this.title,
    this.titleWidget,
    this.leftActions,
    this.rightActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF0FFF4),
      foregroundColor: const Color(0xFF1B1B1B),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      title: titleWidget ??
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF1B1B1B),
            ),
          ),
      leadingWidth: leftActions?.length == 1 ? 72 : null,
      leading: leftActions?.length == 1 ? leftActions![0] : null,
      actions: [
        if (leftActions?.length == 2) ...leftActions!,
        ...?rightActions,
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
