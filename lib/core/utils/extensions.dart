extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$ellipsis';
  }
}

extension IntExtension on int {
  String toXpString() => '$this XP';
  String toDurationString() {
    final m = this ~/ 60;
    final s = this % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }
}

extension DoubleExtension on double {
  String toPercentString({int decimals = 0}) {
    return '${(this * 100).toStringAsFixed(decimals)}%';
  }
}
