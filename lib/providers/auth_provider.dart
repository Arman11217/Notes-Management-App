import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bdapps_api_service.dart';

/// AuthProvider - sob authentication state manage kore.
/// Login, logout, subscription check ekhane handle hoy.
class AuthProvider extends ChangeNotifier {
  final BdappsApiService _apiService = BdappsApiService();

  // ============== STATE ==============
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isSubscribed = false;
  String? _phoneNumber;
  String? _errorMessage;

  // ============== GETTERS ==============
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isSubscribed => _isSubscribed;
  String? get phoneNumber => _phoneNumber;
  String? get errorMessage => _errorMessage;

  // ============== CONSTRUCTOR ==============
  AuthProvider() {
    loadSavedSession();
  }

  /// App khulle age thaka login state load kore.
  Future<void> loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('logged_in_phone');
      final savedSubscribed = prefs.getBool('is_subscribed') ?? false;
      if (savedPhone != null && savedPhone.isNotEmpty) {
        _phoneNumber = savedPhone;
        _isLoggedIn = true;
        _isSubscribed = savedSubscribed;
        notifyListeners();
      }
    } catch (e) {
      // Silent fail - session save korte parle valo
    }
  }

  /// Set loading state and notify UI.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Save login session locally.
  Future<void> _saveSession(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logged_in_phone', phone);
  }

  /// Subscription status locally save kori.
  Future<void> _saveSubscription(bool subscribed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', subscribed);
  }

  /// Clear saved session (logout).
  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logged_in_phone');
    await prefs.remove('is_subscribed');
  }

  /// STEP 1: Check if phone number is already subscribed.
  /// Returns true if subscribed, false if not.
  Future<bool> checkSubscription(String phone) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _apiService.checkSubscription(phone);
      _isSubscribed = result;
      await _saveSubscription(result);
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// STEP 2: Send OTP to phone number for verification.
  Future<bool> sendOtp(String phone) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await _apiService.sendOtp(phone);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// STEP 3: Verify OTP and complete login.
  Future<bool> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _apiService.verifyOtp(
        phoneNumber: phone,
        otp: otp,
      );
      if (success) {
        _phoneNumber = phone;
        _isLoggedIn = true;
        await _saveSession(phone);
        notifyListeners();
        return true;
      }
      _errorMessage = 'Invalid OTP. Please try again.';
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Logout from app - clear session.
  Future<void> logout() async {
    _isLoggedIn = false;
    _phoneNumber = null;
    await _clearSession();
    notifyListeners();
  }

  /// Unsubscribe - subscription cancel kore.
  Future<bool> unsubscribe([String? phone]) async {
    final targetPhone = phone ?? _phoneNumber;
    if (targetPhone == null) return false;

    _setLoading(true);
    _errorMessage = null;
    try {
      final success = await _apiService.unsubscribe(targetPhone);
      if (success) {
        _isSubscribed = false;
        await _saveSubscription(false);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear any error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
