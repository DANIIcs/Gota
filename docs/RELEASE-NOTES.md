**Gota 0.2.1**: tus Word salen igual que en Word aunque usen fuentes que no tienes, nuevo icono y Ajustes como los de macOS.

**Actualizar:** 💧 → *Buscar actualizaciones…*, o descarga `Gota-0.2.1.zip`, sal de Gota y reemplaza `Gota.app` en Aplicaciones.
Guía: [docs/INSTALAR.md](https://github.com/DANIIcs/Gota/blob/main/docs/INSTALAR.md). Requiere macOS 26 o posterior.

### Novedades
- **Fuentes que faltan:** si un Word usa una fuente libre que tu Mac no tiene (Poppins, Montserrat…), Gota la descarga
  una vez de Google Fonts (solo viaja el nombre de la fuente, nunca tu documento). Un documento real en Poppins pasó de
  7 a 9 páginas, como en Word. Si falta una fuente de pago, te avisa. Se puede apagar en *Ajustes → Motores*.
- **Nuevo icono** con Liquid Glass, que sigue tu estilo de iconos (normal, oscuro, teñido, transparente).
- **Ajustes al estilo de macOS:** los iconos reales de Ajustes del Sistema, una cabecera en cada sección y un
  *Acerca de* con versión, actualizaciones (también automáticas, si las activas) y enlaces.

### Arreglos
- Las fuentes compatibles con Calibri y Cambria que incluye Gota eran versiones retocadas que ya no medían igual:
  ahora son las originales (en un documento con tablas, de 0,77 a 0,96 de fidelidad contra Word).
- Seguridad: dependencias del motor de Word actualizadas (0 vulnerabilidades conocidas), los `.docx` "bomba" se
  rechazan antes de abrirlos, y cada cambio pasa ahora por controles automáticos (ver SECURITY.md).
- El icono de *Acerca de* ya no sale vacío, la sección ya no se desplaza al abrirla, y Ajustes se abre delante de las
  demás ventanas.

Comprueba la descarga con el archivo `.sha256` (ver la guía).
