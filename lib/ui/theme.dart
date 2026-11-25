import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

/// Design tokens of the app, named like CSS variables (`--bg`, `--ok`, ...).
@immutable
class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.line2,
    required this.hover,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.ok,
    required this.warn,
    required this.warnText,
    required this.bad,
    required this.unknown,
    this.amber = const Color(0xFFD9A21B),
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color line;
  final Color line2;
  final Color hover;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color ok;
  final Color warn;
  final Color warnText;
  final Color bad;
  final Color unknown;

  /// Cosmetic damage marker (`--amber`).
  final Color amber;

  static const dark = AppPalette(
    bg: Color(0xFF0D1014),
    surface: Color(0xFF151A20),
    surface2: Color(0xFF1C222A),
    line: Color(0xFF232A33),
    line2: Color(0xFF2B333D),
    hover: Color(0xFF3A434F),
    text: Color(0xFFE8EBEF),
    muted: Color(0xFF8B95A1),
    accent: Color(0xFF259DFF),
    onAccent: Color(0xFF0D1014),
    ok: Color(0xFF4FC3B5),
    warn: Color(0xFFF08A4B),
    warnText: Color(0xFFF5A574),
    bad: Color(0xFFE5734F),
    unknown: Color(0xFF5D6773),
  );

  static const light = AppPalette(
    bg: Color(0xFFF3F5F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEDF0F4),
    line: Color(0xFFE0E5EB),
    line2: Color(0xFFD2D8E0),
    hover: Color(0xFFB4BDC8),
    text: Color(0xFF12161B),
    muted: Color(0xFF5A6571),
    accent: Color(0xFF1F7FD1),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF1E9E8E),
    warn: Color(0xFFE0662E),
    warnText: Color(0xFFA8431A),
    bad: Color(0xFFC4502C),
    unknown: Color(0xFF9AA3AD),
  );

  static AppPalette of(Brightness b) => b == Brightness.dark ? dark : light;

  static AppPalette ofContext(BuildContext context) =>
      of(Theme.of(context).brightness);
}

ThemeData buildTheme(Brightness brightness, {bool useGoogleFonts = true}) {
  final p = AppPalette.of(brightness);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
      ).copyWith(
        primary: p.accent,
        onPrimary: p.onAccent,
        primaryContainer: p.accent.withValues(alpha: 0.16),
        onPrimaryContainer: p.text,
        secondary: p.ok,
        secondaryContainer: p.surface2,
        onSecondaryContainer: p.text,
        tertiary: p.warn,
        tertiaryContainer: p.warn.withValues(alpha: 0.16),
        onTertiaryContainer: p.text,
        error: p.bad,
        onError: p.onAccent,
        errorContainer: p.bad.withValues(alpha: 0.16),
        onErrorContainer: p.text,
        surface: p.surface,
        onSurface: p.text,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.bg,
        surfaceContainerLow: p.surface,
        surfaceContainer: p.surface,
        surfaceContainerHigh: p.surface2,
        surfaceContainerHighest: p.surface2,
        outline: p.line2,
        outlineVariant: p.line,
      );

  final base = ThemeData(colorScheme: scheme, brightness: brightness);
  final textTheme = useGoogleFonts
      ? GoogleFonts.geistTextTheme(base.textTheme)
      : base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    textTheme: textTheme.apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.accent.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: p.line),
    chipTheme: ChipThemeData(
      side: BorderSide(color: p.line2),
      selectedColor: p.accent.withValues(alpha: 0.18),
      backgroundColor: p.surface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.line2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: p.line2),
      ),
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
    ),
  );
}

/// User-selected theme. Defaults to dark.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Tests disable runtime font fetching (no network in `flutter test`).
final useGoogleFontsProvider = Provider<bool>((ref) => true);

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return IconButton(
      tooltip: context.t(dark ? 'Light theme' : 'Dark theme'),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: ref.read(themeModeProvider.notifier).toggle,
    );
  }
}
