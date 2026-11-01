import 'package:aero_iptv/app/app_state.dart';
import 'package:aero_iptv/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_domain/iptv_domain.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('fr'));

  String? message(Failure failure) =>
      importMessage(l10n, ImportStatus(failure: failure));

  test('seule une absence de réponse se dit injoignable', () {
    expect(message(const NetworkFailure('x')), contains('injoignable'));
    expect(
      message(const AuthFailure('x', status: 513)),
      isNot(contains('injoignable')),
    );
    expect(
      message(const ServerFailure('x', status: 503)),
      isNot(contains('injoignable')),
    );
  });

  test('un refus par statut HTTP affiche son code', () {
    expect(message(const AuthFailure('x', status: 513)), contains('513'));
  });

  test('une erreur du serveur affiche son code', () {
    expect(message(const ServerFailure('x', status: 503)), contains('503'));
  });

  test('un compte refusé sans statut garde son message', () {
    expect(message(const AuthFailure('x')), l10n.importAuthFailed);
  });
}
