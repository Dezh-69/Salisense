import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Handles Firebase initialization and single-account authentication
/// per PRD FR-10 and Section 6
class FirebaseService {
  // Use a singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseDatabase get _database => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app',
      );
  
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes Firebase
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp();
      
      // Optional: configure offline persistence if needed
      _database.setPersistenceEnabled(true);
      
      _isInitialized = true;
      if (kDebugMode) {
        print('Firebase initialized successfully.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase: $e');
      }
    }
  }

  // --- Auth Methods ---
  
  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email, 
      password: password
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Stream to monitor Firebase connection state (.info/connected)
  Stream<bool> get connectionStateStream {
    return _database.ref('.info/connected').onValue.map((event) {
      return (event.snapshot.value as bool?) ?? false;
    });
  }
}
