import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reduced motion utilities for users with:
/// - Vestibular disorders (vertigo, dizziness)
/// - Epilepsy (photosensitivity)
/// - Motion sickness
/// - Cognitive disabilities (distraction from animations)
///
/// Features:
/// - Detects system "Reduce Motion" setting
/// - Manual toggle in app settings
/// - Provides simple fade animations instead of complex transitions
class ReducedMotion {
  static const String _prefKey = 'reduced_motion_enabled';
  static bool? _manualOverride;

  /// Check if reduced motion should be enabled
  /// Returns true if:
  /// 1. System setting "Reduce Motion" is enabled, OR
  /// 2. User manually enabled it in app settings
  static bool shouldReduce(BuildContext context) {
    // Check system setting
    final systemPreference = MediaQuery.disableAnimationsOf(context);
    if (systemPreference) return true;

    // Check manual override
    if (_manualOverride != null) return _manualOverride!;

    return false;
  }

  /// Load manual preference from storage
  static Future<void> loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    _manualOverride = prefs.getBool(_prefKey);
  }

  /// Save manual preference to storage
  static Future<void> setPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    _manualOverride = enabled;
  }

  /// Get current manual preference (null = follow system)
  static bool? getManualPreference() => _manualOverride;

  /// Get animation duration based on reduced motion setting
  /// Returns:
  /// - 0ms if reduced motion enabled
  /// - normal duration if disabled
  static Duration getDuration(BuildContext context, Duration normalDuration) {
    return shouldReduce(context) ? Duration.zero : normalDuration;
  }

  /// Get curve based on reduced motion setting
  /// Returns:
  /// - Curves.linear if reduced motion enabled
  /// - provided curve if disabled
  static Curve getCurve(BuildContext context, Curve normalCurve) {
    return shouldReduce(context) ? Curves.linear : normalCurve;
  }
}

/// Animated widget that respects reduced motion preferences
/// Uses simple fade instead of complex animations
class ReducedMotionAnimatedOpacity extends StatelessWidget {
  final Widget child;
  final bool visible;
  final Duration duration;

  const ReducedMotionAnimatedOpacity({
    super.key,
    required this.child,
    required this.visible,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: ReducedMotion.getDuration(context, duration),
      curve: ReducedMotion.getCurve(context, Curves.easeInOut),
      child: child,
    );
  }
}

/// Animated container that respects reduced motion
class ReducedMotionAnimatedContainer extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final double? width;
  final double? height;
  final BoxDecoration? decoration;
  final Duration duration;
  final Curve curve;

  const ReducedMotionAnimatedContainer({
    super.key,
    this.child,
    this.color,
    this.width,
    this.height,
    this.decoration,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      color: color,
      width: width,
      height: height,
      decoration: decoration,
      duration: ReducedMotion.getDuration(context, duration),
      curve: ReducedMotion.getCurve(context, curve),
      child: child,
    );
  }
}

/// Page transition that respects reduced motion
/// Uses fade instead of slide
class ReducedMotionPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  ReducedMotionPageRoute({required this.builder});

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Check if reduced motion is enabled
    if (ReducedMotion.shouldReduce(context)) {
      // Simple fade, no slide
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    // Normal slide transition
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      )),
      child: child,
    );
  }
}

/// Scale transition that respects reduced motion
class ReducedMotionScaleTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const ReducedMotionScaleTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (ReducedMotion.shouldReduce(context)) {
      // No scaling, just show/hide
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    }

    // Normal scale transition
    return ScaleTransition(
      scale: animation,
      child: child,
    );
  }
}

/// Rotation transition that respects reduced motion
class ReducedMotionRotationTransition extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;

  const ReducedMotionRotationTransition({
    super.key,
    required this.child,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    if (ReducedMotion.shouldReduce(context)) {
      // No rotation, just show
      return child;
    }

    // Normal rotation
    return RotationTransition(
      turns: animation,
      child: child,
    );
  }
}

/// Animated list that respects reduced motion
class ReducedMotionAnimatedList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Duration duration;

  const ReducedMotionAnimatedList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (ReducedMotion.shouldReduce(context)) {
          // No staggered animation
          return itemBuilder(context, index);
        }

        // Staggered animation
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: duration + Duration(milliseconds: index * 50),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: itemBuilder(context, index),
        );
      },
    );
  }
}
