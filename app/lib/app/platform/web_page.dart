import 'dart:io';

/// Ouvre [url] dans le navigateur du PC.
///
/// Retourne `false` s'il n'a pas pu s'ouvrir, comme sur une TV, qui n'en a pas.
Future<bool> openWebPage(String url) async {
  if (!Platform.isWindows) return false;
  try {
    await Process.start('rundll32', [
      'url.dll,FileProtocolHandler',
      url,
    ], mode: ProcessStartMode.detached);
    return true;
  } on ProcessException {
    return false;
  }
}
