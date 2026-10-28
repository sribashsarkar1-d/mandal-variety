import 'package:flutter/widgets.dart';

/// Centralized file for all MediaQuery logic.
/// UI widgets should use these helpers instead of calling MediaQuery directly.
class MediaQueryHelper {
  static double screenWidth = 375.0;
  static double screenHeight = 812.0;
  static Orientation orientation = Orientation.portrait;

  /// Call this inside the build method of the root widget (or the first screen).
  static void init(BuildContext context) {
    final data =
        MediaQuery.maybeOf(context) ??
        MediaQueryData.fromView(View.of(context));
    screenWidth = data.size.width;
    screenHeight = data.size.height;
    orientation = data.orientation;
  }

  static bool get isMobile => screenWidth < 500;
  static bool get isTablet => screenWidth >= 500 && screenWidth < 1200;

  /// Scales the width proportionally based on a 375px design width.
  static double scaleWidth(double inputWidth) {
    const double uiWidth = 375.0;
    return (inputWidth / uiWidth) * screenWidth;
  }

  /// Scales the height proportionally based on an 812px design height.
  static double scaleHeight(double inputHeight) {
    const double uiHeight = 812.0;
    return (inputHeight / uiHeight) * screenHeight;
  }

  /// Responsive font sizing.
  static double responsiveFontSize(double fontSize) {
    // For extreme screen sizes (tablet and Desktop), cap the scaling to prevent huge fonts
    double scaleFactor = isMobile ? scaleWidth(fontSize) : fontSize * 1.5;
    return scaleFactor;
  }
}
