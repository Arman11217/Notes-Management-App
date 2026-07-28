import 'dart:convert';
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
      final response = await http
          .post(
            Uri.parse(AppConfig.checkSubscriptionUrl),
            body: {
              'app_id': AppConfig.bdappsAppId,
              'password': AppConfig.bdappsApiKey,
              'msisdn': phoneNumber,
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        // Response success - parse kore check kori
        final result = _parseResponse(response.body);
        // BDApps response format: success/subscribed true or false
        return result.toLowerCase().contains('subscribed') ||
            result.toLowerCase().contains('success') ||
            result.toLowerCase() == 'true';
      }
      return false;
    } catch (e) {
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
}
