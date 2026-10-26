// Creates a clean folder of sample files for recording Gota's demo (see docs/media/README.md).
// Only macOS frameworks, no personal data. Usage: swift scripts/make-demo-files.swift [folder]
import AppKit
import ImageIO
import UniformTypeIdentifiers

let folder = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSHomeDirectory() + "/Desktop/Gota demo")
try? FileManager.default.removeItem(at: folder)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

func file(_ name: String) -> URL { folder.appendingPathComponent(name) }

// MARK: - Photos (HEIC, the format iPhones send): a sunset and mountains drawn with Core Graphics

func landscape(sky: [NSColor], sun: NSColor, hills: [NSColor], name: String) throws {
    let size = NSSize(width: 2400, height: 1600)
    let image = NSImage(size: size, flipped: false) { rect in
        NSGradient(colors: sky)!.draw(in: rect, angle: 90)
        sun.setFill()
        NSBezierPath(ovalIn: NSRect(x: 1500, y: 700, width: 360, height: 360)).fill()
        for (index, color) in hills.enumerated() {
            let base = CGFloat(index) * 160
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: 0))
            path.line(to: NSPoint(x: 0, y: 520 - base))
            for x in stride(from: 0, through: 2400, by: 300) {
                let peak = 620 - base + CGFloat((x / 300 + index) % 3) * 120
                path.line(to: NSPoint(x: CGFloat(x) + 150, y: peak))
                path.line(to: NSPoint(x: CGFloat(x) + 300, y: 480 - base))
            }
            path.line(to: NSPoint(x: 2400, y: 0))
            path.close()
            color.setFill()
            path.fill()
        }
        return true
    }
    let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let destination = CGImageDestinationCreateWithURL(file(name) as CFURL, UTType.heic.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1) }

try landscape(sky: [rgb(255, 140, 90), rgb(120, 70, 160)], sun: rgb(255, 214, 120),
              hills: [rgb(80, 50, 110), rgb(55, 35, 85), rgb(30, 20, 55)], name: "Atardecer.heic")
try landscape(sky: [rgb(160, 210, 255), rgb(60, 130, 220)], sun: rgb(255, 245, 200),
              hills: [rgb(110, 170, 120), rgb(70, 130, 90), rgb(40, 90, 60)], name: "Montañas.heic")

// MARK: - A report in Word (.docx) and its two-page PDF

let report = NSMutableAttributedString()
func add(_ text: String, size: CGFloat, bold: Bool = false, color: NSColor = .black) {
    let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    report.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
}
add("Informe trimestral\n", size: 26, bold: true)
add("Equipo de producto · Octubre\n\n", size: 12, color: .darkGray)
add("Resumen\n", size: 16, bold: true)
add("Las ventas crecieron un 24 % respecto al trimestre anterior. Los nuevos usuarios llegaron sobre todo por "
    + "recomendaciones, y la retención a 30 días subió al 68 %.\n\n", size: 12)
add("Próximos pasos\n", size: 16, bold: true)
add("• Lanzar la versión 2 en noviembre.\n• Abrir dos mercados nuevos.\n• Reducir el tiempo de respuesta del soporte.\n", size: 12)
add("\u{0C}Anexo\n", size: 16, bold: true)
add("Detalle de las métricas por región y por canal de adquisición.\n", size: 12)
let docx = try report.data(from: NSRange(location: 0, length: report.length),
                           documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
try docx.write(to: file("Informe trimestral.docx"))

var page = CGRect(x: 0, y: 0, width: 595, height: 842)
let pdf = CGContext(file("Presupuesto.pdf") as CFURL, mediaBox: &page, nil)!
for (index, title) in ["Presupuesto 2027", "Detalle por área"].enumerated() {
    pdf.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: false)
    (title as NSString).draw(at: NSPoint(x: 64, y: 740), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 28)])
    ("Página \(index + 1) de 2" as NSString).draw(at: NSPoint(x: 64, y: 710),
        withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.gray])
    for row in 0..<6 {
        rgb(240, 244, 250).setFill()
        NSRect(x: 64, y: 620 - CGFloat(row) * 48, width: 467, height: 36).fill()
        ("Partida \(row + 1 + index * 6)" as NSString).draw(at: NSPoint(x: 76, y: 630 - CGFloat(row) * 48),
            withAttributes: [.font: NSFont.systemFont(ofSize: 13)])
        ("\((row + 2) * 1_250) €" as NSString).draw(at: NSPoint(x: 440, y: 630 - CGFloat(row) * 48),
            withAttributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)])
    }
    pdf.endPDFPage()
}
pdf.closePDF()

// MARK: - Notes in Markdown

try """
# Ideas para el viaje

Lugares que **no hay que perderse** y lo que falta reservar.

- Machu Picchu, entrada a las 6:00
- Valle Sagrado
  - Pisac
  - Ollantaytambo

| Día | Plan |
|---|---|
| Lunes | Llegada y descanso |
| Martes | Tren a Aguas Calientes |

> Llevar abrigo: por la noche baja de 5 °C.
""".write(to: file("Notas del viaje.md"), atomically: true, encoding: .utf8)

// MARK: - A voice note (AIFF), spoken by macOS

let say = Process()
say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
say.arguments = ["-o", file("Nota de voz.aiff").path, "Hola, esta es una nota de voz para probar Gota."]
try say.run()
say.waitUntilExit()

print("Demo files in \(folder.path)")
