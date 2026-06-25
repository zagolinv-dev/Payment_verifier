import 'package:intl/intl.dart';

/// T's Verify — Currency & Date Formatters
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _etbFormatter = NumberFormat.currency(
    locale: 'en_ET',
    symbol: 'ETB ',
    decimalDigits: 2,
  );

  static final NumberFormat _etbCompactFormatter = NumberFormat.compact(
    locale: 'en',
  );

  static final DateFormat _dateFull = DateFormat('MMM d, yyyy');
  static final DateFormat _dateShort = DateFormat('dd/MM/yy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy · HH:mm');
  static final DateFormat _timeOnly = DateFormat('HH:mm');

  /// Format a double as ETB currency (e.g. "ETB 1,500.00")
  static String formatETB(double amount) {
    return _etbFormatter.format(amount);
  }

  /// Format a double as compact ETB (e.g. "1.5K")
  static String formatETBCompact(double amount) {
    return 'ETB ${_etbCompactFormatter.format(amount)}';
  }

  /// Format a DateTime to full date (e.g. "Jun 24, 2026")
  static String formatDate(DateTime date) {
    return _dateFull.format(date);
  }

  /// Format a DateTime to short date (e.g. "24/06/26")
  static String formatDateShort(DateTime date) {
    return _dateShort.format(date);
  }

  /// Format a DateTime to full date+time (e.g. "Jun 24, 2026 · 15:30")
  static String formatDateTime(DateTime date) {
    return _dateTime.format(date);
  }

  /// Format a DateTime to time only (e.g. "15:30")
  static String formatTime(DateTime date) {
    return _timeOnly.format(date);
  }
}
