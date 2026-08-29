import 'package:flutter/material.dart';

/// An outlined, tappable tile used for single-select option groups
/// (Marital Status, Trading Experience, Occupation, Annual Income, etc).
/// Selected state gets a solid white border + white text, matching the
/// "Single" tile look in the Experience & Confirmation screenshot.
class SelectableTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectableTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected ? Colors.white.withOpacity(0.06) : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }
}