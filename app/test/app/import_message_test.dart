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

  test('un échec d enregistrement parle du stockage', () {
    expect(message(const StorageFailure('x')), contains('stockage'));
  });

  test('un compte refusé sans statut garde son message', () {
    expect(message(const AuthFailure('x')), l10n.importAuthFailed);
  });

  group('import en cours', () {
    String? running(ImportStage stage, {ContentKind? section}) => importMessage(
      l10n,
      ImportStatus(
        running: true,
        stage: stage,
        section: section,
        processed: 1200,
      ),
    );

    test('nomme la section reçue et le nombre d éléments', () {
      expect(
        running(ImportStage.catalog, section: ContentKind.live),
        allOf(contains('chaînes'), contains('1200')),
      );
      expect(
        running(ImportStage.catalog, section: ContentKind.movie),
        contains('films'),
      );
      expect(
        running(ImportStage.catalog, section: ContentKind.series),
        contains('séries'),
      );
    });

    test('une source d un seul tenant ne nomme aucune section', () {
      expect(running(ImportStage.catalog), l10n.importRunning(1200));
    });

    test('chaque phase a son message', () {
      final messages = {
        for (final stage in ImportStage.values) running(stage),
        importMessage(l10n, const ImportStatus(running: true)),
      };
      // La connexion, la réception, la préparation et le guide.
      expect(messages, hasLength(4));
      expect(messages, isNot(contains(null)));
    });
  });

  group('import incomplet', () {
    const status = ImportStatus(
      finished: true,
      failedSections: {
        ContentKind.live: ServerFailure('x', status: 503),
        ContentKind.series: NetworkFailure('x'),
      },
    );

    test('nomme les sections manquantes et la première cause', () {
      final text = importMessage(l10n, status);

      expect(text, contains('chaînes, séries'));
      expect(text, contains('503'));
      expect(text, isNot(contains('films')));
    });

    test('reste signalé une fois l import terminé', () {
      expect(status.needsAttention, isTrue);
      expect(const ImportStatus(finished: true).needsAttention, isFalse);
    });
  });
}
