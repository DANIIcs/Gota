# Cómo funciona Gota por dentro: los motores de conversión

Esta guía explica qué hace Gota cuando sueltas un archivo en la rueda, cómo elige con qué convertirlo y cómo llega
dentro de la app el motor propio de Word. Para instalar Gota, ver [INSTALAR.md](INSTALAR.md); para compilarla,
[GUIA.md](GUIA.md); las mediciones completas están en [MOTORES.md](MOTORES.md).

## 1. Qué es un motor

Un motor es **el programa que hace la conversión de verdad**. Gota no convierte un Word a PDF por sí misma: sabe
**elegir** el mejor motor para cada archivo y **dirigirlo**. Hay tres tipos:

| Tipo | Ejemplos | Dónde vive |
|---|---|---|
| **De macOS** | ImageIO (imágenes), PDFKit (PDF), AVFoundation (vídeo), `afconvert` (audio), `textutil` y TextKit (texto) | Ya vienen en todo Mac |
| **Incluido en Gota** | **docxide-pdf** (Word `.docx`) | Dentro de `Gota.app` |
| **Externos, si los tienes** | LibreOffice, Microsoft Office, Keynote, Pages | Apps que instala el usuario |

## 2. Qué pasa al soltar un archivo

```
Sueltas informe.docx en la burbuja "PDF"
        │
        ▼
1. ¿Qué es?          FileKind: por la extensión, .docx es un documento
2. ¿Quién lo hace?   DocumentEngines.ranking: la fila de .docx, primer motor disponible
                       Office (solo si está activado) → docxide ✅ → LibreOffice → macOS
3. Lo ejecuta        Shell.run: lanza el motor como programa aparte, sin shell
                       docxide-pdf informe.docx informe.pdf   (+ fuentes Carlito/Caladea de Gota)
4. Lo comprueba      Output.requireCreated: ¿existe el PDF? Si no → "no pudo convertir «informe.docx»"
5. Avisa             JobRunner: notificación "Listo", sonido y "Recientes" en el menú
```

**Cada motor externo corre como un proceso aparte**, nunca dentro de Gota:

- si un archivo raro cuelga o rompe el motor, **Gota no se cae**;
- cada conversión tiene **tiempo límite** (`Shell.run(timeout:)`);
- al terminar, el motor **se cierra** y libera su memoria: LibreOffice no se queda abierto;
- los archivos se pasan como argumentos separados, **nunca** dentro de un comando de texto, así que un nombre de archivo
  no puede convertirse en una orden.

El resultado se guarda **junto al original y nunca lo sobrescribe** (`Output.file`): `informe.pdf`, `informe 2.pdf`…

## 3. La tabla: qué motor para cada formato

Vive en `Gota/Conversion/DocumentEngines.swift` → `DocumentEngines.ranking(forExtension:)` y sale de medir cada motor
contra el PDF de Word o PowerPoint (SSIM, 1,0 = idéntico):

| Formato | 1.º (si activas Office) | 2.º, sin ventanas | Después |
|---|---|---|---|
| `.docx` | Word | **docxide** (0,948) | LibreOffice → macOS |
| `.doc` `.odt` `.rtf` `.html` | Word | **LibreOffice** | macOS |
| `.txt` | Word | **macOS** | LibreOffice |
| `.md` (Markdown) | — | **macOS** (lector de Markdown de Foundation → HTML con estilo → TextKit) | — |
| `.pptx` `.ppt` `.odp` | PowerPoint | **LibreOffice** | Keynote |
| `.key` / `.pages` | — | **LibreOffice** | Keynote / Pages |

Tres niveles, siempre en este orden:

1. **Microsoft Office**: exacto, pero abre sus apps y pide acceso a las carpetas, así que solo si el usuario lo activa
   (*Ajustes → Motores → Avanzado*).
2. **Motores sin ventanas**, ordenados por su puntuación en ese formato.
3. **Keynote y Pages**, que abren su ventana: solo si nada de lo anterior puede leer el archivo.

Si un motor nuevo gana en un formato, basta con **moverlo arriba en su fila**.

## 4. Cómo llega docxide dentro de Gota

