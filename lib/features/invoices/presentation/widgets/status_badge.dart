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
        bgColor = AppTheme.zinc300;
        textColor = AppTheme.zinc900;
        break;
      case 'approved':
      case 'paid':
        bgColor = AppTheme.success.withOpacity(0.2);
        textColor = AppTheme.success;
        break;
      case 'draft':
        bgColor = AppTheme.zinc200;
        textColor = AppTheme.zinc800;
        break;
      case 'rejected':
      case 'overdue':
      case 'cancelled':
        bgColor = AppTheme.danger.withOpacity(0.2);
        textColor = AppTheme.danger;
        break;
      default:
        bgColor = AppTheme.zinc200;
        textColor = AppTheme.zinc800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
