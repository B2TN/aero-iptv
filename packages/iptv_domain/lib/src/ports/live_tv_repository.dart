import '../common/page.dart';
import '../entities/channel.dart';
import '../entities/channel_group.dart';
import '../entities/channel_stream.dart';
import '../entities/country.dart';

/// Accès aux chaînes en direct.
///
/// [grouped] applique le réglage de regroupement : il modifie la requête, sans
/// retraiter la playlist.
abstract interface class LiveTvRepository {
  /// Pays présents dans la playlist, du plus fourni au moins fourni.
  Future<List<Country>> countries(int sourceId);

  Future<List<ChannelGroup>> groups(
    int sourceId,
    String? countryCode, {
    required bool grouped,
  });

  Future<Page<Channel>> channels(
    int sourceId,
    String? countryCode,
    ChannelGroup group,
    PageRequest page, {
    required bool grouped,
  });

  /// Flux de [channel], du meilleur au moins bon.
  Future<List<ChannelStream>> streamsOf(
    int sourceId,
    Channel channel, {
    required bool grouped,
  });
}
