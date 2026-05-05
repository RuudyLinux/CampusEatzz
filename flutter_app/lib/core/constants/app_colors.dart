import 'package:flutter/material.dart';

/// Liquid Glass design system — iOS 26 aesthetic
/// Dark: deep #0d0d18 bg, white/silver glass layers
/// Light: #e8eaf6 bg, translucent white glass layers
class AppColors {
  // ── Core backgrounds ───────────────────────────────────────────────────────
  static const Color bg = Color(0xFFf0f2fa);
  static const Color bgSoft = Color(0xFFe8eaf6);
  static const Color darkBg = Color(0xFF0d0d18);
  static const Color darkSurface = Color(0xFF12121f);
  static const Color darkCard = Color(0xFF1a1a2e);
  static const Color darkCardRaised = Color(0xFF1f1f35);
  static const Color darkBorder = Color(0x2DFFFFFF); // white 18%
  static const Color darkDivider = Color(0x14FFFFFF); // white 8%

  // ── Glass surfaces (light) ─────────────────────────────────────────────────
  static const Color glassFill = Color(0x80FFFFFF); // white 50%
  static const Color glassMid = Color(0x99FFFFFF); // white 60%
  static const Color glassStrong = Color(0xB8FFFFFF); // white 72%
  static const Color glassBevelTop = Color(0xF2FFFFFF); // white 95% — top edge
  static const Color glassBevelBottom = Color(0x1A000000); // black 10%
  static const Color glassShadow = Color(0x0A000000); // ambient

  // ── Glass surfaces (dark) ─────────────────────────────────────────────────
  static const Color darkGlassFill = Color(0x12FFFFFF); // white 7%
  static const Color darkGlassMid = Color(0x1AFFFFFF); // white 10%
  static const Color darkGlassStrong = Color(0x21FFFFFF); // white 13%
  static const Color darkGlassBevelTop = Color(0x59FFFFFF); // white 35%
  static const Color darkGlassBorder = Color(0x2DFFFFFF); // white 18%

  // ── Blob background tints ─────────────────────────────────────────────────
  static const Color blobLight1 = Color(0x59B4B4FF); // rgba(180,180,255,0.35)
  static const Color blobLight2 = Color(0x338C8CE6); // rgba(140,140,230,0.20)
  static const Color blobDark1 = Color(0x2EC8C8FF); // rgba(200,200,255,0.18)
  static const Color blobDark2 = Color(0x1FA0A0DC); // rgba(160,160,220,0.12)

  // ── Primary accent ────────────────────────────────────────────────────────
  // Dark mode: white/silver glass accent
  static const Color primaryOnDark = Color(0xF2FFFFFF); // rgba(255,255,255,0.95)
  static const Color accentGlowDark = Color(0x40FFFFFF); // rgba(255,255,255,0.25)
  static const Color accentBtnDark = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  static const Color accentBtnBorderDark = Color(0x66FFFFFF); // rgba(255,255,255,0.40)

  // Light mode: deep indigo accent
  static const Color primary = Color(0xFF3c3c78);
  static const Color primaryBright = Color(0xFF5555a0);
  static const Color primaryContainer = Color(0xFFdde1f5);
  static const Color onPrimary = Colors.white;
  static const Color onPrimaryContainer = Color(0xFF2a2a60);
  static const Color inversePrimary = Color(0xFF9999cc);
  static const Color accentGlowLight = Color(0x405050B4); // rgba(80,80,180,0.25)
  static const Color accentBtnLight = Color(0x99FFFFFF); // rgba(255,255,255,0.60)
  static const Color accentBtnBorderLight = Color(0xE6FFFFFF); // rgba(255,255,255,0.90)

