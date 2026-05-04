import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (Mint Green) ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF006D2F);
  static const Color primaryBright = Color(0xFF00E46B);
  static const Color primaryContainer = Color(0xFF32FF7E);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF007232);
  static const Color inversePrimary = Color(0xFF00E46B);

  // ── Secondary / Neutral ────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF5C5F60);
  static const Color secondaryContainer = Color(0xFFE1E3E4);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF626566);

  // ── Tertiary ───────────────────────────────────────────────────────────────
  static const Color tertiary = Color(0xFF5B5F62);
  static const Color tertiaryContainer = Color(0xFFDCDFE2);

  // ── Surface (Light — glass base) ──────────────────────────────────────────
  static const Color bg = Color(0xFFF7F9FF);
  static const Color bgSoft = Color(0xFFF1F4F9);
  static const Color card = Colors.white;
  static const Color surfaceRaised = Color(0xFFEBEEF3);
  static const Color surfaceHigh = Color(0xFFE5E8EE);
  static const Color surfaceHighest = Color(0xFFE0E3E8);
  static const Color border = Color(0xFF6B7B6A);
  static const Color divider = Color(0xFFBACBB8);

  // ── On-Surface Text (Light) ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF181C20);
  static const Color textSecondary = Color(0xFF3B4B3C);
  static const Color textMuted = Color(0xFF6B7B6A);
  static const Color textDisabled = Color(0xFFBACBB8);

  // ── Dark Mode Surfaces ────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0E1210);
  static const Color darkSurface = Color(0xFF161A17);
  static const Color darkCard = Color(0xFF1E2420);
  static const Color darkCardRaised = Color(0xFF252C28);
  static const Color darkBorder = Color(0xFF2D3830);
  static const Color darkDivider = Color(0xFF1F2922);

  // ── Dark Mode Text ────────────────────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFEEF1F6);
  static const Color darkTextMuted = Color(0xFF8A9E8C);
  static const Color darkTextDisabled = Color(0xFF4A5C4C);

  // ── Dark Mode Primary ─────────────────────────────────────────────────────
  static const Color primaryOnDark = Color(0xFF00E46B);

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF006D2F);
  static const Color successBg = Color(0xFFD6F5E3);
  static const Color successBgDark = Color(0xFF0A2E18);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningBgDark = Color(0xFF2D1F05);

  static const Color danger = Color(0xFFBA1A1A);
  static const Color dangerBg = Color(0xFFFFDAD6);
  static const Color dangerBgDark = Color(0xFF3C1116);

  static const Color info = Color(0xFF006D2F);
  static const Color infoBg = Color(0xFFD6F5E3);

  // ── Glass Surfaces ────────────────────────────────────────────────────────
  // White at 45% — base glass fill
  static const Color glassFill = Color(0x73FFFFFF);
  // White at 20% — inner top/left bevel
  static const Color glassBevelTop = Color(0x33FFFFFF);
  // Black at 10% — inner bottom/right bevel
  static const Color glassBevelBottom = Color(0x1A000000);
  // Ambient shadow — very soft, wide spread
  static const Color glassShadow = Color(0x0A000000);
  // Mint tint on glass
  static const Color glassMintTint = Color(0x0D006D2F);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[Color(0xFFF7F9FF), Color(0xFFF1F4F9), Color(0xFFEBEEF3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFF006D2F), Color(0xFF005322)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGlowGradient = LinearGradient(
    colors: <Color>[Color(0xFF32FF7E), Color(0xFF00E46B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: <Color>[Color(0xFF005322), Color(0xFF006D2F), Color(0xFF008A3A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient = LinearGradient(
    colors: <Color>[Color(0xFF006D2F), Color(0xFF00A845)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: <Color>[Color(0xFF0A1A10), Color(0xFF003D1A), Color(0xFF005322)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows ───────────────────────────────────────────────────────────────
  // Ambient occlusion — lifts glass off white bg (spec: 0 20px 40px rgba(0,0,0,0.04))
  static const Color shadowAmbient = Color(0x0A000000);
  static const Color shadowMintTint = Color(0x0D006D2F);

  // ── Tab Colors ────────────────────────────────────────────────────────────
  static const Color tabHome = Color(0xFF006D2F);
  static const Color tabCart = Color(0xFF5C5F60);
  static const Color tabWallet = Color(0xFF008A3A);
  static const Color tabProfile = Color(0xFF00A845);

  // ── Legacy aliases (kept so existing refs compile) ────────────────────────
  static const Color navy = Color(0xFF181C20);
  static const Color navyLight = Color(0xFF3B4B3C);
  static const Color accent = Color(0xFF00A845);
  static const Color shadowPink = Color(0x0A006D2F);
  static const Color shadowPinkMd = Color(0x14006D2F);
}
