import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public URLs of the legal pages hosted on the Teztrader website.
class LegalLinks {
  LegalLinks._();

  static const String termsOfUse = 'https://teztrader.com/terms-of-use';
  static const String privacyPolicy = 'https://teztrader.com/privacy-policy';

  /// Opens [url] in the external browser; shows a snackbar if it can't open.
  static Future<void> open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }
}
