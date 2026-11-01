import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_kit_engine.dart';

/// Surface d'affichage de la vidéo et des sous-titres.
///
/// Les sous-titres sont dessinés par l'écran de lecture et non par libass : le
/// GPU du stick n'a pas à composer une couche de texte supplémentaire dans mpv,
/// et ils peuvent être traduits avant d'être affichés.
class VideoSurface extends StatefulWidget {
  const VideoSurface({required this.engine, super.key});

  final MediaKitEngine engine;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  // Le contrôleur vit avec le lecteur, qui le libère à sa fermeture.
  late final VideoController _controller = VideoController(
    widget.engine.player,
  );

  @override
  Widget build(BuildContext context) => Video(
    controller: _controller,
    controls: null,
    subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
  );
}
