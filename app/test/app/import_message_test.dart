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

  group('échec d enregistrement', () {
    test('ne demande de libérer de la place que si elle manque', () {
      // 13 : stockage plein. 6410 : dossier temporaire introuvable.
      expect(message(const StorageFailure('x', code: 13)), contains('place'));
      expect(
        message(const StorageFailure('x', code: 6410)),
        isNot(contains('place')),
      );
    });

    test('affiche le code de la base', () {
      expect(message(const StorageFailure('x', code: 6410)), contains('6410'));
    });

    test('nomme une erreur inattendue', () {
      expect(
        message(const UnexpectedFailure('x', kind: 'StateError')),
        contains('StateError'),
      );
      expect(message(const StorageFailure('x')), contains('StorageFailure'));
    });
  });

  test('une connexion chiffrée refusée ne se dit pas injoignable', () {
    final text = message(const SecureConnectionFailure('x'));

    expect(text, contains('https'));
    expect(text, isNot(contains('injoignable')));
  });

  test('un coffre en panne se nomme, sans accuser le stockage', () {
    final text = message(const VaultFailure('x', cause: 'ProviderException'));

    expect(text, contains('ProviderException'));
    expect(text, contains('coffre'));
    expect(text, isNot(contains('stockage')));
  });

  test('un échec dit à quelle étape il est arrivé', () {
    const status = ImportStatus(
      failure: UnexpectedFailure('x', kind: 'StateError'),
      stage: ImportStage.catalog,
      section: ContentKind.series,
      processed: 1200,
    );

    expect(
      importFailureStep(l10n, status),
      allOf(contains('séries'), contains('1200')),
    );
    expect(
      importFailureStep(l10n, const ImportStatus(failure: NetworkFailure('x'))),
      isNull,
    );
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
