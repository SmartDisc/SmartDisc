import 'package:flutter/material.dart';

enum Breakpoints {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

extension ResponsiveContext on BuildContext {
  Breakpoints get breakpoint {
    final width = MediaQuery.of(this).size.width;
    if (width < 600) {
      return Breakpoints.mobile;
    } else if (width < 900) {
      return Breakpoints.tablet;
    } else if (width < 1200) {
      return Breakpoints.desktop;
    } else {
      return Breakpoints.largeDesktop;
    }
  }

  bool get isMobile => breakpoint == Breakpoints.mobile;
  bool get isTablet => breakpoint == Breakpoints.tablet;
  bool get isDesktop => breakpoint == Breakpoints.desktop || breakpoint == Breakpoints.largeDesktop;
  bool get isLargeDesktop => breakpoint == Breakpoints.largeDesktop;

  double get horizontalPadding {
    switch (breakpoint) {
      case Breakpoints.mobile:
        return 16.0;
      case Breakpoints.tablet:
        return 24.0;
      case Breakpoints.desktop:
        return 32.0;
      case Breakpoints.largeDesktop:
        return 48.0;
    }
  }

  double get verticalPadding {
    switch (breakpoint) {
      case Breakpoints.mobile:
        return 16.0;
      case Breakpoints.tablet:
        return 24.0;
      case Breakpoints.desktop:
        return 32.0;
      case Breakpoints.largeDesktop:
        return 48.0;
    }
  }

  double get maxContentWidth {
    switch (breakpoint) {
      case Breakpoints.mobile:
        return double.infinity;
      case Breakpoints.tablet:
        return 768.0;
      case Breakpoints.desktop:
        return 1024.0;
      case Breakpoints.largeDesktop:
        return 1200.0;
    }
  }

  int getGridColumns({
    required int mobile,
    int? tablet,
    int? desktop,
    int? largeDesktop,
  }) {
    switch (breakpoint) {
      case Breakpoints.mobile:
        return mobile;
      case Breakpoints.tablet:
        return tablet ?? mobile;
      case Breakpoints.desktop:
        return desktop ?? tablet ?? mobile;
      case Breakpoints.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
    }
  }

  Responsive get responsive => Responsive(this);
}

class Responsive {
  final BuildContext context;
  Responsive(this.context);

  bool get isMobile => context.isMobile;
  bool get isTablet => context.isTablet;
  bool get isDesktop => context.isDesktop;
  bool get isLargeDesktop => context.isLargeDesktop;

  double get horizontalPadding => context.horizontalPadding;
  double get verticalPadding => context.verticalPadding;
  double get maxContentWidth => context.maxContentWidth;

  int getGridColumns({
    required int mobile,
    int? tablet,
    int? desktop,
    int? largeDesktop,
  }) => context.getGridColumns(
    mobile: mobile,
    tablet: tablet,
    desktop: desktop,
    largeDesktop: largeDesktop,
  );
}
