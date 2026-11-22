# Changelog - Orgrimmar Desokupa Dashboard (ODD)

Todas las versiones notables y cambios de este proyecto están documentados aquí.

---

## [0.1.1-alpha] - 2026-11-22

### 🪓 Interfaz y Arte
- **Marco Temático Horda / Orgrimmar:** Integrado marco personalizado con maderas oscuras, hierro forjado, púas orcas y trofeos cómicos de cabezas de gnomos abatidos en las esquinas.
- **Transparencia Nativa:** Textura en canal alfa puro de 32 bits (`1024x1024`), sin halos ni artefactos blancos residuales.
- **Prioridad Visual en Pantalla:** Configurado `FrameStrata = HIGH` y `Toplevel(true)` para que la ventana y el marco ornamental permanezcan siempre por delante de las barras y elementos de la interfaz.
- **Visualizador 3D del Personaje:** Añadido modelo 3D interactivo en vivo en la pestaña Cuartel General con fondo transparente y rotación libre en 360° mediante arrastre con el ratón.
- **Alineación de Roster:** Espaciado corregido entre los estados de conexión `[ON]` / `[OFF]` y los nombres de personaje.

### ⚙️ Automatización y Fluidez
- **Retirados botones manuales innecesarios:**
  - Eliminado el botón manual "Refrescar Roster": el roster se solicita y refresca automáticamente al seleccionar la pestaña.
  - Eliminado el botón manual "Re-escanear": las habilidades y recetas del jugador se inspeccionan y actualizan automáticamente al entrar a Talleres.
  - Eliminado el botón manual "Sincronizar hermandad": el protocolo de sincronización P2P emite automáticamente la señal de presencia al abrir la ventana y entrar a Cuartel General.
- **Deduplicación en Talleres:** Corregido el listado de artesanos para evitar que el jugador local aparezca dos veces (como observado localmente y como declarado sincronizado).

### 🏆 Catálogo Ampliado de Logros (33 Medallas)
- **Nuevos logros por situación especial:**
  - *Pisotón Desprevenido:* Abate a un gnomo mientras come o bebe (con memoria de combate de auras previas).
  - *Pisa-flores:* Abate a un gnomo que se desplace en Mecazancudo.
- **Nuevos logros por territorio:**
  - *¡A mi casa no entras!:* Abate a un gnomo en Durotar o Los Baldíos.
  - *Safari en Tuercespina:* Abate a 5 gnomos en Vega de Tuercespina.
  - *Trabalomas No se Negocia:* Abate a 5 gnomos en Laderas de Trabalomas.
  - *Visita a Domicilio:* Abate a un gnomo en Dun Morogh o puertas de Gnomeregan.
  - *Control Portuario:* Abate a un gnomo en Bahía del Botín o Trinquete.
  - *Desokupa Global:* Abate gnomos en al menos 10 zonas distintas de Azeroth.
- **Nuevos logros por racha y cooperación:**
  - *Doble Desahucio:* 2 gnomos abatidos con menos de 60 segundos de diferencia.
  - *Desokupación Exprés:* 3 gnomos abatidos en menos de 5 minutos.
  - *Jornada Laboral Completa:* 5 gnomos abatidos en una misma sesión de juego.
  - *Comité de Desahucio Masivo:* 10 gnomos abatidos en grupo con compañeros de hermandad.
- **Corrección de Iconos:** Sustitución de rutas inexistentes en el cliente clásico por iconos oficiales y universales del catálogo de Blizzard.

### 🛠️ Comandos
- **Comando `/odd reset` (o `/odd wipe`):** Permite reiniciar la base de datos local y purgar registros temporales en un solo paso con `/reload` automático.

---

## [0.1.0-alpha] - 2026-11-22

### Versión Inicial
- Estructura base nativa para WoW Forever (Interface 16001).
- 6 pestañas principales: Cuartel General, Gnomómetro, Frente PvP, Talleres, Roster y Ajustes.
- Tracking de bajas de gnomos con `PARTY_KILL` y verificación estricta de raza y autoría.
- Red P2P y protocolo de sincronización incremental mediante `C_ChatInfo`.
