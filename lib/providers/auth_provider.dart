import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _username;
  String? _userRole;
  String? _firstName;
  String? _lastName;
  bool _isAuthenticated = false;

  // Getters
  String? get token => _token;
  String? get username => _username;
  String? get userRole => _userRole;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _loadFromPreferences();
  }

  /// Load authentication data from SharedPreferences
  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      _username = prefs.getString('username');
      _userRole = prefs.getString('user_role');
      _firstName = prefs.getString('first_name');
      _lastName = prefs.getString('last_name');
      _isAuthenticated = _token != null && _token!.isNotEmpty;

      debugPrint('📱 Loaded from preferences:');
      debugPrint('   Token: ${_token != null ? "✅" : "❌"}');
      debugPrint('   Username: $_username');
      debugPrint('   Name: ${_firstName ?? "(none)"} ${_lastName ?? "(none)"}');
      debugPrint('   Role: $_userRole');
      debugPrint('   Authenticated: $_isAuthenticated');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading preferences: $e');
    }
  }

  /// Save authentication data safely to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('auth_token', _token ?? '');
      await prefs.setString('username', _username ?? '');
      await prefs.setString('user_role', _userRole ?? '');
      await prefs.setString('first_name', _firstName ?? '');
      await prefs.setString('last_name', _lastName ?? '');

      debugPrint(
        '💾 Saved to preferences:\n'
        '   Username: $_username\n'
        '   Name: ${_firstName ?? "(none)"} ${_lastName ?? "(none)"}\n'
        '   Role: $_userRole',
      );
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
    }
  }

  /// Login and store authentication data
  Future<void> login(
    String token,
    String username,
    String role,
    BuildContext context, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      debugPrint('🔐 AuthProvider.login called');
      debugPrint('   Token: ${token.isNotEmpty ? "✅" : "❌"}');
      debugPrint('   Username: $username');
      debugPrint('   Role: $role');
      debugPrint('   Name: ${firstName ?? "(none)"} ${lastName ?? "(none)"}');

      _token = token;
      _username = username;
      _userRole = role;
      _firstName = firstName;
      _lastName = lastName;
      _isAuthenticated = true;

      await _saveToPreferences();

      debugPrint('✅ AuthProvider login completed successfully');
      debugPrint('   Authenticated: $_isAuthenticated');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error in AuthProvider.login: $e');
      rethrow;
    }
  }

  /// Logout and clear stored data
  Future<void> logout() async {
    try {
      debugPrint('🚪 Logging out...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('username');
      await prefs.remove('user_role');
      await prefs.remove('first_name');
      await prefs.remove('last_name');

      _token = null;
      _username = null;
      _userRole = null;
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

  /// Clear authentication data from memory (no disk update)
  void clearAuth() {
    _token = null;
    _username = null;
    _userRole = null;
    _firstName = null;
    _lastName = null;
    _isAuthenticated = false;
    notifyListeners();
    debugPrint('🗑️ Auth cleared from memory');
  }

  /// Role helpers
  bool hasRole(String role) => _userRole?.toLowerCase() == role.toLowerCase();
  bool get isStudent => hasRole('student');
  bool get isTeacher => hasRole('teacher');
  bool get isCounselor => hasRole('counselor');

  /// Debug info
  Map<String, String?> getUserInfo() {
    return {
      'username': _username,
      'role': _userRole,
      'first_name': _firstName,
      'last_name': _lastName,
      'token': _token != null ? '***' : null,
    };
  }

  void debugPrintState() {
    debugPrint('📊 AuthProvider State:');
    debugPrint('   Token: ${_token != null ? "Present (${_token!.length} chars)" : "null"}');
    debugPrint('   Username: $_username');
    debugPrint('   Name: ${_firstName ?? "(none)"} ${_lastName ?? "(none)"}');
    debugPrint('   Role: $_userRole');
    debugPrint('   Authenticated: $_isAuthenticated');
  }
}
