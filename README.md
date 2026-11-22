# Orgrimmar Desokupa Dashboard (ODD)

Addon en fase de investigación para **WoW Forever 1.60.1 (Interface 16001)**.

La Fase 0 documenta qué puede construirse con evidencia real del cliente antes de implementar el dashboard, la sincronización o el tracking de eliminaciones.

## Documentación

- [Informe de investigación](docs/fase-0/01-investigacion.md)
- [Viabilidad funcional](docs/fase-0/02-viabilidad.md)
- [Diseño del protocolo](docs/fase-0/03-protocolo.md)
- [Arquitectura y persistencia](docs/fase-0/04-arquitectura.md)
- [Validación en juego y plan de implementación](docs/fase-0/05-validacion-y-plan.md)
- [Fuentes](docs/fase-0/06-fuentes.md)

## Estado

- **Fase 0 (Investigación y Diseño):** Completada y documentada en `docs/fase-0/`.
- **Fase 1 (Base e Infraestructura):** Implementada. Estructura modular Lua nativa, TOC `16001`, ciclo de vida, detección de capacidades, SavedVariables versionados (`ODDDB`, `ODDCharacterDB`), `/odd` y Dashboard con 6 pestañas nativas.
- **Fase 2 (Transporte y Sincronización P2P):** Implementada. Registro de prefijo `ODD` en `C_ChatInfo`, codec binario/nativo (`CB1`/`S1`), control de saturación token bucket (Queue), deduplicación de mensajes, protocolo de presencia `HELLO` con jitter, botón «Sincronizar hermandad» en Cuartel General y comando `/odd sync`.
- **Fase 3 (Gnomómetro y Leaderboard de Hermandad):** Implementada. Escucha pasiva de `PARTY_KILL`, verificación rigurosa de autoría (solo killing blow propio), confirmación estricta de raza Gnomo por GUID/UnitRace, exclusión de BGs/mazmorras (solo mundo abierto), deduplicación por cooldown (60s) y **Leaderboard de hermandad en vivo**: ranking ordenado por bajas con colores de clase de Blizzard, etiquetas de rigor (`Verificado` vs `Declarado`) y sincronización P2P vía `HELLO`/`Sync`.
- **Fase 4 (Frente PvP y Talleres/Artesanía):** Implementada por completo.
  - *PvP:* Estadísticas directas de honor nativo (Hoy, Ayer, Histórico), escucha de `PLAYER_PVP_KILLS_CHANGED`, registro verificado de victorias/derrotas de BGs con `PVP_MATCH_COMPLETE` y cálculo automático de ratio de victorias (%) con historial deslizable.
  - *Talleres:* Escáner nativo de profesiones clásicas de WoW Forever, barra de 8 filtros directos por profesión, catálogo deslizable de artesanos, búsqueda interactiva y distinción de procedencia.
- **Fase 5 (Roster Completo, Medallas y Pulido):** Implementada por completo.
  - *Roster de Hermandad:* Visualizador interactivo con indicador de conexión (online/offline), ordenación inteligente (conectados primero, luego rango y nombre), buscador en tiempo real, filtro `Solo en linea` y refresco manual.
  - *Medallas de Hermandad:* Catálogo ampliado con 19 logros dedicados exclusivamente a la caza de gnomos:
    - *Cadena de Bajas:* Primer Desalojo (1), Control de Plagas (5), Cazagnomos (10), Fumigador Oficial (25), Azote de Gnomeregan (50), Rompeengranajes (75), Terror de la Alianza (100), Exterminador Jefe (250) y Leyenda de Orgrimmar Desokupa (500).
    - *Especialistas por Clase:* Cortahechizos (Mago), Pisa-diablillos (Brujo), Descubierto de las Sombras (Pícaro), Mordisco al Tobillo Evitado (Guerrero) y Desalojo Interdisciplinar (las 4 clases clásicas de gnomo).
    - *Hazañas de Nivel:* Peligro en Miniatura (Gnomo nivel 50+) y David contra Goliat al Revés (Gnomo calavera ??).
    - *Exploración y Caza:* Desokupador Itinerante (3 zonas) y Limpieza Territorial (5 zonas distintas).
  - *Sincronización al Abrir:* Ping P2P reactivo con micro-jitter cada vez que se abre la ventana.

## OpenCode

`opencode.jsonc` permite las herramientas automáticamente solo en este proyecto. No modifica la configuración global del usuario.
