import 'package:aero_iptv/focus/focus_frame.dart';
import 'package:flutter/widgets.dart';

/// Vrai si l'élément qui a le focus le montre par son cadre lumineux : celui
/// d'un bouton, d'un élément de liste ou d'une commande du lecteur.
bool focusIsVisible() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context is! Element) return false;
  var visible = false;
  void visit(Element element) {
    if (element.widget case FocusFrame(focused: true)) visible = true;
    if (!visible) element.visitChildren(visit);
  }

  context.visitChildren(visit);
  if (!visible) {
    context.visitAncestorElements((element) {
      if (element.widget case FocusFrame(focused: true)) visible = true;
      return !visible;
    });
  }
  return visible;
}

/// Décrit l'élément qui a le focus, pour un message d'échec lisible.
String describeFocus() {
  final node = FocusManager.instance.primaryFocus;
  return '${node?.debugLabel ?? node?.runtimeType} '
      '(${node?.context?.widget.runtimeType})';
}
