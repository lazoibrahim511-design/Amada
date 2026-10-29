import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

/// True if running on a native desktop platform (Windows, macOS, Linux).
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
     defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.linux);

/// True if running on Web or native desktop platform (Windows, macOS, Linux).
bool get isWebOrDesktopPlatform => kIsWeb || isDesktopPlatform;

/// Returns true if the layout should be desktop/web layout.
/// Always true on Web and Desktop OS (Windows, macOS, Linux).
/// On mobile (Android/iOS), true if the window/screen width is tablet/desktop size (>= 800px).
bool isWebOrDesktopLayout(BuildContext context) {
  if (kIsWeb || isDesktopPlatform) return true;
  return MediaQuery.of(context).size.width >= 800;
}
