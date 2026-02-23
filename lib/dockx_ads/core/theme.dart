import 'package:fluent_ui/fluent_ui.dart';

class IDETheme {
  static const double edgeSnapBand = 26;
  static const accent = Color(0xFF0078D4);

  // Metrics
  static const autoHideGap = 48.0;
  static const stripThickness = 36.0;
  static const tabbarHeight = 32.0;
  static const floatTitleBarHeight = 28.0;
  static const guideButtonSize = 28.0;
  static const guideButtonPadding = 8.0;
  static const resizeGripSize = 18.0;
  static const cornerRadius = 4.0;
  static const shadowBlur = 16.0;
  static const shadowSpread = 2.0;
  static const shadowOpacity = .35;

  // Floating window defaults & clamps
  static const floatDefaultWidth = 420.0;
  static const floatDefaultHeight = 300.0;
  static const floatTitleGrabOffset = 36.0;
  static const floatScreenPad = 8.0;
  static const floatMinVisibleX = 64.0;
  static const floatMinVisibleY = 32.0;
  static const floatMinWidth = 240.0;
  static const floatMinHeight = 160.0;
  static const floatMaxWidth = 1200.0;
  static const floatMaxHeight = 900.0;
}

/// Resolved style (colors are final values)
class DockStyle {
  // Blur animation
  final double dragHoverBlurSigma;
  final double dragSourceBlurSigma;
  final int dragBlurMs;

  // Colors
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color iconColorBlueBg;
  final Color accent;

  // Extra colors
  final Color shadow;
  final double shadowOpacity;
  final Color overlayButtonBg;
  final Color overlayButtonSelectedBg;
  final Color overlayIcon;
  final Color stripButtonHover;
  final Color splitterHighlight;

  // Metrics
  final double autoHideGap;
  final double stripThickness;

  // Extra metrics
  final double tabbarHeight;
  final double floatTitleBarHeight;
  final double guideButtonSize;
  final double guideButtonPadding;
  final double resizeGripSize;
  final double cornerRadius;
  final double shadowBlur;
  final double shadowSpread;

  // Floating window defaults & clamps
  final double floatDefaultWidth;
  final double floatDefaultHeight;
  final double floatTitleGrabOffset;
  final double floatScreenPad;
  final double floatMinVisibleX;
  final double floatMinVisibleY;
  final double floatMinWidth;
  final double floatMinHeight;
  final double floatMaxWidth;
  final double floatMaxHeight;

  // Misc UI bits
  final EdgeInsets stripButtonPadding;
  final IconData iconClose;
  final IconData iconPin;
  final IconData iconFloatTitle;
  final IconData iconResizeGrip;
  final IconData maximizeIcon;
  final IconData minimizeIcone;
  final double flyoutAnimationOffset;

  const DockStyle({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.text,
    required this.accent,
    required this.shadow,
    required this.shadowOpacity,
    required this.overlayButtonBg,
    required this.overlayButtonSelectedBg,
    required this.overlayIcon,
    required this.stripButtonHover,
    required this.splitterHighlight,
    this.autoHideGap = IDETheme.autoHideGap,
    this.stripThickness = IDETheme.stripThickness,
    this.tabbarHeight = IDETheme.tabbarHeight,
    this.floatTitleBarHeight = IDETheme.floatTitleBarHeight,
    this.guideButtonSize = IDETheme.guideButtonSize,
    this.guideButtonPadding = IDETheme.guideButtonPadding,
    this.resizeGripSize = IDETheme.resizeGripSize,
    this.cornerRadius = IDETheme.cornerRadius,
    this.shadowBlur = IDETheme.shadowBlur,
    this.shadowSpread = IDETheme.shadowSpread,
    this.floatDefaultWidth = IDETheme.floatDefaultWidth,
    this.floatDefaultHeight = IDETheme.floatDefaultHeight,
    this.floatTitleGrabOffset = IDETheme.floatTitleGrabOffset,
    this.floatScreenPad = IDETheme.floatScreenPad,
    this.floatMinVisibleX = IDETheme.floatMinVisibleX,
    this.floatMinVisibleY = IDETheme.floatMinVisibleY,
    this.floatMinWidth = IDETheme.floatMinWidth,
    this.floatMinHeight = IDETheme.floatMinHeight,
    this.floatMaxWidth = IDETheme.floatMaxWidth,
    this.floatMaxHeight = IDETheme.floatMaxHeight,
    this.stripButtonPadding =
        const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
    this.iconClose = FluentIcons.chrome_close,
    this.iconPin = FluentIcons.pin,
    this.iconFloatTitle = FluentIcons.edit,
    this.iconResizeGrip = WindowsIcons.resize_mouse_medium,
    this.flyoutAnimationOffset = 28.0,
    this.dragHoverBlurSigma = 6.0,
    this.dragSourceBlurSigma = 2.0,
    this.dragBlurMs = 120,
    this.maximizeIcon = WindowsIcons.chrome_maximize,
    this.minimizeIcone = WindowsIcons.chrome_restore,
    this.iconColorBlueBg = Colors.white,
  });

