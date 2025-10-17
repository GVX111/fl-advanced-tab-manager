// ===============================
// styles.dart (extended)
// ===============================
import 'package:fluent_ui/fluent_ui.dart';

class IDETheme {
  static const double edgeSnapBand = 26;
  // Base colors
  static const background = Color(0xFF2D2D30);
  static const surface = Color(0xFF3C3C3C);
  static const surface2 = Color(0xFF2B2B2B);
  static const border = Color(0xFF424242);
  static const text = Color(0xFFEAEAEA);
  static const accent = Color(0xFF0078D4);

  // Extra colors
  static const shadow = Color(0xFF000000);
  static const overlayButtonBg = Color(0xC0222222);
  static const overlayButtonSelectedBg = Color(0xF00078D4);
  static const overlayIcon = Color(0xFFFFFFFF);
  static const stripButtonHover = Color(0xFF454545);
  static const splitterHighlight = Color.fromARGB(255, 43, 74, 97);

  // Metrics
  static const autoHideGap = 48.0;
  static const stripThickness = 36.0;

  // Extra metrics
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
  static const floatTitleGrabOffset =
      36.0; // distance from cursor to place titlebar under finger
  static const floatScreenPad = 8.0; // margin from screen edges
  static const floatMinVisibleX =
      64.0; // minimal visible width (avoid total loss)
  static const floatMinVisibleY =
      32.0; // minimal visible height (title/controls)
  static const floatMinWidth = 240.0;
  static const floatMinHeight = 160.0;
  static const floatMaxWidth = 1200.0;
  static const floatMaxHeight = 900.0;
}

class DockStyle {
  final double dragHoverBlurSigma; // blur on current drop target
  final double dragSourceBlurSigma; // (optional) subtle blur on the source node
  final int dragBlurMs; // animation duration in ms
  // Colors
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
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
  final double flyoutAnimationOffset;

  const DockStyle({
    // base
    this.background = IDETheme.background,
    this.surface = IDETheme.surface,
    this.surface2 = IDETheme.surface2,
    this.border = IDETheme.border,
    this.text = IDETheme.text,
    this.accent = IDETheme.accent,

    // extras
    this.shadow = IDETheme.shadow,
    this.shadowOpacity = IDETheme.shadowOpacity,
    this.overlayButtonBg = IDETheme.overlayButtonBg,
    this.overlayButtonSelectedBg = IDETheme.overlayButtonSelectedBg,
    this.overlayIcon = IDETheme.overlayIcon,
    this.stripButtonHover = IDETheme.stripButtonHover,
    this.splitterHighlight = IDETheme.splitterHighlight,

    // sizing
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

    // floating defaults & clamps
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

    // misc
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
  });
}
