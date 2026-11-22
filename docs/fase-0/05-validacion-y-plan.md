# Validación en juego, riesgos y plan de implementación

## 1. Estado de la Fase 0

La investigación documental y el diseño inicial están completos. La **validación práctica está pendiente** porque no había cliente de WoW Forever en el entorno de trabajo. Ninguna API se marcará como probada por ODD hasta ejecutar la prueba correspondiente y registrar build, contexto y resultado.

Antes de cada bloque funcional se creará una pequeña comprobación de capacidad dentro del propio addon; los probes registrarán diagnósticos, no estadísticas de juego.

## 2. Pruebas de humo previas a Fase 1

| ID | Prueba | Resultado necesario |
|---|---|---|
| ENV-01 | Registrar `GetBuildInfo()`, `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT` y carpeta real de instalación. | Confirmar 1.60.1 / 16001 y `_forever_`; guardar build completa en el informe. |
| ENV-02 | Cargar un TOC mínimo y ejecutar `/odd`. | Sin errores Lua ni globals inesperadas. |
| DB-01 | Escribir datos en ambos SavedVariables, hacer `/reload`, logout y cambio de personaje. | Restauración correcta y aislamiento de datos por personaje. |
| UI-01 | Abrir dashboard, cambiar entre las seis pestañas, entrar/salir de combate y hacer `/reload`. | Sin templates ausentes, secretos serializados ni operaciones protegidas en lockdown. |
| GUILD-01 | Leer roster tras login y tras `GUILD_ROSTER_UPDATE`. | Mismos miembros/campos básicos que la UI nativa; estados ausentes no se convierten en ceros. |

## 3. Pruebas de red previas a Fase 2 completa

Usar al menos dos cuentas/clientes en la misma hermandad y una tercera sin ODD cuando sea posible.

| ID | Prueba | Qué medir |
|---|---|---|
| NET-01 | Registro de `ODD` tras carga y `/reload`. | Resultado `Success`/`DuplicatePrefix` tratado correctamente. |
| NET-02 | Mensaje mínimo por `GUILD` y mensaje de 255 bytes. | Resultado de envío, recepción exacta, longitud real y formato de `sender`. |
| NET-03 | Sin hermandad, chat lockdown, cuenta no elegible y destinatario offline si aplica. | Estado `pendiente`/`error` correcto; sin bucle de reintentos. |
| NET-04 | Ráfaga controlada. | Valores reales de `AddonMessageThrottle`/`ChannelThrottle` y recuperación. Nunca provocar desconexiones deliberadamente. |
| NET-05 | Ida y vuelta CBOR/Deflate/Base64 con UTF-8, números, listas y datos vacíos. | Igualdad de DTO, rechazo seguro de datos truncados y coste de CPU. |
| NET-06 | Fragmentos desordenados, repetidos, perdidos y de versiones distintas. | Reensamblado correcto o timeout sin modificar datos válidos. |
| NET-07 | Dos clientes inician sesión a la vez; después 5–10 si el grupo de prueba lo permite. | Jitter, ausencia de tormenta, cola acotada y convergencia. |
| NET-08 | Desconexión durante snapshot y posterior login. | Reanudación/repetición sin duplicados ni perfil corrupto. |
| NET-09 | Mensaje que intenta publicar por otro personaje o contiene tipos/claves inválidas. | Rechazo; identidad tomada del evento, no del payload. |
| NET-10 | Desactivar cada opción de privacidad. | Los campos excluidos no aparecen en el payload ni en la caché de salida. |

## 4. Protocolo de pruebas del Gnomómetro

Las pruebas se harán en juego normal, sin automatizar combate ni conceder datos manualmente. Cada intento registrará evidencia de diagnóstico y el resultado `contado`/`descartado` con motivo.

| ID | Escenario | Criterio |
|---|---|---|
| GN-01 | Killing blow propio sobre gnomo en mundo abierto, objetivo seleccionado. | Un solo evento aceptado; raza y atacante vinculados al mismo `targetGUID`. |
| GN-02 | Lo mismo cambiando de objetivo antes de la muerte. | Contar solo si la raza sigue pudiendo verificarse por GUID; en caso contrario descartar. |
| GN-03 | Gnomo de raza/token desconocido. | Descartar; nunca inferir por nombre/modelo. |
| GN-04 | No gnomo y NPC con apariencia similar. | No contar. |
| GN-05 | Asistencia donde otro jugador fuera del grupo realiza el killing blow. | No contar. |
| GN-06 | Killing blow de otro miembro del grupo. | No atribuirlo al usuario ODD. |
| GN-07 | Killing blow de mascota hunter y warlock; mascotas permanentes/temporales si existen. | Contar únicamente si `attackerGUID` identifica a la mascota del jugador. Si no, queda no verificado. |
| GN-08 | Mismo objetivo dos veces dentro/fuera del cooldown y eventos duplicados. | Deduplicación correcta sin bloquear una nueva kill legítima. |
| GN-09 | BG, arena, dungeon/raid y transición de entrada/salida. | Nunca contar como mundo abierto. |
| GN-10 | Comparación observable con GRS en los mismos casos. | Investigar discrepancias; GRS no se toma como verdad automática, especialmente Enhanced. |

