# Changelog - Orgrimmar Desokupa Dashboard (ODD)

Todas las versiones notables y cambios de este proyecto están documentados aquí.

---

## [0.4.1-alpha] - 2026-11-26

### 🔄 Sincronización P2P y Resolución de Nombres
- **Normalización Unificada de Nombres:** Implementación de `NormalizeName` e `IsSamePlayer` en `API/Forever.lua`. Garantiza que las bases de datos locales, el Roster y los rankings no generen duplicados ni discrepancias entre nombres con o sin apellido/reino.
- **Actualización de Bajas en Tiempo Real:** Al recibir un anuncio de kill `KILL` de un compañero, su cuenta total de bajas se actualiza inmediatamente en la base de datos local y refresca la interfaz sin requerir esperas ni peticiones manuales.
- **Refresco en Vivo del Roster:** La pestaña Miembros (`RosterTab`) y el `HUD` ahora se actualizan reactivamente al recibir paquetes de presencia `HELLO`, réplicas `GOSSIP` o bajas `KILL`.
- **Búsqueda Flexible en Miembros:** `RosterTab` realiza búsqueda cruzada de estadísticas independientemente de cómo el cliente catalogue el nombre del miembro en la hermandad.

### ⚔️ Gnomómetro: Detección Robusta de Bajas
- **Resiliencia ante Restricciones de WoW Forever:** El observador de salud en combate registra las muertes directas del objetivo aunque el evento `PARTY_KILL` del servidor omita el autor o venga protegido por secretos de identidad del cliente (tótems, venenos, DoTs o daño indirecto).

### 🎨 Rediseño del Panel General (Cuartel General)
- **Modelo 3D Ampliado:** Modelo del personaje aumentado a 220x260px con soporte de rotación interactiva mediante arrastre con ratón.
- **Tarjeta de Puntos de Logro:** Nueva tarjeta dedicada para los Puntos de Logro integrada en la cabecera principal junto a las bajas personales y de hermandad.
- **Contratos Semanales Optimizados:** Reorganización espacial y ampliación de los contratos semanales deterministas en la zona inferior.

### 🔊 Soundboard: Ámbito Estricto de Grupo / Banda
- **Exclusión de Hermandad:** Las emisiones de audio del Soundboard quedan restringidas exclusivamente a grupos (`PARTY`) y bandas (`RAID`). Si el jugador no está en grupo, el sonido solo se reproduce en local, evitando spam en el canal de hermandad.

---

## [0.4.0-alpha] - 2026-11-26

### ⚔️ Radar de Proximidad Interactivo con Modelo 3D
- **Detección Anticipada en Mundo Abierto:** Alerte visual y sonora interactiva al detectar gnomos de la Alianza en placas de nombre, mouseover u objetivo visible.
- **Modelo 3D y Datos de Combate:** Muestra el modelo animado en 3D del gnomo enemigo, nombre con color de clase de WoW, nivel y distinción especial si es tu Némesis registrada.
- **Sistema de Colores por Nivel de Dificultad:** El borde de la alerta y el nivel del enemigo se adaptan dinámicamente al sistema oficial de dificultad de WoW (Gris, Verde, Amarillo, Naranja, Rojo).
- **Targeteo Seguro con Clic Izquierdo:** Macro seguro (`/cleartarget`, `/targetexact`) con soporte para nombres y apellidos completos de WoW Forever, libre de errores de taint y sin interferencias de ratón.
- **Voz Nativa de Gnomo:** Reproducción de la voz nativa de gnomo de WoW (`SOUNDKIT.GNOME_MALE_AGGRO`) y alerta de banda (`SOUNDKIT.RAID_WARNING`) a través del canal Master.
- **Comandos de Prueba In-Game:** Pruebas directas con `/odd radar` y `/odd sound [radar|kill|achieve]`.

### 🛡️ HUD Flotante Panorámico Horda (Alta Definición)
- **Textura HD Dedicada:** Marco de hierro forjado, remaches y blasones de Orgrimmar adaptado a proporción panorámica en alta definición.
- **Diseño Limpio y Ajustado:** Fondo oscuro central sin solapamiento de tela roja con estadísticas bien alineadas:
  - Bajas de hoy (verde) y de la semana (naranja).
  - Bajas personales acumuladas (dorado) y bajas totales de hermandad (cian).
