import 'package:flutter/material.dart';
import '../constants/university_constants.dart';

/// A compact, reusable badge that displays the user's university affiliation.
/// Shows the university short name with its brand color.
/// If [universityId] is empty or not found, the widget renders nothing.
class UniversityBadge extends StatelessWidget {
  final String universityId;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  const UniversityBadge({
    super.key,
    required this.universityId,
    this.fontSize = 10,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (universityId.isEmpty) return const SizedBox.shrink();

    final uni = UniversityConstants.getById(universityId);
    if (uni == null) return const SizedBox.shrink();

    final color = Color(uni.colorValue);

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            uni.badgePath,
            width: fontSize * 1.5,
            height: fontSize * 1.5,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),
          Text(
            uni.shortName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
