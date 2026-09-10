import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gdzs_calc/features/history/models/team_report_data.dart';
import 'package:gdzs_calc/features/history/services/report_filename.dart';
import 'package:gdzs_calc/features/history/services/team_pdf_report_service.dart';
import 'package:gdzs_calc/features/team/repositories/team_session_repository.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class TeamReportPreviewPage extends StatefulWidget {
  final int sessionId;
  final TeamSessionRepository? repository;
  final TeamPdfReportService? reportService;
  const TeamReportPreviewPage({
    super.key,
    required this.sessionId,
    this.repository,
    this.reportService,
  });
  @override
  State<TeamReportPreviewPage> createState() => _TeamReportPreviewPageState();
}

class _TeamReportPreviewPageState extends State<TeamReportPreviewPage> {
  late final TeamSessionRepository _repository;
  late final TeamPdfReportService _service;
  Uint8List? _bytes;
  String? _filename;
  bool _loading = true;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? const TeamSessionRepository();
    _service = widget.reportService ?? TeamPdfReportService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final record = await _repository.getById(widget.sessionId);
      if (record == null) throw StateError('Session not found');
      final data = TeamReportData.fromSession(record.session);
      final bytes = await _service.generate(data);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _filename = teamReportFilename(
          inclusionTime: data.session.inclusionTime,
          unitName: data.unitName,
        );
        _loading = false;
      });
    } catch (error, stackTrace) {
      if (kDebugMode) debugPrint('PDF report error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('PDF-звіт')),
    body: _loading
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Формування PDF-звіту…'),
              ],
            ),
          )
        : _failed
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Не вдалося сформувати PDF-звіт'),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Повторити')),
              ],
            ),
          )
        : PdfPreview(
            build: (_) async => _bytes!,
            initialPageFormat: PdfPageFormat.a4,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            allowPrinting: true,
            allowSharing: true,
            pdfFileName: _filename!,
          ),
  );
}
