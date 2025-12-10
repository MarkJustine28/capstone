import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Routes
import 'config/routes.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/counselor_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/notification_provider.dart';

// ✅ Import from separate env file
import 'config/env.dart';

// ===========================
// ✅ Main
// ===========================
Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // ✅ Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');
    
    // ✅ Load environment based on platform
    try {
      if (!kIsWeb) {
        // ✅ MOBILE: Load .env file
        await dotenv.load(fileName: ".env");
        debugPrint('📱 Loaded .env (mobile)');
      } else {
        // ✅ WEB: Use env.js
        debugPrint('🌐 Using env.js (web)');
      }

      // Test environment access
      debugPrint('🌍 ENV: ${Env.env}');
      debugPrint('🌐 SERVER_IP: ${Env.serverIp}');
      
      if (kDebugMode) {
        print('✅ Environment configured successfully');
        print('🎯 Ready to connect to backend');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to load environment: $e');
      // Don't let environment errors crash the app
    }

    // ✅ Start the app
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => StudentProvider()),
          ChangeNotifierProvider(create: (_) => CounselorProvider()),
          ChangeNotifierProvider(create: (_) => TeacherProvider()),
          ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ],
        child: const MyApp(),
      ),
    );
    
  } catch (e) {
    debugPrint('💥 FATAL ERROR in main(): $e');
    
    // ✅ Emergency fallback app (no dart:js dependency)
    runApp(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade50,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red.shade600),
                  const SizedBox(height: 24),
                  Text(
                    'App Failed to Start',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      debugPrint('🔄 Reload button pressed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reload App'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================
// ✅ App Widget
// ===========================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ MyApp build() called');
    
    return MaterialApp(
      title: 'Guidance Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
      onUnknownRoute: (settings) {
        debugPrint('❌ Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Page Not Found')),
            body: const Center(
              child: Text('Page not found'),
            ),
          ),
        );
      },
    );
  }
}