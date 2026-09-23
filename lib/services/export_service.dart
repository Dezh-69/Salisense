import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/salinity_reading.dart';

/// Handles exporting salinity logs to CSV (Recommendation 7)
class ExportService {
  
  /// Generates a CSV file from a list of readings and shares it
  static Future<void> exportLogsToCsv(List<SalinityReading> logs) async {
    if (logs.isEmpty) return;

    try {
      // Prepare CSV data
      List<List<dynamic>> csvData = [
        ['Timestamp', 'Salinity (ppt)'],
      ];

      final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      
      for (var reading in logs) {
        csvData.add([
          formatter.format(reading.timestamp),
          reading.ppt.toStringAsFixed(2),
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      // Save file temporarily
      final directory = await getTemporaryDirectory();
      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final path = '${directory.path}/salisense_logs_$dateStr.csv';
      
      final File file = File(path);
      await file.writeAsString(csvString);

      // Share the file
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(path)], 
        text: 'SaliSense Log Export - $dateStr'
      );
      
    } catch (e) {
      debugPrint('Error exporting CSV: $e');
      // Could show a snackbar or alert here if context was passed
    }
  }
}
