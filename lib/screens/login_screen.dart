// eta login + OTP verification page er code

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _baseUrl = "https://www.bdappsdigitalapps.com/NADB26105/"; // change with your application server url

// ignore: strict_top_level_inference
bool _isSupportedRobiCirkleNumber(String phone) {
  return RegExp(r'^01(?:6|8)\d{8}$').hasMatch(phone);
}

/// Calls `check_subscription.php` and returns true when the server reports an
/// active or activating subscription:
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
    return status == 'REGISTERED' || status == 'INITIAL CHARGING PENDING';
  } catch (e) {
    return false;
  }
}

/// Polls `check_subscription.php` until REGISTERED or INITIAL CHARGING PENDING
/// is reported, or `maxAttempts` is reached. Returns true on either state.
Future<bool> _waitForSubscriptionSyncShared(
  String phone, {
  int maxAttempts = 5,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    await Future.delayed(delay);
    if (await _isUserSubscribedOrPending(phone)) {
      return true;
    }
  }
  return false;
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
    if (!_isSupportedRobiCirkleNumber(phone)) {
      _showError('সঠিক Robi/Cirkle নম্বর দিন');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Check if already subscribed
      final isSubscribed = await _checkAlreadySubscribed(phone);

      if (isSubscribed) {
        _showSuccess('স্বাগতম! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          await _saveAndGoHome(phone);
        } catch (e) {
          if (mounted) {
            _showError('লগইন করতে সমস্যা হয়েছে। আবার চেষ্টা করুন।');
            setState(() => _isLoading = false);
          }
        }
        return;
      }

      // Send OTP request
      final otpResponse = await http
          .post(
            Uri.parse('${_baseUrl}send_otp.php'),
            body: {'user_mobile': phone},
          )
          .timeout(const Duration(seconds: 15));

      final otpData = jsonDecode(otpResponse.body);
      if (otpData is! Map<String, dynamic>) {
        _showError('সার্ভার থেকে ভুল তথ্য এসেছে');
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
                OtpVerifyPage(phone: phone, referenceNo: referenceNo),
          ),
        );
      } else if (statusCode == 'E1351' ||
          message.toLowerCase().contains('already registered')) {
        // Server says user is already in the system. Re-check
        // check_subscription.php with polling — the previous call may have
        // raced with billing. Only REGISTERED can grant home access.
        final subscribed = await _waitForSubscriptionSyncShared(phone);

        if (!mounted) return;

        if (!subscribed) {
          // Still not REGISTERED (e.g. INITIAL CHARGING PENDING).
          // Refuse to log in.
          _showError(
            'সাবস্ক্রিপশন এখনো সক্রিয় হয়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।',
          );
          return;
        }

        _showSuccess('ইতিমধ্যে রেজিস্টার করা! লগইন হচ্ছে...');
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          await _saveAndGoHome(phone);
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
              Image.asset('assets/noteflow_logo.png', width: 100, height: 100, ),
              const SizedBox(height: 20),
              Text(
                'NoteFlow',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade500
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // const Text('Robi/Cirkle নম্বর দিন', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Daily charge is 2.78 BDT (including VAT, SD & SC). For Robi and Cirkle users only.',
                // '2.78 BDT including (Vat+SC+SD) For Robi and Cirkle Users only.',
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
                decoration: InputDecoration(
                  labelText: 'মোবাইল নম্বর',
                  hintText: '018********',
                  prefixIcon: const Icon(Icons.phone_android_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
        final subscribed = await _waitForSubscriptionSyncShared(widget.phone);

        if (!mounted) return;

        if (!subscribed) {
          // Neither REGISTERED nor INITIAL CHARGING PENDING after polling.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('userPhone');

          if (!mounted) return;
          _showError(
            'সাবস্ক্রিপশন এখনো সক্রিয় হয়নি। কিছুক্ষণ পর আবার চেষ্টা করুন।',
          );
          return;
        }

        // REGISTERED or PENDING confirmed — persist login state and go home.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userPhone', widget.phone);

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
                // const SizedBox(height: 8),
                // Text(
                //   'RefNo: ${widget.referenceNo}',
                //   textAlign: TextAlign.center,
                //   style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                // ),
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

