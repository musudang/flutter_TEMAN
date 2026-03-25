import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Web-specific Google sign-in button rendered by the plugin.
Widget buildGoogleWebButton({double height = 48}) {
  return SizedBox(height: height, child: gsi.renderButton());
}
