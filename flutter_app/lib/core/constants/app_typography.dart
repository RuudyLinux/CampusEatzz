import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  // ── Display / Hero — Manrope ──────────────────────────────────────────────
  static TextStyle get display => GoogleFonts.manrope(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02 * 48,
        height: 1.2,
      );

  // ── Headings — Manrope ────────────────────────────────────────────────────
  static TextStyle get heading1 => GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * 32,
        height: 1.3,
      );

  static TextStyle get heading2 => GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.005 * 24,
        height: 1.4,
      );

  static TextStyle get heading3 => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ── Body — Inter ──────────────────────────────────────────────────────────
  static TextStyle get bodyLg => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      );

  static TextStyle get bodySm => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  // ── Labels — Inter ────────────────────────────────────────────────────────
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05 * 14,
        height: 1.2,
      );

  static TextStyle get labelSm => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.05 * 12,
        height: 1.2,
      );

  // ── Prices — Manrope ──────────────────────────────────────────────────────
  static TextStyle get price => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.0,
      );

  static TextStyle get priceLg => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.0,
      );

  static TextStyle get priceSm => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      );

  // ── UI Controls — Inter ───────────────────────────────────────────────────
  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05 * 16,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.02 * 12,
      );

  static TextStyle get chipText => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.03 * 13,
      );

  static TextStyle get badge => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05 * 10,
      );
}
