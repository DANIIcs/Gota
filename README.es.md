# Gota 💧

**Un conversor de archivos nativo para macOS, con una rueda de Liquid Glass.**
Empieza a arrastrar un archivo en Finder, presiona **⇧** y suéltalo sobre un formato. Todo pasa en tu Mac.

| Tecla mientras arrastras | Rueda |
|---|---|
| **⇧ Shift** | Convertir — imágenes (PNG, JPEG, HEIC, TIFF, PDF), PDF → Word/imágenes/texto, video (MP4, MOV, solo audio), audio (M4A, WAV, AIFF), documentos (PDF, Word, texto, HTML), presentaciones — PowerPoint, Keynote (PDF, PNG/JPEG por diapositiva) |
| **⌥ Option** | Herramientas — comprimir/reducir imágenes, unir/dividir/rotar PDF, comprimir video a 720p |
| **⌃ Control** | Acciones — AirDrop, ZIP, copiar ruta, mostrar en Finder |

## Descargar

**[⬇︎ Descargar la última versión](https://github.com/DANIIcs/Gota/releases/latest)** — macOS 26 o posterior, Apple Silicon o Intel.

1. Descarga `Gota-X.Y.Z.zip` en *Assets*, descomprímelo y mueve **Gota.app** a **Aplicaciones**.
2. La primera vez macOS la bloquea porque aún no está notarizada por Apple: ve a **Ajustes del Sistema → Privacidad y
   seguridad → Abrir igualmente**. Solo se hace una vez.
3. Busca la 💧 en la barra de menú.

Guía completa (comprobar la descarga, permisos, actualizar, desinstalar): **[docs/INSTALAR.md](docs/INSTALAR.md)**.

## ¿Por qué otro más?

Hay varios conversores con rueda para Mac. El objetivo de Gota es **sentirse parte de macOS**:

- Hecho con **Liquid Glass de SwiftUI** (`GlassEffectContainer`, `glassEffect`): la gota central se divide en burbujas y
  se vuelve a juntar como un líquido, usando el material del propio sistema (modo claro/oscuro, accesibilidad y las
  próximas actualizaciones de diseño de macOS).
- **Primero lo nativo** (ImageIO, PDFKit, AVFoundation, afconvert): liviano, rápido y con aceleración por hardware.
- **El motor más fiel para cada formato, medido contra Word y PowerPoint**: un motor incluido para `.docx`
  ([docxide-pdf](https://github.com/sverrejb/docxide-pdf), sin instalar nada), LibreOffice para el resto de Office si
  está instalado, macOS para texto plano y Microsoft Office (formato exacto) si lo activas (ver [docs/MOTORES.md](docs/MOTORES.md)).
- **Varios archivos a la vez**: cada uno por separado (*PDF*) o todos en uno (*PDF unido*, *Word unido*, *Texto unido*, *ZIP*).
- **Privado**: las conversiones nunca usan internet, sin telemetría, nunca sobrescribe tus archivos. *Buscar
  actualizaciones* pregunta a GitHub solo cuando lo pulsas.

## Compilar desde el código

macOS 26 o superior, Xcode 26+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen
open Gota.xcodeproj   # luego ⌘R
```

Guía completa paso a paso: [docs/GUIA.md](docs/GUIA.md). Cómo funcionan los motores por dentro: [docs/COMO-FUNCIONA.md](docs/COMO-FUNCIONA.md). Para publicar una versión: `scripts/release.sh --publish`.

## Seguridad

Todo es local y Gota no se conecta a internet. Para reportar una vulnerabilidad en privado: [SECURITY.md](SECURITY.md).

## Estado

Prototipo temprano (0.1). Las contribuciones son bienvenidas: mira [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md).

## Licencia

[MIT](LICENSE)
