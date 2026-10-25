# Agregar una conversión

Todo lo que aparece en la rueda sale de `Gota/Conversion/Catalog.swift`.

1. Elige el modo: `convert` (⇧), `tools` (⌥) o `general` (⌃, para cualquier archivo).
2. Elige el tipo de archivo (`FileKind`: image, pdf, video, audio, document).
3. Agrega un `WheelAction`:

```swift
// Una salida por archivo:
.eachFile(id: "image-webp", title: "WebP", symbol: "photo") { file in
    try await MiConversor.aWebP(file)   // devuelve la URL del archivo creado
}

// Todos los archivos juntos (por ejemplo, unir):
WheelAction(id: "pdf-merge", title: "Unir", symbol: "doc.on.doc") { files in
    [try PDFTools.merge(files)]
}
```

Reglas:

- **Nunca sobrescribir**: usa `Output.file(for:extension:suffix:)`, que guarda junto al original y numera si ya existe.
- **Sin shell**: para herramientas externas usa `Shell.run(ejecutable, [argumentos])`. Nunca armes un comando con texto.
- **Primero lo nativo de macOS** (ImageIO, PDFKit, AVFoundation, Vision, `afconvert`, `textutil`). Herramientas externas
  (ffmpeg, pandoc) solo como opcionales, detectando si están instaladas.
- `symbol` es un nombre de **SF Symbols** (app gratuita de Apple para buscarlos).
- Máximo 8 burbujas por modo (`WheelLayout.maxItems`).
- Agrega un test en `GotaTests/CatalogTests.swift` si cambias qué opciones aparecen.
