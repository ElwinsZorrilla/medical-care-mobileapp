# Hallazgos del backend

Detectados en **F00** (2026-07-30) contra `RafaelEspinal0/medical-care-back` @ `main`.

Regla R3: **el front no los arregla.** Se levantan como issue en el repo del
backend. Acá queda el registro y, sobre todo, **qué hace el front mientras
tanto** — que es lo que decide si una fase se puede construir o no.

Ninguno se ha reportado todavía como issue de GitHub.

| # | Hallazgo | Gravedad | Bloquea |
|---|---|---|---|
| 1 | `docker compose up -d` falla: `argon2` no compila en `node:20-alpine` | Alta | arranque documentado, F14 |
| 2 | CORS no está habilitado | Alta | Flutter web, F14 |
| 3 | No hay logout ni revocación de refresh token | Alta | RF-05 |
| 4 | No hay transición de estado de cita | Alta | RF-23 parcial |
| 5 | Chat, notificaciones y video: entidades sin API | **Crítica** | RF-28..37 → F10, F11, F12 |
| 6 | El README describe un stack que no existe | Media | confianza en la doc |
| 7 | Sin rate limiting | Media | RNF-05 |
| 8 | `GET /doctors` no acepta búsqueda por texto | Media | RF-14 parcial |

---

## 1 · `docker compose up -d` no funciona

El servicio `migrate` corre sobre `node:20-alpine` y hace `npm ci`. `argon2` es
un módulo nativo: no publica binario para musl y la imagen no trae `python3`,
`make` ni `g++`, así que `node-gyp` aborta.

```
gyp ERR! find Python  Could not find any Python installation to use
gyp ERR! cwd /app/node_modules/argon2
npm error command failed  (exit 1)
```

El arranque que documenta el README del backend **no llega a correr las
migraciones**. Cualquiera que clone el repo se traba en el paso 2.

**Arreglo del lado del backend** — una de las dos:
- usar `node:20-bookworm` (glibc: `argon2` trae binario precompilado), o
- seguir en alpine y añadir `RUN apk add --no-cache python3 make g++`.

**Mientras tanto (F00):** se levantó `postgres`/`redis` con compose y la API se
corrió aparte con Node 22 del host, que sí resuelve `argon2`. Las migraciones y
el seed corrieron bien por esa vía.

---

## 2 · CORS no está habilitado

`main.ts` nunca llama a `app.enableCors()`. Verificado:

```
OPTIONS /api/auth/login   Origin: http://localhost:8080
  → 404 · access-control-allow-origin: AUSENTE
```

En móvil no importa — no hay origen. **En Flutter web sí:** el navegador manda
preflight y lo bloquea. El target `web` de `docker/docker-compose.yml` sirve el
front en `:8080` contra la API en `:3000`: **ese escenario no funciona hoy**, y
es justo el que F14 usa para la defensa del proyecto.

**Arreglo:** `app.enableCors({ origin: [...], credentials: true })` en `main.ts`.

**Mientras tanto:** las pruebas end-to-end van en emulador/dispositivo, no en
navegador. F14 no puede cerrar hasta que esto exista.

---

## 3 · No hay logout ni revocación de refresh token

No existe `POST /auth/logout`. Y `refresh` valida con `jwtService.verifyAsync`
contra el secreto, sin store ni lista negra. Verificado:

```
refresh #1 con RT_viejo  → 201, entrega RT_nuevo
refresh #2 con RT_viejo  → 201  ← el viejo sigue sirviendo
```

Rota el token pero **no invalida el anterior**. Un refresh token filtrado vale 7
días completos y no hay forma de cortarlo.

**RF-05 ("logout invalida el refresh token") no se puede cumplir desde el
front.** Borrar el token del dispositivo no lo revoca en el servidor.

**Arreglo:** tabla de refresh tokens (o `jti` + lista negra en Redis — que ya
está levantado y sin usar) y un `POST /auth/logout` que lo marque.

**Mientras tanto:** F04 implementa logout local (borrar de `SecureStore` y
mandar a login) y `TRACEABILITY.md` declara RF-05 como **parcial**, con la razón
escrita. Un requisito faltante declarado vale más que uno escondido.

---

## 4 · Una cita no puede cambiar de estado

`EstadoCita` tiene cinco valores y solo tres son alcanzables:

| Estado | Cómo se llega |
|---|---|
| `PENDIENTE` | `POST /appointments` |
| `CANCELADA` | `PATCH /appointments/{id}/cancelar` |
| `COMPLETADA` | efecto secundario de `POST /consultations` |
| `CONFIRMADA` | — |
| `NO_ASISTIO` | — |

