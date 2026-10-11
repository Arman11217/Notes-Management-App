import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// BDApps API Service - 4ta main API handle kore:
/// 1. checkSubscription - login er somoy check kore subscribed kina
/// 2. sendOtp - OTP pathay phone number e
/// 3. verifyOtp - OTP verify kore login complete kore
/// 4. unsubscribe - app theke ber hoy
class BdappsApiService {
  /// HTTP request timeout (30 seconds)
  static const Duration _timeout = Duration(seconds: 30);

  /// Check if a phone number is already subscribed.
  /// Returns true if subscribed, false otherwise.
  Future<bool> checkSubscription(String phoneNumber) async {
    try {
      // Normalize the phone number to the formats BDApps accepts:
      //   - 8801XXXXXXXXX  (country code + 880 prefix + 10 digits)
      //   - 01XXXXXXXXX   (local Bangladeshi format)
      final String normalized = _normalizeMsisdn(phoneNumber);
      debugPrint('[BDApps] checkSubscription URL=${AppConfig.checkSubscriptionUrl}');
      debugPrint('[BDApps] checkSubscription original="$phoneNumber" normalized="$normalized"');

      final response = await http
          .post(
            Uri.parse(AppConfig.checkSubscriptionUrl),
            body: {
              'app_id': AppConfig.bdappsAppId,
              'password': AppConfig.bdappsApiKey,
              'msisdn': normalized,
              'user_mobile': normalized,
              'mobile': normalized,
            },
          )
          .timeout(_timeout);

      // DEBUG: log raw response so we can see exactly what BDApps returned
      debugPrint('[BDApps] checkSubscription status=${response.statusCode}');
      debugPrint('[BDApps] checkSubscription body=${response.body}');

      if (response.statusCode != 200) return false;

      // Try to parse as JSON first — BDApps standard response shape is:
      // {"subscriptionStatus":"REGISTERED","statusCode":"S1000","statusDetail":"..."}
      try {
        final json = jsonDecode(response.body);
        if (json is Map) {
          // 1) BDApps gives us an explicit boolean — trust that first.
          if (json.containsKey('isSubscribed')) {
            return json['isSubscribed'] == true;
          }
          // 2) Fall back to subscriptionStatus text matching.
          final statusCode = json['statusCode']?.toString() ?? '';
          final subStatus =
              json['subscriptionStatus']?.toString().toUpperCase() ?? '';
          final successFlag = json['success'] == true;

          // Anything containing "REGISTERED" / "ACTIVE" / "SUBSCRIBED"
          // counts as subscribed. "INITIAL CHARGING PENDING" / "PENDING"
          // / "UNREGISTERED" all count as NOT subscribed.
          final isRegistered = successFlag ||
              (statusCode == 'S1000' &&
                  (subStatus.contains('REGISTERED') ||
                      subStatus.contains('ACTIVE') ||
                      subStatus.contains('SUBSCRIBED')));
          return isRegistered;
        }
      } catch (_) {
        // Not JSON — fall through to plain-text matching.
      }

      // Plain-text fallback
      final result = _parseResponse(response.body).toLowerCase();
      return result.contains('subscribed') ||
          result.contains('registered') ||
          (result.contains('active') && !result.contains('not active'));
    } catch (e) {
      debugPrint('[BDApps] checkSubscription error: $e');
      throw Exception('Check subscription failed: $e');
    }
  }

  /// Send OTP to the given phone number for login verification.
  Future<String> sendOtp(String phoneNumber) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.sendOtpUrl),
            body: {
              'app_id': AppConfig.bdappsAppId,
              'password': AppConfig.bdappsApiKey,
              'msisdn': phoneNumber,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        throw Exception(
          'OTP send failed. Server returned: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Send OTP failed: $e');
    }
  }

  /// Verify the OTP entered by user. Returns true if valid.
  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.verifyOtpUrl),
            body: {
              'app_id': AppConfig.bdappsAppId,
              'password': AppConfig.bdappsApiKey,
              'msisdn': phoneNumber,
              'otp': otp,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final result = _parseResponse(response.body);
        // Success message comes back if OTP matched
        return result.toLowerCase().contains('success') ||
            result.toLowerCase().contains('verified') ||
            result.toLowerCase() == 'true';
      }
      return false;
    } catch (e) {
      throw Exception('Verify OTP failed: $e');
    }
  }

  /// Unsubscribe the user from the app.
  Future<bool> unsubscribe(String phoneNumber) async {
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.unsubscribeUrl),
            body: {
              'app_id': AppConfig.bdappsAppId,
              'password': AppConfig.bdappsApiKey,
              'msisdn': phoneNumber,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseResponse(response.body)
            .toLowerCase()
            .contains('success');
      }
      return false;
    } catch (e) {
      throw Exception('Unsubscribe failed: $e');
    }
  }

  /// Helper - parse response body whether JSON or plain text.
  String _parseResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        // Try common keys
        return (json['status'] ??
                json['message'] ??
                json['response'] ??
                json.toString())
            .toString();
      }
      return body;
    } catch (_) {
      // Not JSON, return as-is
      return body.trim();
    }
  }

  /// Normalize the user-provided phone number into a canonical
  /// `8801XXXXXXXXX` (country-code + 880 + 10 digit local) shape.
  ///
  /// Examples:
  ///   "8801603451036" -> "8801603451036"   (already normalized)
  ///   "01603451036"   -> "8801603451036"   (add 880 prefix)
  ///   "+8801603451036"-> "8801603451036"   (strip leading +)
  ///   "1603451036"    -> "8801603451036"   (assume missing 0, add 880)
  String _normalizeMsisdn(String input) {
    String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('8801') && digits.length >= 13) {
      return digits;
    }
    if (digits.startsWith('01') && digits.length == 11) {
      return '88${digits.substring(1)}';
    }
    if (digits.length == 10) {
      return '880$digits';
    }
    return digits;
  }
}
