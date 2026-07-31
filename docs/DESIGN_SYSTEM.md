# MediCare — Sistema de Diseño

## 1. El encargo

**Sujeto:** gestión de citas médicas en República Dominicana.
**Dos audiencias con necesidades opuestas:**

- **Paciente** — usa la app 3–4 veces al mes, en un Android de gama media, a
  veces con datos móviles lentos. Necesita aire, pasos claros, cero ambigüedad
  sobre "¿ya quedó mi cita o no?".
- **Médico** — abre la agenda 20 veces al día entre consultas. Necesita
  **densidad**. Un layout aireado le cuesta scroll y tiempo real.

Un solo sistema, dos densidades. Esa tensión es la decisión de diseño central,
no un detalle de implementación.

**Trabajo de la pantalla principal:** que el paciente sepa en un vistazo cuál es
su próxima cita y en qué estado está.

---

## 2. Dirección: "La ficha clínica"

### Por qué no la ruta obvia

La respuesta plantilla para una app médica es: fondo blanco, menta o teal
suave, tarjetas con esquinas muy redondeadas, sombras difusas, Inter en todo,
ilustraciones de doctores sonriendo. Se ve amable y no se ve **serio**. Este
producto maneja alergias, tipo de sangre, diagnósticos y recetas. La confianza
acá no viene de la simpatía, viene de la **precisión**.

### De dónde sale la dirección

Del mundo real del sujeto: la **ficha clínica en papel** y sus artefactos.

| Artefacto físico | Traducción digital |
|---|---|
| Pestañas de colores del expediente | **Riel de estado** (elemento firma) |
| Márgenes reglados de la hoja clínica | Filete estructural a la izquierda de cada bloque |
| Campos rotulados del formulario | Etiquetas en versalitas con tracking abierto |
| El recetario | Bloque monoespaciado, datos tabulares |
| Número de exequátur | Tratamiento monoespaciado, es un identificador legal |

El resultado no es "app de salud bonita". Es un **instrumento clínico**.

---

## 3. Color

Seis valores. Cada uno tiene un trabajo. Ninguno decora.

| Nombre | Hex | Trabajo |
|---|---|---|
| `ink` | `#0D1F2D` | Texto primario, filetes estructurales |
| `steel` | `#5C7284` | Texto secundario, metadatos, etiquetas |
| `paper` | `#F2F5F7` | Fondo. Blanco frío de panel, **no** crema |
| `surface` | `#FFFFFF` | Tarjetas y superficies elevadas |
| `verde` | `#0E7C66` | Acción primaria · estado confirmado |
| `ambar` | `#B26B00` | Estado pendiente · atención |
| `granate` | `#B3261E` | Cancelado · no asistió · destructivo |
| `cielo` | `#2D6CA2` | Enlaces · info · modalidad virtual |

**Decisiones sostenidas:**

- **Verde profundo, no menta.** `#0E7C66` da 5.8:1 contra blanco — soporta texto
  blanco encima sin trucos. La menta de las apps de wellness no llega a AA y
  obliga a texto oscuro sobre botón claro, que se lee débil. Además el verde
  profundo ya significa "confirmado" sin que nadie lo explique.
- **Fondo frío `#F2F5F7`, no crema cálido.** El crema empuja hacia lo editorial
  y lo acogedor. Esto es un panel de instrumento; lo frío lee como preciso.
- **El rojo es sagrado.** `granate` solo aparece en cancelar, no asistió y
  destructivo. Nunca en un badge decorativo, nunca en un ícono de acento. Si el
  rojo aparece en pantalla, algo pasó.

**Semántica de estado de cita (RF-23)** — un color por estado, sin excepción:

| Estado | Color | Glifo |
|---|---|---|
| Pendiente | `ambar` | `○` |
| Confirmada | `verde` | `●` |
| Completada | `steel` | `✓` |
| Cancelada | `granate` | `╱` |
| No asistió | `granate` @ 60% | `✕` |

El glifo no es adorno: es el respaldo para daltonismo. El color solo nunca
comunica estado. (RNF de accesibilidad)

---

## 4. Tipografía

Tres cortes, tres trabajos. Nunca uno solo haciendo todo.

| Rol | Familia | Por qué |
|---|---|---|
| Display | **Archivo** | Grotesca ajustada, con eje Expanded. Tiene aire de señalética de equipo médico. Se usa con moderación: títulos de pantalla y nada más. |
| Cuerpo | **Public Sans** | Cara de grado cívico, diseñada para formularios de gobierno. Legible a 14sp en pantalla mediocre. No es Inter — Inter es el default de todos. |
| Datos | **IBM Plex Mono** | Tabular. Para horas, dosis, signos vitales, exequátur, tarifas. |

**La decisión que carga el sistema:** en esta app **los números son el
contenido**. `120/80`. `08:30`. `500mg c/8h`. `RD$1,500`. Exequátur `24-1877`.
Darles una monoespaciada tabular hace que se alineen en columna, que se comparen
de un vistazo y que se lean como lectura de instrumento en vez de como prosa. Es
el gesto que separa esto de una app genérica.

### Escala

