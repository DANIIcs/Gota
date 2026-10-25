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
Gota usa **el primero que esté instalado**:

1. **Microsoft Word** (si está instalado) — vía AppleScript. Formato exacto.
2. **LibreOffice** (gratis) — modo `--headless`.
3. *(futuro)* ONLYOFFICE, Oxi u opendoc cuando exporten PDF.

Agregar un motor nuevo = crear un tipo que cumpla `DocumentEngine` y ponerlo en `DocumentEngines.all`.
Así, cuando los motores en Rust maduren, Gota los adopta sin tocar la rueda ni el catálogo.

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
