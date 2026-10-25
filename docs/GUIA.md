# Guía: de cero a Gota corriendo en tu Mac

Esta guía asume que nunca usaste Xcode ni Swift. Si vienes de Python, Java o React, piensa así:

| Lo que conoces | En Mac/Swift |
|---|---|
| VS Code / IntelliJ | **Xcode** (editor + compilador + simulador + depurador, todo en uno) |
| React (componentes, estado) | **SwiftUI**: vistas declarativas, `@State`, `@Published` ≈ `useState` |
| `package.json` / `pom.xml` | `project.yml` (aquí, con XcodeGen) y Swift Package Manager |
| `npm run dev` | **⌘R** en Xcode (Run) |
| `npm test` / `pytest` | **⌘U** en Xcode (Test) |

---

## 1. Instalar lo necesario (una sola vez)

1. **Xcode 26 o superior** desde la Mac App Store (pesa ~10 GB, tarda). Ábrelo una vez y acepta instalar los componentes.
2. Las herramientas de línea de comandos:
   ```bash
   xcode-select --install
   ```
3. **Homebrew** (si no lo tienes): https://brew.sh
4. **XcodeGen**, que genera el proyecto de Xcode desde `project.yml`:
   ```bash
   brew install xcodegen
   ```

> ¿Por qué XcodeGen? El archivo `.xcodeproj` de Xcode es enorme, ilegible y genera conflictos en git.
> Con XcodeGen, el proyecto se describe en un `project.yml` corto y legible, que Claude Code puede editar sin romper nada.
> El `.xcodeproj` se regenera cuando quieras y no se sube a GitHub.

## 2. Abrir y correr el proyecto

```bash
cd gota
xcodegen          # crea Gota.xcodeproj
open Gota.xcodeproj
```

En Xcode:

1. Arriba a la izquierda, al lado del botón ▶, verás el **esquema** `Gota` y el destino `My Mac`. Déjalos así.
2. Presiona **⌘R** (o el botón ▶). Xcode compila y abre la app.
3. No aparece ninguna ventana: Gota vive en la **barra de menú** (busca la gota 💧 arriba a la derecha).
4. Prueba: en Finder, empieza a arrastrar una foto y, **sin soltar**, presiona **⇧ Shift**. Aparece la rueda. Suelta sobre "PNG".

Para detenerla: botón ■ en Xcode (o **⌘.**).

### Lo mínimo de la interfaz de Xcode

```
┌──────────────┬─────────────────────────────────┬──────────────┐
│  Navegador   │            Editor               │  Inspector   │
│  (archivos)  │   (código, o Preview de SwiftUI)│  (detalles)  │
│   ⌘1         │                                 │   ⌥⌘0        │
├──────────────┴─────────────────────────────────┴──────────────┤
│  Consola / depurador (print, errores)            ⇧⌘Y          │
└───────────────────────────────────────────────────────────────┘
```

- **⌘⇧O**: abrir rápido cualquier archivo o símbolo (como ⌘P en VS Code).
- **⌘B**: compilar. **⌘R**: correr. **⌘U**: tests. **⌘.**: detener.
- **⌥ + clic** sobre cualquier API (por ejemplo `glassEffect`): muestra su documentación.
- **⌃⌘ + clic**: ir a la definición.
- Los errores aparecen en rojo en el código y en el **Issue Navigator** (⌘5).
- `print("hola")` sale en la consola de abajo (⇧⌘Y para mostrarla).

### Permisos de macOS que te van a pedir

- **Notificaciones**: la primera vez. Acéptalas para ver "Listo: PNG".
- **Controlar Microsoft Word** (solo si lo tienes y conviertes un .docx a PDF): acepta. Word puede pedir además permiso para la carpeta.
- Si al presionar ⇧ mientras arrastras **no aparece la rueda**, ve a *Configuración del Sistema → Privacidad y seguridad → Monitoreo de entrada* y activa Gota. (Normalmente no hace falta; ver `docs/MOTORES.md` → notas técnicas.)

> Como por defecto la app se firma "para correr localmente" (sin cuenta de Apple), cada vez que compilas
> macOS puede volver a pedir algún permiso. Es normal en desarrollo.

## 3. Trabajar con Claude Code

