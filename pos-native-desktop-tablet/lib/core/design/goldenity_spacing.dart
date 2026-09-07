/// 8pt grid — semua kelipatan 4px. Sesuai Design System handoff §03.
abstract class GoldenitySpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xl2 = 48.0; // alias handoff

  /// Minimum interactive hit area (WCAG 2.5.5) — kasir/EDC.
  static const double touchMin = 48.0;

  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;
}

abstract class GoldenityLayout {
  /// Sidebar tetap 240px (Design System handoff §03 — `GoldenityLayout.sidebarWidth`).
  static const double tabletSidebar = 240.0;
  static const double tabletCart = 360.0;
  static const double backOfficeSidebar = 240.0;
  static const double mobileBottomNav = 56.0;

  // Alias sesuai penamaan handoff.
  static const double sidebarWidth = 240.0;
  static const double cartWidth = 360.0;
  static const double mobileBreak = 600.0;
  static const double tabletBreak = 1024.0;
}
