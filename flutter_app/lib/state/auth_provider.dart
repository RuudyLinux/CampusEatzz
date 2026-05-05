import 'package:flutter/foundation.dart';

import '../data/models/user_session.dart';
import '../data/services/app_preferences.dart';
import '../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._preferences);

  final AuthService _authService;
  final AppPreferences _preferences;

  UserSession? _session;
  bool _loading = false;
  String? _error;
  String _pendingIdentifier = '';
  String? _pendingDevOtp;

  UserSession? get session => _session;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isLoggedIn => _session != null;
  String get pendingIdentifier => _pendingIdentifier;
  String? get pendingDevOtp => _pendingDevOtp;

  Future<void> restoreSession() async {
    _loading = true;
    notifyListeners();
    try {
      final saved = await _preferences.getSession();
      _session = saved;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> requestOtp({
    required String identifier,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final challenge = await _authService.requestOtp(
        identifier: identifier,
        password: password,
      );

      if (!challenge.success) {
        _error = challenge.message;
        return false;
      }

      final resolvedIdentifier = challenge.identifier.trim().isNotEmpty
          ? challenge.identifier.trim()
          : identifier.trim();
      _pendingIdentifier = resolvedIdentifier;
      _pendingDevOtp = challenge.developmentOtp;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendOtp() async {
    if (_pendingIdentifier.trim().isEmpty) {
      _error = 'Missing OTP identifier.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final challenge = await _authService.resendOtp(_pendingIdentifier);
      if (!challenge.success) {
        _error = challenge.message;
        return false;
      }

      _pendingDevOtp = challenge.developmentOtp;
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtp(String otp) async {
    if (_pendingIdentifier.trim().isEmpty) {
      _error = 'Missing OTP identifier.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final session = await _authService.verifyOtp(
        identifier: _pendingIdentifier,
        otp: otp,
      );
      _session = session;
      _pendingIdentifier = '';
      _pendingDevOtp = null;
      _error = null;
      await _preferences.saveSession(session);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProfile() async {
    final current = _session;
    if (current == null) {
      return;
    }

    try {
      final updated = await _authService.fetchMe(current);
      _session = updated;
      await _preferences.saveSession(updated);
      notifyListeners();
    } catch (_) {
      // Keep current session if refresh fails.
    }
  }

  /// Updates session with new profile image URL and persists to prefs.
  Future<void> updateProfileImage(String imageUrl) async {
    final current = _session;
    if (current == null) return;
    _session = current.copyWith(profileImageUrl: imageUrl);
    await _preferences.saveSession(_session!);
    notifyListeners();
  }

  Future<void> logout() async {
    _session = null;
    _pendingIdentifier = '';
    _pendingDevOtp = null;
    _error = null;
    await _preferences.clearSession();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
