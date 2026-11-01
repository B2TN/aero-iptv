import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dpad_shortcuts.dart';
import 'focus_frame.dart';
import 'focus_memory.dart';

/// Distance avant la fin de la liste à laquelle la page suivante est demandée.
const int _endThreshold = 8;
const Duration _scrollDuration = Duration(milliseconds: 150);

/// Durée d'appui sur OK qui ouvre le menu d'un élément.
const Duration _holdDuration = Duration(milliseconds: 600);

typedef DpadItemBuilder =
    Widget Function(BuildContext context, int index, bool focused);

/// Liste ou grille pilotée au D-pad, avec un unique `FocusNode`.
///
/// Les éléments n'ont pas de nœud de focus propre : la liste retient un index et
/// le déplace elle-même. Cette approche apporte trois garanties sur un appareil
/// limité :
///
/// - un élément recyclé hors de l'écran ne peut pas emporter le focus ;
/// - une pression de touche ne reconstruit que deux éléments ;
/// - à l'extrémité de la liste, la touche est ignorée : le focus passe alors à
///   l'élément voisin de l'écran et l'utilisateur n'est jamais bloqué.
class DpadCollection extends ConsumerStatefulWidget {
  /// Liste horizontale.
  const DpadCollection.horizontal({
    required this.itemCount,
    required this.itemExtent,
    required this.crossExtent,
    required this.itemBuilder,
    required this.onSelect,
    this.onLongSelect,
    this.spacing = 16,
    this.padding = EdgeInsets.zero,
    this.memoryKey,
    this.autofocus = false,
    this.focusNode,
    this.onIndexChanged,
    this.onEndReached,
    this.onFocusChange,
    this.focusScale = 1.05,
    super.key,
  }) : axis = Axis.horizontal,
       columns = 1,
       clipBehavior = Clip.none;

  /// Liste verticale.
  const DpadCollection.vertical({
    required this.itemCount,
    required this.itemExtent,
    required this.itemBuilder,
    required this.onSelect,
    this.onLongSelect,
    this.spacing = 8,
    this.padding = EdgeInsets.zero,
    this.memoryKey,
    this.autofocus = false,
    this.focusNode,
    this.onIndexChanged,
    this.onEndReached,
    this.onFocusChange,
    this.focusScale = 1.0,
    super.key,
  }) : axis = Axis.vertical,
       columns = 1,
       crossExtent = null,
       clipBehavior = Clip.hardEdge;

  /// Grille de [columns] colonnes, à défilement vertical.
  const DpadCollection.grid({
    required this.itemCount,
    required this.itemExtent,
    required this.columns,
    required this.itemBuilder,
    required this.onSelect,
    this.onLongSelect,
    this.spacing = 12,
    this.padding = EdgeInsets.zero,
    this.memoryKey,
    this.autofocus = false,
    this.focusNode,
    this.onIndexChanged,
    this.onEndReached,
    this.onFocusChange,
    this.focusScale = 1.05,
    super.key,
  }) : axis = Axis.vertical,
       crossExtent = null,
       clipBehavior = Clip.hardEdge;

  final int itemCount;
  final DpadItemBuilder itemBuilder;
  final ValueChanged<int> onSelect;

  /// Appui long sur OK, clic droit ou appui long à la souris.
  final ValueChanged<int>? onLongSelect;
  final Axis axis;
  final int columns;

  /// Taille d'un élément dans le sens du défilement.
  final double itemExtent;

  /// Hauteur d'une liste horizontale.
  final double? crossExtent;
  final double spacing;
  final EdgeInsets padding;

  /// Clé de `FocusMemory`. Sans clé, la liste repart du premier élément.
  final String? memoryKey;

  /// La liste prend le focus dès son apparition. Contrairement à
  /// `Focus.autofocus`, cela fonctionne si un autre élément l'a déjà, par
  /// exemple l'onglet qui vient d'ouvrir l'écran.
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<int>? onIndexChanged;

  /// Appelé à l'approche de la fin, pour charger la page suivante.
  final VoidCallback? onEndReached;
  final ValueChanged<bool>? onFocusChange;
  final double focusScale;
  final Clip clipBehavior;

  @override
  ConsumerState<DpadCollection> createState() => _DpadCollectionState();
}

class _DpadCollectionState extends ConsumerState<DpadCollection> {
  final ScrollController _scroll = ScrollController();

