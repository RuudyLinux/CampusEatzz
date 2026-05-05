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
      onPrimary: isDark ? AppColors.darkBg : Colors.white,
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
      error: isDark ? AppColors.darkDanger : AppColors.danger,
      onError: Colors.white,
      errorContainer: isDark ? AppColors.dangerBgDark : AppColors.dangerBg,
      onErrorContainer: isDark ? AppColors.darkDanger : AppColors.danger,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      outlineVariant: isDark ? AppColors.darkDivider : AppColors.divider,
    );

    final base = isDark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);

    // Plus Jakarta Sans for everything
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800, fontSize: 48, letterSpacing: -0.96, height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800, fontSize: 40, letterSpacing: -0.5, height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: -0.32, height: 1.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800, fontSize: 28, letterSpacing: -0.5, height: 1.3,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800, fontSize: 22, letterSpacing: -0.3, height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700, fontSize: 18, height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700, fontSize: 17, height: 1.4,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.1,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.1,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w400, height: 1.6,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.6,
        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 13, fontWeight: FontWeight.w400, height: 1.5,
        color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2,
      ),
    );

    // Glass button foreground color helper
    final btnFg = isDark ? Colors.white : AppColors.textPrimary.withValues(alpha: 0.9);

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.bg,
      textTheme: textTheme,

      // ── AppBar — glass frosted ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.navBgDark
            : AppColors.navBgLight,
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

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.primaryOnDark : AppColors.primary,
        linearTrackColor: isDark ? AppColors.darkGlassMid : AppColors.glassMid,
        circularTrackColor: Colors.transparent,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerColor: isDark ? AppColors.darkDivider : AppColors.divider,
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.darkDivider : AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar — glass ──────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? AppColors.darkGlassStrong.withValues(alpha: 0.95)
            : AppColors.textPrimary.withValues(alpha: 0.92),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),

      // ── Elevated Button — Liquid Glass frosted ────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark
                  ? AppColors.darkGlassFill
                  : AppColors.glassFill.withValues(alpha: 0.4);
            }
            if (states.contains(WidgetState.pressed)) {
              return isDark
                  ? AppColors.accentBtnDark.withValues(alpha: 0.85)
                  : AppColors.accentBtnLight.withValues(alpha: 0.85);
            }
            return isDark ? AppColors.accentBtnDark : AppColors.accentBtnLight;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return isDark
                  ? AppColors.darkTextMuted
                  : AppColors.textPrimary.withValues(alpha: 0.4);
            }
            return btnFg;
          }),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.08),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: WidgetStatePropertyAll(
            isDark ? AppColors.accentGlowDark : AppColors.accentGlowLight,
          ),
          side: WidgetStatePropertyAll(BorderSide(
            color: isDark ? AppColors.accentBtnBorderDark : AppColors.accentBtnBorderLight,
            width: 1,
          )),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
        ),
      ),

      // ── Outlined Button — glass pill ──────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.primary,
          side: BorderSide(
            color: isDark ? AppColors.darkGlassBorder : AppColors.border,
            width: 1,
          ),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          minimumSize: const Size(0, 48),
        ),
      ),

      // ── Text Button ───────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.primary,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2,
          ),
          shape: const StadiumBorder(),
        ),
      ),

      // ── Input — liquid glass etched ───────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 15,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 15, fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.primaryOnDark : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.inputBorderDark : AppColors.inputBorderLight,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.inputBorderDark : AppColors.inputBorderLight,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.primaryOnDark : AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDanger : AppColors.danger,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDanger : AppColors.danger,
            width: 1.5,
          ),
        ),
      ),

      // ── Card — liquid glass ───────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: isDark
            ? AppColors.darkGlassFill
            : AppColors.glassMid,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      // ── Chip — glass pill ─────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? AppColors.darkGlassMid
            : AppColors.glassMid,
        selectedColor: isDark
            ? AppColors.primaryOnDark.withValues(alpha: 0.20)
            : AppColors.primary.withValues(alpha: 0.15),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark
                ? AppColors.primaryOnDark.withValues(alpha: 0.35)
                : AppColors.primary.withValues(alpha: 0.35);
          }
          return isDark ? AppColors.darkGlassBorder : AppColors.border;
        }),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Bottom Nav bar ────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? AppColors.navBgDark : AppColors.navBgLight,
        selectedItemColor: isDark ? AppColors.primaryOnDark : AppColors.primary,
        unselectedItemColor: isDark ? AppColors.darkTextDisabled : AppColors.textMuted,
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
          shadowColor: const WidgetStatePropertyAll(AppColors.glassShadow),
        ),
      ),
    );
  }
}
