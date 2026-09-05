import 'package:flutter/material.dart';

enum GoldenityBreakpoint { mobile, tablet, backOffice, signage }

extension BreakpointExtension on BuildContext {
  GoldenityBreakpoint get breakpoint {
    final double w = MediaQuery.of(this).size.width;
    if (w < 600) return GoldenityBreakpoint.mobile;
    if (w < 1024) return GoldenityBreakpoint.tablet;
    if (w < 1280) return GoldenityBreakpoint.backOffice;
    return GoldenityBreakpoint.signage;
  }
}
