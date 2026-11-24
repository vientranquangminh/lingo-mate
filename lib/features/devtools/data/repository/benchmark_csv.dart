import '../model/benchmark_models.dart';

/// Writes benchmark rows as RFC 4180 CSV.
abstract final class BenchmarkCsv {
  /// Returns the CSV text with a header line.
  static String encode(Iterable<BenchmarkRow> rows) {
    final buffer = StringBuffer()..writeln(_line(BenchmarkRow.header));
    for (final row in rows) {
      buffer.writeln(_line(row.toCells()));
    }
    return buffer.toString();
  }

  /// Joins cells into one CSV line.
  static String _line(List<Object?> cells) => cells.map(_cell).join(',');

  /// Quotes a cell when it holds a comma, quote or line break.
  static String _cell(Object? value) {
    final text = value?.toString() ?? '';
    if (!text.contains(RegExp(r'[",\r\n]'))) {
      return text;
    }
    return '"${text.replaceAll('"', '""')}"';
  }
}
