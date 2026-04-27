import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFB80049);
  static const Color primaryDark = Color(0xFF900038);
  static const Color primaryContainer = Color(0xFFE2165F);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color inversePrimary = Color(0xFFFFB2BE);
  static const Color accent = Color(0xFF9F345E); // tertiary rose-pink

  // ── Semantic alias kept for legacy widget refs ────────────────────────────
  static const Color navy = Color(0xFF1D1B1C);
  static const Color navyLight = Color(0xFF5B3F43);

  // ── Light Mode Surfaces ───────────────────────────────────────────────────
  static const Color bg = Color(0xFFFEF8F9);
  static const Color bgSoft = Color(0xFFF8F2F3);
  static const Color card = Colors.white;
  static const Color surfaceRaised = Color(0xFFF2ECED);
  static const Color border = Color(0xFF8F6F73);
  static const Color divider = Color(0xFFE4BDC2);

  // ── Light Mode Text ───────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1D1B1C);
  static const Color textSecondary = Color(0xFF5B3F43);
  static const Color textMuted = Color(0xFF5B3F43);
  static const Color textDisabled = Color(0xFF8F6F73);

  // ── Dark Mode Surfaces ────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF1A1112);
  static const Color darkSurface = Color(0xFF261A1C);
  static const Color darkCard = Color(0xFF332225);
  static const Color darkCardRaised = Color(0xFF42292E);
  static const Color darkBorder = Color(0xFF5B3F43);
  static const Color darkDivider = Color(0xFF3D2729);

  // ── Dark Mode Text ────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF5EFF0);
  static const Color darkTextMuted = Color(0xFFC4A8AC);
  static const Color darkTextDisabled = Color(0xFF8F6F73);

  // ── Dark Mode Primary ─────────────────────────────────────────────────────
  static const Color primaryOnDark = Color(0xFFFFB2BE);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2C9E68);
  static const Color successBg = Color(0xFFDDF6E8);
  static const Color successBgDark = Color(0xFF1A3527);

  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFF3CD);
  static const Color warningBgDark = Color(0xFF3A2B12);

  static const Color danger = Color(0xFFBA1A1A);
  static const Color dangerBg = Color(0xFFFFDAD6);
  static const Color dangerBgDark = Color(0xFF3C1116);

  static const Color info = Color(0xFF9F345E);
  static const Color infoBg = Color(0xFFF4DCE4);

  // ── Ambient Shadow (pink-tinted) ──────────────────────────────────────────
  static const Color shadowPink = Color(0x14B80049); // rgba(184,0,73,0.08)
  static const Color shadowPinkMd = Color(0x1FB80049); // rgba(184,0,73,0.12)

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[Color(0xFFFEF8F9), Color(0xFFF8F2F3), Color(0xFFF2ECED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: <Color>[Color(0xFF900038), Color(0xFFB80049), Color(0xFFE2165F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFFB80049), Color(0xFF900038)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient = LinearGradient(
    colors: <Color>[Color(0xFFB80049), Color(0xFF9F345E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: <Color>[Color(0xFF1A1112), Color(0xFF4D001A), Color(0xFF7A173E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Tab Colors (bottom nav) ───────────────────────────────────────────────
  static const Color tabHome = Color(0xFFB80049);
  static const Color tabCart = Color(0xFF9F345E);
  static const Color tabWallet = Color(0xFFBE4D76);
  static const Color tabProfile = Color(0xFFE2165F);
}
