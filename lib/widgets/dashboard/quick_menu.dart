import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../app_card.dart';

class ExpandableQuickMenu extends StatelessWidget {
  const ExpandableQuickMenu({
    super.key,
    required this.selectedIndex,
    required this.onMenuTap,
    required this.onOpenQuickAdd,
  });

  final int selectedIndex;
  final ValueChanged<int> onMenuTap;
  final VoidCallback onOpenQuickAdd;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 32;

    return SizedBox(
      width: maxWidth,
      height: 100,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: maxWidth,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                QuickNavItem(
                  icon: Icons.home_rounded,
                  semanticLabel: 'Beranda',
                  selected: selectedIndex == 0,
                  onTap: () => onMenuTap(0),
                ),
                QuickNavItem(
                  icon: Icons.swap_horiz_rounded,
                  semanticLabel: 'Transaksi',
                  selected: selectedIndex == 1,
                  onTap: () => onMenuTap(1),
                ),
                const SizedBox(width: 74),
                QuickNavItem(
                  icon: Icons.shopping_cart_outlined,
                  semanticLabel: 'Daftar Belanja',
                  selected: selectedIndex == 2,
                  onTap: () => onMenuTap(2),
                ),
                QuickNavItem(
                  icon: Icons.settings_outlined,
                  semanticLabel: 'Pengaturan',
                  selected: selectedIndex == 3,
                  onTap: () => onMenuTap(3),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: FloatingQuickAddButton(onTap: onOpenQuickAdd),
          ),
        ],
      ),
    );
  }
}

class FloatingQuickAddButton extends StatelessWidget {
  const FloatingQuickAddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppTheme.fabBgColor,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 28,
          color: AppTheme.fabIconColor,
        ),
      ),
    );
  }
}

class QuickAddSheetItem extends StatelessWidget {
  const QuickAddSheetItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final themeTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final themeSubtitleColor = Theme.of(context).textTheme.bodySmall?.color;

    return AppCard(
      isInteractive: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
              border: Theme.of(
                context,
              ).extension<AppThemeExtension>()?.cardBorder,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: themeTextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: themeSubtitleColor),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: themeTextColor),
        ],
      ),
    );
  }
}

class QuickNavItem extends StatefulWidget {
  const QuickNavItem({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<QuickNavItem> createState() => _QuickNavItemState();
}

class _QuickNavItemState extends State<QuickNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.selected;
    final activeColor = theme.brightness == Brightness.dark 
        ? Colors.white 
        : Colors.black;
    final iconColor = isSelected
        ? activeColor
        : theme.iconTheme.color ?? AppTheme.borderColor;

    return Expanded(
      child: Semantics(
        label: widget.semanticLabel,
        button: true,
        selected: isSelected,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          scale: _isPressed ? 0.93 : 1,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (_isPressed == value) return;
              setState(() => _isPressed = value);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 48 : 40,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(widget.icon, size: 20, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
