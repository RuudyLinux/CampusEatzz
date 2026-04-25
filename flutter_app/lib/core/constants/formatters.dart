import 'package:intl/intl.dart';

final _currencyFormatter = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String formatInr(num value) => _currencyFormatter.format(value);

String formatDate(DateTime? value) {
  if (value == null) {
    return 'N/A';
  }
  return DateFormat('dd MMM yyyy').format(value.toLocal());
}

String formatDateTime(DateTime? value) {
  if (value == null) {
    return 'N/A';
  }
  return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
}

String titleCase(String value) {
  final text = value.trim();
  if (text.isEmpty) {
    return '';
  }
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}
