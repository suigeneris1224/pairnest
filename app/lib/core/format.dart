import 'package:intl/intl.dart';

final _peso = NumberFormat.currency(locale: 'en_US', symbol: '₱', decimalDigits: 0);
final _pesoCents = NumberFormat.currency(locale: 'en_US', symbol: '₱', decimalDigits: 2);

String peso(num value, {bool cents = false}) => (cents ? _pesoCents : _peso).format(value);

String shortDate(DateTime d) => DateFormat('MMM d').format(d);
String longDate(DateTime d) => DateFormat('MMM d, yyyy').format(d);
String monthLabel(DateTime d) => DateFormat('MMMM yyyy').format(d);
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String timeLabel(DateTime d) => DateFormat('h:mm a').format(d);

DateTime monthStart(DateTime d) => DateTime(d.year, d.month);

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 12) return 'Good morning,';
  if (h < 18) return 'Good afternoon,';
  return 'Good evening,';
}

String monthShort(DateTime d) => DateFormat('MMM yyyy').format(d);

/// "Just now", "5m ago", "3h ago", "Yesterday", or a short date.
String relativeTime(DateTime at, [DateTime? now]) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return shortDate(at);
}
