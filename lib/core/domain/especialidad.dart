/// Especialidad médica.
///
/// Vive en `core/` y no en un feature porque la comparten dos: `perfil`
/// muestra las del médico y `especialidades` lista el catálogo. Si estuviera
/// dentro de uno, el otro tendría que importarlo — y eso rompe la regla de
/// que un feature no depende de otro.
class Especialidad {
  const Especialidad({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.urlIcono,
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final String? urlIcono;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Especialidad && other.id == id && other.nombre == nombre;

  @override
  int get hashCode => Object.hash(id, nombre);

  @override
  String toString() => nombre;
}
