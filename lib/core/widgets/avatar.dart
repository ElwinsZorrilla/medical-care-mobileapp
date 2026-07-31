import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Avatar circular con respaldo de iniciales.
///
/// El único lugar del sistema con radio completo — todo lo demás tiene
/// esquinas. La foto se cachea en disco: en datos móviles lentos, volver a
/// bajar la misma foto en cada scroll es la diferencia entre una lista que
/// fluye y una que se traba.
class Avatar extends StatelessWidget {
  const Avatar({
    required this.nombre,
    this.urlFoto,
    this.tamano = Space.xxl,
    super.key,
  });

  /// Se usa para las iniciales y para el `Semantics`.
  final String nombre;
  final String? urlFoto;
  final double tamano;

  String get _iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first +
            partes.elementAt(1).characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;

    final respaldo = Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.verde.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: colors.filete, width: Strokes.filete),
      ),
      child: Text(
        _iniciales,
        style: text.bodyStrong.copyWith(color: colors.verde),
      ),
    );

    return Semantics(
      label: 'Foto de $nombre',
      image: true,
      child: ClipOval(
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: urlFoto == null || urlFoto!.isEmpty
              ? respaldo
              : CachedNetworkImage(
                  imageUrl: urlFoto!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => respaldo,
                  errorWidget: (_, _, _) => respaldo,
                ),
        ),
      ),
    );
  }
}
