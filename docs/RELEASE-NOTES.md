Segunda versión de **Gota**: el motor más fiel para cada formato, Word sin instalar nada, PowerPoint, icono y
actualizaciones.

**Instalar o actualizar:** descarga `Gota-0.2.0.zip`, descomprímelo y mueve `Gota.app` a Aplicaciones (sal antes de la
versión anterior desde la 💧). La primera vez, abre *Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente*
(la app aún no está notarizada). Guía: [docs/INSTALAR.md](https://github.com/DANIIcs/Gota/blob/main/docs/INSTALAR.md).

**Requisitos:** macOS 26 o posterior (probado en macOS 27 Golden Gate), Apple Silicon o Intel.

### Novedades
- **El motor más fiel para cada formato**, medido contra Word y PowerPoint
  ([docs/MOTORES.md](https://github.com/DANIIcs/Gota/blob/main/docs/MOTORES.md)).
- **Word `.docx` → PDF sin instalar nada**: Gota incluye su propio motor
  ([docxide-pdf](https://github.com/sverrejb/docxide-pdf)) con fuentes compatibles con Calibri y Cambria. Más fiel que
  LibreOffice (0,948 frente a 0,909), en menos de un segundo.
- **PowerPoint, Keynote y ODP** → PDF o imágenes por diapositiva.
- **PDF → Word**, y **varios archivos a la vez**: cada uno por separado o todo en uno (*PDF unido*, *Word unido*…).
- **Apariencia de la rueda**: Liquid Glass o Transparente, opacidad, colores, Negro espacial metálico y RGB.
- **Ajustes al estilo de macOS**, con buscador, y **botón para instalar LibreOffice** si hace falta.
- **Icono** propio y **Buscar actualizaciones** (a mano, o una vez al día si lo activas).
- Sonido de alerta de tu Mac al terminar.

### Arreglos
- Seguridad: un documento malicioso ya no puede colar imágenes de tu Mac dentro del PDF; páginas de PDF gigantes ya
  no cierran la app.
- Microsoft Word ya no puede cerrar otro documento tuyo sin guardar, y espera a los formatos que tardan en abrir.
- Se ignoran los archivos de bloqueo de Office (`~$…`); los errores dicen qué archivo falló.
- La rueda recibe bien el arrastre, se mantiene centrada y el texto del centro ya no lo tapa Finder.

Comprueba la descarga con el archivo `.sha256` (ver la guía).
