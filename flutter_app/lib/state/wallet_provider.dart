import 'package:flutter/foundation.dart';

import '../data/models/wallet_models.dart';
import '../data/services/app_preferences.dart';
import '../data/services/customer_service.dart';

class WalletProvider extends ChangeNotifier {
  WalletProvider(this._service, this._preferences);

  final CustomerService _service;
  final AppPreferences _preferences;

  WalletInfo _wallet = const WalletInfo(balance: 0, currency: 'INR');
  List<WalletTransaction> _transactions = const <WalletTransaction>[];
  bool _loading = false;
  String? _error;

  WalletInfo get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> load(String identifier) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        _service.getWallet(identifier),
        _service.getWalletTransactions(identifier, limit: 10),
      ]);

      _wallet = results[0] as WalletInfo;
      _transactions = results[1] as List<WalletTransaction>;
      await _preferences.setWalletBalance(_wallet.balance);
    } catch (e) {
      _error = e.toString();
      final cached = await _preferences.getWalletBalance();
      if (cached != null) {
        _wallet = WalletInfo(balance: cached, currency: 'INR');
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> recharge({
    required String identifier,
    required double amount,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _wallet = await _service.rechargeWallet(identifier: identifier, amount: amount);
      await _preferences.setWalletBalance(_wallet.balance);
      _transactions = await _service.getWalletTransactions(identifier, limit: 10);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void applyLocalBalance(double value) {
    _wallet = WalletInfo(balance: value, currency: _wallet.currency);
    _preferences.setWalletBalance(value);
    notifyListeners();
  }
}
