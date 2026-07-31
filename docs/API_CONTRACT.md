# Contrato de API — VERIFICADO

> Verificado contra el backend real el **2026-07-30**, ejecutándolo en local y
> consultando `GET /docs-json`. El spec crudo está en [`openapi.json`](openapi.json).
>
> Fuente: `RafaelEspinal0/medical-care-back` @ `main`. NestJS 11 + TypeORM +
> PostgreSQL 16. **29 endpoints reales.**
>
> Todo lo marcado abajo se confirmó ejecutando peticiones, no leyendo código.
> Los huecos del backend están en [`BACKEND_ISSUES.md`](BACKEND_ISSUES.md).

---

## 1. Convenciones — confirmadas

| Aspecto | Real | Antes se asumía |
|---|---|---|
| Prefijo | **`/api`** | `/api/v1` ✏️ |
| Swagger | `/docs` · JSON en `/docs-json` (sin prefijo) | ✅ |
| Auth | `Authorization: Bearer <jwt>` | ✅ |
| Fechas | ISO-8601 UTC con `Z`, `timestamptz` en Postgres | ✅ |
| Paginación | **`{ data, total, page, limit }` plano** | `{ data, meta:{...} }` ✏️ |
| Error | `{ message, error, statusCode }` | ✅ |
| Validación | **400** con `message: string[]` | 422 o 400 ✏️ |
| Idioma | **rutas en inglés, campos en español** | rutas en español ✏️ |

### Lo que rompe si se asume mal

**1. `POST /auth/login` y `POST /auth/refresh` devuelven `201`, no `200`.**
Nest usa 201 por defecto en `POST` y estos controladores no declaran
`@HttpCode(200)`. El Swagger *dice* 200 y la respuesta real es 201. Un cliente
que compare `statusCode == 200` falla en el login. **Aceptar cualquier 2xx.**

**2. `ValidationPipe` corre con `forbidNonWhitelisted: true`.** Mandar un campo
de más no se ignora: devuelve `400 "property X should not exist"`. Los DTOs del
front tienen que serializar **exactamente** los campos permitidos — nada de
mandar el modelo entero con extras.

**3. El `400` de reserva no es un error de validación.** En
`POST /appointments`, `400` significa "ese turno no existe en ninguna franja".
Si el mapeo genérico manda todo 400 a `Validacion`, este caso se pinta como
error de formulario. Necesita su propia rama.

**4. `401` sin token no trae la clave `error`.** Llega
`{"message":"Unauthorized","statusCode":401}`. El parser del `Failure` no puede
exigir `error`.

---

## 2. Zona horaria — RNF-18 · **resuelto**

**`?fecha=YYYY-MM-DD` es una fecha del calendario de Santo Domingo, no UTC.**

El backend usa un offset **fijo de UTC-4** (constante
`OFFSET_SANTO_DOMINGO_HORAS = 4`, citando ADR-005: RD no tiene horario de
verano). Verificado:

```
franja del médico: horaInicio "08:00", horaFin "10:00"  (hora local, string)
GET /availability/doctors/1/slots?fecha=2026-08-17
  → [{ "horaInicio": "2026-08-17T12:00:00.000Z", ... }]   # 08:00 -04 = 12:00Z
```

Reglas que salen de ahí:

- Las **franjas** (`horaInicio`/`horaFin` de `AvailabilityResponseDto`) son
  strings `"HH:mm"` en **hora local de Santo Domingo**. No llevan fecha ni zona.
- Los **slots** (`SlotResponseDto`) son instantes **ISO-8601 UTC absolutos**.
- `diaSemana` es `getUTCDay()`: **0 = domingo, 1 = lunes** … 6 = sábado.
- Al reservar, `horaInicio` se manda **tal cual vino del endpoint de slots**.
  No reconstruirlo.

> **Cuidado con `AppTime`.** El backend usa offset fijo −4; el paquete
> `timezone` de Dart usa la zona IANA `America/Santo_Domingo`. Hoy coinciden
> (RD no aplica DST desde 2000). No "corregir" por horario de verano: si algún
> día divergen, manda el servidor. La prueba de RNF-18 debe fijar −4.

---

## 3. Auth — RF-01..06

| Método | Ruta | Cuerpo | Éxito | Errores |
|---|---|---|---|---|
| POST | `/api/auth/register` | `{ correo, contrasena, tipoUsuario, telefono? }` | **201** `{ accessToken, refreshToken }` | 409 correo ya registrado · 400 validación |
| POST | `/api/auth/login` | `{ correo, contrasena }` | **201** `{ accessToken, refreshToken }` | 401 credenciales · 403 bloqueado/inactivo |
| POST | `/api/auth/refresh` | `{ refreshToken }` | **201** `{ accessToken, refreshToken }` | 401 inválido/expirado |
| GET | `/api/auth/me` | — | 200 `UsuarioResponseDto` | 401 |

