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
  /// Nilai AKTUAL dari layar Figma yang dipublish (arch-sleek-20433581):
  /// `<aside>` sidebar = 200px, cart panel = 340px, top bar = 56px.
  /// (Token doc handoff menulis 240/360 tapi layar render 200/340 — ikut layar.)
  static const double tabletSidebar = 200.0;
  static const double tabletCart = 340.0;
  static const double backOfficeSidebar = 200.0;
  static const double topBarHeight = 56.0;
  static const double mobileBottomNav = 56.0;

  static const double sidebarWidth = 200.0;
  static const double cartWidth = 340.0;
  static const double mobileBreak = 600.0;
  static const double tabletBreak = 1024.0;
}
