// lib/config/env.dart
export 'env_mobile.dart' // Default for mobile
    if (dart.library.html) 'env_web.dart'; // Web implementation