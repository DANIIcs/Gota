# Grabar la demo de Gota

Para el README (GIF corto) y para redes (vídeo). Todo con archivos de muestra, sin datos personales.

## 1. Preparar

```bash
swift scripts/make-demo-files.swift      # crea ~/Desktop/Gota demo (la borra y la rehace limpia)
```

Contiene: `Atardecer.heic` y `Montañas.heic` (fotos como las de un iPhone), `Informe trimestral.docx`,
`Presupuesto.pdf` (2 páginas), `Notas del viaje.md` y `Nota de voz.aiff`. Vuelve a ejecutarlo antes de cada toma: al
convertir, la carpeta se llena de resultados.

Antes de grabar:
- Abre la carpeta en Finder, vista de **iconos** grandes (⌘1, *Mostrar opciones de visualización* → tamaño 96).
- Ventana de Finder de unos 1000 × 600, centrada. Cierra lo demás y oculta el Dock si molesta.
- Modo oscuro o claro, el que se vea mejor con tu fondo; Gota con su apariencia por defecto (Liquid Glass).
- Apaga las notificaciones de otras apps (*Centro de control → No molestar*); deja activadas las de Gota.

## 2. Guion

**GIF del README (10–15 s, sin cortes).** Lo primero que se ve tiene que ser la rueda, sin introducción:

| Segundo | Acción |
|---|---|
| 0–2 | Empieza a arrastrar `Atardecer.heic` y pulsa **⇧**: aparece la rueda |
| 2–4 | Pasa por un par de burbujas (se ve el nombre en el centro) y suelta en **PNG** |
| 4–6 | Aparece `Atardecer.png` al lado y la notificación *Listo* |
| 6–9 | Arrastra `Informe trimestral.docx` con **⇧** y suelta en **PDF** |
| 9–13 | Selecciona las dos fotos, arrastra con **⇧** y suelta en **PDF unido**: un solo PDF |

**Vídeo para redes (30–45 s).** El GIF y además:
- **⌥** con `Presupuesto.pdf` → **Rotar 90°** o **Dividir**.
- **⇧** con `Notas del viaje.md` → **PDF**, y ábrelo con la barra espaciadora (Vista rápida) para ver la tabla.
- **⌃** → **AirDrop** o **ZIP**.
- Cambiar de tecla a mitad del arrastre (⇧ → ⌥) para que se vea la rueda cambiando.
- Termina en Ajustes → Apariencia moviendo el color a **RGB**.

## 3. Grabar

**⌘⇧5** → *Grabar porción seleccionada* → encuadra solo la ventana de Finder (y la zona de notificaciones si cabe) →
*Opciones*: *Mostrar clics del ratón*, guardar en el Escritorio. Graba varias tomas y quédate con la más limpia.

## 4. Convertir a GIF (para el README)

GitHub muestra GIFs de hasta 10 MB; apunta a menos de 5 MB. Con ffmpeg (`brew install ffmpeg`):

```bash
ffmpeg -i demo.mov -vf "fps=15,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer" docs/media/demo.gif
```

Si pesa demasiado, baja `fps` a 12 o `scale` a 800. Después, en `README.md` y `README.es.md`, cambia el comentario
`<!-- Demo: … -->` por la línea `<p align="center"><img …></p>` que trae dentro.

Para X, sube el `.mov` directamente (o expórtalo a MP4 con `ffmpeg -i demo.mov -c:v libx264 -crf 20 -pix_fmt yuv420p demo.mp4`):
se ve mejor que un GIF.
