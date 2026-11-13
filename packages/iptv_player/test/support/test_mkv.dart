import 'dart:convert';
import 'dart:typed_data';

const int _frameBytes = 960;
const int _framesPerCluster = 42;

/// Une trame MP3 silencieuse dure 24 ms : un groupe dure un peu plus d'une seconde.
const int _clusterMs = 1008;
const int _subtitleEveryClusters = 5;

List<int> _size(int value) => [
  0x01,
  for (var shift = 48; shift >= 0; shift -= 8) (value >> shift) & 0xFF,
];

List<int> _element(List<int> id, List<int> data) => [
  ...id,
  ..._size(data.length),
  ...data,
];

List<int> _uint(int value) {
  final bytes = <int>[];
  var rest = value;
  do {
    bytes.insert(0, rest & 0xFF);
    rest >>= 8;
  } while (rest > 0);
  return bytes;
}

List<int> _float(double value) {
  final data = ByteData(8)..setFloat64(0, value);
  return data.buffer.asUint8List();
}

List<int> _block(int track, int timecode, List<int> payload) => [
  0x80 | track,
  (timecode >> 8) & 0xFF,
  timecode & 0xFF,
  0x80,
  ...payload,
];

/// Chapitres Matroska : titre et début, en millisecondes.
List<int> _chapters(List<(String, int)> chapters) => _element(
  const [0x10, 0x43, 0xA7, 0x70],
  _element(
    const [0x45, 0xB9],
    [
      for (final (index, (title, startMs)) in chapters.indexed)
        ..._element(
          const [0xB6],
          [
            ..._element(const [0x73, 0xC4], _uint(index + 1)),
            ..._element(const [0x91], _uint(startMs * 1000000)),
            ..._element(
              const [0x80],
              [
                ..._element(const [0x85], utf8.encode(title)),
                ..._element(const [0x43, 0x7C], ascii.encode('eng')),
              ],
            ),
          ],
        ),
    ],
  ),
);

/// Écrit un vrai MKV : audio, sous-titres anglais intégrés et index en fin de
/// fichier, comme une VOD. Le texte de chaque réplique contient son numéro.
///
/// [chapters] ajoute des chapitres, chacun avec son titre et son début en
/// millisecondes.
Uint8List buildTestMkv({
  required int clusters,
  List<(String, int)> chapters = const [],
}) {
  final frame = Uint8List(_frameBytes)
    ..setRange(0, 4, const [0xFF, 0xFB, 0xE4, 0x00]);
  final header = _element(
    const [0x1A, 0x45, 0xDF, 0xA3],
    [
      ..._element(const [0x42, 0x82], ascii.encode('matroska')),
      ..._element(const [0x42, 0x87], _uint(4)),
      ..._element(const [0x42, 0x85], _uint(2)),
    ],
  );
  final info = _element(
    const [0x15, 0x49, 0xA9, 0x66],
    [
      ..._element(const [0x2A, 0xD7, 0xB1], _uint(1000000)),
      ..._element(const [
        0x44,
        0x89,
      ], _float((clusters * _clusterMs).toDouble())),
      ..._element(const [0x4D, 0x80], ascii.encode('aero')),
      ..._element(const [0x57, 0x41], ascii.encode('aero')),
    ],
  );
  final audio = _element(
    const [0xAE],
    [
      ..._element(const [0xD7], _uint(1)),
      ..._element(const [0x73, 0xC5], _uint(1)),
      ..._element(const [0x83], _uint(2)),
      ..._element(const [0x9C], _uint(0)),
      ..._element(const [0x86], ascii.encode('A_MPEG/L3')),
      ..._element(
        const [0xE1],
        [
          ..._element(const [0xB5], _float(48000)),
          ..._element(const [0x9F], _uint(2)),
        ],
      ),
    ],
  );
  final subtitles = _element(
    const [0xAE],
    [
      ..._element(const [0xD7], _uint(2)),
      ..._element(const [0x73, 0xC5], _uint(2)),
      ..._element(const [0x83], _uint(17)),
      ..._element(const [0x9C], _uint(0)),
      ..._element(const [0x86], ascii.encode('S_TEXT/UTF8')),
      ..._element(const [0x22, 0xB5, 0x9C], ascii.encode('eng')),
    ],
  );
  final tracks = _element(
    const [0x16, 0x54, 0xAE, 0x6B],
    [...audio, ...subtitles],
  );

  // L'index de tête a une taille fixe : les positions écrites n'en dépendent pas.
  List<int> seekHead(int cuesPosition) => _element(
    const [0x11, 0x4D, 0x9B, 0x74],
    _element(
      const [0x4D, 0xBB],
      [
        ..._element(const [0x53, 0xAB], const [0x1C, 0x53, 0xBB, 0x6B]),
        ..._element(
          const [0x53, 0xAC],
          [
            for (var shift = 56; shift >= 0; shift -= 8)
              (cuesPosition >> shift) & 0xFF,
          ],
        ),
      ],
    ),
  );

  final chapterList = chapters.isEmpty ? const <int>[] : _chapters(chapters);
  final prefix =
      seekHead(0).length + info.length + tracks.length + chapterList.length;
  final body = BytesBuilder(copy: false);
  final clusterPositions = <int>[];
  for (var cluster = 0; cluster < clusters; cluster++) {
    clusterPositions.add(prefix + body.length);
    final content = BytesBuilder(copy: false)
      ..add(_element(const [0xE7], _uint(cluster * _clusterMs)));
    for (var index = 0; index < _framesPerCluster; index++) {
      content.add(_element(const [0xA3], _block(1, index * 24, frame)));
    }
    if (cluster % _subtitleEveryClusters == 0) {
      content.add(
        _element(
          const [0xA0],
          [
            ..._element(const [
              0xA1,
            ], _block(2, 0, utf8.encode('Line $cluster'))),
            ..._element(const [0x9B], _uint(3000)),
          ],
        ),
      );
    }
    body.add(_element(const [0x1F, 0x43, 0xB6, 0x75], content.takeBytes()));
  }

  final cuesPosition = prefix + body.length;
  final cues = _element(
    const [0x1C, 0x53, 0xBB, 0x6B],
    [
      for (var cluster = 0; cluster < clusters; cluster += 10)
        ..._element(
          const [0xBB],
          [
            ..._element(const [0xB3], _uint(cluster * _clusterMs)),
            ..._element(
              const [0xB7],
              [
                ..._element(const [0xF7], _uint(1)),
                ..._element(const [0xF1], _uint(clusterPositions[cluster])),
              ],
            ),
          ],
        ),
    ],
  );

  final segment = BytesBuilder(copy: false)
    ..add(seekHead(cuesPosition))
    ..add(info)
    ..add(tracks)
    ..add(chapterList)
    ..add(body.takeBytes())
    ..add(cues);
  final content = segment.takeBytes();
  return (BytesBuilder(copy: false)
        ..add(header)
        ..add(const [0x18, 0x53, 0x80, 0x67])
        ..add(_size(content.length))
        ..add(content))
      .takeBytes();
}
