# Motores de conversión de documentos (Word → PDF)

Convertir un `.docx` a PDF **respetando el formato** es la parte más difícil de cualquier conversor:
el formato de Word no tiene una especificación de *maquetación*, solo de contenido. Cada motor que no es Word
"adivina" cómo Word reparte el texto en páginas, y ahí aparecen los saltos de página movidos, tablas corridas, etc.

## Qué dicen las mediciones (octubre 2026)

El proyecto **Oxi** publica un benchmark contra **Microsoft Word 365** real: renderiza cada página con Word y con
cada motor, y las compara con SSIM (similitud de imagen; 1.0 = idéntico). Usa conjuntos de documentos "ciegos"
que nunca se usaron para corregir el motor.

| Motor | Documentos en inglés (50) | Documentos en japonés (50) |
|---|---|---|
| **ONLYOFFICE** | **0.918** (el mejor) | — |
| Oxi (Rust + WebAssembly) | 0.874 | **0.857** |
| LibreOffice | 0.858 | 0.807 |

Fuente: https://oxi-dd65f4.gitlab.io/ (medido el 2026-10-02).

Conclusiones:

- **LibreOffice no es tan malo como parece**, pero sí es el peor de los tres y se nota en documentos complejos.
- **Los motores nuevos en Rust todavía no superan a ONLYOFFICE.** Y lo más importante: **ninguno exporta PDF todavía**:
  - **Oxi** — Rust/WASM, licencia MPL-2.0 (núcleo). Renderiza y edita en el navegador; el sitio no ofrece exportación a PDF.
  - **opendoc** — Rust, Apache-2.0. Su README dice que **no tiene exportación a PDF** y que no es "pixel-perfect Word-grade". Se compara contra LibreOffice, no contra Word. https://github.com/DePasqualeOrg/opendoc
  - **WordCraft** — Rust (egui), MIT/Apache. Es un *procesador de texto* (reemplazo de Word), no una librería de conversión; versión 0.x de octubre de 2026.
- **ONLYOFFICE** es el motor libre más fiel, pero su *Document Builder* gratuito agrega una **marca de agua** a los documentos generados (sin marca requiere licencia comercial), y el código fuente es AGPL-3.0. Hay que estudiar bien la licencia antes de integrarlo.
- **Microsoft Word** es, obviamente, 100% fiel: es el original.

## Estrategia de Gota

`Gota/Conversion/DocumentEngines.swift` define un protocolo `DocumentEngine` y una lista ordenada por fidelidad.
Gota usa **el primero que esté disponible y sepa leer el archivo**:

1. **Microsoft Word** y **Microsoft PowerPoint** (si están instalados **y** activas *Usar Microsoft Office* en
   Ajustes) — vía AppleScript. Formato exacto, porque son el original. macOS pide permiso para controlarlos y, como
   viven en un *sandbox*, pueden pedir acceso a la carpeta: por eso no van por defecto.
2. **docxide-pdf** (incluido en Gota, solo `.docx`) — motor en Rust hecho para imitar a Word. Usa Carlito/Caladea
   (clones libres de Calibri/Cambria, incluidos en Gota) cuando no hay fuentes de Office: lo propuso Gota y ya está en docxide.
   Sin instalar nada, sin ventanas, menos de 1 s y ~35 MB de RAM.
3. **LibreOffice** (gratis) — modo `--headless`. El resto de formatos de Office y las presentaciones.
4. **Keynote** / **Pages** (gratis, de Apple) — solo `.key` / `.pages` si falta LibreOffice. Abren su ventana.
5. **macOS (integrado)** — `DocumentRenderer`: lee el documento con `NSAttributedString` y lo pagina con TextKit, el
   mismo motor de TextEdit. Siempre disponible y sin permisos, pero el menos fiel. No lee `.pages` ni presentaciones.
6. *(futuro)* Oxi o BetterOffice cuando exporten PDF; ONLYOFFICE si su conversor gratuito deja de poner marca de agua.

Agregar un motor nuevo = crear un tipo que cumpla `DocumentEngine` y ponerlo en `DocumentEngines.all`.
Así, cuando los motores en Rust maduren, Gota los adopta sin tocar la rueda ni el catálogo.

## Medición propia (octubre 2026)

Para decidir el orden se midió en un Mac con macOS 27: 3 documentos `.docx` (informe con encabezados, listas,
encabezado/pie y salto de página; tablas con celdas combinadas y sombreadas más imagen; página horizontal a dos
columnas con varias fuentes) y 2 `.pptx` (plantilla básica; formas, imagen, cuadro de texto y tabla), generados con
`python-docx` / `python-pptx`. Cada motor exportó a PDF y cada página se comparó con la de **Word** o **PowerPoint**
con SSIM (1,0 = idéntico; una página que falta cuenta 0).

