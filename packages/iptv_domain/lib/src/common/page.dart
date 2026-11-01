/// Fenêtre demandée dans une liste paginée.
final class PageRequest {
  const PageRequest({this.offset = 0, this.limit = 50})
    : assert(offset >= 0),
      assert(limit > 0);

  final int offset;
  final int limit;

  /// Fenêtre suivante, de même taille.
  PageRequest get next => PageRequest(offset: offset + limit, limit: limit);
}

/// Portion d'une liste. L'interface ne garde en mémoire que ces fenêtres.
final class Page<T> {
  const Page({required this.items, required this.request});

  final List<T> items;
  final PageRequest request;

  /// Une page pleine indique qu'il reste peut-être des éléments.
  bool get hasMore => items.length == request.limit;
}
