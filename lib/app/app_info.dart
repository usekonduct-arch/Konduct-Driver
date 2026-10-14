import '../theme/tokens.dart';

/// Which app this is. Drivers and bike riders get paid here; the
/// student app lives in its own repo (usekonduct-arch/Konduct-student).
abstract final class AppInfo {
  static const name = 'Konduct Driver';
  /// The account role this app serves; the backend sets it as a custom claim.
  static const role = 'driver';
  static const palette = Palette.driver;
  static const dark = true;
}

/// Backend settings. The region must match `REGION` in konduct-backend/functions/src/config.ts.
abstract final class AppConfig {
  static const functionsRegion = 'europe-west1';
  static const campusId = 'uniosun';
  static const campusName = 'UNIOSUN';
  static const campusPlace = 'Osun State University';
}
