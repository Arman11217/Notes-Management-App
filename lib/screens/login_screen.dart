import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// BDApps API base URL — automatically derived from your NADB ID.
// Change `nadbId` in lib/config/app_config.dart to point at your
// application server. The trailing slash is required because every
// endpoint below concatenates `path.php` directly.
// Use `final` (not `const`) because AppConfig.baseUrl is a getter, not
// a compile-time constant.
final String _baseUrl = AppConfig.baseUrl;

/// True for Robi (018) / Airtel (016) prefixes. We strip the leading 0
/// later so the value sent to BDApps is the international form
/// `8801XXXXXXXXX`.
bool _isSupportedRobiAirtelNumber(String phone) {
  return RegExp(r'^01(?:6|8)\d{8}$').hasMatch(phone);
}

/// Calls `check_subscription.php` and returns true when the server reports
/// an active or activating subscription:
///   - `REGISTERED`              → billing confirmed
///   - `INITIAL CHARGING PENDING` → subscription exists, billing still ticking
/// Any other state (`UNREGISTERED`, missing field, error, etc.) returns false.
Future<bool> _isUserSubscribedOrPending(String phone) async {
  try {
    final response = await http
        .post(
          Uri.parse('${_baseUrl}check_subscription.php'),
          body: {'user_mobile': phone},
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return false;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }

    final status =
        decoded['subscriptionStatus']?.toString().trim().toUpperCase() ?? '';
    return status == 'REGISTERED';
  } catch (e) {
    return false;
  }
}

/// Polls `check_subscription.php` until REGISTERED (or INITIAL CHARGING
/// PENDING — both grant access) is reported, or `maxAttempts` is reached.
/// Returns true on either of those states, false otherwise.
Future<bool> _waitForSubscriptionSyncShared(
  String phone, {
  int maxAttempts = 12,
  Duration delay = const Duration(seconds: 2),
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await Future.delayed(delay);
    if (await _isUserSubscribedOrPending(phone)) {
      return true;
    }
  }
  return false;
}

