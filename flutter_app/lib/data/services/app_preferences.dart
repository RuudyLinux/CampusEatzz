import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_item.dart';
import '../models/canteen_admin_session.dart';
import '../models/user_session.dart';

class AppPreferences {
  static const _sessionKey = 'flutter_user_session';
  static const _canteenAdminSessionKey = 'flutter_canteen_admin_session';
  static const _apiBaseKey = 'flutter_api_base';
  static const _cartKey = 'flutter_cart_items';
  static const _walletBalanceKey = 'flutter_wallet_balance';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<void> saveSession(UserSession session) async {
    final prefs = await _prefs;
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<UserSession?> getSession() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return UserSession.fromJson(map);
      }
      if (map is Map) {
        return UserSession.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionKey);
  }

  Future<void> saveCanteenAdminSession(CanteenAdminSession session) async {
    final prefs = await _prefs;
    await prefs.setString(_canteenAdminSessionKey, jsonEncode(session.toJson()));
  }

  Future<CanteenAdminSession?> getCanteenAdminSession() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_canteenAdminSessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return CanteenAdminSession.fromJson(map);
      }
      if (map is Map) {
        return CanteenAdminSession.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCanteenAdminSession() async {
    final prefs = await _prefs;
    await prefs.remove(_canteenAdminSessionKey);
  }

  Future<void> setApiBase(String base) async {
    final prefs = await _prefs;
    await prefs.setString(_apiBaseKey, base);
  }

  Future<String?> getApiBase() async {
    final prefs = await _prefs;
    return prefs.getString(_apiBaseKey);
  }

  Future<void> saveCart(List<CartItem> items) async {
    final prefs = await _prefs;
    final rows = items.map((e) => e.toJson()).toList(growable: false);
    await prefs.setString(_cartKey, jsonEncode(rows));
  }

  Future<List<CartItem>> getCart() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_cartKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <CartItem>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false);
      }
      return const <CartItem>[];
    } catch (_) {
      return const <CartItem>[];
    }
  }

  Future<void> clearCart() async {
    final prefs = await _prefs;
    await prefs.remove(_cartKey);
  }

  // ── Saved canteens ────────────────────────────────────────────────────────
  static const _savedCanteensKey = 'flutter_saved_canteens';

  Future<void> saveSavedCanteenIds(List<int> ids) async {
    final prefs = await _prefs;
    await prefs.setString(_savedCanteensKey, jsonEncode(ids));
  }

  Future<List<int>> getSavedCanteenIds() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_savedCanteensKey);
    if (raw == null) return <int>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return <int>[];
    }
  }

  // ── Theme mode ───────────────────────────────────────────────────────────
  static const _themeModeKey = 'flutter_theme_mode';

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await _prefs;
    final index = prefs.getInt(_themeModeKey);
    if (index == null || index >= ThemeMode.values.length) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> setWalletBalance(double balance) async {
    final prefs = await _prefs;
    await prefs.setDouble(_walletBalanceKey, balance);
  }

  Future<double?> getWalletBalance() async {
    final prefs = await _prefs;
    return prefs.getDouble(_walletBalanceKey);
  }
}
