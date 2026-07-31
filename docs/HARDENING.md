# Endurecimiento — F13

Cierra **RNF-14** (pruebas por módulo, ≥ 80 %) y **RNF-18** (UTC ↔ Santo
Domingo). Lo que sigue son cambios verificados, no intenciones.

## Resumen

| | Antes | Después |
|---|---|---|
| Cobertura de línea | 73.7 % (1954/2651) | **86.0 %** (2297/2672) |
| Pruebas | 325 | **445** |
| `flutter analyze` | 0 | 0 |
| Tiempo hasta ver un error de red | 38.2 s | **1.2 s** |

Se excluyen del cálculo los `*.g.dart` y `*.freezed.dart`: son código
generado, y contarlos infla el número sin que nadie haya escrito una prueba.

`scripts/verify.sh` exigía **70 %** mientras se construían los módulos, o sea
que la puerta dejaba pasar cobertura por debajo de lo que pide RNF-14. El piso
sube a **80 %**, el valor del requerimiento. Comprobado que muerde:
`COBERTURA_MINIMA=90 ./scripts/verify.sh` falla.

---

## 1. El error tardaba 38 segundos en aparecer

El hallazgo más serio de la fase, y no estaba en el plan.

Riverpod 3 reintenta solo cualquier provider que falle.
`ProviderContainer.defaultRetry` reintenta todo lo que no sea un `Error` de
Dart ni un `ProviderException` —o sea, los diez `Failure` de la app— **10
veces**, con backoff de 200 ms a 6.4 s: **38.2 segundos** exactos
(200+400+800+1600+3200+6400×5; el backoff se satura en el sexto intento). Durante toda esa espera el estado sigue
siendo `AsyncLoading`.

Las cinco pantallas con estado asíncrono hacen `switch` con `AsyncLoading`
primero, así que pintaban el skeleton todo ese rato. El `ErrorState` con su
botón «Reintentar» aparecía más de medio minuto después de que el pedido
fallara. Sin conexión, la app se veía cargando para siempre.

Peor que la demora: reintentar no es neutral. El default repetía **el 409 de
turno ya reservado** (RF-20), que es justo el caso donde reintentar en
silencio está prohibido (RNF-10), y también los 403 y los 404.

`core/network/politica_reintento.dart` fija la política:

| Failure | ¿Reintenta? | Por qué |
|---|---|---|
| `SinConexion`, `ErrorServidor` | sí, 2 veces (300 ms, 900 ms) | El mismo pedido puede salir bien sin que el usuario cambie nada |
| `Conflicto` | **no** | RF-20: el turno ya lo tomaron. Reintentar le esconde al usuario el segundo que podría usar para elegir otro |
| `Prohibido`, `NoEncontrado`, `Validacion`, `TurnoInvalido` | **no** | Deterministas |
| `NoAutorizado`, `SesionExpirada` | **no** | Lo resuelve el refresh del interceptor, no la repetición |
| `ErrorInesperado` y todo lo que no sea `Failure` | **no** | Un parseo roto se repite igual de roto |

Cómo se descubrió: al escribir la prueba de estado de error de
`BusquedaScreen`, el `ErrorState` nunca aparecía. Las pruebas equivalentes de
las otras cuatro pantallas pasaban *por accidente* — usan `pumpAndSettle`, y
como el skeleton anima en bucle, seguían bombeando frames hasta agotar los 10
reintentos. Pasaban verificando un comportamiento que el usuario no vive.

Las seis pruebas de pantalla ahora montan `ProviderScope` con la **misma**
política que `main.dart`. Doce pruebas en
`test/core/network/politica_reintento_test.dart` cubren la política, dos de
ellas ancladas contra el default de Riverpod: si una versión futura lo cambia,
avisan en vez de dejar esta justificación apuntando a algo que ya no es cierto.

## 2. Las pruebas de API no ejecutaban la API

Los `*_api.dart` estaban entre 3 % y 8 %. La causa: cada doble de prueba
`extends XApi` y sobrescribe los métodos, así que la construcción real de URL
y parámetros **nunca corría**. Un `page` escrito `pagina`, una ruta mal
tecleada o un filtro nulo viajando como `especialidadId=null` solo se habrían
visto contra el servidor.

`test/contrato_api_test.dart` usa las clases reales sobre un
`HttpClientAdapter` falso y verifica la petición ya armada contra
`API_CONTRACT.md`: 24 pruebas sobre las 6 APIs. Entre otras cosas fija el
prefijo `/api`, que `especialidadId` desaparezca de la query cuando es nulo,
que `PATCH` no mande las claves sin tocar (mandarlas en `null` borraría el
dato), que reservar **no** incluya `idPaciente` (RF-09) y que el historial
solo acepte paginación (RNF-06).

Comprobado falsificable: al quitar el `?` de `'especialidadId': ?especialidadId`
falla la prueba correspondiente y ninguna otra.

## 3. Los tokens: la regla estaba escrita en un comentario

`secure_store.dart` decía «nunca `SharedPreferences`» en un comentario, y
estaba en 0 % de cobertura. Un comentario no detiene a nadie.