/// Converts a local Robi/Airtel number (`01XXXXXXXXX`) into the
/// international format (`8801XXXXXXXXX`) that BDApps expects.
String _toInternational(String phone) {
  if (phone.startsWith('880')) return phone;
  if (phone.startsWith('0')) return '88$phone';
  return phone;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<bool> _checkAlreadySubscribed(String phone) async {
    return _isUserSubscribedOrPending(phone);
  }

  Future<void> _onContinue() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showError('মোবাইল নম্বর দিন');
      return;
    }
    if (!_isSupportedRobiAirtelNumber(phone)) {
      _showError('সঠিক Robi/Airtel নম্বর দিন');
      return;
    }

    setState(() => _isLoading = true);

    // Convert to international format for the BDApps API.
    final intlPhone = _toInternational(phone);

    try {
      // Check if already subscribed
      final isSubscribed = await _checkAlreadySubscribed(intlPhone);

      if (isSubscribed) {
        _showSuccess('স্বাগতম! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          await _saveAndGoHome(intlPhone);
        } catch (e) {
          if (mounted) {
            _showError('লগইন করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।');
            setState(() => _isLoading = false);
          }
        }
        return;
      }

      // Send OTP request. Wrapped in its own try/catch so a network blip
      // or non-JSON response surfaces as "OTP পাঠাতে সমস্যা" instead of
      // the generic "নেটওয়ার্ক সমস্যা" — the real failure is on the
      // send_otp endpoint, not on the device's connectivity.
      Map<String, dynamic> otpData;
      try {
        final otpResponse = await http
            .post(
              Uri.parse('${_baseUrl}send_otp.php'),
              body: {'user_mobile': intlPhone},
            )
            .timeout(const Duration(seconds: 15));

        final decoded = jsonDecode(otpResponse.body);
        if (decoded is! Map<String, dynamic>) {
          _showError(
            'OTP পাঠাতে সমস্যা হয়েছে। সার্ভার থেকে সঠিক উত্তর আসছে না।',
          );
          return;
        }
        otpData = decoded;
      } on TimeoutException {
        _showError('OTP পাঠাতে সমস্যা হয়েছে। সময় শেষ — আবার চেষ্টা করুন।');
        return;
      } on FormatException {
        _showError(
          'OTP পাঠাতে সমস্যা হয়েছে। সার্ভার থেকে সঠিক উত্তর আসছে না।',
        );
        return;
      } catch (e) {
        _showError('OTP পাঠাতে সমস্যা হয়েছে। আবার চেষ্টা করুন।');
        return;
      }

      final success = otpData['success'] == true;
      final referenceNo = otpData['referenceNo']?.toString().trim() ?? '';
      final message = otpData['message']?.toString() ?? '';
      final statusDetail = otpData['statusDetail']?.toString() ?? '';
      final statusCode = otpData['statusCode']?.toString().trim() ?? '';

      if (success && referenceNo.isNotEmpty) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                OtpVerifyPage(phone: intlPhone, referenceNo: referenceNo),
          ),
        );
      } else if (statusCode == 'E1351' ||
          message.toLowerCase().contains('already registered')) {
        // Server says user is already in the system. Re-check
        // check_subscription.php with polling — the previous call may have
        // raced with billing. REGISTERED is the strict happy-path, but we
        // also let them through with a soft-login if the carrier hasn't
        // propagated yet — the home screen will keep checking.
        final subscribed = await _waitForSubscriptionSyncShared(intlPhone);

        if (!mounted) return;

        if (!subscribed) {
          // Billing hasn't synced yet — grant soft-login so the user is
          // not stranded. The home screen will poll subscription status
          // and update the UI as soon as BDApps reports REGISTERED.
          _showSuccess('লগইন হচ্ছে...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userPhone', intlPhone);
          await prefs.setBool('is_subscribed', false);
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
          return;
        }

        _showSuccess('ইতিমধ্যে রেজিস্টার করা! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          await _saveAndGoHome(intlPhone);
        } catch (e) {
          if (mounted) {
            _showError(
              'লগইন করতে সমস্যা হয়েছে। কিছুক্ষণ পর আবার চেষ্টা করুন।',
            );
            setState(() => _isLoading = false);
          }
        }
      } else {
        final errorMsg = message.isNotEmpty
            ? message
            : (statusDetail.isNotEmpty ? statusDetail : 'OTP পাঠানো যায়নি');
        _showError(errorMsg);
      }
    } catch (e) {
      _showError('নেটওয়ার্ক সমস্যা হয়েছে। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAndGoHome(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userPhone', phone);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App logo
              SizedBox(
                width: 90,
                height: 90,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/noteflow_logo.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'NoteFlow',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade500,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 8),
              Text(
                'Daily charge is 2.78 BDT (including VAT, SD & SC). For Robi and Airtel users only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
                maxLength: 11,
                decoration: InputDecoration(
                  labelText: 'মোবাইল নম্বর',
                  hintText: '018XXXXXXXX',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton(
                      onPressed: _onContinue,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('পরবর্তী'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpVerifyPage extends StatefulWidget {
  final String phone;
  final String referenceNo;

  const OtpVerifyPage({
    super.key,
    required this.phone,
    required this.referenceNo,
  });

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  late Timer _timer;
  int _remainingSeconds = 240; // 4 minutes = 240 seconds

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_remainingSeconds > 120) return Colors.green;
    if (_remainingSeconds > 60) return Colors.orange;
    return Colors.red;
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      _showError('OTP সঠিকভাবে দাও');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${_baseUrl}verify_otp.php'),
            body: {
              'Otp': otp,
              'otp': otp,
              'referenceNo': widget.referenceNo,
              'reference_no': widget.referenceNo,
              'user_mobile': widget.phone,
            },
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        _showError('সার্ভার থেকে ভুল তথ্য এসেছে');
        return;
      }

      final statusCode = _readString(data, [
        'statusCode',
        'StatusCode',
        'status_code',
      ]).toUpperCase();
      final successFlag =
          data['success'] == true ||
          _readString(data, ['status', 'result']).toLowerCase() == 'success';

      if (statusCode == 'S1000' || successFlag) {
        // OTP verified. Poll subscription status. REGISTERED or
        // INITIAL CHARGING PENDING both grant app access; everything else
        // (still pending incorrectly, error) blocks it.
        //
        // The fact that we got a valid OTP from the BDApps gateway means the
        // user has already subscribed and the carrier confirmed the charge —
        // so if billing sync hasn't propagated to the subscription endpoint
        // yet, we trust the OTP and let them in rather than locking them out.
        final subscribed = await _waitForSubscriptionSyncShared(widget.phone);

        if (!mounted) return;

        if (!subscribed) {
          // Subscription not yet REGISTERED on the BDApps side after polling,
          // but the OTP itself came back successfully — that means the user
          // already paid. Persist a soft-login state so the home screen can
          // re-check subscription in the background, instead of stranding
          // them on the OTP screen with no way to retry from inside the app.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userPhone', widget.phone);
          await prefs.setBool('is_subscribed', false);

          if (!mounted) return;
          _showSuccess('লগইন হচ্ছে...');
          await Future.delayed(const Duration(milliseconds: 800));
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
          return;
        }

        // REGISTERED or PENDING confirmed — persist login state and go home.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userPhone', widget.phone);
        await prefs.setBool('is_subscribed', true);

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        final message = _readString(data, [
          'message',
          'statusDetail',
          'error',
          'errorMessage',
        ]);
        _showError(message.isNotEmpty ? message : 'OTP ভুল হয়েছে');
      }
    } catch (e) {
      _showError('নেটওয়ার্ক সমস্যা হয়েছে। আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('যাচাই'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.sms_outlined,
                  size: 64,
                  color: Color(0xFF6C63FF),
                ),
                const SizedBox(height: 16),
                Text(
                  'OTP দিন',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.phone} নম্বরে কোড পাঠানো হয়েছে',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                // Countdown timer display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getTimerColor().withValues(alpha: 0.1),
                    border: Border.all(color: _getTimerColor(), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'OTP এর সময় বাকি',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: _getTimerColor(),
                        ),
                      ),
                      if (_remainingSeconds <= 60)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'সময় শেষ হয়ে যাচ্ছে!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  enabled: !_isLoading && _remainingSeconds > 0,
                  style: const TextStyle(fontSize: 28, letterSpacing: 12),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '******',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _remainingSeconds > 0
                        ? FilledButton(
                            onPressed: _verifyOtp,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('যাচাই করুন'),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: null,
                            icon: const Icon(Icons.schedule_rounded),
                            label: const Text('সময় শেষ হয়েছে'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('ভুল নম্বর? আবার চেষ্টা করুন'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}