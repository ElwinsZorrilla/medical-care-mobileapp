# Gate de revisión de código

`code-reviewer-pro` vive en tu máquina (`C:\CssProject\ERP\ai-code-skills`), no
en este entorno. Lo que sigue es el **contrato** que debe cumplir para que el
hook lo pueda usar como puerta, más el rubro específico de Flutter que debe
aplicar. Si la skill ya define su propio formato de salida, adapta el `grep` del
hook; lo que no se negocia es que exista una línea final legible por máquina.

---

## 1. Contrato

**Entrada** — el revisor recibe:

| Campo | Valor |
|---|---|
| Diff | `git diff main...HEAD` |
| Alcance | fase `FXX` y su nombre |
| Requerimientos | los RF/RNF que la fase debía cubrir |
| Rubro | este archivo |
| Contrato de API | `docs/API_CONTRACT.md` |
| Diseño | `docs/DESIGN_SYSTEM.md` |

**Salida** — la **última línea**, exactamente uno de estos dos:

```
VERDICT: APPROVED
VERDICT: CHANGES_REQUESTED
```

Nada después. Sin punto final, sin markdown, sin comillas.

**Persistencia** — la salida completa se guarda en `.review/verdict`:

```bash
mkdir -p .review
# pegar la salida del revisor
$EDITOR .review/verdict
```

`.review/` está en `.gitignore`: es evidencia local, no artefacto del repo.

**Caducidad** — el hook compara el mtime de `.review/verdict` contra el del
archivo staged más reciente. Si tocaste código después de aprobar, el
`APPROVED` no vale. Esto cierra el hueco obvio: aprobar una versión y commitear
otra.

---

## 2. Severidades

| Nivel | Efecto | Definición |
|---|---|---|
| **BLOQUEANTE** | `CHANGES_REQUESTED` automático | Rompe seguridad, corrección o un requerimiento explícito |
| **MAYOR** | 3+ ⇒ `CHANGES_REQUESTED` | Deuda que va a doler en la fase siguiente |
| **MENOR** | no bloquea, se registra | Estilo, nombres, comentarios |

Un solo BLOQUEANTE tumba la fase. No se negocia "lo arreglo después".

---

## 3. Rubro

### 3.1 Seguridad — todo acá es BLOQUEANTE

- [ ] Ningún secreto, URL de producción, llave o token en el código. Solo
      `String.fromEnvironment` / `--dart-define`. (RNF-04)
- [ ] Tokens en `flutter_secure_storage`. **Nunca** en `SharedPreferences`.
      (RNF-03)
- [ ] El refresh de token es *single-flight*: N peticiones que reciben 401 en
      paralelo disparan **un** refresh, no N. Sin esto se agotan los refresh
      tokens y se saca al usuario. (RF-04)
- [ ] Ningún `print`/`debugPrint` que emita token, contraseña, cédula,
      diagnóstico o receta. Datos médicos en un log es una fuga. (RNF-06)
- [ ] El `userId` sale del token, nunca de un campo que el cliente pueda
      elegir. (RF-09)
- [ ] Cada pantalla de historial clínico verifica que el usuario sea el
      paciente titular o el médico tratante. La UI no confía en que el back lo
      filtre. (RNF-06)
- [ ] Certificado: sin `badCertificateCallback` que devuelva `true`.

### 3.2 Corrección

- [ ] **BLOQUEANTE** — Todo `DateTime` en modelos y payloads está en UTC. La
      conversión pasa solo por `AppTime`. Cero `DateTime.now()` suelto en
      lógica de negocio. (RNF-18)
- [ ] **BLOQUEANTE** — El 409 de reserva (RF-20) se maneja explícito: refresca
      la grilla y avisa. No reintenta en silencio, no muestra "error genérico".
- [ ] **MAYOR** — Toda llamada de red tiene sus cuatro estados en UI: cargando,
      vacío, error, sin conexión.