`test/core/storage/secure_store_test.dart` verifica el comportamiento
(`limpiar` borra **los dos** tokens: dejar el refresh vivo permite sacar otro
access token, o sea esconder el botón en vez de cerrar sesión) y agrega una
guarda que recorre `lib/` y `pubspec.yaml` buscando `shared_preferences`.
Comprobada falsificable.

## 4. La redacción de logs no se estaba probando

La prueba original de `LoggingInterceptor` **reimplementaba** la lógica de
redacción para compararla. Eso no protege nada: si alguien rompe el original,
la copia sigue en verde — el mismo defecto que el gate rechazó en F06.

La redacción se extrajo a `core/network/redactor.dart` y se prueba directo:
la redacción **a cualquier profundidad** (un diagnóstico dentro de
`data[0].consulta` es exactamente la forma en que viaja), listas anidadas y
claves con distinta capitalización.

La revisión encontró tres huecos más, todos corregidos:

- **El cableado no estaba probado.** `Redactor` quedó verificado como función
  pura, pero nada comprobaba que el interceptor lo llamara: borrar un
  `Redactor.cuerpo(...)` —dieciséis caracteres— mandaba diagnósticos a logcat
  con la suite en verde. La construcción del mensaje se extrajo a tres
  funciones puras (`mensajePeticion`, `mensajeRespuesta`, `mensajeError`) y
  `test/core/network/logging_interceptor_test.dart` afirma sobre ellas. No
  hacía falta interceptar `developer.log`: bastaba poder mirar el mensaje
  antes de emitirlo.
- **Faltaban campos de identidad.** `GET /api/patients/me` devuelve
  `fechaNacimiento`, `direccion` y `sexo`, y ninguno estaba en la lista.
  Nombre + nacimiento + dirección reidentifica a una persona, dentro de un
  registro que ya delata que es paciente. Agregados, junto con `motivo` (el
  texto libre de la cancelación).
- **La prueba de cobertura de la lista era una copia a mano.** Once nombres
  literales de §8: detectaba que alguien *quitara* un campo, no que el backend
  *agregara* uno, porque para eso había que acordarse de editar la copia — el
  mismo olvido que decía prevenir. Por eso no vio el punto anterior. Ahora
  recorre los esquemas de `docs/openapi.json` y exige que **cada** propiedad
  esté clasificada: o redactada, o en una lista blanca explícita. Al escribirla
  aparecieron `ciudad`, `latitud` y `longitud`, que resultaron ser de
  `CentroMedicoResponseDto`.

