# Gota 💧

**A native macOS file converter with a Liquid Glass wheel.**
Start dragging a file in Finder, hold **⇧**, and drop it on a format. Everything happens on your Mac.

*[Leer en español](README.es.md)*

| Key while dragging | Wheel |
|---|---|
| **⇧ Shift** | Convert — images (PNG, JPEG, HEIC, TIFF, PDF), PDF → Word/images/text, video (MP4, MOV, audio only), audio (M4A, WAV, AIFF), documents (PDF, Word, text, HTML) |
| **⌥ Option** | Tools — compress / resize images, merge / split / rotate PDFs, compress video to 720p |
| **⌃ Control** | Actions — AirDrop, ZIP, copy path, reveal in Finder |

## Why another one?

There are several radial converters for the Mac. Gota's goal is to **feel like part of macOS**:

- Built with **SwiftUI's Liquid Glass** (`GlassEffectContainer`, `glassEffect`): the central drop splits into bubbles and
  merges back like liquid, and it follows the system's own material — light/dark mode, accessibility settings and
  future macOS design updates.
- **Native frameworks first** (ImageIO, PDFKit, AVFoundation, afconvert): small, fast, hardware accelerated.
- **Word → PDF with nothing to install**: macOS's own text engine by default, LibreOffice when installed, and Microsoft
  Word (exact layout) if you turn it on in Settings, behind a pluggable engine interface (see [docs/MOTORES.md](docs/MOTORES.md)).
- **Several files at once**: each on its own (*PDF*) or all in one file (*PDF unido*, *Word unido*, *Texto unido*, *ZIP*).
- **Private**: no network, no telemetry, never overwrites your files.

## Requirements

macOS 26 or later. To build: Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen
open Gota.xcodeproj   # then ⌘R
```

Full setup guide (Spanish): [docs/GUIA.md](docs/GUIA.md).

## Status

Early prototype (0.1). Contributions welcome — see [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md) to add a format.

## License

[MIT](LICENSE)
