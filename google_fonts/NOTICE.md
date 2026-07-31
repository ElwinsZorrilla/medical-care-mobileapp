# Tipografías empaquetadas

Las tres familias del sistema viajan **dentro del APK**, no se descargan.

## Por qué empaquetadas y no por red

`google_fonts` por defecto baja las tipografías por HTTP la primera vez que se
usan. Para el usuario que describe `docs/DESIGN_SYSTEM.md` §1 —Android de gama
media, a veces con datos móviles lentos— eso significa tres cosas malas:

1. El primer arranque muestra tipografía de respaldo hasta que termine la
   descarga. La app se ve distinta la primera vez que todas las siguientes.
2. Sin conexión en el primer arranque, **nunca** llega la tipografía de marca.
3. Cada usuario paga la descarga de algo que jamás cambia.

Empaquetadas cuestan **576 KB** en el APK y eliminan el problema entero. Con
`GoogleFonts.config.allowRuntimeFetching = false` la app además **falla ruidoso**
si alguien usa una familia o un peso que no está acá, en vez de irse a la red
en silencio.

También es lo que hace los goldens posibles: un golden que depende de una
descarga no es determinista.

## Pesos incluidos

Solo los que el sistema usa. Agregar un peso a `AppTextStyles` obliga a
agregar su `.ttf` acá.

| Archivo | Familia | Peso | Uso |
|---|---|---|---|
| `Archivo-SemiBold.ttf` | Archivo | 600 | `display`, `title` |
| `PublicSans-Regular.ttf` | Public Sans | 400 | `body`, `caption` |
| `PublicSans-SemiBold.ttf` | Public Sans | 600 | `heading`, `bodyStrong`, `label` |
| `IBMPlexMono-Medium.ttf` | IBM Plex Mono | 500 | `data` |
| `IBMPlexMono-SemiBold.ttf` | IBM Plex Mono | 600 | `dataLg` |

## Licencias

Las tres son **SIL Open Font License 1.1**, que permite redistribuirlas dentro
de una aplicación.

| Familia | Autoría | Origen |
|---|---|---|
| Archivo | Omnibus-Type | <https://github.com/Omnibus-Type/Archivo> |
| Public Sans | U.S. Web Design System (dominio público / OFL) | <https://public-sans.digital.gov> |
| IBM Plex Mono | IBM Corp. | <https://github.com/IBM/plex> |

Texto de la licencia: <https://scripts.sil.org/OFL>
