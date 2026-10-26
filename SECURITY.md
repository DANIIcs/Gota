# Security

Gota converts files that often come from other people, so crafted input files are the main risk.

## Reporting a vulnerability

Please **don't open a public issue**. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on this repository. You'll get an answer as soon as possible.

## What Gota does to stay safe

- **Your files never leave the Mac**, and there is no telemetry. Gota makes only two kinds of requests:
  - **Missing open fonts**: when a Word document uses an open-source font the Mac doesn't have (e.g. Poppins), Gota
    downloads its regular/bold/italic files once from Google Fonts' repository (`api.github.com/repos/google/fonts`,
    `raw.githubusercontent.com/google/fonts`) into `~/Library/Application Support/Gota/Fonts`. Only the font's name is
    sent. Names are restricted to letters, digits and spaces; only `.ttf`/`.otf` files from that repository are taken,
    at most 10 MB each and 12 MB per family, and each must parse as a font with macOS's own font parser. Turn it off in
    *Ajustes → Motores → Fuentes*.
  - The update check: when you click *Buscar actualizaciones…*, or at most once a day if you turn on *Buscar actualizaciones
  automáticamente* (off by default). It's an anonymous request to GitHub's public API for the latest release: nothing
  else is sent and no cookies are kept. Links (LibreOffice's download page, the source code) open in your
  browser when you click them.
- **No shell**: external tools (`afconvert`, `textutil`, `ditto`, `soffice`, `osascript`) run directly with
  file paths as separate arguments, so a file name can never become a command.
- **Never overwrites**: every result gets a new name next to the original.
- **Linked files are not embedded**: an HTML or Word document can point at any picture on the Mac
  (`file:///…`, `../`). Gota keeps only images from the document's own folder (built-in engine) and
  runs LibreOffice with `BlockUntrustedRefererLinks`, so a crafted file can't smuggle your files
  into a PDF you send back.
- **Size limits**: PDF pages exported as images are capped at 10 000 px, so a crafted page can't
  exhaust memory.

## Known limits

- Gota is not sandboxed yet (it has to write next to the files you drop). Decoding is done by
  macOS's own frameworks (ImageIO, PDFKit, AVFoundation, WebKit), which Apple keeps patched:
  keep macOS up to date.
- Optional Microsoft Word conversion opens the document in Word itself, with Word's own protections.