| Motor | vs Word (3 `.docx`) | vs PowerPoint (2 `.pptx`) | Notas |
|---|---|---|---|
| **LibreOffice** | **0,908** | **0,970** | Respeta columnas, tablas y páginas. El mejor sin Office. |
| Keynote | — | 0,945 | Muy cerca; desplaza un poco algunos textos dentro de formas. |
| Pages | 0,705 | — | **Ignora las dos columnas** y cambia tablas: no se usa. |
| macOS (integrado) | 0,599 | — | Ignora columnas, pierde estilos de título y **le faltó una página** al informe. |

### Por formato (motores sin ventanas, contra Word o PowerPoint)

Mismos documentos convertidos a cada formato (RTF/HTML/TXT con `textutil`, DOC/ODT/PPT/ODP con LibreOffice):

| Formato | LibreOffice | macOS | Motor elegido |
|---|---|---|---|
| `.docx` | 0,908 | 0,599 | **docxide: 0,948** (ver abajo) |
| `.doc` | **0,747** | 0,616 | LibreOffice |
| `.odt` | **0,888** | 0,597 | LibreOffice |
| `.rtf` | **0,820** | 0,759 | LibreOffice |
| `.html` | **0,743** | 0,600 | LibreOffice |
| `.txt` | 0,727 | **0,743** | macOS (empate técnico, y no arranca LibreOffice) |
| `.pptx` | **0,970** | — | LibreOffice (Keynote: 0,945) |
| `.ppt` | **0,960** | — | LibreOffice |
| `.odp` | **0,905** | — | LibreOffice |

### docxide-pdf (`.docx`)

Mismos 3 documentos contra Word (el de columnas, con un único `w:cols` como lo guarda Word):

| Variante | Informe | Tablas | Columnas | Media |
|---|---|---|---|---|
| docxide sin fuentes de Office (cae en Arial) | 0,825 | 0,745 | 0,786 | 0,785 |
| docxide con las fuentes de Office | 0,977 | 0,973 | 0,761 | 0,904 |
| **docxide + Carlito/Caladea (lo que usa Gota)** | 0,923 | 0,961 | 0,961 | **0,948** |
| LibreOffice | 0,941 | 0,944 | 0,841 | 0,909 |

Coincide con el benchmark publicado por su autor (174 documentos reales, contra Word): SSIM 84,8 frente a 68,0 de
LibreOffice, mejor en 141 de 174. Seguridad: no sigue enlaces a archivos externos (`DocxideTests`), no tiene código de
red (ninguna de sus 132 dependencias) y corre en un proceso aparte con tiempo límite.

`.key` y `.pages` no tienen referencia de Microsoft: su original es Keynote / Pages, que abren su ventana, así que van
después de LibreOffice y solo se usan si falta. La tabla vive en `DocumentEngines.ranking(forExtension:)`.

Conclusiones: Office es el único exacto; sin Office, **LibreOffice primero**, luego Keynote para presentaciones y el
motor de macOS solo como último recurso. Son documentos sintéticos con funciones estándar: con archivos reales más
complejos (SmartArt, gráficos, fuentes incrustadas) LibreOffice baja (ver el benchmark de arriba: 0,858 contra Word).

### Idea a futuro: un "benchmark" propio

Como Oxi, se puede agregar un comando de desarrollo que convierta una carpeta de `.docx` con cada motor disponible
y compare el resultado con el PDF de Word (SSIM por página). Eso te deja **decidir con datos** qué motor priorizar.

## Notas técnicas

- **Detección del arrastre**: Gota no usa *event taps* ni pide Accesibilidad. Observa los clics globales y, mientras el
  botón está apretado, mira el `NSPasteboard(name: .drag)`. Las teclas se leen con `NSEvent.modifierFlags`.
  Si en alguna versión de macOS las teclas no se detectan sin permiso, la solución es pedir *Monitoreo de entrada*.
- **Soltar sobre la rueda**: la rueda es un `NSPanel` transparente. Los píxeles 100% transparentes dejan pasar el clic y el
  "drop" a la ventana de abajo (¡podría mover el archivo en Finder!), por eso hay un disco casi invisible (opacidad 1%)
  detrás de las burbujas. Si en pruebas un "drop" se cuela igual, la alternativa es `panel.ignoresMouseEvents = false`
  y recortar el panel al tamaño exacto del disco.
- **El vidrio en un panel que nunca se activa**: el panel no se vuelve ventana "activa", así que macOS podría dibujar el
  vidrio en su variante inactiva (más plana). Si se ve así, el plan B es poner un `NSGlassEffectView` como `contentView`
  del panel y el `NSHostingView` dentro.
- **Shift + clic**: si ya tienes ⇧ apretado al empezar a arrastrar (por ejemplo, tras seleccionar varios archivos con
  ⇧-clic), la rueda se abre de inmediato. ⌃ + clic en Finder es clic derecho, así que ⌃ funciona solo si lo presionas
  después de empezar a arrastrar. Los archivos "prometidos" (arrastrados desde Fotos o Mail) todavía no se soportan.
