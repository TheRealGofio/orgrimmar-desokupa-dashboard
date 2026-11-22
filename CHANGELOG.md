# Changelog - Orgrimmar Desokupa Dashboard (ODD)

Todas las versiones notables y cambios de este proyecto están documentados aquí.

---

## [0.1.5-alpha] - 2026-11-22

### 🔍 Detección Infalible de Gnomos (Inspirado en arquitectura GRS)
- **Resolución nativa por `GetPlayerInfoByGUID`:** Implementada resolución directa de raza y nombre mediante el GUID del jugador muerto, exactamente como hace GRS. Si el gnomo muere, el cliente de WoW sigue conociendo su raza a través de su identificador permanente sin depender de que esté seleccionado en el objetivo.
- **Escáner pasivo de entorno:** Escucha activa de `NAME_PLATE_UNIT_ADDED`, `UPDATE_MOUSEOVER_UNIT` y `PLAYER_TARGET_CHANGED` para indexar gnomos presentes en el combate.
- **Doble escucha de muerte:** Activado fallback con `UNIT_DIED` si el evento de grupo `PARTY_KILL` no se dispara.

## [0.1.4-alpha] - 2026-11-22

### 🐛 Corrección Crítica en Detección de Bajas
- **Persistencia de metadatos de víctimas:** En el milisegundo en que un gnomo muere, el cliente de WoW limpia el token `"target"`. Se ha añadido una caché de combate que guarda automáticamente la raza, nombre, clase y nivel del gnomo durante el combate, permitiendo validar la baja aunque el jugador ya no lo tenga en el objetivo en el momento exacto del golpe final.
- **Robustez en parámetros de `PARTY_KILL`:** Añadida resolución de fallback para `attackerGUID` y `targetGUID` si el cliente despacha el evento sin payload directo.

## [0.1.3-alpha] - 2026-11-22

### ✨ Nuevas Características
- **Botón de Minimapa Nativo:** Creado botón circular en el minimapa con icono nativo de cabeza de gnomo (`INV_Misc_Head_Gnome_01`), borde oficial de Blizzard y efecto de brillo al pasar el ratón.
- **Interacción y Tooltip:**
  - Clic izquierdo: Abre o cierra el panel del dashboard.
  - Clic derecho o Shift+Arrastrar: Permite mover libremente el botón alrededor del borde del minimapa en 360°, guardando la posición en los ajustes.
  - Tooltip: Muestra información de ayuda y el contador total de gnomos abatidos en tiempo real.

## [0.1.2-alpha] - 2026-11-22

### 🐛 Correcciones
- **Error en `UnitAura` (attempt to call a nil value):** En el motor moderno de WoW Forever, la función clásica global `UnitAura` está retirada. Se ha adaptado la detección de auras a `C_UnitAuras.GetAuraDataByIndex` con compatibilidad hacia atrás segura.

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
