class AppBreakpoints {
  // Standard breakpoints
  static const double mobile = 600;   // <600 = mobile
  static const double tablet = 1100;  // 600–1100 = tablet
  static const double desktop = 1100; // >1100 = desktop
  static const double widescreen = 1800;

  // Check width
  static bool isMobile(double width) => width < mobile;
  static bool isTablet(double width) => width >= mobile && width < tablet;
  static bool isDesktop(double width) => width >= tablet;
  static bool isWidescreen(double width) => width >= widescreen;

  // Max content width
  static double getMaxContentWidth(double width) {
    if (isMobile(width)) return width;         // full width
    if (isTablet(width)) return 900;           // centered container
    if (isWidescreen(width)) return 1400;      
    return 1200;                               
  }

  // Padding
  static double getPadding(double width) {
    if (isMobile(width)) return 12.0;
    if (isTablet(width)) return 20.0;
    return 32.0;
  }

  // GRID COLUMN FIXED (IMPORTANT!)
  static int getGridColumns(double width) {
    if (isMobile(width)) return 2;        // 👍 FIX: mobile is always 2 columns
    if (isTablet(width)) return 3;
    if (isWidescreen(width)) return 4;
    return 3; // desktop default
  }
}