- **Arrastre y Posición Persistente:** Mueve el HUD con clic izquierdo a cualquier parte de la pantalla; la posición se guarda automáticamente. Clic derecho abre el dashboard principal.

### 🗺️ Mapa de Zonas Calientes (Heatmap de Desalojo)
- **Top Áreas de Operación en el Gnomómetro:** Nueva sección interactiva en la pestaña Gnomómetro con barras visuales térmicas y porcentajes de las 4 zonas con mayor actividad de desalojo.
- **Agregación P2P:** Sincroniza las zonas con más bajas entre los compañeros de hermandad para reflejar el mapa colectivo de caza en vivo.

### 💬 Compartir Logros y Némesis por Chat (Shift + Clic)
- **Integración con el Chat:** `Shift + Clic` sobre cualquier logro en la pestaña Medallas o sobre una ficha de Némesis en la pestaña PvP pega automáticamente el progreso formateado en la ventana de chat activa para compartirlo con la hermandad o grupo.
- **Apertura Inteligente:** Si no tenías la caja de chat abierta, el addon la activa e inserta el enlace automáticamente.

### 📜 Títulos Honoríficos y Fichas en el Roster
- **Títulos Cómicos de Hermandad:** Asignación automática de títulos honoríficos en la pestaña Miembros según las bajas y medallas conseguidas:
  - *«El Fumigador Jefe»* (Líder en bajas de la hermandad).
  - *«Inspector de Desokupaciones»* (Líder en puntos de logro).
  - *«Azote de Manitas»*, *«Desalojador Élite»*, *«Cazarratas»*, *«Desokupador Novato»*, *«Coleccionista de Medallas»* y *«Aspirante»*.
- **Tooltips Enriquecidos:** Al pasar el ratón por los miembros de la hermandad, se despliega una tarjeta emergente completa con su nivel, clase, rol, bajas verificadas, puntos de medallas y estado.

---

## [0.3.5-alpha] - 2026-11-23

### 🏆 Sistema de Puntos de Logro
- **Puntuación por Dificultad:** Se asignan puntos (de 5 a 50 pts) a cada logro y medalla según su complejidad y rareza.
- **Visualización en la UI:**
  - En la pestaña **General** (`HQTab`), la ficha del personaje muestra la suma total de puntos de logro junto a la clase y nivel.
  - En la pestaña **Logros**, la cabecera resume el progreso en logros y puntos totales (`Progreso: X / Y logros • Puntos de Logro: X / Y pts`). Cada fila detalla los puntos que otorga la medalla.
- **Clasificación y Ordenación en el Gnomómetro:**
  - El Leaderboard de hermandad muestra tanto las bajas como los puntos de logro conseguidos (`X bajas • Y pts`).
  - Nuevos botones de filtrado rápido: **`[Más Bajas]`** (orden por gnomos abatidos) y **`[Más Puntos]`** (orden por puntuación de logros).
- **Sincronización P2P:** El protocolo de red incluye `ap` (achievement points) en el intercambio entre miembros de hermandad.

### 🎯 Sistema de Némesis en PvP
- **Sustitución de Historial:** La pestaña **PvP** reemplaza el registro genérico de partidas por un rastreador interactivo de Némesis.
- **Identificación de Agresores:** Registra a los jugadores de la Alianza que te derrotan, indicando su clase, zona, fecha y marcador de venganzas.
- **Estados de Búsqueda:** Clasificación dinámica con etiquetas `[BUSCADO]` (si te van ganando el marcador) y `[VENGADO]` (en cuanto igualas o superas las bajas).
- **Rangos de Honor:** Visualización del rango PvP oficial de WoW Forever (`GetPVPRankInfo`) en lugar de etiquetas numéricas genéricas.

### 🔊 Efectos de Sonido Personalizados
- **Módulo `Core/Audio.lua`:** Detección y reproducción nativa de efectos sonoros sin dependencias externas.
- **Eventos con Sonido:**
  - Sonido al abatir un gnomo (`Media/Sounds/kill.mp3` o `.ogg`).
  - Sonido al desbloquear un nuevo logro (`Media/Sounds/achievement.mp3` o `.ogg`).
