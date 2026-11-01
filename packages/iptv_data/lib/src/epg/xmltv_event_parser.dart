import 'package:xml/xml_events.dart';

/// Horodatage XMLTV : `20261031203000 +0100`.
final RegExp _timestamp = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*(?:([+-])(\d{2}):?(\d{2}))?',
);

/// Convertit un horodatage XMLTV en instant UTC.
///
/// Sans décalage indiqué, l'heure est considérée comme étant en UTC.
DateTime? parseXmltvTimestamp(String? value) {
  final match = value == null ? null : _timestamp.firstMatch(value.trim());
  if (match == null) return null;
  final utc = DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6] ?? '0'),
  );
  final sign = match[7];
  if (sign == null) return utc;
  final offset = Duration(
    hours: int.parse(match[8]!),
    minutes: int.parse(match[9]!),
  );
  return sign == '+' ? utc.subtract(offset) : utc.add(offset);
}

/// Élément lu dans un fichier XMLTV.
sealed class XmltvItem {
  const XmltvItem();
}

/// Déclaration `<channel>`.
final class XmltvChannel extends XmltvItem {
  const XmltvChannel({required this.id, required this.displayNames});

  final String id;
  final List<String> displayNames;
}

/// Émission `<programme>`.
final class XmltvProgramme extends XmltvItem {
  const XmltvProgramme({
    required this.channelId,
    required this.title,
    required this.start,
    required this.stop,
    this.description,
  });

  final String channelId;
  final String title;
  final DateTime start;
  final DateTime stop;
  final String? description;
}

/// Lit un fichier XMLTV par événements, sans construire son arbre XML.
///
/// Une Regex ne peut pas lire du XML de façon fiable : les entités, les sections
/// CDATA et les attributs dans un ordre quelconque la mettraient en défaut. Les
/// Regex ne servent ici qu'aux horodatages. La mémoire utilisée reste celle
/// d'une seule émission, même pour un guide de plusieurs centaines de Mo.
Stream<XmltvItem> parseXmltv(Stream<String> chunks) async* {
  final text = StringBuffer();
  String? capturing;

  String? channelId;
  var displayNames = <String>[];

  String? programmeChannel;
  DateTime? start;
  DateTime? stop;
  String? title;
  String? description;

  await for (final events in chunks.toXmlEvents()) {
    for (final event in events) {
      switch (event) {
        case final XmlStartElementEvent element:
          switch (element.name) {
            case 'channel':
              channelId = _attribute(element, 'id');
              displayNames = [];
            case 'programme':
              programmeChannel = _attribute(element, 'channel');
              start = parseXmltvTimestamp(_attribute(element, 'start'));
              stop = parseXmltvTimestamp(_attribute(element, 'stop'));
              title = null;
              description = null;
            case 'display-name' || 'title' || 'desc'
                when !element.isSelfClosing:
              capturing = element.name;
              text.clear();
          }
        case final XmlTextEvent node:
          if (capturing != null) text.write(node.value);
        case final XmlCDATAEvent node:
          if (capturing != null) text.write(node.value);
        case final XmlEndElementEvent element:
          if (element.name == capturing) {
            final value = text.toString().trim();
            capturing = null;
            switch (element.name) {
              case 'display-name':
                if (value.isNotEmpty) displayNames.add(value);
              // Un guide multilingue répète ces balises : la première l'emporte.
              case 'title':
                title ??= value;
              case 'desc':
                description ??= value;
            }
          } else if (element.name == 'channel' && channelId != null) {
            yield XmltvChannel(id: channelId, displayNames: displayNames);
            channelId = null;
          } else if (element.name == 'programme') {
            final channel = programmeChannel;
            final startAt = start;
            final stopAt = stop;
            final name = title;
            if (channel != null &&
                startAt != null &&
                stopAt != null &&
                name != null &&
                name.isNotEmpty) {
              yield XmltvProgramme(
                channelId: channel,
                title: name,
                start: startAt,
                stop: stopAt,
                description: description,
              );
            }
          }
        default:
          break;
      }
    }
  }
}

String? _attribute(XmlStartElementEvent element, String name) {
  for (final attribute in element.attributes) {
    if (attribute.name == name) return attribute.value;
  }
  return null;
}
