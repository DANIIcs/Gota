## What and why / Qué y por qué

<!-- One feature or fix per PR. / Una funcionalidad o arreglo por PR. -->

## How it was tested / Cómo se probó

<!-- Tests added or run; for UI changes, a screenshot or short recording. -->

## Checklist

- [ ] Tests pass (`xcodebuild -scheme Gota -destination 'platform=macOS' test`)
- [ ] No new network requests, and files never leave the Mac
- [ ] Results never overwrite files (`Output.file`), external tools only via `Shell.run`
- [ ] New UI text is in `Localizable.xcstrings` with its English translation
