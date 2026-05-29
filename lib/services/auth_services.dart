import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'local_storage_service.dart';

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userEmailKey = 'userEmail';
  static const String _currentUserIdKey = 'currentUserId';

  static SharedPreferences? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!Hive.isBoxOpen('user_profiles')) {
      await LocalStorageService.initialize();
    }
  }

  Future<bool> isUserLoggedIn() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
    final currentId = prefs.getString(_currentUserIdKey);
    if (!isLoggedIn || currentId == null) {
      return false;
    }
    return LocalStorageService.getUserProfile(currentId) != null;
  }

  Future<String?> login({
    required String email,
    required String password,
    bool rememberMe = true,         // receive boolean form login screen
  }) async {
    // Validate input
    if (email.trim().isEmpty || password.trim().isEmpty) {
      return null;
    }

    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final hash = _hash(password.trim());
    final users = LocalStorageService.getAllUserProfiles();

    // Check if user exists and credentials match
    for (final profile in users) {
      final profileEmail = profile['email']?.toString().trim().toLowerCase();
      final profileHash = profile['passwordHash']?.toString();
      
      // Strict validation: email must match exactly and password hash must match
      if (profileEmail == email.trim().toLowerCase() && 
          profileHash != null && 
          profileHash == hash) {
        final userId = profile['id'] as String;
        
        // Verify user profile is valid
        if (userId == null || userId.isEmpty) {
          return null;
        }
        
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_currentUserIdKey, userId);
        if (rememberMe) {
          await prefs.setString(_userEmailKey, email.trim());
        } else {
          await prefs.remove(_userEmailKey);
        }
        return userId;
      }
    }
    return null;
  }

  Future<String?> register({                     // called by register screen    receives username em,pass form register screen
    required String username,
    required String email,
    required String password,
  }) async {
    final existing = LocalStorageService
        .getAllUserProfiles()
        .firstWhere(
          (profile) => profile['email']?.toString().toLowerCase() == email.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );

    if (existing.isNotEmpty) {
      return null; // Email already registered
    }

    final userId = const Uuid().v4();
    final profile = {
      'id': userId,
      'username': username,
      'email': email,
      'passwordHash': _hash(password),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await LocalStorageService.saveUserProfile(userId, profile);
    return userId;
  }

  Future<void> logout() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentUserIdKey);
  }

  Future<void> saveLoginState(String userId, {required String email}) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_currentUserIdKey, userId);
    await prefs.setString(_userEmailKey, email);
  }

  Future<void> clearLoginState() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, false);
    await prefs.remove(_currentUserIdKey);
    await prefs.remove(_userEmailKey);
  }

  Future<String?> getSavedEmail() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  String? get currentUserId {
    final prefs = _prefs;
    return prefs?.getString(_currentUserIdKey);
  }

  Map<String, dynamic>? currentUserProfile() {
    final id = currentUserId;
    if (id == null) return null;
    return LocalStorageService.getUserProfile(id);
  }


  // update username in homescreen
  Future<bool> updateUsername(String newUsername) async {
    final id = currentUserId;
    if (id == null) return false;
    final profile = LocalStorageService.getUserProfile(id) ?? <String, dynamic>{};
    profile['username'] = newUsername;
    profile['updatedAt'] = DateTime.now().toIso8601String();
    await LocalStorageService.saveUserProfile(id, profile);        // calls local sotrage to update username
    return true;
  }

  /// Check if email exists in the system
  Future<bool> emailExists(String email) async {
    final users = LocalStorageService.getAllUserProfiles();
    final emailLower = email.trim().toLowerCase();
    
    for (final profile in users) {
      final profileEmail = profile['email']?.toString().trim().toLowerCase();
      if (profileEmail == emailLower) {
        return true;
      }
    }
    return false;
  }

  /// Reset password for a user (requires email verification)
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    print('🔐 Starting password reset for: $email');
    final users = LocalStorageService.getAllUserProfiles();
    final emailLower = email.trim().toLowerCase();
    final newHash = _hash(newPassword.trim());
    
    print('🔍 Searching through ${users.length} user profiles...');
    
    for (final profile in users) {
      final profileEmail = profile['email']?.toString().trim().toLowerCase();
      print('   Checking: $profileEmail');
      
      if (profileEmail == emailLower) {
        final userId = profile['id'] as String;
        print('✅ Found user with ID: $userId');
        print('📝 Updating password hash...');
        
        profile['passwordHash'] = newHash;
        profile['updatedAt'] = DateTime.now().toIso8601String();
        await LocalStorageService.saveUserProfile(userId, profile);
        
        print('✅ Password reset successful! New password saved.');
        return true;
      }
    }
    
    print('❌ No user found with email: $email');
    return false;
  }

  static String _hash(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }
}