import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.textColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? const Color(0xFFA4DBB2))
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: selected
                ? (textColor ?? const Color(0xFF1F5A62))
                : Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }
}

class IconFilterButton extends StatelessWidget {
  const IconFilterButton({
    super.key,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.selectedColor,
    this.iconColor,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: selected
              ? (selectedColor ?? const Color(0xFFA4DBB2))
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected
              ? (iconColor ?? const Color(0xFF1F5A62))
              : Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }
}

class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.background,
    required this.iconBackground,
    required this.onTap,
    this.labelColor,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color iconBackground;
  final VoidCallback onTap;
  final Color? labelColor;
  final Color? iconColor;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      scale: _isPressed ? 0.98 : 1,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged: (value) {
          if (_isPressed == value) return;
          setState(() => _isPressed = value);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(10),
            border: Theme.of(
              context,
            ).extension<AppThemeExtension>()?.cardBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: widget.labelColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: widget.iconBackground,
                  borderRadius: BorderRadius.circular(4),
                  border: Theme.of(
                    context,
                  ).extension<AppThemeExtension>()?.cardBorder,
                ),
                child: Icon(widget.icon, size: 12, color: widget.iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          shape: BoxShape.circle,
          border: Theme.of(context).extension<AppThemeExtension>()?.cardBorder,
        ),
        child: Icon(icon, size: 16, color: Theme.of(context).iconTheme.color),
      ),
    );
  }
}
