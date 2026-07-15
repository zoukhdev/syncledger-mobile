import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'pending_approval':
      case 'pending_payment':
      case 'pending_review':
        bgColor = AppTheme.orange.withOpacity(0.12);
        textColor = AppTheme.orange;
        break;
      case 'approved':
      case 'paid':
        bgColor = AppTheme.emerald.withOpacity(0.12);
        textColor = AppTheme.emerald;
        break;
      case 'draft':
        bgColor = AppTheme.surfaceContainerHigh;
        textColor = AppTheme.onSurfaceVariant;
        break;
      case 'rejected':
      case 'overdue':
      case 'cancelled':
        bgColor = AppTheme.error.withOpacity(0.12);
        textColor = AppTheme.error;
        break;
      default:
        bgColor = AppTheme.surfaceContainer;
        textColor = AppTheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999), // pill shape
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