- Campos en español: **`correo`, `contrasena`, `tipoUsuario`** — no
  `email`/`password`/`rol`.
- `contrasena`: 8–72 caracteres. Hash `argon2` del lado servidor (RNF-01 ✅).
- `tipoUsuario` en registro público: **`PACIENTE` | `MEDICO`**. `ADMIN` existe
  en el enum pero el registro lo rechaza.
- La respuesta **no incluye el usuario**. Para tener el rol hay que llamar
  `GET /auth/me` o leer el JWT. Payload: `{ sub, correo, tipoUsuario }`.
- Vigencia: access **15m**, refresh **7d**.

**Refresh — comportamiento verificado:** rota el par (devuelve un
`refreshToken` nuevo cada vez) **pero no revoca el anterior**. La validación es
`jwtService.verifyAsync` sin store: cualquier refresh token vale hasta que
expire. Consecuencias:

- El *single-flight* sigue siendo obligatorio (evita la estampida y las
  condiciones de carrera al guardar el token), pero el modo de falla que
  describe `ARCHITECTURE.md` — "el back invalida el anterior y expulsa al
  usuario" — **no ocurre acá**.
- **No existe `POST /auth/logout`.** RF-05 no tiene backend: el logout solo
  puede borrar tokens del dispositivo. Ver `BACKEND_ISSUES.md` #3.

---

## 4. Perfiles — RF-07..11

| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/patients` | crea el perfil del usuario autenticado · 409 si ya existe |
| GET/PATCH | `/api/patients/me` | 404 si no creó perfil |
| POST | `/api/doctors` | 409 si ya existe |
| GET | `/api/doctors/me` | |
| GET/PATCH | `/api/doctors/{id}` | PATCH → 403 si no es el titular |
| PUT | `/api/doctors/{id}/especialidades` | `{ idsEspecialidades: number[] }` |

**Paciente** (`PatientResponseDto`): `idPaciente, idUsuario, nombres, apellidos,
documentoIdentidad, fechaNacimiento` obligatorios; `sexo ('M'|'F'), direccion,
tipoSangre, alergias, seguroMedico` nullables.
→ **`alergias` es `string`, no `string[]`.** ✏️

**Médico** (`DoctorResponseDto`): `idMedico, idUsuario, nombres, apellidos,
numExequatur, estadoVerificacion, especialidades[]`; `biografia,
aniosExperiencia, tarifaConsulta` nullables.
→ el campo es **`numExequatur`**, no `exequatur`. ✏️

**RF-09 ✅ confirmado.** El id sale de `JwtPayload.sub`; `/patients/me` y
`/doctors/me` no aceptan id del cliente. `PATCH /doctors/{id}` da **403** a un
tercero (`doctor-ownership.guard.ts`).

---

## 5. Especialidades y búsqueda — RF-12..15

| Método | Ruta | Query |
|---|---|---|
| GET | `/api/specialties` | — (sin paginar, 10 sembradas) |
| GET | `/api/specialties/{id}` | |
| GET | `/api/doctors` | `page`, `limit`, **`especialidadId`** |
| GET | `/api/medical-centers` | — |

- Paginación: `page` ≥ 1 (def. 1), `limit` 1–**50** (def. **10**). `limit=999`
  → 400. Nada de `limit: 1000`.
- No hay `lastPage`: el cliente calcula `ceil(total / limit)`.
- **No existe búsqueda por texto.** El único filtro es `especialidadId`.
  RF-14 ✅; buscar médico por nombre **no tiene backend** — o se filtra en
  cliente sobre la página actual (malo) o se declara fuera de alcance.
  Ver `BACKEND_ISSUES.md` #8.

---

## 6. Disponibilidad — RF-16..18

| Método | Ruta | Notas |
|---|---|---|
| POST | `/api/availability` | `{ diaSemana, horaInicio, horaFin, duracionSlotMin, modalidad, idCentro? }` |
| GET | `/api/availability/me` | lista sin paginar, orden `diaSemana, horaInicio` |
| PATCH | `/api/availability/{id}` | edición parcial · 409 si solapa |
| PATCH | `/api/availability/{id}/desactivar` | `activo = false` |
| GET | `/api/availability/doctors/{idMedico}/slots?fecha=` | **público**, `fecha` obligatoria |

- `modalidad` de la franja: `PRESENCIAL` | `VIRTUAL` | **`AMBAS`**.
  La de la cita solo `PRESENCIAL` | `VIRTUAL`.
- Solape de franjas activas del mismo día → **409**.
- `horaFin <= horaInicio` → **409** (no 400).
- Los slots ya excluyen los ocupados. `fecha` mal formada → 400.

---

## 7. Citas — RF-19..24

| Método | Ruta | Rol | Éxito |
|---|---|---|---|
| POST | `/api/appointments` | PACIENTE | **201** |
| PATCH | `/api/appointments/{id}/cancelar` | paciente o médico de la cita | 200 |
| GET | `/api/appointments/me` | PACIENTE | 200 paginado |
| GET | `/api/appointments/agenda` | MEDICO | 200 paginado |

**Reserva** — `{ idMedico, fecha, horaInicio, modalidad, motivoConsulta? }`.
`fecha` es `YYYY-MM-DD` local y `horaInicio` el ISO UTC del slot: **van los
dos**, aunque sea redundante.

### RF-20 / RNF-10 — **409 CONFIRMADO con una carrera real**

Dos pacientes contra el mismo slot, en paralelo:

```
A -> 201 PENDIENTE
B -> 409 "Ese turno ya fue reservado"
```

El backend lo sostiene bien: transacción + `pessimistic_write` sobre la franja,
más `@Unique(['medico','fechaHoraInicio'])` en la tabla y captura del código
`23505`. La suposición del diseño se cumple: **refrescar la grilla y avisar, sin
reintento silencioso.**

**Pero `409` está sobrecargado — significados distintos:**

| Mensaje | Qué hacer en la UI |
|---|---|
| `Ese turno ya fue reservado` | refrescar slots + "elige otra hora" |
| `Ese turno ya fue reservado por otro paciente` | ídem (carrera perdida) |
| `Ese turno solo admite modalidad PRESENCIAL` | corregir modalidad, no refrescar |
| `La cita ya estaba cancelada` (en cancelar) | refrescar el detalle |

No hay código de error propio: **hay que mirar el `message`.** Encapsularlo en
el repositorio de `citas`, nunca en un widget.

Y `400` = "ese turno no corresponde a ninguna franja" — turno inválido, no
error de formulario.

**Listados:** `ListAppointmentsQueryDto` **solo extiende paginación**. No hay
`estado`, ni `desde`, ni `hasta`. ✏️ Filtrar por estado es en cliente, sobre la
página traída. Orden fijo: `fechaHoraInicio DESC`.

**Forma de la cita** (`AppointmentResponseDto`) — **ids planos, sin anidar:**

```json
{ "idCita":1, "idPaciente":1, "idMedico":2, "idCentro":null,
  "idDisponibilidad":2, "fechaHoraInicio":"2026-08-17T12:00:00.000Z",
  "fechaHoraFin":"2026-08-17T12:30:00.000Z", "modalidad":"PRESENCIAL",
  "estado":"PENDIENTE", "motivoConsulta":"...",
  "fechaCreacion":"2026-07-31T01:03:39.194Z" }
