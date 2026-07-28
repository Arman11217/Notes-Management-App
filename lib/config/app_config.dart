/// App Configuration - BDApps API er sob constant ekhane rakha.
///
/// IMPORTANT: Tomar NADB ID, App name, App ID, API key, SMS keyword, USSD keyword
/// bosale kaj korbe. Niche tomar values bosabe - ekhon o default value ache.
class AppConfig {
  // =====================================================
  // Tomar NADB ID (BDApps portal theke paoa)
  // Example: "NADB26015"
  // =====================================================
  static const String nadbId = 'NADB26105';

  // =====================================================
  // Tomar App Name (lowercase, no space)
  // Example: "noteflow" ba "mynotes"
  // =====================================================
  static const String appName = 'noteflow';

  // =====================================================
  // Tomar BDApps App ID (email e pawa)
  // Example: "APP_139125"
  // =====================================================
  static const String bdappsAppId = 'APP_139243';

  // =====================================================
  // Tomar BDApps API Key/Password (email e pawa approval er por)
  // Example: "341f6d53bfe0653xxx4eb912c77048b0"
  // =====================================================
  static const String bdappsApiKey = '461cc70f078cf1eb67f9ca5136dc63a5';

  // =====================================================
  // Tomar SMS keyword (BDApps portal e dewa)
  // Example: "DOWN"
  // =====================================================
  static const String smsKeyword = '34533';

  // =====================================================
  // Tomar USSD keyword (BDApps portal e dewa)
  // =====================================================
  static const String ussdKeyword = '45334';

  // =====================================================
  // Server URLs - Auto generated from nadbId
  // =====================================================
  static String get baseUrl => 'https://www.bdappsdigitalapps.com/$nadbId/';
  static String get appDownloadUrl =>
      'https://www.bdappsdigitalapps.com/$nadbId/$appName';

  // API endpoints
  static String get sendOtpUrl => '${baseUrl}send_otp.php';
  static String get verifyOtpUrl => '${baseUrl}verify_otp.php';
  static String get unsubscribeUrl => '${baseUrl}unsubscribe.php';
  static String get checkSubscriptionUrl => '${baseUrl}check_subscription.php';
  static String get smsUrl => '${baseUrl}sms.php';
  static String get ussdUrl => '${baseUrl}ussd.php';

  // App title
  static const String appTitle = 'NoteFlow';

  /// Subscription er jonne dial korar USSD code.
  /// Example: "*123*4#"
  static String get fullUssdCode => ussdKeyword;
}

