import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData build() => _build(Brightness.light);
  static ThemeData buildDark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.primaryOnDark : AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      inversePrimary: AppColors.inversePrimary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      surface: isDark ? AppColors.darkCard : AppColors.card,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      onSurfaceVariant: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
      surfaceContainerHighest: isDark ? AppColors.darkSurface : AppColors.surfaceRaised,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.danger,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      outlineVariant: isDark ? AppColors.darkDivider : AppColors.divider,
    );

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    // Manrope for headings, Inter for body
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 48,
        letterSpacing: -0.96,
        height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 40,
        letterSpacing: -0.5,
        height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.32,
        height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 32,
        letterSpacing: -0.32,
        height: 1.3,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        letterSpacing: -0.12,
        height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.manrope(
        fontWeight: FontWeight.w600,
        fontSize: 18,
        height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        letterSpacing: 0.1,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.inter(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.1,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      textTheme: textTheme,

      // ── AppBar — glass style ──────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkSurface.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // ── Page Transitions ──────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      // ── Progress Indicator — mint liquid ──────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.primaryOnDark : AppColors.primary,
        linearTrackColor: isDark ? AppColors.darkSurface : AppColors.surfaceRaised,
        circularTrackColor: Colors.transparent,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerColor: isDark ? AppColors.darkDivider : AppColors.divider,
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar — glass style ────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkCardRaised.withValues(alpha: 0.92)
            : AppColors.textPrimary.withValues(alpha: 0.92),
        contentTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),

      // ── Elevated Button — glass mint slab ────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.primary.withValues(alpha: 0.30);
            }
            if (states.contains(WidgetState.pressed)) {
              return (isDark ? AppColors.primaryOnDark : AppColors.primary)
                  .withValues(alpha: 0.95);
            }
            return isDark ? AppColors.primaryOnDark : AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.white.withValues(alpha: 0.5);
            }
            return Colors.white;
          }),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.08),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            (isDark ? AppColors.primaryOnDark : AppColors.primary)
                .withValues(alpha: 0.08),
          ),
          // Glass slab shape
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              letterSpacing: 0.05 * 16,
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
        ),
      ),

      // ── Outlined Button — pill, mint border ───────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
          side: BorderSide(
            color: isDark ? AppColors.primaryOnDark : AppColors.primary,
            width: 1.5,
          ),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            letterSpacing: 0.05 * 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          minimumSize: const Size(0, 48),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.05 * 14,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      // ── Input Decoration — etched glass ───────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.darkCard.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.7),
        hintStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.inter(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.inter(
          color: isDark ? AppColors.primaryOnDark : AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.divider,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.divider,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryOnDark : AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),

      // ── Card — glass surface, ambient shadow ──────────────────────────────
      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.55),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // ── Chip — light grey semi-transparent pill ───────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.7)
            : AppColors.surfaceRaised,
        selectedColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.05 * 13,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // ── Switch — mint ─────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? AppColors.primaryOnDark : AppColors.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return (isDark ? AppColors.primaryOnDark : AppColors.primary)
                .withValues(alpha: 0.3);
          }
          return null;
        }),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Bottom Nav ────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.darkCard.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.85),
        selectedItemColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
        unselectedItemColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
      ),

      // ── Dropdown ──────────────────────────────────────────────────────────
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            isDark
                ? AppColors.darkCard.withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(AppColors.shadowAmbient),
        ),
      ),
    );
  }
}
