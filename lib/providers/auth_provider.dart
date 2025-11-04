import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _username;
  String? _role;
  String? _firstName;
  String? _lastName;
  int? _userId;
  bool _isAuthenticated = false;

  // Getters
  String? get token => _token;
  String? get username => _username;
  String? get role => _role;
  String? get userRole => _role; // Alias for compatibility
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  int? get userId => _userId;
  bool get isAuthenticated => _isAuthenticated;

  // ✅ Display name with fallback chain
  String get displayName {
    final firstName = _firstName ?? '';
    final lastName = _lastName ?? '';
    final fullName = [firstName, lastName]
        .where((name) => name.isNotEmpty)
        .join(' ')
        .trim();
    
    if (fullName.isNotEmpty) {
      return fullName;
    } else if (_username != null && _username!.isNotEmpty) {
      return _username!;
    } else {
      return 'User';
    }
  }

  // ✅ First name or username fallback
  String get firstNameOrUsername {
    if (_firstName != null && _firstName!.isNotEmpty) {
      return _firstName!;
    } else if (_username != null && _username!.isNotEmpty) {
      return _username!;
    } else {
      return 'User';
    }
  }

  // ✅ Full name (empty string if no names)
  String get fullName {
    final firstName = _firstName ?? '';
    final lastName = _lastName ?? '';
    return [firstName, lastName]
        .where((name) => name.isNotEmpty)
        .join(' ')
        .trim();
  }

  AuthProvider() {
    _loadFromPreferences();
  }

  /// Load authentication data from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      _username = prefs.getString('username');
      _role = prefs.getString('role');
      _firstName = prefs.getString('first_name');
      _lastName = prefs.getString('last_name');
      _userId = prefs.getInt('userId');
      _isAuthenticated = _token != null && _token!.isNotEmpty;

      debugPrint('📱 Loaded from preferences:');
      debugPrint('   Token: ${_token != null ? "✅" : "❌"}');
      debugPrint('   Username: $_username');
      debugPrint('   Name: $_firstName $_lastName');
      debugPrint('   Display Name: $displayName');
      debugPrint('   Role: $_role');
      debugPrint('   UserId: $_userId');
      debugPrint('   Authenticated: $_isAuthenticated');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading preferences: $e');
    }
  }

  /// ✅ NEW: Login method with named parameters
  Future<void> login({
    required String token,
    required String username,
    required String role,
    required int userId,
    String? firstName,
    String? lastName,
  }) async {
    debugPrint('🔐 AuthProvider.login called');
    debugPrint('   Token: ${token.isNotEmpty ? '✅' : '❌'}');
    debugPrint('   Username: $username');
    debugPrint('   Role: $role');
    debugPrint('   UserId: $userId');
    debugPrint('   First Name: ${firstName ?? '(none)'}');
    debugPrint('   Last Name: ${lastName ?? '(none)'}');

    // ✅ Set state FIRST before saving to preferences
    _token = token;
    _username = username;
    _role = role;
    _userId = userId;
    _firstName = firstName;
    _lastName = lastName;
    _isAuthenticated = true;

    debugPrint('📱 State updated in memory');
    debugPrint('   Display Name: $displayName');
    
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Save to SharedPreferences
      await prefs.setString('token', token);
      await prefs.setString('username', username);
      await prefs.setString('role', role);
      await prefs.setInt('userId', userId);
      
      // ✅ Save names only if they exist
      if (firstName != null && firstName.isNotEmpty) {
        await prefs.setString('first_name', firstName);
        debugPrint('💾 Saved first_name: $firstName');
      } else {
        await prefs.remove('first_name');
        debugPrint('🗑️ Removed first_name (was null/empty)');
      }
      
      if (lastName != null && lastName.isNotEmpty) {
        await prefs.setString('last_name', lastName);
        debugPrint('💾 Saved last_name: $lastName');
      } else {
        await prefs.remove('last_name');
        debugPrint('🗑️ Removed last_name (was null/empty)');
      }

      debugPrint('💾 Saved to preferences:');
      debugPrint('   Username: $username');
      debugPrint('   Name: ${firstName ?? ''} ${lastName ?? ''}');
      debugPrint('   Role: $role');
      debugPrint('✅ AuthProvider login completed successfully');
      debugPrint('   Authenticated: $_isAuthenticated');
      debugPrint('   Display Name: $displayName');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
      // State is already set in memory, just notify listeners
      notifyListeners();
    }
  }

  /// Logout and clear stored data
  Future<void> logout() async {
    try {
      debugPrint('🚪 Logging out...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear all preferences

      _token = null;
      _username = null;
      _role = null;
      _userId = null;
      _firstName = null;
      _lastName = null;
      _isAuthenticated = false;

      debugPrint('✅ Logout completed');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  /// Check if user is authenticated (reload from SharedPreferences)
  Future<bool> checkAuthStatus() async {
    await _loadFromPreferences();
    debugPrint('🔍 Auth status checked: $_isAuthenticated');
    return _isAuthenticated;
  }

  /// Update token (for refresh scenarios)
  void updateToken(String newToken) {
    _token = newToken;
    _saveToPreferences();
    notifyListeners();
    debugPrint('🔄 Token updated');
  }

  /// Save current state to preferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_token != null) await prefs.setString('token', _token!);
      if (_username != null) await prefs.setString('username', _username!);
      if (_role != null) await prefs.setString('role', _role!);
      if (_userId != null) await prefs.setInt('userId', _userId!);
      if (_firstName != null && _firstName!.isNotEmpty) {
        await prefs.setString('first_name', _firstName!);
      }
      if (_lastName != null && _lastName!.isNotEmpty) {
        await prefs.setString('last_name', _lastName!);
      }

      debugPrint('💾 Saved current state to preferences');
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
    }
  }

  /// Clear authentication data from memory (no disk update)
  void clearAuth() {
    _token = null;
    _username = null;
    _role = null;
    _userId = null;
    _firstName = null;
    _lastName = null;
    _isAuthenticated = false;
    notifyListeners();
    debugPrint('🗑️ Auth cleared from memory');
  }

  /// Role helpers
  bool hasRole(String roleToCheck) => _role?.toLowerCase() == roleToCheck.toLowerCase();
  bool get isStudent => hasRole('student');
  bool get isTeacher => hasRole('teacher');
  bool get isCounselor => hasRole('counselor');

  /// Get user info map
  Map<String, dynamic> getUserInfo() {
    return {
      'username': _username,
      'role': _role,
      'userId': _userId,
      'first_name': _firstName,
      'last_name': _lastName,
      'full_name': fullName,
      'display_name': displayName,
      'token': _token != null ? '***' : null,
      'is_authenticated': _isAuthenticated,
    };
  }

  /// Debug print current state
  void debugPrintState() {
    debugPrint('📊 AuthProvider State:');
    debugPrint('   Token: ${_token != null ? "Present (${_token!.length} chars)" : "null"}');
    debugPrint('   Username: $_username');
    debugPrint('   Name: $_firstName $_lastName');
    debugPrint('   Display Name: $displayName');
    debugPrint('   Role: $_role');
    debugPrint('   UserId: $_userId');
    debugPrint('   Authenticated: $_isAuthenticated');
  }

  /// Reload from preferences (useful for debugging)
  Future<void> reload() async {
    await _loadFromPreferences();
  }
}