No hay `PATCH /appointments/{id}/estado`. El médico no puede confirmar una cita
ni marcar que el paciente no asistió.

**Arreglo:** endpoint de transición restringido al médico de la cita, con
validación de transiciones legales.

**Mientras tanto:** `CitaEstado.fromApi` mapea los cinco (están en el enum y en
la BD, y un valor no mapeado debe fallar ruidoso). El `StatusRail` de F02 pinta
los cinco. La acción "confirmar cita" no se construye en F08; RF-23 queda
**parcial** en la matriz.

---

## 5 · Chat, notificaciones y video: tablas sin API

Las tres tienen entidad TypeORM y tabla creada por la migración
`InitialSchema`, pero **ni controller, ni service, ni módulo**. No están en
`app.module.ts` y no aparecen en los 29 endpoints del spec.

| Módulo | Hay | Falta |
|---|---|---|
| `chat/` | `conversacion.entity.ts`, `mensaje.entity.ts` | todo lo demás + transporte realtime |
| `notifications/` | `notificacion.entity.ts` | todo lo demás + proveedor de push |
| `video/` | `videollamada.entity.ts` | todo lo demás + proveedor de video |

**10 de 37 RF no tienen backend: RF-28..RF-37.**

Es el hallazgo más caro del proyecto, porque **F10, F11 y F12 son tres fases
completas del loop sin nada contra qué construir.** No es un detalle de
contrato: es un tercio de las fases de features.

### El backend está cerrado

Verificado el 2026-07-30 sobre el repo real:

- una sola rama (`main`), sin ramas de feature pendientes;
- **cero pull requests abiertos**;
- último commit: `Merge pull request #10 from RafaelEspinal0/chore/cierre-proyecto`.

**No hay trabajo en curso sobre estos módulos.** La opción "esperar a que el
backend los implemente" está descartada salvo que el equipo reabra el proyecto.

**Decisión requerida antes de llegar a F10** — quedan dos caminos honestos:

1. **Reducir el alcance del front.** F10/F11/F12 salen del plan y los 10 RF se
   declaran fuera de alcance en `TRACEABILITY.md`, con la razón escrita.
   Defendible ante un jurado: el requisito no se cumple *y se sabe por qué*.
2. **Construir contra un mock.** UI real contra datos falsos, detrás de las
   mismas interfaces de repositorio que usaría la API. Se ve completo en la
   defensa y no funciona contra nada. Si se elige, **hay que declararlo en la
   presentación** — el riesgo no es técnico, es que parezca funcional.

Lo que no es una opción: construirlo contra un mock y no decirlo.

No es decisión del front tomarla solo.

---

## 6 · El README del backend describe un stack que no existe

Dice textualmente:

> Notificaciones (confirmación, cancelación, recordatorios 24h/1h) procesadas de
> forma asíncrona con BullMQ.
> Redis + BullMQ para colas asíncronas, `@nestjs/schedule` para cron.

**Ni `bullmq`, ni `@nestjs/schedule`, ni cliente de Redis están en
`package.json`.** No hay módulo de notificaciones (ver #5). El contenedor
`redis` se levanta en el compose y no lo usa nadie.

Cuesta tiempo real: planificar F10 leyendo ese README lleva a asumir que los
recordatorios ya existen del lado servidor.

**Arreglo:** alinear el README con lo implementado, o marcar esa sección como
pendiente.

---

## 7 · Sin rate limiting

No hay `@nestjs/throttler` ni equivalente. `POST /auth/login` acepta intentos
ilimitados. RNF-05 pide "cabeceras, CORS y rate limit" y hoy no se cumple
ninguno de los tres del lado aplicación.

**Mientras tanto:** `docker/nginx.conf` ya pone las cabeceras de seguridad para
el target web, pero eso no protege a los clientes móviles, que pegan directo a
la API.

---

## 8 · `GET /doctors` no busca por texto

Los únicos parámetros son `page`, `limit` y `especialidadId`. No hay `q` ni
`nombre`.

RF-14 (filtrar por especialidad) **se cumple**. Buscar un médico por nombre no
tiene backend.

**Mientras tanto:** F06 hace el buscador con debounce de 300ms **solo sobre el
filtro de especialidad**. Filtrar por nombre en cliente sobre la página actual
sería peor que no tenerlo: da resultados que dependen de en qué página estás.
Mejor no ofrecerlo hasta que exista.
