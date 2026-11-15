import 'package:flutter/material.dart';

class Breakpoints {
  static const double compactPhone = 380;
  static const double tablet = 700;
  static const double wide = 1024;
}

class Responsive {
  const Responsive._();

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  static bool isCompactPhone(BuildContext context) =>
      width(context) < Breakpoints.compactPhone;

  static bool isTablet(BuildContext context) =>
      width(context) >= Breakpoints.tablet;

  static bool isWide(BuildContext context) =>
      width(context) >= Breakpoints.wide;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Adaptive Split View: true on iPad / wide tablets OR landscape tablets.
  static bool useSplitPane(BuildContext context) {
    final w = width(context);
    final h = height(context);
    return w >= Breakpoints.wide || (w >= Breakpoints.tablet && w > h * 1.05);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = width(context);
    if (w >= Breakpoints.wide) {
      return const EdgeInsets.fromLTRB(28, 18, 28, 24);
    }
    if (w >= Breakpoints.tablet) {
      return const EdgeInsets.fromLTRB(20, 14, 20, 20);
    }
    return const EdgeInsets.fromLTRB(14, 10, 14, 16);
  }

  static int gridColumns(BuildContext context, {int phone = 1, int tablet = 2, int wide = 3}) {
    final w = width(context);
    if (w >= 1180) return wide;
    if (w >= Breakpoints.tablet) return tablet;
    return phone;
  }
}
