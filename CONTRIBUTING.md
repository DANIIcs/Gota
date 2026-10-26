# Contributing to Gota

Thanks for helping! Bugs, ideas and pull requests are all welcome. Issues and PRs can be in English or Spanish
(*se aceptan en español o inglés*).

## Reporting a bug or asking for a feature

Open an [issue](https://github.com/DANIIcs/Gota/issues/new/choose) and pick a template. For conversion bugs, the most
useful things are: your macOS version, the file type, which engine converted it (*Ajustes → Motores*) and, if you can
share it, a sample file **without personal data**.

Security problems go through private reporting instead, never a public issue: see [SECURITY.md](SECURITY.md).

## Building

macOS 26+, Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Rust is optional (it builds the bundled
`.docx` engine).

```bash
brew install xcodegen
Engines/docxide/build.sh   # optional, needs Rust
xcodegen                   # after adding/removing files or editing project.yml
open Gota.xcodeproj        # ⌘R to run, ⌘U to test
```

The `.xcodeproj`, `Info.plist` and entitlements are generated: edit `project.yml` instead. Step-by-step guide
(Spanish): [docs/GUIA.md](docs/GUIA.md). How the engines work: [docs/COMO-FUNCIONA.md](docs/COMO-FUNCIONA.md). Adding a
format: [docs/AGREGAR-CONVERSION.md](docs/AGREGAR-CONVERSION.md).

## Rules that keep Gota safe and native

- **Files never leave the Mac.** No new network requests, no telemetry. The only exceptions are the update check and
  open-font downloads (see [SECURITY.md](SECURITY.md)).
- **Never overwrite** the user's files: results go through `Output.file(for:extension:suffix:)`.
- **External tools** only through `Shell.run(executable, [args])`: no shell strings, no `sh -c`.
- **Untrusted input**: files come from other people. A conversion must never embed files a document links to, and sizes
  read from a file are capped. Each new parser or engine needs a case in `SecurityTests`.
- **Native first**: system frameworks (ImageIO, PDFKit, AVFoundation…) and system UI (Liquid Glass, SF Symbols) before
  third-party code. Optional external engines are detected, never required.
- **UI text** is localized: Spanish source, English translation in `Gota/Resources/Localizable.xcstrings`. Non-SwiftUI
  strings use `String(localized:)`.
- Add **unit tests** for logic changes (catalog, geometry, naming).

## Pull requests

1. Fork, create a branch, keep the change focused (one feature or fix).
2. Run the tests (`xcodebuild -scheme Gota -destination 'platform=macOS' test`) and, for UI changes, describe or show
   what changed (a screenshot or short recording helps a lot).
3. CI runs secret scanning, static analysis, a dependency audit and the tests; all must pass before merging.

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE) and that you follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
