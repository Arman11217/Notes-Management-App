import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'notes_list_screen.dart';

/// Splash Screen - App khulle first e dekhay.
/// Check kore user already logged in kina.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
    _navigateAfterDelay();
  }

  /// 2.5 sec por navigate kori - auth state dekhe.
  /// AuthProvider.loadSavedSession() ke o await korar try kori jate
  /// fresh-install e stored session miss na hoy.
  Future<void> _navigateAfterDelay() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait for any in-flight session load to complete, then ensure at
    // least 2.5s of splash branding is shown for a smooth UX.
    await Future.wait<dynamic>([
      authProvider.sessionReady,
      Future.delayed(const Duration(milliseconds: 2500)),
    ]);

    if (!mounted) return;

    if (authProvider.isLoggedIn) {
      // Re-check subscription on resume so the user doesn't see stale
      // "Active" badge if they unsubscribed while the app was closed.
      try {
        final phone = authProvider.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          await authProvider.checkSubscription(phone);
        }
      } catch (_) {
        // Network might be down — fall back to last-known state.
      }
      if (!mounted) return;
      _goTo(const NotesListScreen());
    } else {
      _goTo(const LoginPage());
    }
  }

  void _goTo(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/noteflow_logo.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppConfig.appTitle,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'আপনার ব্যক্তিগত নোট',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 48),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
