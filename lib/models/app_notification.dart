import 'package:flutter/material.dart';

class AppNotification {
  final int? id;
  final String title;
  final String subtitle;
  final String type; // 'PLAN_DUE', 'POCKET_OVER_BUDGET', 'BACKUP_SUCCESS', 'BACKUP_FAILED', 'RESTORE_SUCCESS', 'RESTORE_FAILED', etc.
  final bool isRead;
  final DateTime createdAt;

  // Optional dynamically attached data (e.g., plan id, pocket id, etc.)
  final Map<String, dynamic>? payload;

  AppNotification({
    this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.isRead = false,
    required this.createdAt,
    this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      type: map['type'],
      isRead: map['is_read'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  /// UI Helpers
  IconData get icon {
    switch (type) {
      case 'PLAN_DUE':
        return Icons.warning_rounded;
      case 'PLAN_WARNING':
        return Icons.access_time_rounded;
      case 'POCKET_OVER_BUDGET':
        return Icons.account_balance_wallet_rounded;
      case 'BACKUP_SUCCESS':
      case 'RESTORE_SUCCESS':
        return Icons.check_circle_outline_rounded;
      case 'BACKUP_FAILED':
      case 'RESTORE_FAILED':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'PLAN_DUE':
      case 'POCKET_OVER_BUDGET':
      case 'BACKUP_FAILED':
      case 'RESTORE_FAILED':
        return const Color(0xFFE53935); // Red
      case 'PLAN_WARNING':
        return const Color(0xFFF57C00); // Orange
      case 'BACKUP_SUCCESS':
      case 'RESTORE_SUCCESS':
        return const Color(0xFF43A047); // Green
      default:
        return const Color(0xFF0066FF); // Blue
    }
  }

  Color get backgroundColor {
    switch (type) {
      case 'PLAN_DUE':
      case 'POCKET_OVER_BUDGET':
      case 'BACKUP_FAILED':
      case 'RESTORE_FAILED':
        return const Color(0xFFFFEBEE); // Soft Red
      case 'PLAN_WARNING':
        return const Color(0xFFFFF3E0); // Soft Orange
      case 'BACKUP_SUCCESS':
      case 'RESTORE_SUCCESS':
        return const Color(0xFFE8F5E9); // Soft Green
      default:
        return const Color(0xFFE5F0FF); // Soft Blue
    }
  }
}
