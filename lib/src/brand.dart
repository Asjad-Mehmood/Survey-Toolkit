// The program's name, version and colours, in one place. The release workflow stamps the version
// with --dart-define=APP_VERSION=x.y.z; a local build shows 0.0.0.
import 'package:flutter/material.dart';

const appName = 'Survey Toolkit';
const appTagline = 'Every survey tool from exceltokml.com, always up to date';
const appPublisher = 'Excel to KML';
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');
const websiteUrl = 'https://www.exceltokml.com';

/// The website the program talks to (a test build can point at a copy with --dart-define=API_BASE=)
const apiBase = String.fromEnvironment('API_BASE', defaultValue: websiteUrl);

/// The Toolkit's own releases: v0.x pre-releases during the beta, ordinary releases from v1.1.0
const releasesRepo = 'Asjad-Mehmood/Survey-Toolkit';

/// The same navy and survey gold as Excel to KML, Traverse & Level and Slope Calculator.
abstract final class BrandColors {
  static const navy = Color(0xFF0A1A36);
  static const navyLight = Color(0xFF17386B);
  static const gold = Color(0xFFE9B949);
  static const goldLight = Color(0xFFF7D774);
}