- **Control en Ajustes:** Nueva opción de configuración para silenciar todos los sonidos del addon.

### 📢 Mensajes Dinámicos e Identidad en Hermandad
- **10 Frases Ingeniosas de Desalojo:** Al abatir un gnomo, el mensaje enviado al chat de hermandad elige aleatoriamente entre 10 frases cómicas y temáticas de Orgrimmar Desokupa.
- **Anuncio Natural de Logros:** Al desbloquear un logro se anuncia de forma limpia y directa al chat de hermandad: *"He conseguido el logro [Nombre del Logro]"*.
- **Nombre y Apellido Oficiales:** Adaptada la lectura de identidad para extraer el nombre y apellido completos tal como están registrados en el Roster de hermandad de WoW Forever (ej. `Holgar Stormaxe`).

### ⚡ Red, Rendimiento y Correcciones Críticas
- **Solución al Límite de 250 Bytes:** Corregido el desbordamiento en el canal de addon limitando el broadcast de talleres a las 2 profesiones primarias y añadiendo un fallback automático al codificador plano `S1`.
- **Deduplicación Estricta del Jugador Local:** Implementada la función `IsMe()` para comparar de forma insensible a mayúsculas nombres simples y nombres con reino (`Nombre`, `Nombre-Reino`, `Nombre Reino`). Corrige el bug donde el HUD y la pestaña General duplicaban las bajas del propio jugador sumándolas como si fueran de un compañero remoto.
- **Renombrado y Pulido de Pestañas:** Pestañas renombradas a *General, Gnomómetro, Logros, PvP, Profesiones, Miembros y Ajustes*. Retirados campos obsoletos de "Personaje Principal".
- **Ajuste de ScrollFrames:** Corregida la altura de todas las listas con scroll para evitar solapamientos con los botones inferiores.

---

## [0.1.8-alpha] - 2026-11-23

### ⚔️ Detección Directa de Bajas y Descarte de UnitCanAttack
- **Eliminación del bloqueo de `UnitCanAttack` tras la muerte:** En el momento exacto en que un jugador muere en WoW, `UnitCanAttack("player", "target")` pasa a devolver `false` porque un cadáver no es atacable. Esto provocaba que tanto `UNIT_HEALTH` como la comprobación de autoría en solitario descartaran la baja justo al producirse la muerte.
- **Doble resolución en `GetPlayerInfoByGUID`:** Soportada la estructura variante de retorno de `GetPlayerInfoByGUID` para asegurar que razas localizadas ("Gnomo") y en inglés ("Gnome") se validen siempre.

## [0.1.7-alpha] - 2026-11-23

### 🛡️ Protección de Motor contra Valores Secretos (Secret Values Taint)
- **Error en `UNIT_HEALTH` subsanado:** En WoW Camelot/Forever, los valores numéricos de vida (`UnitHealth`) o nivel (`UnitLevel`) durante el combate de jugadores de facción opuesta pueden estar encapsulados como `secret number value`. Las comparaciones directas en Lua como `hp <= 0` provocan una excepción de taint.
- **Validación Segura:** Todas las lecturas de salud, nivel y raza se realizan ahora con comprobación estricta de `ODD.API.Forever:IsSecret()` y `tonumber()` seguro, evitando excepciones en tiempo de combate.

## [0.1.6-alpha] - 2026-11-23

### ⚔️ Detección en Solitario, Mascotas y Tótems
- **Atribución Universal de Bajas:** Detecta kills tanto en solitario como en grupo. Añadido soporte para mascotas, tótems (Chamanes) y guardianes mediante `UnitTokenFromGUID` y `UnitGUID("pet")`.
- **Detección por `UNIT_HEALTH`:** Añadido observador en tiempo real de salud cero y muerte sobre el objetivo (`UnitHealth("target") <= 0` o `UnitIsDead("target")`), asegurando que las muertes por DoTs o golpes finales en solitario se registren inmediatamente aunque `PARTY_KILL` tarde o no despache payload.
- **Blindaje de Inspección de Auras:** Envuelto el escaneo de auras en `pcall` seguro con comprobaciones de tipo (`type(...) == "function"`) para prevenir errores de lua ante cualquier variación de API del cliente.

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
