# Security

Gota converts files that often come from other people, so crafted input files are the main risk.

## Reporting a vulnerability

Please **don't open a public issue**. Use GitHub's private reporting instead:
**Security → Report a vulnerability** on this repository. You'll get an answer as soon as possible.

## What Gota does to stay safe

- **Fully local**: no network code, no telemetry. The only links (LibreOffice's download page, the source code)
  open in your browser when you click them.
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
