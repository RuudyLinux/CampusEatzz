import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF4A2134);
  static const Color navyLight = Color(0xFF8B2A5C);
  static const Color primary = Color(0xFFB70049);
  static const Color primaryDark = Color(0xFFA1003F);
  static const Color accent = Color(0xFF6149B2);

  // ── Light Mode Surfaces ───────────────────────────────────────────────────
  static const Color bg = Color(0xFFFFF4F6);
  static const Color bgSoft = Color(0xFFFFECF1);
  static const Color card = Colors.white;
  static const Color surfaceRaised = Color(0xFFFFE0EA);
  static const Color border = Color(0xFFD89CB4);
  static const Color divider = Color(0xFFFFD8E5);

  // ── Light Mode Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF4A2134);
  static const Color textSecondary = Color(0xFF7E4D61);
  static const Color textMuted = Color(0xFF7E4D61);
  static const Color textDisabled = Color(0xFF9C677D);

  // ── Dark Mode Surfaces ────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF220213);
  static const Color darkSurface = Color(0xFF331022);
  static const Color darkCard = Color(0xFF431930);
  static const Color darkCardRaised = Color(0xFF52263D);
  static const Color darkBorder = Color(0xFF7E4D61);
  static const Color darkDivider = Color(0xFF6A3A4F);

  // ── Dark Mode Text ────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFFFEAF1);
  static const Color darkTextMuted = Color(0xFFC68DA3);
  static const Color darkTextDisabled = Color(0xFF9C677D);

  // ── Dark Mode Primary (lighter for contrast) ──────────────────────────────
  static const Color primaryOnDark = Color(0xFFFF4E7C);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2C9E68);
  static const Color successBg = Color(0xFFDDF6E8);
  static const Color successBgDark = Color(0xFF1A3527);

  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFF3CD);
  static const Color warningBgDark = Color(0xFF3A2B12);

  static const Color danger = Color(0xFFB31B25);
  static const Color dangerBg = Color(0xFFFFE4E6);
  static const Color dangerBgDark = Color(0xFF3C1116);

  static const Color info = Color(0xFF6149B2);
  static const Color infoBg = Color(0xFFEAE4FF);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[Color(0xFFFFF6F9), Color(0xFFFFECF1), Color(0xFFFFE0EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: <Color>[Color(0xFFA1003F), Color(0xFFB70049), Color(0xFFFF5580)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFFB70049), Color(0xFFA1003F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient = LinearGradient(
    colors: <Color>[Color(0xFFB70049), Color(0xFF8B2A5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: <Color>[Color(0xFF220213), Color(0xFF4D001A), Color(0xFF7A173E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Tab Colors (bottom nav) ───────────────────────────────────────────────
  static const Color tabHome = Color(0xFFB70049);
  static const Color tabCart = Color(0xFF6149B2);
  static const Color tabWallet = Color(0xFF9A3669);
  static const Color tabProfile = Color(0xFFFF5580);
}
