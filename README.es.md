# Gota 💧

**Un conversor de archivos para macOS, gratis y de código abierto, con una rueda de Liquid Glass.**
Empieza a arrastrar un archivo en Finder, mantén **⇧** y suéltalo sobre un formato. Tus archivos nunca salen de tu Mac.

*[Read in English](README.md)*

<!-- Demo: graba 10–15 s con ⌘⇧5 (arrastra una foto, mantén ⇧, suelta en PNG), guárdalo como docs/media/demo.gif y
     cambia este comentario por:  <p align="center"><img src="docs/media/demo.gif" width="720" alt="La rueda de Gota"></p> -->

| Tecla mientras arrastras | Rueda |
|---|---|
| **⇧ Shift** | **Convertir** — imágenes (PNG, JPEG, HEIC, TIFF, PDF), PDF → Word / imágenes / texto, documentos de Word y de texto → PDF / Word / texto / HTML, PowerPoint y Keynote → PDF / PNG / JPEG por diapositiva, vídeo (MP4, MOV, solo audio), audio (M4A, WAV, AIFF) |
| **⌥ Option** | **Herramientas** — comprimir / reducir imágenes, unir / dividir / rotar PDF, comprimir vídeo a 720p |
| **⌃ Control** | **Acciones** — AirDrop, ZIP, copiar ruta, mostrar en Finder |

Con varios archivos, cada conversión viene en dos versiones: un resultado por archivo, o todo en uno (*PDF unido*,
*Word unido*, *ZIP*…).

## Descargar

**[⬇︎ Descargar la última versión](https://github.com/DANIIcs/Gota/releases/latest)** — macOS 26 o posterior, Apple Silicon o Intel.

1. Descarga `Gota-X.Y.Z.zip` en *Assets*, descomprímelo y mueve **Gota.app** a **Aplicaciones**.
2. La primera vez macOS la bloquea porque aún no está notarizada por Apple: ve a **Ajustes del Sistema → Privacidad y
   seguridad → Abrir igualmente**. Solo se hace una vez.
3. Busca la 💧 en la barra de menú. Para actualizar: 💧 → *Buscar actualizaciones…*.

Guía completa (comprobar la descarga, permisos, actualizar, desinstalar): **[docs/INSTALAR.md](docs/INSTALAR.md)**.

## ¿Por qué otro más?

Ya existen conversores con rueda para Mac (Gota se inspira en ellos). El objetivo de Gota es ser **gratis, abierto y
sentirse parte de macOS**:

- Hecho con **Liquid Glass de SwiftUI**: la gota central se divide en burbujas y se vuelve a juntar como un líquido, con
  el material del propio sistema, así que sigue el modo claro/oscuro, la accesibilidad y los cambios de diseño de macOS.
- **Primero lo nativo** (ImageIO, PDFKit, AVFoundation, afconvert): liviano, rápido y con aceleración por hardware.
- **El motor más fiel para cada formato, medido contra Word y PowerPoint** ([docs/MOTORES.md](docs/MOTORES.md)): un motor
  incluido para `.docx` ([docxide-pdf](https://github.com/sverrejb/docxide-pdf), sin instalar nada), LibreOffice para el
  resto de Office si está instalado, macOS para texto plano y Microsoft Office (formato exacto) si lo activas.
- **Fuentes que faltan**: si un Word usa una fuente libre que no tienes (Poppins, Montserrat…), Gota la consigue una vez
  para que el PDF salga igual que en Word, y te avisa si falta una de pago.
- **Ajustes como los de Ajustes del Sistema**, un icono que sigue tu estilo de iconos y el sonido de alerta de tu Mac.

## Privacidad

**Tus archivos nunca salen de tu Mac.** Todas las conversiones son locales y no hay telemetría. Gota solo se conecta a
internet en dos casos, explicados en [SECURITY.md](SECURITY.md):

- **Buscar actualizaciones**: cuando pulsas *Buscar actualizaciones…*, o una vez al día si lo activas (viene apagado).
- **Fuentes libres que faltan**: cuando un Word las necesita, Gota las descarga una vez de Google Fonts. Solo se envía
  el nombre de la fuente, nunca tu documento. Se apaga en *Ajustes → Motores → Fuentes*.

Los resultados se guardan junto al original y nunca sobrescriben nada.

## Compilar desde el código

macOS 26 o superior, Xcode 26+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen). [Rust](https://rustup.rs) es
opcional: compila el motor de `.docx` incluido; sin él, los `.docx` usan LibreOffice.

```bash
brew install xcodegen
Engines/docxide/build.sh   # opcional, necesita Rust
xcodegen
open Gota.xcodeproj        # luego ⌘R
```

Guías: puesta en marcha [docs/GUIA.md](docs/GUIA.md), cómo funcionan los motores [docs/COMO-FUNCIONA.md](docs/COMO-FUNCIONA.md),
agregar un formato [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md). Publicar una versión: `scripts/release.sh --publish`.

## Seguridad

Un archivo malicioso no puede colar otros archivos de tu Mac en un resultado, los documentos desmesurados se rechazan, y
cada cambio pasa por búsqueda de secretos, análisis estático, auditoría de dependencias y los tests. Para reportar una
vulnerabilidad en privado: [SECURITY.md](SECURITY.md).

## Estado

Versión 0.2: se puede usar a diario, pero aún es joven. Bugs e ideas, bienvenidos en
[Issues](https://github.com/DANIIcs/Gota/issues).

## Créditos

[docxide-pdf](https://github.com/sverrejb/docxide-pdf) (Apache-2.0) convierte los `.docx`; Carlito (OFL) y Caladea
(Apache-2.0) sustituyen a Calibri y Cambria. Las licencias viajan dentro de la app ([Engines/Licenses](Engines/Licenses)).

## Licencia

[MIT](LICENSE)
