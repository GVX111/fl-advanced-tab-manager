import 'package:fluent_ui/fluent_ui.dart';

class IDETheme {
  static const background = Color(0xFF2D2D30);
  static const surface = Color(0xFF3C3C3C);
  static const surface2 = Color(0xFF2B2B2B);
  static const border = Color(0xFF424242);
  static const text = Color(0xFFEAEAEA);
  static const accent = Color(0xFF0078D4);

  static const autoHideGap = 48.0;
  static const stripThickness = 36.0;
}

class DockStyle {
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color text;
  final Color accent;
  final double autoHideGap;
  final double stripThickness;
  final EdgeInsets stripButtonPadding;
  final Color stripButtonHover;
  final IconData iconClose;
  final IconData iconPin;
  final IconData iconFloatTitle;
  final double flyoutAnimationOffset;
  final Color splitterHighlight;

  const DockStyle({
    this.background = IDETheme.background,
    this.surface = IDETheme.surface,
    this.surface2 = IDETheme.surface2,
    this.border = IDETheme.border,
    this.text = IDETheme.text,
    this.accent = IDETheme.accent,
    this.splitterHighlight = const Color.fromARGB(255, 43, 74, 97),
    this.autoHideGap = IDETheme.autoHideGap,
    this.stripThickness = IDETheme.stripThickness,
    this.stripButtonPadding =
        const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
    this.stripButtonHover = const Color(0xFF454545),
    this.iconClose = FluentIcons.chrome_close,
    this.iconPin = FluentIcons.pin,
    this.iconFloatTitle = FluentIcons.edit,
    this.flyoutAnimationOffset = 28.0,
  });
}