| Token | Tam/Interlínea | Peso | Uso |
|---|---|---|---|
| `display` | 32 / 36 | Archivo 600 | Título de pantalla |
| `title` | 22 / 28 | Archivo 600 | Encabezado de sección |
| `heading` | 17 / 24 | Public Sans 600 | Título de tarjeta |
| `body` | 15 / 22 | Public Sans 400 | Texto corrido |
| `bodyStrong` | 15 / 22 | Public Sans 600 | Énfasis |
| `caption` | 13 / 18 | Public Sans 400 | Metadatos |
| `label` | 11 / 14 · +0.8 tracking · MAYÚS | Public Sans 600 | Rótulo de campo |
| `data` | 15 / 20 | Plex Mono 500 | Valores clínicos |
| `dataLg` | 24 / 28 | Plex Mono 600 | Cifra destacada |

`label` en versalitas con tracking abierto es la cita directa del formulario
clínico. Aparece encima de cada dato: `TIPO DE SANGRE` / `O+`.

---

## 5. Espacio, forma, elevación

**Base 4pt.** `4 · 8 · 12 · 16 · 24 · 32 · 48 · 64`

**Radio deliberadamente corto:**
`sm 4` (chips, campos) · `md 8` (tarjetas) · `lg 12` (hojas modales) · `full`
solo en avatares.

Nada de radio 24. El redondeo suave dice "app de consumo relajada". Un
expediente tiene esquinas.

**Elevación: casi ninguna.** La jerarquía se construye con **filetes de 1px
`ink` @ 12%**, no con sombras. Sombra solo en lo que flota de verdad: hoja
modal, FAB, menú. *La estructura es información* — un filete dice "esto es un
límite"; una sombra difusa no dice nada.

**Dos densidades:**

| | Paciente | Médico |
|---|---|---|
| Padding de tarjeta | `16` | `12` |
| Separación de lista | `12` | `4` |
| Alto de fila | `72` | `56` |
| Tipo base | `body 15` | `body 14` |

Se implementa como `AppDensity.patient` / `AppDensity.clinician` inyectado por
`Theme.extension`, resuelto por el rol del token. No son dos design systems: son
los mismos tokens con otra escala de espaciado.

---

## 6. Firma: el riel de estado

**El único elemento con el que se gasta la audacia.**

Una regla vertical de **4px** en el borde izquierdo de cada tarjeta de cita,
receta y notificación. Su color es el estado. Encima, el rótulo en versalitas.

```
┌─┬────────────────────────────────────────┐
│ │  CONFIRMADA                            │   ← riel verde, 4px
│ │                                        │
│ │  Dra. Alejandra Peña                   │
│ │  Cardiología · Presencial              │
│ │                                        │
│ │  ┌──────────┬──────────────────────┐   │
│ │  │ FECHA    │ HORA                 │   │   ← versalitas
│ │  │ 04 AGO   │ 08:30                │   │   ← mono, tabular
│ │  └──────────┴──────────────────────┘   │
└─┴────────────────────────────────────────┘
```

**Por qué funciona:**

1. **Es funcional.** El estado de la cita es el dato de mayor frecuencia de
   consulta en toda la app. Merece el canal visual más fuerte.
2. **Escanea vertical.** En la agenda del médico, 20 rieles en columna se leen
   como una sola imagen: dónde está lo amarillo, dónde lo rojo.
3. **Es la pestaña del expediente.** Cita literal del artefacto físico.
4. **Es barato.** Un `Container` de 4px. Cero costo de render, cero imágenes.

Todo lo demás en la pantalla se mantiene callado para que el riel cargue.

---

## 7. Movimiento

Poco y con motivo. El exceso de animación es de las señales más fuertes de
interfaz generada sin criterio.

| Momento | Duración | Curva |
|---|---|---|
| Riel cambia de color al cambiar estado | 240ms | `easeOutCubic` |
| Entrada escalonada de lista (primeros 6, 30ms de offset) | 200ms | `easeOut` |
| Transición de página | 180ms | `easeOutCubic` |
| Presión de botón | 90ms escala a 0.98 | `easeOut` |

**`MediaQuery.disableAnimations` se respeta.** Si está activo, todo cae a 0ms.
Sin excepciones.

Nada de parallax, nada de hero elaborado, nada de shimmer decorativo. El
skeleton de carga sí, porque comunica estado.

---

## 8. Voz

De este lado de la pantalla. Verbos planos, oración normal, cero relleno.

| No | Sí |
|---|---|
| "Enviar" | "Reservar cita" |
| "Ocurrió un error" | "Ese turno ya lo tomaron. Elige otra hora." |
| "No hay datos" | "Aún no tienes citas. Busca un médico para empezar." |
| "Autenticación fallida" | "Correo o contraseña incorrectos." |
| "Cargando..." | "Buscando turnos disponibles" |

**El nombre de la acción no cambia en el camino.** El botón dice "Reservar
cita" → el toast dice "Cita reservada". Nunca "Solicitud procesada".

**El error no pide disculpas y no es vago.** Dice qué pasó y qué hacer. El error
más importante de esta app es el 409 de RF-20 (dos pacientes, mismo turno): no
se reintenta en silencio, se refresca la grilla y se le dice al usuario en
lenguaje llano que escoja otra hora.

**El vacío invita.** Cada pantalla vacía lleva una acción, no un dibujo triste.

---

## 9. Piso de calidad

No negociable, no se anuncia:

- Objetivo táctil mínimo **48×48dp**
- Contraste **AA** en todo texto; **AAA** en datos clínicos (dosis, vitales)
- Foco de teclado visible en todo control (filete `cielo` de 2px)
- `Semantics` en todo ícono que actúe solo
- Escala de texto hasta **200%** sin romper layout ni recortar
- Todo estado de pantalla tiene diseño: carga, vacío, error, sin conexión
- Modo oscuro derivado de los mismos tokens, no una paleta aparte
