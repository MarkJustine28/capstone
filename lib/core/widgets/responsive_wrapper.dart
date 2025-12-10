import 'package:flutter/material.dart';
import '../constants/app_breakpoints.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveWrapper({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (AppBreakpoints.isDesktop(width) && desktop != null) {
          return desktop!;
        } else if (AppBreakpoints.isTablet(width) && tablet != null) {
          return tablet!;
        } else {
          return mobile;
        }
      },
    );
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: builder);
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = AppBreakpoints.getMaxContentWidth(constraints.maxWidth);
        final padding = AppBreakpoints.getPadding(constraints.maxWidth);

        return Container(
          color: backgroundColor,
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: EdgeInsets.all(padding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}