**Puerta de Fase 3:** GN-01–GN-06 y GN-08–GN-09 deben ser consistentes. Si GN-07 no es concluyente, el Gnomómetro se lanza sin contabilizar mascotas y lo declara explícitamente; no se activa una heurística probabilística.

## 5. Pruebas PvP y profesiones

### PvP

- Comparar honor/nivel/HK de sesión/ayer/históricas con la UI nativa antes y después de una actualización.
- Confirmar que `PLAYER_PVP_KILLS_CHANGED` solo se usa como señal de refresco, no como kill de gnomo.
- Registrar un match completo de cada tipo disponible: victoria, derrota, abandono y empate si el juego lo permite. Validar `winner`, duración, facción y tipo antes de agregar W/L.
- Probar marcador durante y después del match. Si es secreto, se muestra `no disponible`, no valores inventados.
- Consultar capacidades rated antes de crear cualquier tabla de arena.

### Talleres

- Escanear cada profesión aprendida con la ventana cerrada y abierta; repetir tras aprender una receta.
- Comparar número y IDs de recetas con la UI nativa, incluidos filtros, expansiones, profesiones secundarias y habilidades nuevas de Forever.
- Resolver salida de item, encantamiento y recetas sin salida única; no fabricar nombres a partir del título de la receta.
- Comprobar que dos clientes con distinto idioma intercambian IDs y obtienen textos locales correctos.

## 6. Riesgos y alternativas

| Riesgo | Impacto | Alternativa/decisión |
|---|---|---|
| `PARTY_KILL` o raza son secretos en algunos contextos | Falsos positivos si se improvisa | Descartar el evento, registrar motivo y ofrecer cobertura parcial explícita. |
| Mascota no figura como atacante | Kills omitidas | No contar mascotas. No copiar el modo probabilístico Enhanced de GRS. |
| Cambios de API entre builds | Addon roto o datos corruptos | Capabilities por build, adaptadores, feature flags y pruebas de humo tras cada parche. |
| Throttle dinámico o hermandades grandes | Colas largas/desconexión | Manifiestos, deltas, páginas, jitter, backoff y cuotas. No enviar historiales completos periódicamente. |
| Datos remotos falsificados | Rankings manipulados | Etiqueta «declarado», owner=sender, validación de esquema; no prometer autoridad/antitrampas. |
| Datos duplicados tras sync offline | Totales inflados | IDs estables por evento, revisiones y cursores; agregados derivados. |
| SavedVariables crecen demasiado | Memoria y tiempos de carga | Retención/paginación, índices acotados y poda documentada; nunca reenviar toda la base en cada login. |
| APIs de marcador/rated presentes pero sin contenido | Métricas falsas | No disponible ≠ 0. Ocultar paneles sin capacidad. |
| Recetas incompletas con ventana cerrada | Crafters incorrectos | Escanear bajo demanda al abrir profesión y marcar fecha/cobertura del escaneo. |
| Confusión con Retail/Classic | Uso de APIs equivocadas | TOC 16001, detección Camelot y ninguna rama de compatibilidad Classic. |

## 7. Plan de implementación por puertas

### Fase 1 — Base, sin combate

1. TOC y namespace modular.
2. Inicialización, capabilities y diagnóstico.
3. SavedVariables versionados/migraciones.
4. `/odd` y dashboard con seis pestañas, estados vacíos explícitos.
5. Perfil básico y roster `C_Club`, main/alts/roles como datos declarados.
6. Pruebas ENV/DB/UI/GUILD.

**Entrega:** addon instalable sin estadísticas de combate ni sincronización todavía.

### Fase 2 — Transporte y sincronización

1. Registro/prefijo, codec y validación.
2. Cola/throttling, fragmentación/reensamblado y deduplicación.
3. `HELLO`, manifiestos, request/snapshot/ACK.
4. Presencia con jitter y botón «Sincronizar hermandad».
5. Privacidad aplicada a DTO y pruebas NET-01–NET-10.
6. Perfiles como primer dominio; profesiones/historial solo después de medir.

**Entrega:** dos o más clientes convergen sin duplicados ni tormentas.

### Fase 3 — Gnomómetro

1. Probe independiente de `PARTY_KILL`/GUID/raza/contexto.
2. Tracker conservador y registro de descartes.
3. Historial con IDs/cooldown y sincronización por lotes.
4. Estadísticas/rankings derivados y etiqueta de procedencia.
5. Mascotas solo si superan su puerta de fiabilidad.

### Fase 4 — PvP y Talleres

1. Honor/HK directos y partidas completas verificadas.
2. Marcador/rated únicamente si las pruebas los habilitan.
3. Escáner de profesiones/recetas y salidas de item.
4. Sync paginada y búsqueda de crafters.

### Fase 5 — Pulido

- Logros/medallas derivados, privacidad final, rendimiento, pruebas con hermandades de distinto tamaño y documentación de instalación/sincronización.

## 8. Siguiente acción recomendada

Revisar estas conclusiones y ejecutar las pruebas de humo al comenzar Fase 1 en una instalación real de Forever. El desarrollo del Gnomómetro no debe adelantarse a Fase 1/2 ni a la validación de `PARTY_KILL`.