```

> **Impacto de diseño.** "Mis citas" no trae el nombre del médico ni la
> especialidad: solo `idMedico`. Para pintar la tarjeta del riel de estado hay
> que resolver `GET /doctors/{id}` aparte. Con 10 citas son 10 peticiones. F08
> necesita **caché de médicos en `core`** — resolver una vez por `idMedico` y
> reutilizar. Sin eso la agenda del médico hace N+1 y RNF-07 se cae.

### RF-23 — estados

`PENDIENTE · CONFIRMADA · CANCELADA · COMPLETADA · NO_ASISTIO` ✅ strings
exactos, alimentan `CitaEstado.fromApi`.

**Pero solo tres son alcanzables:**

| Estado | Cómo se llega |
|---|---|
| `PENDIENTE` | al reservar |
| `CANCELADA` | `PATCH /appointments/{id}/cancelar` |
| `COMPLETADA` | efecto secundario de `POST /consultations` |
| `CONFIRMADA` | **inalcanzable — no hay endpoint** |
| `NO_ASISTIO` | **inalcanzable — no hay endpoint** |

`CitaEstado` debe mapear los cinco (están en el enum y en la BD), pero la UI de
"confirmar cita" no tiene contra qué hablar. Ver `BACKEND_ISSUES.md` #4.

---

## 8. Historial clínico — RF-25..27

| Método | Ruta | Rol |
|---|---|---|
| POST | `/api/consultations` | MEDICO tratante |
| POST | `/api/consultations/{id}/recetas` | MEDICO |
| GET | `/api/consultations/me` | PACIENTE — su historial |
| GET | `/api/consultations/atendidas` | MEDICO — lo que atendió |

- Registrar consulta **completa la cita** (`estado → COMPLETADA`).
- Precondición: cita en `PENDIENTE` o `CONFIRMADA`. Cancelada/completada/
  no-asistió → **409**.
- Una consulta por cita: repetir → 409.
- Médico ajeno → **403** (`consultation-ownership.guard.ts`).

`ConsultationResponseDto`: `idConsulta, idCita, idPaciente, idMedico,
diagnostico, fechaRegistro, recetas[]` obligatorios; `tratamiento,
observaciones, signosVitales` nullables.
→ **`signosVitales` es un objeto anidado** (nullable), no campos planos.
`RecetaResponseDto`: `idReceta, medicamento, dosis, frecuencia` +
`duracionDias, indicaciones` nullables. → es **`duracionDias` (number)**, no
`duracion`. ✏️

**RNF-06:** el filtrado por titular lo hace el servidor (`/consultations/me`
sale del token). No hay endpoint para pedir el historial de otro paciente, así
que no hay 403 que probar: el acceso cruzado simplemente no se puede expresar.

---

## 9. Lo que **no existe** en el backend

Confirmado sobre los 29 endpoints reales y los módulos registrados en
`app.module.ts`:

| Requerimientos | Estado real |
|---|---|
| **RF-28..30** Notificaciones | tabla `notificacion` + entidad. **Sin controller, sin service, sin módulo.** 0 endpoints. |
| **RF-31..34** Chat | tablas `conversacion` y `mensaje` + entidades. **0 endpoints, 0 WebSocket.** |
| **RF-35..37** Videollamada | tabla `videollamada` + entidad. **0 endpoints.** |
| **RF-05** Logout | no hay endpoint ni revocación. |

**10 de 37 RF no tienen backend.** Las fases **F10, F11 y F12 no se pueden
construir contra la API real.**

Respuestas a las preguntas abiertas de F00:

- **Transporte de realtime:** ninguno. No hay `@nestjs/websockets` ni
  `socket.io` en `package.json`. `socket_io_client` sobra en el `pubspec`.
- **Proveedor de push:** ninguno. No hay `firebase-admin` ni equivalente.
  `firebase_messaging` sobra hasta que exista backend.
- **Proveedor de video:** ninguno. La entidad `videollamada` guarda un enlace,
  pero nada lo genera.

> El README del backend dice que las notificaciones se procesan "de forma
> asíncrona con BullMQ" y que el stack incluye `@nestjs/schedule`. **Ninguna de
> las dos es dependencia del proyecto.** Redis se levanta en el compose y no lo
> usa nadie. Ver `BACKEND_ISSUES.md` #6.

---

## 10. Errores — mapeo a `Failure`

| HTTP | Cuándo | `Failure` |
|---|---|---|
| 400 | validación (`message: string[]`) | `Validacion` |
| 400 | turno fuera de franja (`POST /appointments`) | `TurnoInvalido` |
| 401 | sin token / token vencido | `NoAutorizado` → dispara refresh |
| 401 | refresh inválido | `SesionExpirada` → limpiar y a login |
| 403 | rol incorrecto, recurso ajeno, usuario bloqueado | `Prohibido` |
| 404 | no existe / perfil no creado | `NoEncontrado` |
| 409 | turno tomado, solape, duplicado, modalidad | `Conflicto` (+ `message`) |
| 5xx | | `ErrorServidor` |
| — | sin red / timeout | `SinConexion` |

Forma: `{ message: string | string[], error?: string, statusCode: number }`.
`message` es **`string` o `string[]`** según el caso — el parser tiene que
aguantar los dos. En `401` sin token no viene `error`.

---

## 11. Salud

`GET /api/health` → 200 / 503 (`@nestjs/terminus`). Cubre RNF-09.

---

## Salida de F00

- [x] `docs/openapi.json` en el repo (29 endpoints)
- [x] Todos los ❓ resueltos
- [x] Confirmado: **409** en reserva concurrente, con carrera real
- [x] Confirmado: `?fecha=` es calendario de **Santo Domingo**, offset fijo −4
- [x] Confirmado: refresh **rota** pero **no revoca** el anterior
- [x] Confirmado: **no hay** realtime, push ni video del lado servidor
- [x] Huecos del backend documentados en `BACKEND_ISSUES.md`
- [ ] DTOs generados en `lib/core/api/` — **va en F01**, cuando exista el
      proyecto Flutter
- [ ] Colección Bruno en `tools/api/` — pendiente