- [ ] **MAYOR** — Paginación real en listados (RF-15), no `limit: 1000`.
- [ ] **MAYOR** — `CitaEstado.fromApi` cubre todos los valores del back. Un
      estado no mapeado debe fallar ruidoso, no caer a un default silencioso.

### 3.3 Arquitectura

- [ ] **BLOQUEANTE** — Sin dependencias de importación entre features. Si
      `citas` importa de `chat`, lo compartido sube a `core`.
- [ ] **BLOQUEANTE** — La capa de presentación no importa `dio` ni toca
      `Response`. Solo habla con repositorios.
- [ ] **MAYOR** — Los errores de `dio` se traducen a `Failure` de dominio en la
      capa de datos. Una `DioException` no debe llegar a un widget.
- [ ] **MAYOR** — Un módulo por dominio de negocio. (RNF-11)

### 3.4 UI y diseño

- [ ] **BLOQUEANTE** — Cero colores, tamaños o espacios literales en widgets.
      Todo sale de `AppColors` / `Space` / `context.text`. Un `Color(0xFF...)`
      dentro de un widget es rechazo directo.
- [ ] **BLOQUEANTE** — Objetivo táctil ≥ 48×48dp en todo control.
- [ ] **MAYOR** — Contraste AA en texto; AAA en datos clínicos.
- [ ] **MAYOR** — El estado nunca se comunica solo por color: siempre color +
      glifo + etiqueta.
- [ ] **MAYOR** — El layout sobrevive `textScaleFactor` 2.0 sin recortes.
- [ ] **MAYOR** — Las animaciones pasan por `Motion.of(context, …)` para
      respetar movimiento reducido.
- [ ] **MENOR** — La copia sigue §8 del design system: verbos planos, el nombre
      de la acción no cambia entre botón y confirmación.

### 3.5 Pruebas — RNF-14

- [ ] **BLOQUEANTE** — Cada caso de uso nuevo trae prueba de camino feliz **y**
      de al menos un camino de error.
- [ ] **MAYOR** — Cobertura de la fase ≥ 70%.
- [ ] **MAYOR** — Prueba de widget para cada pantalla con lógica condicional.
- [ ] **MAYOR** — Hay una prueba que rompe si alguien mete un `DateTime` local
      en un payload. La regla más fácil de violar necesita su propia red.

### 3.6 Higiene

- [ ] **BLOQUEANTE** — Cero atribución de IA en código, comentarios o commits.
- [ ] **BLOQUEANTE** — `CLAUDE.md` y `.claude/` no están staged.
- [ ] **MAYOR** — `flutter analyze --fatal-infos` en cero. Sin `// ignore:`
      nuevos salvo justificación escrita en el mismo renglón.
- [ ] **MENOR** — Sin código muerto, sin `TODO` sin ticket.

---

## 4. Formato del hallazgo

```
[BLOQUEANTE] lib/features/citas/data/citas_repository.dart:64
  El payload manda `fecha.toIso8601String()` sobre un DateTime local.
  El servidor lo va a leer como UTC y la cita queda 4 horas corrida.
  → Usar AppTime.toUtc(...) antes de serializar. (RNF-18)
```

Tres partes obligatorias: **dónde**, **qué rompe en la práctica**, **qué
hacer**. Un hallazgo que solo dice "esto está mal" no sirve para cerrar el loop.

---

## 5. Antipatrones del propio revisor

Cosas que invalidan la revisión:

- **Aprobar por cansancio en la 3ra vuelta.** Si el mismo hallazgo vuelve tres
  veces, el problema es el diseño de la fase. Se para y se escala, no se aprueba.
- **Revisar el plan en vez del diff.** Se revisa lo que se va a commitear.
- **Solo hallazgos MENORES en una fase grande.** Si una fase de 40 archivos
  sale con tres comentarios de nombres, la revisión fue superficial. Se pide
  otra pasada enfocada en 3.1 y 3.2.
