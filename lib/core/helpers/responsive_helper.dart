import 'package:flutter/rendering.dart';

/// UI responsive design
class ResponsiveHelper {
  static double mainPadding(BoxConstraints constraints) {
    return constraints.maxWidth > 1200
        ? 64
        : constraints.maxWidth < 640
            ? 16
            : 32;
  }

  static int crossAxisCount(BoxConstraints constraints) {
    return constraints.maxWidth > 1200
        ? 3
        : constraints.maxWidth < 640
            ? 1
            : 2;
  }
}
