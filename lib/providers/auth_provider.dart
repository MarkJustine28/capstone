import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _username;
  String? _userRole;
  bool _isAuthenticated = false;

  // Getters
  String? get token => _token;
  String? get username => _username;
  String? get userRole => _userRole;
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
      _isAuthenticated = _token != null && _username != null && _userRole != null;
      
      debugPrint('📱 Loaded from preferences:');
      debugPrint('   Token: ${_token != null ? "✅" : "❌"}');
      debugPrint('   Username: $_username');
      debugPrint('   Role: $_userRole');
      debugPrint('   Authenticated: $_isAuthenticated');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading preferences: $e');
    }
  }

  /// Save authentication data to SharedPreferences
  Future<void> _saveToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_token != null && _username != null && _userRole != null) {
        await prefs.setString('auth_token', _token!);
        await prefs.setString('username', _username!);
        await prefs.setString('user_role', _userRole!);
        debugPrint('💾 Saved to preferences - Username: $_username, Role: $_userRole');
      }
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
    }
  }

  /// Login method - sets authentication data
  Future<void> login(String token, String username, String role, BuildContext context) async {
    try {
      debugPrint('🔐 AuthProvider.login called');
      debugPrint('   Token: ${token.isNotEmpty ? "✅" : "❌"}');
      debugPrint('   Username: $username');
      debugPrint('   Role: $role');

      _token = token;
      _username = username;
      _userRole = role;
      _isAuthenticated = true;

      await _saveToPreferences();
      
      debugPrint('✅ AuthProvider login completed successfully');
      debugPrint('   _isAuthenticated: $_isAuthenticated');
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error in AuthProvider.login: $e');
      rethrow;
    }
  }

  /// Logout method - clears all authentication data
  Future<void> logout() async {
    try {
      debugPrint('🚪 Logging out...');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('username');
      await prefs.remove('user_role');

      _token = null;
      _username = null;
      _userRole = null;
      _isAuthenticated = false;

      debugPrint('✅ Logout completed');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  /// Check if user is authenticated
  Future<bool> checkAuthStatus() async {
    await _loadFromPreferences();
    debugPrint('🔍 Auth status checked: $_isAuthenticated');
    return _isAuthenticated;
  }

  /// Update token (useful for token refresh)
  void updateToken(String newToken) {
    _token = newToken;
    _saveToPreferences();
    notifyListeners();
    debugPrint('🔄 Token updated');
  }

  /// Clear authentication without saving to preferences
  void clearAuth() {
    _token = null;
    _username = null;
    _userRole = null;
    _isAuthenticated = false;
    notifyListeners();
    debugPrint('🗑️ Auth cleared from memory');
  }

  /// Check if user has specific role
  bool hasRole(String role) {
    return _userRole?.toLowerCase() == role.toLowerCase();
  }

  /// Check if user is student
  bool get isStudent => hasRole('student');

  /// Check if user is teacher
  bool get isTeacher => hasRole('teacher');

  /// Check if user is counselor
  bool get isCounselor => hasRole('counselor');

  /// Get user display info
  Map<String, String?> getUserInfo() {
    return {
      'username': _username,
      'role': _userRole,
      'token': _token != null ? '***' : null, // Don't expose full token
    };
  }

  /// Debug method to print current state
  void debugPrintState() {
    debugPrint('📊 AuthProvider State:');
    debugPrint('   Token: ${_token != null ? "Present (${_token!.length} chars)" : "null"}');
    debugPrint('   Username: $_username');
    debugPrint('   Role: $_userRole');
    debugPrint('   Authenticated: $_isAuthenticated');
  }
}