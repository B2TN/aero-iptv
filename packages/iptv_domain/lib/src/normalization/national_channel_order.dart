import 'text_folding.dart';

/// Chaînes principales de quelques pays, dans l'ordre de leur numérotation
/// nationale : la TNT en France (plan du 6 juin 2025), la LCN en Italie,
/// Freeview au Royaume-Uni... Chaque chaîne a ses noms possibles, réduits à
/// leurs lettres et chiffres en minuscules. Un nom suivi de `*` couvre aussi
/// ses déclinaisons régionales (`France 3 Alpes`).
const Map<String, List<List<String>>> _lineups = {
  'FR': [
    ['tf1'],
    ['france2'],
    ['france3*'],
    ['france4'],
    ['france5'],
    ['m6'],
    ['arte', 'artefrance', 'artefr'],
    ['lcp', 'lcppublicsenat', 'publicsenat', 'lcpan', 'lcpassembleenationale'],
    ['w9'],
    ['tmc'],
    ['tfx'],
    ['gulli'],
    ['bfmtv'],
    ['cnews'],
    ['lci'],
    ['franceinfo', 'franceinfotv'],
    ['cstar'],
    ['t18', 'cmitv'],
    ['novo19'],
    ['tf1seriesfilms', 'tf1series'],
    ['lequipe', 'lachainelequipe', 'lequipetv'],
    ['6ter'],
    ['rmcstory'],
    ['rmcdecouverte'],
    ['cherie25'],
    // Chaînes payantes sorties de la TNT, attendues juste après elle.
    ['canalplus'],
    ['canalpluscinema', 'canalpluscinemas'],
    ['canalplussport'],
    ['parispremiere'],
    ['planeteplus'],
  ],
  'BE': [
    ['laune', 'rtbflaune'],
    ['tipik', 'ladeux', 'rtbftipik'],
    ['latrois', 'rtbflatrois'],
    ['rtltvi'],
    ['clubrtl'],
    ['plugrtl'],
    ['ln24'],
    ['ab3'],
    ['een', 'vrt1'],
    ['canvas', 'vrtcanvas'],
    ['vtm'],
    ['play4'],
  ],
  'CH': [
    ['rtsun', 'rts1'],
    ['rtsdeux', 'rts2'],
    ['srf1'],
    ['srfzwei', 'srf2'],
    ['srfinfo'],
    ['rsila1'],
    ['rsila2'],
  ],
  'GB': [
    ['bbcone', 'bbc1'],
    ['bbctwo', 'bbc2'],
    ['itv1', 'itv'],
    ['channel4'],
    ['channel5'],
    ['itv2'],
    ['bbcthree', 'bbc3'],
    ['bbcfour', 'bbc4'],
    ['itv3'],
    ['e4'],
    ['film4'],
    ['more4'],
    ['dave'],
  ],
  'DE': [
    ['daserste', 'ard'],
    ['zdf'],
    ['rtl'],
    ['sat1'],
    ['prosieben', 'pro7'],
    ['vox'],
    ['kabeleins', 'kabel1'],
    ['rtlzwei', 'rtl2'],
    ['3sat'],
    ['zdfneo'],
    ['zdfinfo'],
    ['phoenix'],
    ['kika'],
    ['ntv'],
    ['welt'],
    ['superrtl'],
    ['nitro', 'rtlnitro'],
    ['sixx'],
    ['tele5'],
    ['dmax'],
  ],
  'ES': [
    ['la1', 'tve1', 'tve'],
    ['la2'],
    ['antena3'],
    ['cuatro'],
    ['telecinco'],
    ['lasexta'],
    ['24h', 'canal24horas'],
    ['clan'],
    ['teledeporte'],
    ['neox'],
    ['nova'],
    ['mega'],
    ['atreseries'],
    ['fdf'],
    ['energy'],
    ['divinity'],
    ['boing'],
    ['bemad'],
    ['dmax'],
    ['ten'],
  ],
  'IT': [
    ['rai1'],
    ['rai2'],
    ['rai3'],
    ['rete4'],
    ['canale5'],
    ['italia1'],
    ['la7'],
    ['tv8'],
    ['nove'],
    ['20mediaset', '20'],
    ['rai4'],
    ['iris'],
    ['rai5'],
    ['raimovie'],
    ['raipremium'],
    ['cielo'],
    ['twentyseven', '27twentyseven'],
    ['tv2000'],
    ['la7d', 'la7cinema'],
    ['la5'],
    ['realtime'],
  ],
  'PT': [
    ['rtp1'],
    ['rtp2'],
    ['sic'],
    ['tvi'],
    ['rtp3'],
    ['rtpmemoria'],
  ],
  'NL': [
    ['npo1'],
    ['npo2'],
    ['npo3'],
    ['rtl4'],
    ['rtl5'],
    ['sbs6'],
    ['rtl7'],
    ['veronica'],
    ['net5'],
    ['rtl8'],
    ['sbs9'],
  ],
};

/// Rangs des noms exacts, puis des préfixes régionaux, par pays.
final Map<String, ({Map<String, int> exact, Map<String, int> prefix})> _ranks =
    {
      for (final MapEntry(key: country, value: lineup) in _lineups.entries)
        country: (
          exact: {
            for (final (index, names) in lineup.indexed)
              for (final name in names) name.replaceAll('*', ''): index + 1,
          },
          prefix: {
            for (final (index, names) in lineup.indexed)
              for (final name in names)
                if (name.endsWith('*'))
                  name.substring(0, name.length - 1): index + 1,
          },
        ),
    };

final RegExp _notAlphanumeric = RegExp('[^a-z0-9]');

/// Nom réduit à ses lettres et chiffres : « Canal+ » devient `canalplus`.
String _compact(String name) => lowerWithoutDiacritics(
  name.replaceAll('+', 'plus'),
).replaceAll(_notAlphanumeric, '');

/// Place d'une chaîne dans la numérotation nationale de [countryCode], à
/// partir de 1 ; `null` si elle n'y figure pas, ou si le pays n'en a pas ici.
int? nationalChannelRank(String? countryCode, String channelName) {
  final ranks = _ranks[countryCode];
  if (ranks == null) return null;
  final name = _compact(channelName);
  final exact = ranks.exact[name];
  if (exact != null) return exact;
  for (final MapEntry(key: prefix, value: rank) in ranks.prefix.entries) {
    // `france3alpes`, mais pas `france24` sous `france2`.
    if (name.length > prefix.length &&
        name.startsWith(prefix) &&
        !_isDigit(name.codeUnitAt(prefix.length))) {
      return rank;
    }
  }
  return null;
}

bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
