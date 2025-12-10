import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _username;
  String? _role;
  String? _firstName;
  String? _lastName;
  int? _userId;
  bool _isAuthenticated = false;
  
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  // Getters
  String? get token => _token;
  String? get username => _username;
  String? get role => _role;
  String? get userRole => _role;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  int? get userId => _userId;
  bool get isAuthenticated => _isAuthenticated;

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

  String get firstNameOrUsername {
    if (_firstName != null && _firstName!.isNotEmpty) {
      return _firstName!;
    } else if (_username != null && _username!.isNotEmpty) {
      return _username!;
    } else {
      return 'User';
    }
  }

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

  Future<void> login({
    required String token,
    required String username,
    required String role,
    required int userId,
    String? firstName,
    String? lastName,
    String? email,
    String? password,
  }) async {
    debugPrint('🔐 AuthProvider.login called');
    debugPrint('   Token: ${token.isNotEmpty ? '✅' : '❌'}');
    debugPrint('   Username: $username');
    debugPrint('   Role: $role');
    debugPrint('   UserId: $userId');
    debugPrint('   Email: ${email ?? '(none)'}');
    debugPrint('   First Name: ${firstName ?? '(none)'}');
    debugPrint('   Last Name: ${lastName ?? '(none)'}');

    _token = token;
    _username = username;
    _role = role;
    _userId = userId;
    _firstName = firstName;
    _lastName = lastName;
    _isAuthenticated = true;

    debugPrint('📱 State updated in memory');
    debugPrint('   Display Name: $displayName');
    
    if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
      await _syncWithFirebase(email, password);
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', token);
      await prefs.setString('username', username);
      await prefs.setString('role', role);
      await prefs.setInt('userId', userId);
      
      if (email != null && email.isNotEmpty) {
        await prefs.setString('email', email);
        debugPrint('💾 Saved email: $email');
      }
      
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
      notifyListeners();
    }
  }

  Future<void> _syncWithFirebase(String email, String password) async {
    try {
      debugPrint('🔥 Attempting Firebase sync for: $email');
      
      try {
        await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        debugPrint('✅ Firebase sign-in successful');
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          debugPrint('⚠️ Firebase user not found, creating new user...');
          try {
            final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            debugPrint('✅ Firebase user created successfully: ${userCredential.user?.email}');
            
            final firebaseUser = userCredential.user;
            if (firebaseUser != null && fullName.isNotEmpty) {
              await firebaseUser.updateDisplayName(fullName);
              debugPrint('✅ Firebase display name updated: $fullName');
            }
          } on firebase_auth.FirebaseAuthException catch (createError) {
            if (createError.code == 'email-already-in-use') {
              debugPrint('⚠️ Firebase email already in use with different password');
            } else {
              debugPrint('❌ Failed to create Firebase user: ${createError.code} - ${createError.message}');
            }
          }
        } else if (e.code == 'wrong-password') {
          debugPrint('⚠️ Firebase password mismatch - passwords may be out of sync');
        } else {
          debugPrint('❌ Firebase auth error: ${e.code} - ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase sync error: $e');
    }
  }

  Future<void> register({
    required String token,
    required String username,
    required String role,
    required int userId,
    String? firstName,
    String? lastName,
    required String email,
    required String password,
  }) async {
    debugPrint('📝 AuthProvider.register called');
    
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Firebase user created during registration');
      
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        final displayName = [firstName, lastName]
            .where((name) => name != null && name.isNotEmpty)
            .join(' ')
            .trim();
        
        if (displayName.isNotEmpty) {
          await firebaseUser.updateDisplayName(displayName);
          debugPrint('✅ Firebase display name set: $displayName');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Firebase user creation failed during registration: $e');
    }
    
    await login(
      token: token,
      username: username,
      role: role,
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    try {
      debugPrint('🚪 Logging out...');
      
      try {
        await _firebaseAuth.signOut();
        debugPrint('✅ Firebase sign-out successful');
      } catch (e) {
        debugPrint('⚠️ Firebase sign-out error: $e');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

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

  Future<bool> checkAuthStatus() async {
    await _loadFromPreferences();
    debugPrint('🔍 Auth status checked: $_isAuthenticated');
    return _isAuthenticated;
  }

  void updateToken(String newToken) {
    _token = newToken;
    _saveToPreferences();
    notifyListeners();
    debugPrint('🔄 Token updated');
  }

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

  bool hasRole(String roleToCheck) => _role?.toLowerCase() == roleToCheck.toLowerCase();
  bool get isStudent => hasRole('student');
  bool get isTeacher => hasRole('teacher');
  bool get isCounselor => hasRole('counselor');

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

  void debugPrintState() {
    debugPrint('📊 AuthProvider State:');
    debugPrint('   Token: ${_token != null ? "Present (${_token!.length} chars)" : "null"}');
    debugPrint('   Username: $_username');
    debugPrint('   Name: $_firstName $_lastName');
    debugPrint('   Display Name: $displayName');
    debugPrint('   Role: $_role');
    debugPrint('   UserId: $_userId');
    debugPrint('   Authenticated: $_isAuthenticated');
    debugPrint('   Firebase User: ${_firebaseAuth.currentUser?.email ?? 'Not signed in'}');
  }

  Future<void> reload() async {
    await _loadFromPreferences();
  }
  
  // ✅ NEW: Update user info method for profile updates
  Future<void> updateUserInfo({
    String? firstName,
    String? lastName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (firstName != null) {
        _firstName = firstName;
        await prefs.setString('first_name', firstName);
      }
      
      if (lastName != null) {
        _lastName = lastName;
        await prefs.setString('last_name', lastName);
      }
      
      notifyListeners();
      debugPrint('✅ User info updated: $_firstName $_lastName');
    } catch (e) {
      debugPrint('❌ Error updating user info: $e');
    }
  }
}