/// Quita de un cuerpo o unas cabeceras todo lo que no puede aparecer en un
/// log — RNF-06.
///
/// Vive separado del interceptor a propósito: **es un control de seguridad y
/// tiene que ser verificable**. Dentro del interceptor solo se podía probar
/// a través de `developer.log`, que no es interceptable de forma portable, y
/// una prueba que reimplementa la redacción para compararla no protege nada:
/// si alguien rompe el original, la copia sigue verde.
///
/// La lista es amplia a propósito. Un log menos útil es barato; un
/// diagnóstico en logcat es una fuga de historia clínica que cualquier app
/// con permiso de lectura de logs puede leer.
abstract final class Redactor {
  static const marca = '«redactado»';

  /// Cabeceras que nunca se imprimen.
  static const cabecerasSensibles = {'authorization', 'cookie', 'set-cookie'};

  /// Campos que nunca se imprimen, ni en petición ni en respuesta.
  ///
  /// En minúsculas: la comparación normaliza antes de buscar. Un backend que
  /// devolviera `Diagnostico` en vez de `diagnostico` no debe abrir un hueco.
  static const camposSensibles = {
    // Credenciales y sesión
    'contrasena', 'password', 'accesstoken', 'refreshtoken', 'token',
    // Identidad. Nombre + fecha de nacimiento + dirección es el trío clásico
    // de reidentificación, y el registro ya delata que la persona es paciente.
    'documentoidentidad', 'cedula', 'correo', 'telefono',
    'fechanacimiento', 'direccion', 'sexo',
    // Clínicos — RNF-06
    'diagnostico', 'tratamiento', 'observaciones', 'signosvitales',
    'alergias', 'tiposangre', 'medicamento', 'dosis', 'frecuencia',
    'indicaciones', 'motivoconsulta', 'motivo', 'recetas', 'seguromedico',
    // Notificaciones y chat — RF-28 a RF-34. El cuerpo de una notificacion
    // dice "tu cita con el Dr. X del jueves"; el de un mensaje es la
    // conversacion clinica entera.
    'titulo', 'cuerpo', 'contenido',
    // **Credenciales, no metadatos.** Quien tenga `urlSala` entra a la
    // videollamada de un paciente sin mas; `urlAdjunto` puede ser una URL
    // firmada a un documento medico. En un log son una puerta abierta.
    'urlsala', 'urladjunto',
  };

  /// Si esta clave no puede aparecer en un log.
  ///
  /// `direccion` también la usa un centro médico, donde no es dato personal.
  /// Se redacta igual: el redactor no puede distinguir por nombre de clave y
  /// perder utilidad del log es más barato que filtrar el domicilio de un
  /// paciente.
  static bool esSensible(Object? clave) =>
      camposSensibles.contains(clave.toString().toLowerCase());

  /// Recorre el árbol y reemplaza los campos sensibles **a cualquier
  /// profundidad**.
  ///
  /// Mirar solo el primer nivel dejaría pasar un diagnóstico anidado dentro
  /// de `data[0].consulta`, que es exactamente la forma en que viaja.
  static Object? cuerpo(Object? dato) => switch (dato) {
    final Map<dynamic, dynamic> m => {
      for (final e in m.entries)
        e.key: esSensible(e.key) ? marca : cuerpo(e.value),
    },
    final List<dynamic> l => l.map(cuerpo).toList(),
    // Un cuerpo que no es JSON decodificado llega como texto crudo: una página
    // de error 500 del proxy, un `text/plain`. No hay claves que mirar, así
    // que se recorta en vez de imprimirlo entero — si adentro venía una traza
    // con datos, al menos no va completa.
    final String s when s.length > _maxTextoCrudo =>
      '${s.substring(0, _maxTextoCrudo)}… (${s.length} car.)',
    _ => dato,
  };

  static const _maxTextoCrudo = 200;

  /// Redacta las cabeceras sensibles, sin importar cómo vengan escritas.
  static Map<String, dynamic> cabeceras(Map<String, dynamic> headers) => {
    for (final e in headers.entries)
      e.key: cabecerasSensibles.contains(e.key.toLowerCase()) ? marca : e.value,
  };
}
