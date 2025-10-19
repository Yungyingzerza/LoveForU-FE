import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves API-relative image URLs into absolute URLs using the configured base.
String resolvePhotoUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  final base = dotenv.env['API_BASE_URL'];
  if (base == null || base.isEmpty) {
    return url;
  }
  return '$base$url';
}

/// Formats a timestamp into a short, human-friendly label.
String formatElapsedTime(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inSeconds < 60) {
    final seconds = difference.inSeconds.clamp(1, 59);
    return seconds == 1 ? '1 sec ago' : '$seconds secs ago';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return minutes == 1 ? '1 min ago' : '$minutes mins ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  }

  final DateTime local = timestamp.toLocal();
  final String month = _monthName(local.month);
  return '$month ${local.day}, ${local.year}';
}

/// Formats a timestamp into a short relative label used in conversation lists.
String formatRelativeTime(DateTime timestamp) {
  final now = DateTime.now().toUtc();
  final value = timestamp.toUtc();
  final difference = now.difference(value);

  if (difference.inSeconds < 60) {
    return 'now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  return '${value.month}/${value.day}';
}

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > months.length) {
    return '';
  }
  return months[month - 1];
}