docxide-pdf está escrito en **Rust** (licencia Apache-2.0). Se compila **solo al publicar Gota**: quien la descarga
recibe el motor ya compilado y no necesita Rust ni nada más.

```
Engines/
├── docxide/
│   ├── REVISION              versión exacta de docxide que usa Gota (fijada)
│   ├── gota.patch            actualizaciones de seguridad de sus dependencias
│   ├── build.sh              descarga esa versión, aplica el parche y compila para Apple Silicon + Intel
│   └── LICENSE
├── Fonts/                    Carlito (OFL) y Caladea (Apache-2.0), versiones originales; ver SOURCE.md
└── Licenses/                 licencias de todo lo anterior, que viajan dentro de la app
```

1. `Engines/docxide/build.sh` deja el binario en `build/engines/docxide-pdf` (no se sube a git).
2. Al compilar Gota, una fase de Xcode (en `project.yml`) lo copia a `Gota.app/Contents/MacOS/` y lo firma.
3. `Engines/Fonts` y `Engines/Licenses` se copian a `Gota.app/Contents/Resources/`.
4. Al convertir, `DocxideEngine` lo lanza con `DOCXIDE_FONTS` apuntando a esas fuentes y a las descargadas.

**Fuentes que faltan** (`FontResolver`). Antes de convertir, Gota lee qué fuentes usa el documento. Si falta una
**libre** (Poppins, Montserrat…), la descarga una vez de Google Fonts, solo los estilos normal/negrita/cursiva (~0,7 MB),
a `~/Library/Application Support/Gota/Fonts`. Si falta una de pago (Aptos) y se usa en el texto, avisa de que el PDF
puede cambiar. Medido con un documento real en Poppins: 0,497 y 7 de 9 páginas sin la fuente, 0,859 y 9 de 9 con ella.

**¿Por qué Carlito y Caladea?** En un Mac sin Office no existen Calibri ni Cambria, las fuentes por defecto de Word, y
docxide las cambiaba por Arial: todo el texto se descolocaba (0,785 contra Word). Con sus clones de medidas idénticas
sube a 0,948, por encima de LibreOffice (0,909). Gota lo propuso a docxide y ya viene de serie
([PR #141](https://github.com/sverrejb/docxide-pdf/pull/141)), pero docxide no trae las fuentes: por eso siguen
incluidas en Gota. El parche que queda solo actualiza dependencias con avisos de seguridad (zip 8.1 → 9 y otras).

**Compilar sin Rust:** Gota compila igual, solo que sin docxide; los `.docx` usan entonces LibreOffice. El script de
publicación, en cambio, se niega a empaquetar una versión sin el motor.

## 5. Publicar una versión

```bash
scripts/release.sh --publish
```

1. Compila docxide (`Engines/docxide/build.sh`).
2. Compila Gota en modo Release, universal (Apple Silicon + Intel).
3. Verifica que el motor está dentro y que la firma es válida.
4. Crea `dist/Gota-X.Y.Z.zip` y su huella SHA-256.
5. Etiqueta `vX.Y.Z` y lo publica en GitHub Releases con `docs/RELEASE-NOTES.md`.

Los usuarios se enteran con **💧 → Buscar actualizaciones…**, que pregunta a GitHub por la última versión solo cuando
lo pulsan.

## 6. Añadir un motor nuevo

1. Crea un tipo que cumpla `DocumentEngine` en `DocumentEngines.swift`: `isAvailable` (¿está instalado o incluido?),
   `canConvert` (¿qué formatos lee?) y `convertToPDF` (cómo lo lanza, siempre con `Shell.run`).
2. **Mídelo** contra Word o PowerPoint con los mismos documentos y el mismo método (ver [MOTORES.md](MOTORES.md)).
3. Colócalo en `ranking(forExtension:)` donde diga su puntuación.
4. Añade sus tests, incluido uno de **seguridad**: un documento que enlaza a un archivo privado del Mac no debe acabar
   dentro del PDF (ver `SecurityTests` y `DocxideTests`).
5. Si va incluido en la app, su licencia va en `Engines/Licenses/`.
