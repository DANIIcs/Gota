# Gota 💧

**Un conversor de archivos nativo para macOS, con una rueda de Liquid Glass.**
Empieza a arrastrar un archivo en Finder, presiona **⇧** y suéltalo sobre un formato. Todo pasa en tu Mac.

| Tecla mientras arrastras | Rueda |
|---|---|
| **⇧ Shift** | Convertir — imágenes (PNG, JPEG, HEIC, TIFF, PDF), PDF → Word/imágenes/texto, video (MP4, MOV, solo audio), audio (M4A, WAV, AIFF), documentos (PDF, Word, texto, HTML) |
| **⌥ Option** | Herramientas — comprimir/reducir imágenes, unir/dividir/rotar PDF, comprimir video a 720p |
| **⌃ Control** | Acciones — AirDrop, ZIP, copiar ruta, mostrar en Finder |

## ¿Por qué otro más?

Hay varios conversores con rueda para Mac. El objetivo de Gota es **sentirse parte de macOS**:

- Hecho con **Liquid Glass de SwiftUI** (`GlassEffectContainer`, `glassEffect`): la gota central se divide en burbujas y
  se vuelve a juntar como un líquido, usando el material del propio sistema (modo claro/oscuro, accesibilidad y las
  próximas actualizaciones de diseño de macOS).
- **Primero lo nativo** (ImageIO, PDFKit, AVFoundation, afconvert): liviano, rápido y con aceleración por hardware.
- **Word → PDF sin instalar nada**: por defecto usa el motor de texto de macOS, LibreOffice si está instalado y Microsoft
  Word (formato exacto) si lo activas en Ajustes, detrás de una interfaz de motores intercambiables (ver [docs/MOTORES.md](docs/MOTORES.md)).
- **Privado**: sin red, sin telemetría, nunca sobrescribe tus archivos.

## Requisitos

macOS 26 o superior. Para compilar: Xcode 26+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen
open Gota.xcodeproj   # luego ⌘R
```

Guía completa paso a paso: [docs/GUIA.md](docs/GUIA.md).

## Estado

Prototipo temprano (0.1). Las contribuciones son bienvenidas: mira [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md).

## Licencia

[MIT](LICENSE)
