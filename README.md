# Gota 💧

**A native macOS file converter with a Liquid Glass wheel.**
Start dragging a file in Finder, hold **⇧**, and drop it on a format. Everything happens on your Mac.

*[Leer en español](README.es.md)*

| Key while dragging | Wheel |
|---|---|
| **⇧ Shift** | Convert — images (PNG, JPEG, HEIC, TIFF, PDF), PDF → Word/images/text, video (MP4, MOV, audio only), audio (M4A, WAV, AIFF), documents (PDF, Word, text, HTML), presentations — PowerPoint, Keynote (PDF, PNG/JPEG per slide) |
| **⌥ Option** | Tools — compress / resize images, merge / split / rotate PDFs, compress video to 720p |
| **⌃ Control** | Actions — AirDrop, ZIP, copy path, reveal in Finder |

## Download

**[⬇︎ Download the latest release](https://github.com/DANIIcs/Gota/releases/latest)** — macOS 26 or later, Apple Silicon or Intel.

1. Download `Gota-X.Y.Z.zip` under *Assets*, unzip it and move **Gota.app** to **Applications**.
2. The first time, macOS blocks it because it isn't notarized by Apple yet: go to **System Settings → Privacy &
   Security → Open Anyway**. You only do this once.
3. Look for the 💧 in the menu bar.

Full guide (verifying the download, permissions, updating, uninstalling) — Spanish: **[docs/INSTALAR.md](docs/INSTALAR.md)**.

## Why another one?

There are several radial converters for the Mac. Gota's goal is to **feel like part of macOS**:

- Built with **SwiftUI's Liquid Glass** (`GlassEffectContainer`, `glassEffect`): the central drop splits into bubbles and
  merges back like liquid, and it follows the system's own material — light/dark mode, accessibility settings and
  future macOS design updates.
- **Native frameworks first** (ImageIO, PDFKit, AVFoundation, afconvert): small, fast, hardware accelerated.
- **The most faithful engine per format, measured against Word and PowerPoint**: a bundled engine for `.docx`
  ([docxide-pdf](https://github.com/sverrejb/docxide-pdf), nothing to install), LibreOffice for other Office files when
  installed, macOS for plain text, and Microsoft Office (exact layout) if you turn it on (see [docs/MOTORES.md](docs/MOTORES.md)).
- **Several files at once**: each on its own (*PDF*) or all in one file (*PDF unido*, *Word unido*, *Texto unido*, *ZIP*).
- **Private**: conversions never go online, no telemetry, never overwrites your files. *Check for updates* asks GitHub
  only when you click it.

## Build from source

macOS 26 or later, Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen
open Gota.xcodeproj   # then ⌘R
```

Full setup guide (Spanish): [docs/GUIA.md](docs/GUIA.md). To publish a release: `scripts/release.sh --publish`.

## Security

Everything runs locally and Gota never connects to the internet. To report a vulnerability privately: [SECURITY.md](SECURITY.md).

## Status

Early prototype (0.1). Contributions welcome — see [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md) to add a format.

## License

[MIT](LICENSE)
