import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart'; // Add this import for ByteData
import '../models/model.dart';
import '../services/storage_service.dart';
import './detaildistresslog.dart';
import '../services/apis.dart';

class DistressLogScreen extends StatefulWidget {
  const DistressLogScreen({super.key});

  @override
  State<DistressLogScreen> createState() => _DistressLogScreenState();
}

class _DistressLogScreenState extends State<DistressLogScreen> {
  List<RAMSDataPost> logs = [];
  String selectedTypeFilter = 'All';
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await StorageService.loadRAMSDataPosts();
    setState(() => logs = data);
  }

  Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      if (await downloads.exists()) return downloads;
      final extDir = await getExternalStorageDirectory();
      return extDir ?? await getApplicationDocumentsDirectory();
    }
    return await getApplicationDocumentsDirectory();
  }

  List<List<String>> _prepareTableData() {
    return [
      ['Location', 'Date', 'Unit', 'Area', 'Dimensions', 'Image Path'],
      ...logs.map(
        (log) => [
          'Lat: ${log.longitude}, Lon: ${log.longitude}', // Location updated to use lat/long
          log.timestamp.toLowerCase().toString().split(' ')[0], // Date
          log.unit, // Unit
          log.area.(', '), // Area
          log.dimensions.join(', '), // Added Dimensions field
          log.imagePath// Image Path (now using `distressImageId`)
        ],
      ),
    ];
  }

  Future<Uint8List?> _loadImageBytes(String imagePath) async {
    try {
      if (imagePath.isEmpty) return null;
      final file = File(imagePath);
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (e) {
      return null;
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
    );
  }

  void _hideLoadingDialog() {
    if (isExporting) {
      Navigator.of(context).pop();
      setState(() => isExporting = false);
    }
  }

  Future<void> _showPreviewDialog() async {
    if (logs.isEmpty) {
      _showSnackBar('No data to preview', Colors.orange);
      return;
    }

    final tableData = _prepareTableData();
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Export Preview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          border: TableBorder.all(color: Colors.grey),
                          columnSpacing: 12,
                          columns:
                              tableData[0]
                                  .map(
                                    (header) => DataColumn(
                                      label: Text(
                                        header,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          rows:
                              tableData
                                  .skip(1)
                                  .map(
                                    (row) => DataRow(
                                      cells:
                                          row
                                              .map(
                                                (cell) => DataCell(
                                                  Text(
                                                    cell.length > 20
                                                        ? '${cell.substring(0, 20)}...'
                                                        : cell,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.table_chart),
                        label: const Text('CSV'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exportToCSV();
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.grid_on),
                        label: const Text('Excel'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exportToExcel();
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _exportToPDF();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _exportData() async {
    if (logs.isEmpty) {
      _showSnackBar('No data to export', Colors.orange);
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Export Distress Logs"),
            content: Text("Export ${logs.length} records to file"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showPreviewDialog();
                },
                child: const Text("Preview & Export"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _exportToCSV();
                },
                child: const Text("Quick CSV"),
              ),
            ],
          ),
    );
  }

  Future<void> _exportToCSV() async {
    setState(() => isExporting = true);
    _showLoadingDialog('Exporting to CSV...');

    try {
      final tableData = _prepareTableData();
      final csvData = const ListToCsvConverter().convert(tableData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          '${(await _getExportDirectory()).path}/distress_logs_$timestamp.csv';

      await File(path).writeAsString(csvData);
      _hideLoadingDialog();
      _showExportSuccess(path, await File(path).length());
    } catch (e) {
      _hideLoadingDialog();
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => isExporting = true);
    _showLoadingDialog('Exporting to Excel...');

    try {
      final excelFile = excel.Excel.createExcel();
      if (excelFile.sheets.containsKey('Sheet1')) excelFile.delete('Sheet1');
      final sheet = excelFile['Distress Logs'];
      final tableData = _prepareTableData();

      // Add headers
      for (int i = 0; i < tableData[0].length; i++) {
        final cell = sheet.cell(
          excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = tableData[0][i];
        cell.cellStyle = excel.CellStyle(
          bold: true,
          backgroundColorHex: "#D9D9D9",
        );
      }

      // Add data
      for (int rowIndex = 1; rowIndex < tableData.length; rowIndex++) {
        for (
          int colIndex = 0;
          colIndex < tableData[rowIndex].length;
          colIndex++
        ) {
          sheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex,
                ),
              )
              .value = tableData[rowIndex][colIndex];
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          '${(await _getExportDirectory()).path}/distress_logs_$timestamp.xlsx';
      final excelBytes = excelFile.encode();

      if (excelBytes != null) {
        await File(path).writeAsBytes(excelBytes);
        _hideLoadingDialog();
        _showExportSuccess(path, await File(path).length());
      } else {
        _hideLoadingDialog();
        _showSnackBar('Failed to encode Excel file', Colors.red);
      }
    } catch (e) {
      _hideLoadingDialog();
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  Future<void> _exportToPDF() async {
    setState(() => isExporting = true);
    _showLoadingDialog('Exporting to PDF...');

    try {
      final pdf = pw.Document();

      // Fix 1: Get font as ByteData instead of Uint8List
      final fontData = await _getDefaultFont();
      pw.Font? font;
      if (fontData.lengthInBytes > 0) {
        font = pw.Font.ttf(fontData);
      }

      // Fix 2: Make the build function async and handle image loading properly
      final pdfWidgets = await _buildPdfContent();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme:
              font != null ? pw.ThemeData.withFont(base: font) : pw.ThemeData(),
          build: (pw.Context context) => pdfWidgets,
        ),
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path =
          '${(await _getExportDirectory()).path}/distress_logs_$timestamp.pdf';
      await File(path).writeAsBytes(await pdf.save());

      _hideLoadingDialog();
      _showExportSuccess(path, await File(path).length());
    } catch (e) {
      _hideLoadingDialog();
      _showSnackBar('Export failed: $e', Colors.red);
    }
  }

  // Fix 2: Create a separate async function to build PDF content
  Future<List<pw.Widget>> _buildPdfContent() async {
    final widgets = <pw.Widget>[
      pw.Header(
        level: 0,
        child: pw.Text(
          'Distress Logs Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Paragraph(
        text: 'Generated: ${DateTime.now().toLocal().toString().split('.')[0]}',
        style: const pw.TextStyle(fontSize: 12),
      ),
      pw.Paragraph(
        text: 'Total Records: ${logs.length}',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 20),
    ];

    for (int i = 0; i < logs.length; i++) {
      final log = logs[i];
      final imageBytes = await _loadImageBytes(log.imagePath ?? '');

      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Record ${i + 1}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  _buildTableRow(
                    'Location:',
                    '${log.longitude}, ${log.longitude}',
                  ),
                  _buildTableRow(
                    'Date:',
                    log.timestamp.toLocal().toString().split(' ')[0],
                  ),
                  _buildTableRow('Unit:', log.unit),
                  _buildTableRow('Area:', log.area.join(', ')),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Image:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              imageBytes != null
                  ? pw.Container(
                    height: 200,
                    width: double.infinity,
                    child: pw.Image(
                      pw.MemoryImage(imageBytes),
                      fit: pw.BoxFit.contain,
                    ),
                  )
                  : pw.Container(
                    height: 100,
                    width: double.infinity,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey200,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'No Image Available',
                        style: pw.TextStyle(
                          color: PdfColors.grey600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(value)),
      ],
    );
  }

  // Fix 1: Return ByteData instead of Uint8List
  Future<ByteData> _getDefaultFont() async {
    try {
      // Try to load a system font, fallback to empty ByteData if not available
      return await rootBundle.load('fonts/Roboto-Regular.ttf');
    } catch (e) {
      // Return empty ByteData if no font is available
      return ByteData(0);
    }
  }

  void _showExportSuccess(String path, int fileSize) {
    final sizeKB = (fileSize / 1024).toStringAsFixed(1);
    _showSnackBar(
      '✅ Export successful!\nFile: ${path.split('/').last}\nSize: ${sizeKB}KB',
      Colors.green,
      duration: 6,
    );
  }

  void _showSnackBar(String message, Color color, {int duration = 4}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: duration),
        action:
            color == Colors.green
                ? SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                )
                : null,
      ),
    );
  }

  Future<void> _deleteLog(RAMSDataPost log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Log'),
            content: Text('Delete this ${log.distressType} log?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await StorageService.deleteRAMSDataPostById(log.id);
      setState(() => logs.removeWhere((m) => m.id == log.id));
      _showSnackBar('✅ Log deleted successfully', Colors.green);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        logs.where((log) {
            if (selectedTypeFilter == 'All') return true;
            final type = log.distressType.toLowerCase();
            return (selectedTypeFilter == 'Flexible' &&
                    type.contains('flexible')) ||
                (selectedTypeFilter == 'Rigid' && type.contains('rigid'));
          }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: Text('Distress Logs (${logs.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _showPreviewDialog,
            tooltip: 'Preview Data',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportData,
            tooltip: 'Export Data',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                const Text(
                  'Filter by Type:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedTypeFilter,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Types')),
                      DropdownMenuItem(
                        value: 'Flexible',
                        child: Text('Flexible'),
                      ),
                      DropdownMenuItem(value: 'Rigid', child: Text('Rigid')),
                    ],
                    onChanged:
                        (val) => setState(() => selectedTypeFilter = val!),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Showing: ${filtered.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            logs.isEmpty
                                ? 'No distress logs found'
                                : 'No logs match the current filter',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            logs.isEmpty
                                ? 'Start by adding some measurements'
                                : 'Try changing the filter or add more logs',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final log = filtered[i];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blueGrey,
                              child: Icon(
                                log.distressType.toLowerCase().contains(
                                      'pothole',
                                    )
                                    ? Icons.circle
                                    : Icons.line_weight,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              log.distressType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('📍 Lat: ${log.lat}, Lon: ${log.long}'),
                                const SizedBox(height: 2),
                                Text(
                                  '📅 ${log.timestamp.toLocal().toString().split(' ')[0]} • 📏 ${log.volume?.toStringAsFixed(1) ?? 'N/A'} ${log.unit}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteLog(log),
                            ),
                            onTap:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) =>
                                            DetailDistressLog(measurement: log),
                                  ),
                                ).then((_) => _loadLogs()),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
