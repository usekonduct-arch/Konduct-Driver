import '../theme/tokens.dart';

/// Which app this is. Drivers and bike riders get paid here; the
/// student app lives in its own repo (usekonduct-arch/Konduct-student).
abstract final class AppInfo {
  static const name = 'Konduct Driver';
  /// The account role this app serves; the backend sets it as a custom claim.
  static const role = 'driver';
  static const palette = Palette.driver;
  static const dark = true;

  /// Links into the app: konductdriver://payout (AndroidManifest.xml). Its own scheme, so a
  /// konduct:// link meant for the student app never asks which app to open.
  static const linkScheme = 'konductdriver';
  static const linkHosts = <String>{};

  /// Screens a link, shortcut or widget may open (the home screen's app: actions).
  static const linkScreens = {'payout', 'bank', 'account', 'reports', 'feedback', 'shift'};

  /// Long-press shortcuts on the app icon: action, English title, Android drawable.
  static const shortcuts = [
    ('reports', "Today's earnings", 'ic_shortcut_earnings'),
    ('payout', 'Pay out', 'ic_shortcut_payout'),
    ('shift', 'End my shift', 'ic_shortcut_shift'),
  ];
}

/// Backend settings. The region must match `REGION` in konduct-backend/functions/src/config.ts.
abstract final class AppConfig {
  static const functionsRegion = 'europe-west1';
  /// The Render server (konduct-backend/functions/src/server.ts), e.g. https://konduct-backend.onrender.com.
  /// Build with --dart-define=BACKEND_URL=...; empty means Cloud Functions in [functionsRegion].
  static const backendUrl = String.fromEnvironment('BACKEND_URL');
  static const campusId = 'uniosun';
  static const campusName = 'UNIOSUN';
  static const campusPlace = 'Osun State University';

  /// The website, where the Terms, Privacy Policy and Account Deletion Policy live.
  static const siteUrl = 'https://konduct.com.ng';

  /// The legal documents' version people agree to at sign-up. Must match LEGAL_VERSION in
  /// konduct-landing/src/content/legal.ts; the backend records it on the account.
  static const legalVersion = '2026-10-17';
}