Claude Code puede escribir y editar el código, correr los tests y compilar desde la terminal. Tú usas Xcode para **ver** la app y depurar.

### Flujo recomendado

1. Abre la terminal en la carpeta del proyecto y ejecuta `claude`.
2. Claude lee automáticamente `CLAUDE.md`, que le explica la arquitectura, las reglas y cómo compilar.
3. Pídele cosas concretas y pequeñas, por ejemplo:
   - *"Agrega una conversión de imagen a WebP usando ffmpeg si está instalado."*
   - *"Cuando paso el mouse sobre una burbuja, muestra el nombre debajo de la rueda con una animación."*
   - *"Corre los tests y arregla lo que falle."*
4. Claude compila con `xcodebuild` (ver comandos abajo). Si algo falla, lee el error y lo corrige.
5. Tú corres la app en Xcode (⌘R) y pruebas a mano lo visual. Si algo se ve mal, **descríbelo o pega una captura** (⌘⇧4) en Claude Code.
6. Cuando te guste: `git commit`. Haz commits pequeños y frecuentes.

### Comandos que Claude (o tú) puede usar en la terminal

```bash
xcodegen                                             # regenerar el proyecto tras cambiar project.yml o agregar archivos
xcodebuild -scheme Gota -destination 'platform=macOS' build    # compilar
xcodebuild -scheme Gota -destination 'platform=macOS' test     # tests
```

> Si agregas archivos nuevos `.swift`, vuelve a correr `xcodegen` para que Xcode los vea.

### Consejos para que Claude Code rinda más

- **Una cosa a la vez.** "Agrega X" funciona mucho mejor que "rehaz toda la app".
- **Pídele un plan primero** para cambios grandes: *"Antes de tocar código, dime cómo harías el soporte de OCR."*
- **Las animaciones se juzgan a ojo**: Claude no ve la pantalla. Corre la app, mira y dale feedback concreto ("el rebote es exagerado", "las burbujas se superponen con 8 opciones").
- **Pídele tests** para la lógica (catálogo, geometría, nombres de archivo). Lo visual lo pruebas tú.

## 4. Publicarlo como open source

1. Crea el repo en GitHub (por ejemplo `gota`) y súbelo:
   ```bash
   git init
   git add .
   git commit -m "Gota: primera versión"
   git branch -M main
   git remote add origin git@github.com:TU-USUARIO/gota.git
   git push -u origin main
   ```
2. Cambia el bundle id a algo tuyo en `Config/Base.xcconfig` (`GOTA_BUNDLE_ID = io.github.TU-USUARIO.gota`).
3. La licencia ya es **MIT** (`LICENSE`): cualquiera puede usarlo y contribuir. Pon tu nombre en el copyright.
4. Agrega capturas o un GIF de la rueda al README: es lo que más atrae estrellas.
5. **Releases para usuarios normales:** para que macOS no bloquee la app al abrirla, hay que **firmarla con Developer ID y notarizarla**. Eso requiere el Apple Developer Program (US$99/año). Mientras tanto, puedes publicar builds sin notarizar explicando el "Abrir igualmente" (lo hacen todos los proyectos que revisamos), o distribuir solo el código.

## 5. Cuando algo falla

| Síntoma | Qué hacer |
|---|---|
| `xcodegen: command not found` | `brew install xcodegen` |
| Xcode dice que la versión de macOS no es compatible | La app requiere **macOS 26+** (Liquid Glass). Actualiza macOS y Xcode. |
| Error de firma ("Signing for Gota requires a development team") | Revisa `Config/Base.xcconfig`: por defecto usa firma local (`GOTA_SIGN_IDENTITY = -`). Si creaste `Config/Local.xcconfig`, revisa tu Team ID. |
| No aparece la gota en la barra de menú | Puede estar oculta detrás del notch: cierra otras apps de barra de menú o usa Bartender/Ice. |
| La rueda no aparece | Asegúrate de **empezar a arrastrar antes** de presionar ⇧, y de arrastrar desde Finder o el Escritorio. Revisa "Monitoreo de entrada". |
| Convertir .docx a PDF falla | Instala Microsoft Word o LibreOffice (ver Ajustes de Gota → Motor para Word → PDF). |
