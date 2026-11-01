import 'package:iptv_domain/iptv_domain.dart';

import '../database/app_database.dart';
import '../database/locator_columns.dart';

/// Lecture des chaînes en direct.
final class LiveTvRepositoryImpl implements LiveTvRepository {
  const LiveTvRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<Country>> countries(int sourceId) async {
    final rows = await _db.countriesOfSource(sourceId: sourceId).get();
    return [
      for (final row in rows)
        Country(code: row.countryCode, channelCount: row.channelCount),
    ];
  }

  @override
  Future<List<ChannelGroup>> groups(
    int sourceId,
    String? countryCode, {
    required bool grouped,
  }) async {
    if (grouped) {
      final rows = await _db
          .groupsMerged(sourceId: sourceId, country: countryCode)
          .get();
      return [
        for (final row in rows)
          ChannelGroup(
            key: row.groupKey,
            displayName: row.displayName ?? '',
            channelCount: row.channelCount,
          ),
      ];
    }
    final rows = await _db
        .groupsRaw(sourceId: sourceId, country: countryCode)
        .get();
    return [
      for (final row in rows)
        ChannelGroup(
          key: row.groupKey,
          displayName: row.rawName,
          channelCount: row.channelCount,
          rawGroupId: row.groupId,
        ),
    ];
  }

  @override
  Future<Page<Channel>> channels(
    int sourceId,
    String? countryCode,
    ChannelGroup group,
    PageRequest page, {
    required bool grouped,
  }) async {
    final rawGroupId = group.rawGroupId;
    final List<Channel> items;
    if (grouped || rawGroupId == null) {
      final rows = await _db
          .channelsMerged(
            sourceId: sourceId,
            country: countryCode,
            groupKey: group.key,
            limit: page.limit,
            offset: page.offset,
          )
          .get();
      items = [
        for (final row in rows)
          Channel(
            id: row.channelId!,
            name: row.displayName ?? '',
            groupingKey: row.channelKey,
            countryCode: countryCode,
            logoUrl: row.logoUrl,
            epgKey: row.epgKey,
          ),
      ];
    } else {
      final rows = await _db
          .channelsRaw(
            groupId: rawGroupId,
            limit: page.limit,
            offset: page.offset,
          )
          .get();
      // La vue brute affiche le nom exact de la playlist, sans fusion.
      items = [
        for (final row in rows)
          Channel(
            id: row.id,
            name: row.rawName,
            groupingKey: row.groupingKey,
            countryCode: row.countryCode,
            logoUrl: row.logoUrl,
            epgKey: row.epgKey,
          ),
      ];
    }
    return Page(items: items, request: page);
  }

  @override
  Future<List<ChannelStream>> streamsOf(
    int sourceId,
    Channel channel, {
    required bool grouped,
  }) async {
    if (!grouped) {
      final row = await _db.liveChannelById(id: channel.id).getSingleOrNull();
      return row == null ? const [] : [_toStream(row)];
    }
    final rows = await _db
        .streamsOfChannel(
          sourceId: sourceId,
          country: channel.countryCode,
          channelKey: channel.groupingKey,
        )
        .get();
    return rows.map(_toStream).toList(growable: false);
  }

  ChannelStream _toStream(LiveChannelRow row) => ChannelStream(
    id: row.id,
    quality: StreamQuality.values[row.quality],
    label: row.variantLabel,
    locator: LocatorColumns(
      streamUrl: row.streamUrl,
      xtreamStreamId: row.xtreamStreamId,
      containerExt: row.containerExt,
      userAgent: row.userAgent,
      referrer: row.referrer,
    ).toLocator(XtreamNamespace.live),
  );
}
