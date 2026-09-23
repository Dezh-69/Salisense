import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';

/// Manages device registration, selection, and persistence.
/// Devices are stored in Firebase under users/{uid}/devices.
/// The active device selection is stored locally in SharedPreferences.
class DeviceService {
  static const String _activeDeviceKey = 'active_device_code';

  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DatabaseReference _userDevicesRef() {
    final uid = _uid;
    if (uid == null) throw Exception('User not authenticated');
    return _db.ref('users/$uid/devices');
  }

  /// Get all registered devices from Firebase
  Future<List<Device>> getRegisteredDevices() async {
    try {
      final snapshot = await _userDevicesRef().get();
      if (!snapshot.exists || snapshot.value == null) return [];

      final data = snapshot.value as Map<dynamic, dynamic>;
      return data.entries.map((entry) {
        final code = entry.key as String;
        final name = (entry.value as Map<dynamic, dynamic>)['name'] as String? ?? code;
        return Device(code: code, name: name);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Register a new device and save to Firebase under user account
  Future<void> registerDevice(String code, String name) async {
    await _userDevicesRef().child(code).set({'name': name});
    
    // If this is the first device, set it as active automatically
    final devices = await getRegisteredDevices();
    if (devices.length == 1) {
      await setActiveDevice(code);
    }
  }

  /// Remove a device from user's account in Firebase
  Future<void> removeDevice(String code) async {
    await _userDevicesRef().child(code).remove();

    // If the removed device was active, clear or switch
    final activeCode = await getActiveDeviceCode();
    if (activeCode == code) {
      final devices = await getRegisteredDevices();
      if (devices.isNotEmpty) {
        await setActiveDevice(devices.first.code);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_activeDeviceKey);
      }
    }
  }

  /// Rename a device
  Future<void> renameDevice(String code, String newName) async {
    await _userDevicesRef().child(code).update({'name': newName});
  }

  /// Get the currently active device code (stored locally)
  Future<String?> getActiveDeviceCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeDeviceKey);
  }

  /// Get the currently active device
  Future<Device?> getActiveDevice() async {
    final code = await getActiveDeviceCode();
    if (code == null) return null;
    final devices = await getRegisteredDevices();
    try {
      return devices.firstWhere((d) => d.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Set the active device (stored locally)
  Future<void> setActiveDevice(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeDeviceKey, code);
  }

  /// Validate that a device code exists in Firebase RTDB
  /// Checks if `devices/{code}/info` exists
  Future<bool> validateDeviceCode(String code) async {
    try {
      final snapshot = await _db.ref('devices/$code/info').get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }
}