  // ── Typography ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0f0f1e);
  static const Color textSecondary = Color(0xFF2a2a40);
  static const Color textMuted = Color(0x61000F1E); // rgba(15,15,30,0.38)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextMuted = Color(0x99FFFFFF); // rgba(255,255,255,0.60)
  static const Color darkTextDisabled = Color(0x59FFFFFF); // rgba(255,255,255,0.35)

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF059669); // light
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color successBgDark = Color(0xFF052e1e);
  static const Color darkSuccess = Color(0xFF6EFFC1); // rgba(110,255,193,1)

  static const Color warning = Color(0xFFD97706); // light
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color warningBgDark = Color(0xFF2D1F05);
  static const Color darkWarning = Color(0xFFFFCC66);

  static const Color danger = Color(0xFFE53E3E); // light
  static const Color dangerBg = Color(0xFFFFE4E4);
  static const Color dangerBgDark = Color(0xFF3c1116);
  static const Color darkDanger = Color(0xFFFF6B7A);

  static const Color info = Color(0xFF2563EB); // light
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color darkInfo = Color(0xFF82CFFF);

  // ── Nav / header ──────────────────────────────────────────────────────────
  static const Color navBgDark = Color(0xBF0A0A14); // rgba(10,10,20,0.75)
  static const Color headerBgDark = Color(0xB30A0A14); // rgba(10,10,20,0.70)
  static const Color navBgLight = Color(0xCCE6E8F8); // rgba(230,232,248,0.80)
  static const Color headerBgLight = Color(0xBFE6E8F8); // rgba(230,232,248,0.75)

  // ── Input ─────────────────────────────────────────────────────────────────
  static const Color inputBgDark = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color inputBorderDark = Color(0x33FFFFFF); // rgba(255,255,255,0.20)
  static const Color inputBgLight = Color(0xA6FFFFFF); // rgba(255,255,255,0.65)
  static const Color inputBorderLight = Color(0xE6FFFFFF); // rgba(255,255,255,0.90)

  // ── Legacy surface aliases ─────────────────────────────────────────────────
  static const Color surfaceHigh = Color(0xFFE0E3EE);
  static const Color surfaceHighest = Color(0xFFD8DCE8);
  static const Color shadowMintTint = Color(0x0A3c3c78);

  // ── Misc ──────────────────────────────────────────────────────────────────
  static const Color navy = Color(0xFF0f0f1e);
  static const Color card = Colors.white;
  static const Color surfaceRaised = Color(0xFFEBEEF3);
  static const Color border = Color(0xFFCCCEE0);
  static const Color divider = Color(0xFFD8DAF0);
  static const Color accent = Color(0xFF5555a0); // alias for primaryBright
  static const Color shadowPink = Color(0x0A3c3c78);
  static const Color shadowAmbient = Color(0x0A000000);
  static const Color secondary = Color(0xFF5C5F60);
  static const Color secondaryContainer = Color(0xFFE1E3E4);
  static const Color onSecondary = Colors.white;
  static const Color onSecondaryContainer = Color(0xFF626566);
  static const Color tertiary = Color(0xFF5B5F62);
  static const Color tertiaryContainer = Color(0xFFDCDFE2);
  static const Color textDisabled = Color(0xFFBACBB8);
  static const Color tabHome = Color(0xFF3c3c78);
  static const Color tabCart = Color(0xFF5C5F60);
  static const Color tabWallet = Color(0xFF5555a0);
  static const Color tabProfile = Color(0xFF6666a8);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: <Color>[Color(0xFFe8eaf6), Color(0xFFf3f4fb), Color(0xFFdde1f5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: <Color>[Color(0xFF0d0d18), Color(0xFF12121f), Color(0xFF0a0a14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[Color(0xFF3c3c78), Color(0xFF28286e)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintGlowGradient = LinearGradient(
    colors: <Color>[Color(0xFF5555a0), Color(0xFF3c3c78)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Glass card gradient (light)
  static const LinearGradient glassCardGradient = LinearGradient(
    colors: <Color>[Color(0x99FFFFFF), Color(0x8CFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass card gradient (dark)
  static const LinearGradient darkGlassCardGradient = LinearGradient(
    colors: <Color>[Color(0x1AFFFFFF), Color(0x0FFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Full glass panel gradient (dark)
  static const LinearGradient darkGlassPanelGradient = LinearGradient(
    colors: <Color>[Color(0x21FFFFFF), Color(0x12FFFFFF), Color(0x0AFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: <double>[0.0, 0.6, 1.0],
  );

  // Full glass panel gradient (light)
  static const LinearGradient glassHeroGradient = LinearGradient(
    colors: <Color>[Color(0x24FFFFFF), Color(0x0DFFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Header gradient (dark)
  static const LinearGradient headerGradient = LinearGradient(
    colors: <Color>[Color(0xFF0d0d18), Color(0xFF12121f), Color(0xFF0a0a14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: <Color>[Color(0xFF0d0d18), Color(0xFF12121f), Color(0xFF0a0a14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient walletGradient = LinearGradient(
    colors: <Color>[Color(0xFF3c3c78), Color(0xFF5555a0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shadowPinkMd = LinearGradient(
    colors: <Color>[Color(0x143c3c78), Color(0x0A3c3c78)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color shadowPinkMdFlat = Color(0x143c3c78);
}
