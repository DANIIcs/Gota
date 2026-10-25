# Instalar Gota

Gota es una app para la **barra de menú** de macOS. No tiene ventana ni icono en el Dock: vive en la gota 💧
de arriba a la derecha.

**Requisitos:** macOS 26 (Tahoe) o posterior, en un Mac con Apple Silicon o Intel.

---

## 1. Descargar

1. Abre la página de versiones: **https://github.com/DANIIcs/Gota/releases/latest**
2. En **Assets**, descarga `Gota-X.Y.Z.zip`. Pesa menos de 1 MB.

### (Opcional) Comprobar que la descarga no fue alterada

Cada versión publica también un archivo `.sha256` con la "huella" del zip. En Terminal:

```bash
cd ~/Downloads
shasum -a 256 Gota-*.zip
```

El código que aparece debe ser **idéntico** al del archivo `Gota-X.Y.Z.zip.sha256` de la página de la versión.
Si no coincide, no abras la app y avisa en *Issues*.

## 2. Instalar

1. Haz doble clic en el `.zip`: aparece `Gota.app`.
2. Arrastra **Gota.app** a la carpeta **Aplicaciones**.

## 3. Abrirla la primera vez

Gota es gratis y de código abierto, pero todavía no está **notarizada** por Apple (eso requiere una cuenta de
desarrollador de pago). Por eso, la primera vez macOS dice algo como *"No se puede abrir Gota porque Apple no puede
comprobar que no contenga software malicioso"*. Es normal: solo hay que confirmarlo **una vez**.

1. Abre **Gota** desde Aplicaciones. Aparece el aviso: pulsa **Aceptar** (o **Listo**).
2. Abre **Ajustes del Sistema → Privacidad y seguridad**.
3. Baja hasta **Seguridad**: verás *"Se bloqueó el uso de Gota…"*. Pulsa **Abrir igualmente**.
4. Confirma con tu contraseña o Touch ID, y pulsa **Abrir**.

<details>
<summary>Alternativa por Terminal (para usuarios avanzados)</summary>

Quita la marca de "descargado de internet" y ábrela:

```bash
xattr -dr com.apple.quarantine /Applications/Gota.app
open /Applications/Gota.app
```

Hazlo solo con apps en las que confíes: así te saltas la comprobación de macOS.
</details>

> **¿Prefieres no confiar en un binario?** Compílala tú mismo desde el código: ver [GUIA.md](GUIA.md).
> Es exactamente el mismo código que está en este repositorio.

## 4. Permisos

- **Notificaciones:** la primera vez Gota pregunta si puede mostrar notificaciones ("Listo: PNG"). Acepta para
  saber cuándo termina cada conversión.
- **Controlar Microsoft Word:** solo si activas *Usar Microsoft Word* en Ajustes. Word también puede pedir acceso a
  la carpeta.
- Gota **no** necesita permiso de Accesibilidad ni de Grabación de pantalla, y **no se conecta a internet**.

## 5. Usarla

1. En Finder, empieza a **arrastrar** uno o varios archivos y, **sin soltar el clic**, mantén una tecla:

   | Tecla | Rueda |
   |---|---|
   | **⇧ Shift** | Convertir (PNG, JPEG, PDF, Word, MP4, M4A…) |
   | **⌥ Option** | Herramientas (comprimir, reducir, unir/dividir/rotar PDF…) |
   | **⌃ Control** | Acciones (AirDrop, ZIP, copiar ruta, mostrar en Finder) |

2. Lleva el cursor hasta una burbuja y **suelta** encima.
3. El resultado se guarda **junto al original**, sin sobrescribir nada (`foto.png` → `foto.jpg`, `foto 2.jpg`…).

Soltar en el **centro** de la rueda cancela: el archivo se queda donde estaba.

## 6. Ajustes

Clic en la 💧 → **Ajustes…** (⌘,):

- **Abrir Gota al iniciar sesión**, para tenerla siempre disponible.
- **Mostrar el resultado en Finder** y **Sonido al terminar**.
- **Apariencia de la rueda:** Liquid Glass o Transparente, opacidad y color (incluye Negro espacial y RGB).
- **Documentos → PDF:** qué motor usar (macOS integrado, LibreOffice si lo tienes, o Microsoft Word).

## 7. Actualizar

Descarga la nueva versión y reemplaza `Gota.app` en Aplicaciones (sal antes de Gota desde la 💧 → *Salir de Gota*).
Puede que macOS vuelva a pedir el paso 3.

## 8. Desinstalar

1. 💧 → **Salir de Gota**.
2. Si activaste *Abrir al iniciar sesión*, desactívalo antes en Ajustes de Gota (o en *Ajustes del Sistema →
   General → Ítems de inicio*).
3. Arrastra **Gota.app** de Aplicaciones a la Papelera.
4. (Opcional) Borra sus preferencias:
   ```bash
   defaults delete pe.danielc.gota
   ```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| No veo la 💧 en la barra de menú | Puede estar oculta detrás del notch: cierra otras apps de la barra de menú. |
| *"Gota está dañada y no se puede abrir"* | El zip se descargó a medias o lo descomprimió otra app. Vuelve a descargarlo y ábrelo con doble clic. |
| La rueda no aparece | **Empieza a arrastrar primero** y luego pulsa la tecla. Arrastra desde Finder o el Escritorio. |
| Un `.pages` no pasa a PDF | Instala [LibreOffice](https://www.libreoffice.org): el motor de macOS no lee Pages. |
| Otra cosa | Abre un *Issue* en GitHub con lo que hiciste y una captura. Si es un fallo de seguridad, usa *Security → Report a vulnerability* (ver [SECURITY.md](../SECURITY.md)). |
