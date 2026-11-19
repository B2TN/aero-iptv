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
    final groups = await _groups(sourceId, countryCode, grouped: grouped);
    // « Toutes les chaînes » d'abord, dès qu'il y a de quoi choisir.
    if (groups.length < 2) return groups;
    return [
      ChannelGroup(
        key: ChannelGroup.allKey,
        displayName: '',
        channelCount: groups.fold(0, (sum, group) => sum + group.channelCount),
      ),
      ...groups,
    ];
  }

  Future<List<ChannelGroup>> _groups(
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
  Future<List<Channel>> channelsByKeys(
    int sourceId,
    List<({String? countryCode, String groupingKey})> keys,
  ) async => [
    for (final key in keys)
      if (await _db
              .channelByKey(
                sourceId: sourceId,
                country: key.countryCode,
                channelKey: key.groupingKey,
              )
              .getSingleOrNull()
          case final row?)
        Channel(
          id: row.channelId!,
          name: row.displayName ?? '',
          groupingKey: row.channelKey,
          countryCode: key.countryCode,
          logoUrl: row.logoUrl,
          epgKey: row.epgKey,
        ),
  ];

  @override
  Future<Page<Channel>> channels(
    int sourceId,
    String? countryCode,
    ChannelGroup group,
    PageRequest page, {
    required bool grouped,
  }) async {
    if (group.isAll) {
      return Page(
        items: await _channelsOfCountry(
          sourceId,
          countryCode,
          page,
          grouped: grouped,
        ),
        request: page,
      );
    }
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
            // Un groupe régional mêle plusieurs pays : chacun ses chaînes.
            country: countryCode,
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

  /// Toutes les chaînes du pays, fusionnées ou telles que la playlist les
  /// nomme.
  Future<List<Channel>> _channelsOfCountry(
    int sourceId,
    String? countryCode,
    PageRequest page, {
    required bool grouped,
  }) async {
    if (grouped) {
      final rows = await _db
          .channelsOfCountryMerged(
            sourceId: sourceId,
            country: countryCode,
            limit: page.limit,
            offset: page.offset,
          )
          .get();
      return [
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
    }
    final rows = await _db
        .channelsOfCountryRaw(
          sourceId: sourceId,
          country: countryCode,
          limit: page.limit,
          offset: page.offset,
        )
        .get();
    return [
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