  /// Index de l'élément actif, ou -1 si la liste n'a pas le focus. Chaque
  /// élément n'écoute que ce signal, sans reconstruire la liste.
  final ValueNotifier<int> _active = ValueNotifier(-1);
  FocusNode? _ownNode;
  Timer? _holdTimer;
  int _index = 0;
  bool _hasFocus = false;

  FocusNode get _node =>
      widget.focusNode ??
      (_ownNode ??= FocusNode(debugLabel: 'DpadCollection'));

  bool get _isGrid => widget.columns > 1;

  double get _lineExtent => widget.itemExtent + widget.spacing;

  @override
  void initState() {
    super.initState();
    final key = widget.memoryKey;
    if (key != null) _index = ref.read(focusMemoryProvider).read(key);
    _index = _clamp(_index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToIndex(animated: false);
      if (widget.autofocus && (ModalRoute.isCurrentOf(context) ?? true)) {
        _node.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(DpadCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount) {
      final clamped = _clamp(_index);
      if (clamped != _index) {
        _index = clamped;
        if (_hasFocus) _active.value = _index;
      }
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _scroll.dispose();
    _active.dispose();
    _ownNode?.dispose();
    super.dispose();
  }

  int _clamp(int index) =>
      widget.itemCount == 0 ? 0 : index.clamp(0, widget.itemCount - 1);

  void _onFocusChange(bool focused) {
    _hasFocus = focused;
    _active.value = focused ? _index : -1;
    widget.onFocusChange?.call(focused);
  }

  void _moveTo(int index, {required bool animated}) {
    _index = index;
    _active.value = index;
    final key = widget.memoryKey;
    if (key != null) ref.read(focusMemoryProvider).write(key, index);
    widget.onIndexChanged?.call(index);
    _scrollToIndex(animated: animated);
    final onEndReached = widget.onEndReached;
    if (onEndReached != null && index >= widget.itemCount - _endThreshold) {
      onEndReached();
    }
  }

  /// Garde un élément visible devant l'élément actif, pour montrer la suite.
  void _scrollToIndex({required bool animated}) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final line = _index ~/ widget.columns;
    final target = ((line - 1) * _lineExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final viewport = position.viewportDimension;
    final top = line * _lineExtent;
    final isVisible =
        top >= position.pixels + (line == 0 ? 0 : _lineExtent) &&
        top + _lineExtent * 2 <= position.pixels + viewport;
    if (isVisible || target == position.pixels) return;
    if (animated) {
      _scroll.animateTo(
        target,
        duration: _scrollDuration,
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(target);
    }
  }

  /// OK ne déclenche la sélection qu'au relâchement : l'appui peut encore
  /// devenir un appui long.
  KeyEventResult _onHold(KeyEvent event, ValueChanged<int> onLongSelect) {
    if (event is KeyDownEvent) {
      _holdTimer?.cancel();
      _holdTimer = Timer(_holdDuration, () {
        _holdTimer = null;
        onLongSelect(_index);
      });
    } else if (event is KeyUpEvent) {
      final timer = _holdTimer;
      _holdTimer = null;
      if (timer != null && timer.isActive) {
        timer.cancel();
        widget.onSelect(_index);
      }
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    final onLongSelect = widget.onLongSelect;
    if (onLongSelect != null &&
        widget.itemCount > 0 &&
        isConfirmKey(event.logicalKey)) {
      return _onHold(event, onLongSelect);
    }
    if (event is KeyUpEvent || widget.itemCount == 0) {
      return KeyEventResult.ignored;
    }
    final next = _nextIndex(event.logicalKey);
    if (next == null || next < 0 || next >= widget.itemCount) {
      return KeyEventResult.ignored;
    }
    // Maintenir une touche enchaîne les éléments : l'animation serait en retard.
    _moveTo(next, animated: event is! KeyRepeatEvent);
    return KeyEventResult.handled;
  }

  int? _nextIndex(LogicalKeyboardKey key) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final forward = isRtl
        ? LogicalKeyboardKey.arrowLeft
        : LogicalKeyboardKey.arrowRight;
    final backward = isRtl
        ? LogicalKeyboardKey.arrowRight
        : LogicalKeyboardKey.arrowLeft;

    if (_isGrid) {
      final column = _index % widget.columns;
      if (key == forward) {
        return column == widget.columns - 1 ? null : _index + 1;
      }
      if (key == backward) return column == 0 ? null : _index - 1;
      if (key == LogicalKeyboardKey.arrowDown) {
        final next = _index + widget.columns;
        // La dernière ligne peut être incomplète.
        final lastLine = (widget.itemCount - 1) ~/ widget.columns;
        final canDrop = _index ~/ widget.columns < lastLine;
        return next < widget.itemCount
            ? next
            : canDrop
            ? widget.itemCount - 1
            : null;
      }
      if (key == LogicalKeyboardKey.arrowUp) return _index - widget.columns;
      return null;
    }
    if (widget.axis == Axis.horizontal) {
      if (key == forward) return _index + 1;
      if (key == backward) return _index - 1;
      return null;
    }
    if (key == LogicalKeyboardKey.arrowDown) return _index + 1;
    if (key == LogicalKeyboardKey.arrowUp) return _index - 1;
    return null;
  }

  void _select(int index) {
    if (index != _index) _moveTo(index, animated: false);
    _node.requestFocus();
    widget.onSelect(index);
  }

  Widget _buildItem(BuildContext context, int index) => _DpadItem(
    index: index,
    active: _active,
    builder: widget.itemBuilder,
    scale: widget.focusScale,
    onTap: () => _select(index),
    onLongPress: widget.onLongSelect == null
        ? null
        : () {
            if (index != _index) _moveTo(index, animated: false);
            _node.requestFocus();
            widget.onLongSelect!(index);
          },
    onHover: () {
      if (index != _index) _moveTo(index, animated: true);
      _node.requestFocus();
    },
  );

  @override
  Widget build(BuildContext context) {
    final Widget list = _isGrid
        ? GridView.builder(
            controller: _scroll,
            padding: widget.padding,
            clipBehavior: widget.clipBehavior,
            scrollCacheExtent: ScrollCacheExtent.pixels(_lineExtent * 2),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.columns,
              mainAxisExtent: widget.itemExtent,
              mainAxisSpacing: widget.spacing,
              crossAxisSpacing: widget.spacing,
            ),
            itemCount: widget.itemCount,
            itemBuilder: _buildItem,
          )
        : ListView.builder(
            controller: _scroll,
            scrollDirection: widget.axis,
            padding: widget.padding,
            clipBehavior: widget.clipBehavior,
            scrollCacheExtent: ScrollCacheExtent.pixels(_lineExtent * 3),
            itemExtent: _lineExtent,
            itemCount: widget.itemCount,
            itemBuilder: (context, index) => Align(
              alignment: AlignmentDirectional.topStart,
              child: SizedBox(
                width: widget.axis == Axis.horizontal
                    ? widget.itemExtent
                    : null,
                height: widget.axis == Axis.vertical ? widget.itemExtent : null,
                child: _buildItem(context, index),
              ),
            ),
          );

    return Actions(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.itemCount > 0) widget.onSelect(_index);
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _node,
        canRequestFocus: widget.itemCount > 0,
        onKeyEvent: _onKeyEvent,
        onFocusChange: _onFocusChange,
        child: widget.crossExtent == null
            ? list
            : SizedBox(height: widget.crossExtent, child: list),
      ),
    );
  }
}

/// Élément de liste : il ne se reconstruit que si son état de focus change.
class _DpadItem extends StatefulWidget {
  const _DpadItem({
    required this.index,
    required this.active,
    required this.builder,
    required this.scale,
    required this.onTap,
    required this.onLongPress,
    required this.onHover,
  });

  final int index;
  final ValueNotifier<int> active;
  final DpadItemBuilder builder;
  final double scale;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onHover;

  @override
  State<_DpadItem> createState() => _DpadItemState();
}

class _DpadItemState extends State<_DpadItem> {
  late bool _focused;

  @override
  void initState() {
    super.initState();
    _focused = widget.active.value == widget.index;
    widget.active.addListener(_update);
  }

  @override
  void didUpdateWidget(_DpadItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      oldWidget.active.removeListener(_update);
      widget.active.addListener(_update);
    }
    _focused = widget.active.value == widget.index;
  }

  @override
  void dispose() {
    widget.active.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final focused = widget.active.value == widget.index;
    if (focused != _focused) setState(() => _focused = focused);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onHover: (_) {
      if (!_focused) widget.onHover();
    },
    child: GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: FocusFrame(
        focused: _focused,
        scale: widget.scale,
        child: widget.builder(context, widget.index, _focused),
      ),
    ),
  );
}