  /// Build a style based on current FluentTheme (auto light/dark).
  factory DockStyle.fromTheme(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness.isDark;

    // Fluent UI gives you a lot, but not everything in one place.
    // We’ll derive a consistent “IDE-like” palette from available theme colors.
    final accent = theme.accentColor;

    // Most apps treat "scaffoldBackgroundColor" as true background.
    final background = theme.scaffoldBackgroundColor;

    // Use a slightly elevated surface for panels.
    // If cardColor is not set, fall back to micaBackgroundColor or background.
    final surface = theme.cardColor;

    // A second surface level (slightly different from surface).
    final surface2 = theme.micaBackgroundColor;

    // Borders: fluent often uses subtle dividers.
    // theme.inactiveColor is a decent subtle border-ish color across modes.
    final border = surface;

    // Text: theme.typography applies, but we want a base color.
    // theme.typography.body?.color can be null, so fallback.
    final text =
        theme.typography.body?.color ?? (isDark ? Colors.white : Colors.black);

    // Overlays/buttons used on top of content.
    final overlayButtonBg =
        isDark ? const Color(0xC0222222) : const Color(0xCCFFFFFF);

    final overlayButtonSelectedBg = accent.withOpacity(isDark ? 0.95 : 0.90);
    final overlayIcon = isDark ? Colors.white : Colors.black;

    // Hover colors: subtle highlight based on accent.
    final stripButtonHover = accent.withOpacity(isDark ? 0.18 : 0.12);

    // Splitter highlight: bluish highlight derived from accent.
    final splitterHighlight = accent.withOpacity(isDark ? 0.35 : 0.25);

    final shadow = Colors.black;
    final shadowOpacity = isDark ? IDETheme.shadowOpacity : 0.18;

    return DockStyle(
      background: background,
      surface: surface,
      surface2: surface2,
      border: border,
      text: text,
      accent: accent,
      shadow: shadow,
      shadowOpacity: shadowOpacity,
      overlayButtonBg: overlayButtonBg,
      overlayButtonSelectedBg: overlayButtonSelectedBg,
      overlayIcon: overlayIcon,
      stripButtonHover: stripButtonHover,
      splitterHighlight: splitterHighlight,
    );
  }

  /// Default style for backward compatibility
  static DockStyle defaultStyle() {
    return DockStyle(
      background: const Color(0xFF2D2D30),
      surface: const Color(0xFF3C3C3C),
      surface2: const Color(0xFF2B2B2B),
      border: const Color(0xFF424242),
      text: const Color(0xFFEAEAEA),
      accent: const Color(0xFF0078D4),
      shadow: const Color(0xFF000000),
      shadowOpacity: 0.35,
      overlayButtonBg: const Color(0xC0222222),
      overlayButtonSelectedBg: const Color(0xF00078D4),
      overlayIcon: const Color(0xFFFFFFFF),
      stripButtonHover: const Color(0xFF454545),
      splitterHighlight: const Color(0xFF2B4A61),
    );
  }

  DockStyle copyWith({
    Color? background,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? text,
    Color? accent,
    Color? shadow,
    double? shadowOpacity,
    Color? overlayButtonBg,
    Color? overlayButtonSelectedBg,
    Color? overlayIcon,
    Color? stripButtonHover,
    Color? splitterHighlight,
    double? dragHoverBlurSigma,
    double? dragSourceBlurSigma,
    int? dragBlurMs,
  }) {
    return DockStyle(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      text: text ?? this.text,
      accent: accent ?? this.accent,
      shadow: shadow ?? this.shadow,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      overlayButtonBg: overlayButtonBg ?? this.overlayButtonBg,
      overlayButtonSelectedBg:
          overlayButtonSelectedBg ?? this.overlayButtonSelectedBg,
      overlayIcon: overlayIcon ?? this.overlayIcon,
      stripButtonHover: stripButtonHover ?? this.stripButtonHover,
      splitterHighlight: splitterHighlight ?? this.splitterHighlight,
      dragHoverBlurSigma: dragHoverBlurSigma ?? this.dragHoverBlurSigma,
      dragSourceBlurSigma: dragSourceBlurSigma ?? this.dragSourceBlurSigma,
      dragBlurMs: dragBlurMs ?? this.dragBlurMs,
      // keep metrics/icons as-is
      autoHideGap: autoHideGap,
      stripThickness: stripThickness,
      tabbarHeight: tabbarHeight,
      floatTitleBarHeight: floatTitleBarHeight,
      guideButtonSize: guideButtonSize,
      guideButtonPadding: guideButtonPadding,
      resizeGripSize: resizeGripSize,
      cornerRadius: cornerRadius,
      shadowBlur: shadowBlur,
      shadowSpread: shadowSpread,
      floatDefaultWidth: floatDefaultWidth,
      floatDefaultHeight: floatDefaultHeight,
      floatTitleGrabOffset: floatTitleGrabOffset,
      floatScreenPad: floatScreenPad,
      floatMinVisibleX: floatMinVisibleX,
      floatMinVisibleY: floatMinVisibleY,
      floatMinWidth: floatMinWidth,
      floatMinHeight: floatMinHeight,
      floatMaxWidth: floatMaxWidth,
      floatMaxHeight: floatMaxHeight,
      stripButtonPadding: stripButtonPadding,
      iconClose: iconClose,
      iconPin: iconPin,
      iconFloatTitle: iconFloatTitle,
      iconResizeGrip: iconResizeGrip,
      maximizeIcon: maximizeIcon,
      minimizeIcone: minimizeIcone,
      flyoutAnimationOffset: flyoutAnimationOffset,
    );
  }
}
