import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';


// Change `nadbId` in lib/config/app_config.dart to point at your
// application server. The trailing slash is required because every
// endpoint below concatenates the path directly.
// `final` (not `const`) because AppConfig.baseUrl is a getter, not
// a compile-time constant.
final String _baseUrl = AppConfig.baseUrl;

/// Profile Screen - User info + logout + unsubscribe.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUnsubscribing = false;

  Future<void> _unsubscribe() async {
    if (_isUnsubscribing) return;

    // Capture the phone from the provider *before* any async gap so we
    // don't reuse a stale BuildContext later.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final phone = authProvider.phoneNumber ?? '';

    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone not found!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsubscribing'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUnsubscribing = true);

    // Hold a reference to the loader dialog so we can reliably close it.
    bool loaderOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );

    Future<void> closeLoader() async {
      if (!loaderOpen) return;
      loaderOpen = false;
      if (!mounted) return;
      // Guard against pop when no dialog actually exists on the navigator.
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    try {
      final res = await http
          .post(
            Uri.parse('${_baseUrl}unsubscribe.php'),
            body: {'user_mobile': phone},
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;
      await closeLoader();
      if (!mounted) return;

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response shape');
      }
      final data = decoded;
      final statusCode = data['statusCode']?.toString() ?? '';
      final statusDetail = data['statusDetail']?.toString() ?? '';
      final successFlag = data['success'] == true;
      final subscriptionStatus =
          (data['subscriptionStatus']?.toString() ?? '').toUpperCase();

      final success = successFlag ||
          statusCode == 'S1000' ||
          subscriptionStatus == 'UNREGISTERED';

      if (success) {
        // Clear auth state before navigating so the cold-start guard in
        // main.dart doesn't read a stale `isLoggedIn` flag.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', false);
        await prefs.remove('userPhone');
        await prefs.remove('logged_in_phone');
        await prefs.remove('is_subscribed');

        // Also clear AuthProvider's in-memory state.
        if (!mounted) return;
        await Provider.of<AuthProvider>(context, listen: false).logout();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unsubscribing success!'),
            backgroundColor: Colors.green,
          ),
        );

        // Use the named route already registered in main.dart — this avoids
        // building a new LoginPage widget ad-hoc and bypasses history quirks
        // that triggered `_history.isNotEmpty` assertion failures.
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(statusDetail.isNotEmpty
                ? statusDetail
                : 'Unsubscribing failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } on TimeoutException {
      if (!mounted) return;
      await closeLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timeout error!'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await closeLoader();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUnsubscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final phone = authProvider.phoneNumber ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              phone,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: authProvider.isSubscribed
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  authProvider.isSubscribed
                      ? '✓ Active Subscriber'
                      : '⚠ No Active Subscription',
                  style: TextStyle(
                    color: authProvider.isSubscribed
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _sectionTitle('App Info'),
            _infoTile(Icons.app_settings_alt, 'App Name', AppConfig.appTitle),
            //_infoTile(Icons.fingerprint, 'App ID', AppConfig.bdappsAppId),
            //_infoTile(Icons.tag, 'NADB ID', AppConfig.nadbId),
            const SizedBox(height: 16),
            _sectionTitle('Subscription'),
            ListTile(
              leading: const Icon(Icons.subscriptions, color: Colors.blue),
              title: const Text('Check subscription'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _isUnsubscribing
                  ? null
                  : () async {
                      final hasSub =
                          await authProvider.checkSubscription(phone);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            hasSub
                                ? 'Active subscription found ✓'
                                : 'No active subscription',
                          ),
                        ),
                      );
                    },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: Text(
                'Unsubscribe',
                style: TextStyle(
                  color: _isUnsubscribing ? Colors.grey : Colors.red,
                ),
              ),
              subtitle: Text('Send SMS: ${AppConfig.fullUssdCode}'),
              onTap: _isUnsubscribing ? null : _unsubscribe,
            ),
            const SizedBox(height: 24),
            _sectionTitle('Account'),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.orange),
              title: const Text('Logout'),
              onTap: _isUnsubscribing
                  ? null
                  : () => _confirmLogout(context),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will need to login again with OTP.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
}