El query string también pasa ahora por el redactor. Hoy no lleva nada
sensible, pero el día que el backend tenga búsqueda por texto
(BACKEND_ISSUES.md #8) el término natural es un nombre o una cédula, y se
imprimiría en claro mientras el mismo dato en el cuerpo sí se taparía.

## 5. RNF-18 — UTC

`test/core/time/disciplina_utc_test.dart` recorre `lib/` y falla si aparece
`DateTime.now()`, `.toLocal()`, `DateTime.parse` sin normalizar, el
constructor `DateTime(...)` o `fromMillisecondsSinceEpoch`. Comprobada
falsificable: al insertar `DateTime.now()` en `cita.dart` falló nombrando
archivo y línea.

La revisión encontró que la guarda tenía tres puntos ciegos, y que uno de
ellos escondía una violación real:

- **Saltaba los generados.** El argumento era "no se escriben a mano", que
  para esta regla es exactamente al revés: `json_serializable` emite
  `DateTime.parse(...)` sin `.toUtc()` porque no sabe nada de RNF-18, y nadie
  revisa esa salida. Al incluirlos aparecieron
  `auth_dto.g.dart:58` y `:61`. `UsuarioDto` era el único DTO del proyecto que
  declaraba campos `DateTime`; los otros cinco features usan `String` y
  convierten en el repositorio. Se alineó con ellos.
- **Eximía la línea entera** si `.toUtc()` aparecía en cualquier parte, así
  que `DateTime.parse(a), DateTime.parse(b).toUtc()` pasaba con el primer
  parseo en local. Ahora la comprobación es por aparición.
- **Fallaba en silencio si el cwd no era la raíz del paquete**: devolvía la
  lista vacía y las tres pruebas pasaban sin leer un archivo. Ahora afirma que
  `lib/` existe y que recorrió más de treinta archivos.

El desfase es **fijo de −4 h**, no la zona IANA. Es deliberado: coincide con
`OFFSET_SANTO_DOMINGO_HORAS = 4` del backend (ADR-005). Usar la zona real
haría que front y back discreparan si alguna vez se reinstaura el horario de
verano. Las fechas de calendario (nacimiento, `?fecha=`) usan
`FechaCalendario` y **no** pasan por `AppTime`: no tienen hora que convertir.

## 6. Rendimiento

Auditoría, no perfilado: no hay dispositivo en este entorno y un número de
jank inventado sería peor que no darlo.

- **Listas.** Las cuatro pantallas con listas de tamaño desconocido usan
  constructores perezosos: `ListView.separated` en búsqueda, citas e historial
  y en la grilla de turnos de agenda; `ListView.builder` en el listado de
  franjas de agenda.
  Quedan **cinco** `ListView(` con `children` literales, todos de tamaño
  acotado: `login_screen.dart:86` y `registro_screen.dart:96` (formularios),
  `dev/gallery.dart:41` (galería de desarrollo) y
  `perfil_screen.dart:103` y `:182`. Los dos de perfil son los únicos que
  pintan datos del servidor y por eso se revisaron uno por uno: son campos
  fijos más un bloque condicional, y las especialidades del médico se
  colapsan a un `String` con `join(' · ')` en vez de expandirse a hijos.
- **`const`.** `prefer_const_constructors` está activo y `flutter analyze`
  cierra en cero, así que la ausencia de `const` no puede pasar sin verse.
- **N+1.** `core/data/medico_directorio.dart` cachea y agrupa las llamadas a
  `/doctors/{id}` de los listados de citas (resuelto en F08).
- **Sin `shrinkWrap: true`** en ninguna lista: fuerza medir todos los hijos y
  anula la ventaja de la lista perezosa.

**Pendiente y honesto:** falta un perfil de jank en dispositivo real y una
medición de arranque en frío. Requiere hardware; queda para F15.

## 6.b Accesibilidad — la prueba medía algo que no podía fallar

Las diez pruebas de escala de texto al 200 % montaban el widget dentro de un
`SingleChildScrollView`, que le pasa al hijo `maxHeight: infinity`. Con altura
infinita un `RenderFlex` **no puede** desbordar en vertical, así que
`takeException` nunca iba a devolver nada por el motivo que las pruebas
nombraban. Se quitó el envoltorio y todas siguen en verde: ningún widget
desborda a 200 % contra la altura real del viewport.

Además, el recorte de texto no lanza excepción —`TextOverflow.ellipsis` es
silencioso—, así que las dos pruebas que afirmaban «no se corta» se pasaron a
geometría: `didExceedMaxLines` en falso y altura mayor a la de una línea.

## 7. Fuera de alcance, dicho explícitamente

- **Banner de sin-conexión global y cola de reintentos.** No hay RNF que lo
  pida. Hoy `SinConexion` llega con mensaje claro y botón en cada pantalla, y
  la política de §1 absorbe los baches cortos. Un banner global además
  necesita `connectivity_plus`, que reporta la interfaz de red, no si el
  servidor responde: mostraría «con conexión» con el wifi de un café que no
  deja salir.
- **i18n.** La app es de una sola región (Santo Domingo, es_DO) y todos los
  textos —incluidos los mensajes de error, que llegan ya redactados desde la
  capa de datos— están en español. Meter ARB ahora mueve ~200 cadenas sin que
  exista un segundo idioma que las use.

## 7.b Deuda encontrada, no cerrada: imports entre features

La revisión de arquitectura encontró una violación **BLOQUEANTE** del rubro
3.3 que llevaba seis fases sin verse: cinco features importan
`dioClienteProvider`, `secureStoreProvider` y `sesionActualProvider` desde
`features/auth/presentation/`. Siete archivos. Y `auth_provider.dart`, que
vive en `presentation/`, importa `dio` — la otra regla BLOQUEANTE del mismo
rubro.

Sobrevivió porque `ARCHITECTURE.md` afirma que la regla está «verificada en el
gate» y no lo estaba: solo existía en Markdown. `test/arquitectura_test.dart`
la vuelve ejecutable y comprobadamente muerde.

**No se corrigió en esta fase, a propósito.** Mover los dos providers de
infraestructura a `core/` es mecánico, pero `dioCliente` llama a
`sesionActual.expirar()` cuando el refresh falla: subirlo invierte la
dependencia y `core` pasaría a depender de `auth`. Hacerlo bien pide decidir
dónde vive la sesión —hoy la consumen el router, `historial` y `perfil`— y
probablemente una interfaz en `core` que `auth` implemente. Es un rediseño con
decisiones propias; mezclarlo con el endurecimiento habría vuelto el commit
irrevisable.

La guarda lleva las siete rutas en un registro de deuda. Cualquier violación
**nueva** falla, y una entrada que ya no corresponde también falla, así que el
registro solo puede encoger.

## 8. Lo que sigue sin cubrir, y por qué

| Archivo | % | Motivo |
|---|---|---|
| `core/network/logging_interceptor.dart` | — | Ya no es excepción: la construcción del mensaje se extrajo a funciones puras y tiene pruebas propias. Solo queda sin cubrir el `developer.log` final |
| `core/theme/app_theme.dart` | 54 % | Declaraciones de tokens. Las pruebas de golden y de accesibilidad cubren las que se usan |
| `core/data/medico_directorio.dart` | 38 % | Caché y coalescencia; las rutas de fallo de red no tienen prueba propia |
| `*_dto.dart` | 17-40 % | `fromJson`/`toJson` generado; se ejercita indirectamente en las pruebas de contrato |
