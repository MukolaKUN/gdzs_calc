String teamReportFilename({
  required DateTime inclusionTime,
  required String unitName,
}) {
  String two(int value) => value.toString().padLeft(2, '0');
  var safe = unitName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  safe = safe.replaceAll(RegExp(r'\s+'), '_');
  if (safe.length > 48) safe = safe.substring(0, 48);
  if (safe.isEmpty) safe = 'unit';
  return 'GDZS_${inclusionTime.year}-${two(inclusionTime.month)}-'
      '${two(inclusionTime.day)}_${two(inclusionTime.hour)}-'
      '${two(inclusionTime.minute)}_$safe.pdf';
}
