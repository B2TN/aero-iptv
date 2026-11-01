import 'package:iptv_domain/iptv_domain.dart';

/// Colonnes de base de données équivalentes à un [StreamLocator].
final class LocatorColumns {
  const LocatorColumns({
    this.streamUrl,
    this.xtreamStreamId,
    this.containerExt,
    this.userAgent,
    this.referrer,
  });

  factory LocatorColumns.from(StreamLocator locator) => switch (locator) {
    DirectStream() => LocatorColumns(
      streamUrl: locator.url,
      userAgent: locator.userAgent,
      referrer: locator.referrer,
    ),
    XtreamStream() => LocatorColumns(
      xtreamStreamId: locator.streamId,
      containerExt: locator.extension,
    ),
  };

  final String? streamUrl;
  final int? xtreamStreamId;
  final String? containerExt;
  final String? userAgent;
  final String? referrer;

  /// Reconstruit le localisateur. [namespace] dépend de la table lue.
  StreamLocator toLocator(XtreamNamespace namespace) {
    final url = streamUrl;
    if (url != null) {
      return DirectStream(url, userAgent: userAgent, referrer: referrer);
    }
    return XtreamStream(
      namespace: namespace,
      streamId: xtreamStreamId!,
      extension: containerExt!,
    );
  }
}
