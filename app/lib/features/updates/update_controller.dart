import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_domain/iptv_domain.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/daily_sync.dart';
import '../../app/di/infrastructure_providers.dart';
import '../../app/di/repository_providers.dart';
import '../../app/platform/update_installer.dart';
import '../../app/platform/web_page.dart';

/// Écart entre deux vérifications, application ouverte.
const Duration _checkInterval = Duration(hours: 24);

/// Version de l'application, transmise à la compilation par les scripts de
/// `tool`. `null` dans un build de développement : il ne cherche pas de mise
/// à jour.
final appVersionProvider = Provider<AppVersion?>(
  (ref) => AppVersion.tryParse(const String.fromEnvironment('AERO_VERSION')),
);

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => const PlatformUpdateInstaller(),
);

/// Dossier où les mises à jour se téléchargent.
final updateDirectoryProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async =>
          Directory(p.join((await getTemporaryDirectory()).path, 'updates')),
);

/// Où en est la mise à jour proposée.
enum UpdatePhase {
  /// Le bandeau propose la mise à jour.
  offered,

  /// Le fichier se télécharge.
  downloading,

  /// Android attend que l'utilisateur autorise l'installation.
  needsPermission,

  /// Le téléchargement ou l'installation a échoué.
  failed,
}

/// Mise à jour proposée par le bandeau.
final class UpdateState {
  const UpdateState({
    this.release,
    this.phase = UpdatePhase.offered,
    this.progress,
  });

  /// `null` sans mise à jour à proposer : pas de bandeau.
  final AppRelease? release;
  final UpdatePhase phase;

  /// Part téléchargée, de 0 à 1, si la taille est connue.
  final double? progress;
}

/// Cherche une nouvelle version sur GitHub, au lancement puis toutes les
/// 24 h, et l'installe à la demande.
class UpdateController extends Notifier<UpdateState> {
  DateTime? _checkedAt;

  @override
  UpdateState build() => const UpdateState();

  /// Vérifie si la dernière vérification date de plus de 24 h.
  Future<void> checkIfDue() async {
    final now = ref.read(clockProvider)();
    final last = _checkedAt;
    if (last != null && now.difference(last) < _checkInterval) return;
    await check();
  }

  /// Cherche une version plus récente que celle-ci. Une panne de réseau ne
  /// se voit pas : la vérification se refera.
  Future<void> check() async {
    final current = ref.read(appVersionProvider);
    if (current == null) return;
    _checkedAt = ref.read(clockProvider)();
    final settings = await ref.read(settingsRepositoryProvider).watch().first;
    final List<AppRelease> releases;
    try {
      releases = await ref.read(releaseRepositoryProvider).releases();
    } on Failure {
      return;
    }
    // Un téléchargement en cours garde sa release.
    if (state.phase == UpdatePhase.downloading) return;
    state = UpdateState(
      release: findUpdate(
        releases,
        current: current,
        preReleases: settings.betaUpdates,
        dismissedTag: settings.dismissedUpdate,
      ),
    );
  }

  /// Ferme le bandeau ; il ne revient que pour une version plus récente.
  Future<void> dismiss() async {
    final release = state.release;
    if (release == null) return;
    state = const UpdateState();
    final repository = ref.read(settingsRepositoryProvider);
    final settings = await repository.watch().first;
    await repository.save(settings.copyWith(dismissedUpdate: release.tag));
  }

  /// Télécharge la mise à jour et lance son installation.
  ///
  /// Sans fichier à installer ici (une release sans installateur Windows),
  /// la page de la release s'ouvre dans le navigateur.
  Future<void> install() async {
    final release = state.release;
    if (release == null || state.phase == UpdatePhase.downloading) return;
    final installer = ref.read(updateInstallerProvider);
    final asset = release.assets[installer.assetName];
    if (asset == null) {
      await openWebPage(release.pageUrl);
      return;
    }
    if (!await installer.canInstall()) {
      state = UpdateState(release: release, phase: UpdatePhase.needsPermission);
      await installer.openInstallSettings();
      return;
    }
    state = UpdateState(
      release: release,
      phase: UpdatePhase.downloading,
      progress: 0,
    );
    try {
      final file = await _download(asset, installer.assetName!, (progress) {
        state = UpdateState(
          release: release,
          phase: UpdatePhase.downloading,
          progress: progress,
        );
      });
      await installer.install(file);
      // Android affiche sa demande d'installation : le bandeau reste, au cas
      // où l'utilisateur la refuserait.
      state = UpdateState(release: release);
    } on Object {
      state = UpdateState(release: release, phase: UpdatePhase.failed);
    }
  }

  Future<File> _download(
    ReleaseAsset asset,
    String name,
    void Function(double progress) onProgress,
  ) async {
    final directory = await ref.read(updateDirectoryProvider)();
    await directory.create(recursive: true);
    final file = File(p.join(directory.path, name));
    final response = await ref
        .read(httpClientProvider)
        .send(http.Request('GET', Uri.parse(asset.url)));
    if (response.statusCode != HttpStatus.ok) {
      throw ServerFailure(
        'Téléchargement refusé.',
        status: response.statusCode,
      );
    }
    final total = response.contentLength ?? asset.size;
    final sink = file.openWrite();
    var received = 0;
    var shown = -1;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        final percent = total > 0 ? received * 100 ~/ total : 0;
        if (percent != shown) {
          shown = percent;
          onProgress(percent / 100);
        }
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      throw const NetworkFailure('Téléchargement interrompu.');
    }
    return file;
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
