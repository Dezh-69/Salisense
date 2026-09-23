import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/constants.dart';
import '../models/salinity_reading.dart';
import '../models/system_status.dart';
import '../models/preset.dart';
import '../models/alert.dart';

/// Handles all real-time data streaming from Firebase RTDB
/// Strictly READ-ONLY per PRD FR-10
class RealtimeService {
  final String deviceCode;

  RealtimeService({required this.deviceCode});

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

  /// Stream for the live salinity reading (FR-01)
  Stream<SalinityReading?> streamCurrentSalinity() {
    return _db.ref(AppConstants.pathCurrentSalinity(deviceCode)).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return SalinityReading.fromJson(data, event.snapshot.key ?? '');
      } catch (e) {
        return null;
      }
    });
  }

  /// Stream for the active preset (FR-02, FR-04)
  Stream<Preset> streamActivePreset() {
    return _db.ref(AppConstants.pathActivePreset(deviceCode)).onValue.map((event) {
      if (event.snapshot.value == null) return Preset(name: 'No Preset', minPpt: 0, maxPpt: 0);
      try {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return Preset.fromJson(data);
      } catch (e) {
        return Preset(name: 'Error', minPpt: 0, maxPpt: 0);
      }
    });
  }

  /// Stream for system status (FR-03)
  Stream<SystemStatus> streamSystemStatus() {
    return _db.ref(AppConstants.pathSystemStatus(deviceCode)).onValue.map((event) {
       if (event.snapshot.value == null) return SystemStatus();
       try {
         final data = event.snapshot.value as Map<dynamic, dynamic>;
         return SystemStatus.fromJson(data);
       } catch (e) {
         return SystemStatus();
       }
    });
  }

  /// Stream for the historical logs (FR-05, FT-07)
  Stream<List<SalinityReading>> streamSalinityLogs() {
    return _db.ref(AppConstants.pathSalinityLogs(deviceCode))
        .orderByChild('timestamp')
        .limitToLast(AppConstants.maxLogsToDisplay)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      try {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        List<SalinityReading> logs = data.entries
            .map((e) => SalinityReading.fromJson(e.value as Map<dynamic, dynamic>, e.key.toString()))
            .toList();
        // Sort descending (newest first)
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return logs;
      } catch (e) {
        return [];
      }
    });
  }

  /// Stream for active alerts (FR-06, FR-07, FR-08, FR-09)
  Stream<List<Alert>> streamAlerts() {
    return _db.ref(AppConstants.pathAlerts(deviceCode)).onValue.map((event) {
      if (event.snapshot.value == null) return [];
      try {
         final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
         List<Alert> alerts = data.entries
            .map((e) => Alert.fromJson(e.value as Map<dynamic, dynamic>, e.key.toString()))
            .where((alert) => alert.isActive)
            .toList();
         return alerts;
      } catch (e) {
        return [];
      }
    });
  }

  /// Stream for historical alert logs
  Stream<List<Alert>> streamAlertLogs() {
    return _db.ref(AppConstants.pathAlertLogs(deviceCode))
        .orderByChild('timestamp')
        .limitToLast(100)
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      try {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        List<Alert> logs = data.entries
            .map((e) => Alert.fromJson(e.value as Map<dynamic, dynamic>, e.key.toString()))
            .toList();
        // Sort descending (newest first)
        logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return logs;
      } catch (e) {
        return [];
      }
    });
  }
}
