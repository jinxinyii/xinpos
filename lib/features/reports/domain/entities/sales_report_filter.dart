class SalesReportFilter {
  final DateTime startDate;
  final DateTime endDate;

  SalesReportFilter({required DateTime startDate, required DateTime endDate})
    : startDate = DateTime(startDate.year, startDate.month, startDate.day),
      endDate = DateTime(endDate.year, endDate.month, endDate.day) {
    if (this.endDate.isBefore(this.startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }
  }

  int get startTimestamp => startDate.millisecondsSinceEpoch;

  int get endExclusiveTimestamp => DateTime(
    endDate.year,
    endDate.month,
    endDate.day + 1,
  ).millisecondsSinceEpoch;

  @override
  bool operator ==(Object other) =>
      other is SalesReportFilter &&
      other.startDate == startDate &&
      other.endDate == endDate;

  @override
  int get hashCode => Object.hash(startDate, endDate);
}
