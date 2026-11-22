# Fase 0 — Investigación de WoW Forever y GRS

**Fecha de corte:** 2026-11-22.  
**Objetivo:** Interface 16001 / juego 1.60.1, exclusivamente WoW Forever.

## 1. Alcance y método

- El directorio del proyecto estaba vacío y no es un repositorio Git.
- No hay una instalación del cliente ni archivos de interfaz dentro del directorio de trabajo. Por tanto, esta iteración **no incluye ejecución dentro del juego**.
- Se inspeccionó el espejo de código de interfaz `Gethe/wow-ui-source`, rama `forever`, commit `734f065329cff4992835b01a84f210a297db91b6` (20-11-2026), incluidos sus archivos de documentación generada por Blizzard y la UI específica `Camelot`.
- Se contrastaron Warcraft Wiki, una medición pública en build 70938 y la documentación/paquete público de GRS. No se copió código ni recurso de GRS al proyecto.
- Herramientas locales: PowerShell, Git y tar disponibles; no hay intérprete `lua`/`luac`. No se instalaron dependencias.

### Escala de evidencia

| Marca | Significado |
|---|---|
| **Fuente** | La función, evento, campo o restricción aparece en el código de interfaz Forever inspeccionado. |
| **Medición de terceros** | Otro autor afirma haberlo probado en una build concreta; no es una prueba propia. |
| **Documentación del autor** | Comportamiento declarado por GRS u otra fuente pública. |
| **Hipótesis de diseño** | Propuesta técnica que todavía debe probarse. |
| **Pendiente en juego** | No se puede afirmar comportamiento final hasta ejecutar la prueba en Forever. |

## 2. Cliente y arquitectura real

- La documentación de cambios 1.60.1 fija **TOC `16001`** y añade el game type `forever`, equivalente al nombre interno `camelot`.
- El archivo `Blizzard_ProjectConstants/Camelot/ProjectConstants.lua` contiene `WOW_PROJECT_CAMELOT = 18` y asigna ese valor a `WOW_PROJECT_ID`.
- Forever pertenece a la familia de interfaz moderna/Mainline y comparte gran parte de la API 12.1.5, **pero no es Retail y no debe seleccionarse una ruta Classic**.
- La detección propuesta combina la constante `WOW_PROJECT_CAMELOT`, la interfaz obtenida con `GetBuildInfo` y comprobaciones de capacidad. Nunca se inferirá compatibilidad únicamente por `WOW_PROJECT_ID`.
- El sitio de datos wow-forever.gg registra como última build comparada **1.60.1.71037** el 21-11-2026. La fuente de interfaz inspeccionada es un commit del 20-11; no se afirma que ambos identificadores representen exactamente la misma build.
- Las restricciones modernas incluyen valores secretos: no se puede comparar, ordenar, calcular, obtener longitud o serializar un valor secreto. `SecretInChatMessagingLockdown`, `SecretWhenUnitIdentityRestricted`, `SecretInActivePvPMatch` y predicados similares importan para ODD.

## 3. APIs y eventos inspeccionados

### 3.1 Ciclo de vida y persistencia

| Capacidad | Evidencia | Restricción/pendiente |
|---|---|---|
| `ADDON_LOADED`, `PLAYER_LOGIN`, `PLAYER_LOGOUT` | Arquitectura moderna y documentación de SavedVariables. | Inicializar SavedVariables al cargar ODD, no al ejecutar el archivo. |
| SavedVariables / PerCharacter | Fuente y documentación 1.60.1. | La beta tuvo un fallo de restauración; las notas lo marcan corregido en build 70009. Probar en la build actual. |
| Lua/XML nativo | UI Forever disponible. | Comprobar cada template; no presuponer todos los de Retail. |
| `C_Timer` | API moderna usada por la interfaz. | Temporizadores para cola, TTL y jitter; no polling cuando exista evento. |

### 3.2 Comunicación

La fuente `ChatInfoDocumentation.lua` declara:

- `C_ChatInfo.RegisterAddonMessagePrefix(prefix)` → `RegisterAddonMessagePrefixResult`.
- `C_ChatInfo.SendAddonMessage(prefix, message [, chatType, target])` → `SendAddonMessageResult`.
- `CHAT_MSG_ADDON` con `prefix`, `text`, `channel`, `sender`, `target` y metadatos.
- `AreOutgoingAddonChatMessagesRestricted()` e `InChatMessagingLockdown()`.
- `SendAddonMessage` no admite argumentos secretos.

Warcraft Wiki etiqueta la función para Forever y documenta:

- Prefijo máximo 16 caracteres; mensaje máximo 255 caracteres; NUL no permitido.
- `GUILD`, `PARTY`, `RAID`, `INSTANCE_CHAT`, `WHISPER`, etc.; ODD solo necesita `GUILD` inicialmente.
- `Success` indica que el mensaje fue encolado, no que llegara.
- Resultados para prefix/mensaje/canal inválido, throttle, ausencia de grupo/hermandad, lockdown y destinatario offline.
- Throttle por prefijo configurable por servidor; referencia general de ráfaga 10 y recuperación 1/s.
- Cuentas trial/veteran sin permiso de envío en Forever.

La fuente `EncodingUtilDocumentation.lua` declara CBOR, JSON, Deflate/Zlib/Gzip, Base64 y Hex. ODD puede evitar librerías externas, pero debe probar el pipeline elegido en juego.

### 3.3 Combat log y alternativa

La presencia de `CombatLogDocumentation.lua` no prueba que el contenido sea legible por addons:

- Existen `COMBAT_LOG_EVENT`/`COMBAT_LOG_EVENT_UNFILTERED` en la documentación, junto a `C_CombatLog.IsCombatLogRestricted`.
- `C_CombatLogSecure.GetCurrentEventInfo`, `GetCurrentEntryInfo` y otras llamadas tienen `HasRestrictions`.
- `COMBAT_LOG_MESSAGE` se documenta como mensaje preformateado protegido por wrapper `|K`.
- Una medición pública de Grimoire en **1.60.1.70938**, en mundo abierto, registró **eventos de combat log no entregados** tanto dentro como fuera de combate.

**Decisión:** ODD no se basará en `COMBAT_LOG_EVENT_UNFILTERED` ni intentará reconstruir estadísticas a partir de texto de chat. La alternativa a validar es `PARTY_KILL` y consultas de unidad, no el combat log.

### 3.4 Identificación de killing blows y raza

La fuente `UnitDocumentation.lua` declara:

- `PARTY_KILL(attackerGUID, targetGUID)`, marcado `SecretWhenUnitIdentityRestricted`.
- `UnitRace(unit)` → `localizedRaceName`, `englishRaceName`, `raceID`, también sujeto a restricción de identidad.
- `UnitTokenFromGUID(guid)`, `UnitGUID(unit)`, `UnitName`, `UnitLevel`, `UnitIsPlayer`, `UnitIsDead`.
- `PLAYER_PVP_KILLS_CHANGED(unitTarget)`, útil para refrescar HK agregadas, pero sin víctima en el payload.

**Hipótesis que debe probarse:** en mundo abierto, un `PARTY_KILL` cuyo `attackerGUID` coincide con el jugador o su mascota puede constituir evidencia de killing blow. Para clasificarlo como gnomo se necesita además una consulta de raza no secreta y vinculada al `targetGUID` del mismo evento. Si no hay token/raza fiable, se descarta.

No se deducirá raza a partir del nombre, apariencia, modelo, guild, nivel o una kill honorable. Un HK sin `PARTY_KILL` no demuestra killing blow propio.

### 3.5 Roster y profesiones

- `C_Club.GetGuildClubId`, `GetClubMembers` y `GetMemberInfo` están presentes. La UI nativa obtiene los IDs y consulta cada miembro.
- `ClubMemberInfo` contiene `memberId`, `name`, `guid`, `classID`, `race`, `level`, `zone`, `guildRank`, presencia, última conexión y `profession1/2ID`, rango y nombre.
- Algunas llamadas requieren clubs inicializados y pueden ser secretas durante chat lockdown. Se refrescará con eventos de roster/club y se omitirán campos no legibles.
- La UI `Camelot` sigue usando `GetProfessions` y `GetProfessionInfo` para las profesiones aprendidas.
- `C_TradeSkillUI.GetProfessionInfoBySkillLineID` devuelve `ProfessionInfo` con `skillLevel`, `maxSkillLevel`, IDs y nombres.
- `GetProfessionSpells` devuelve IDs de hechizos conocidos; `GetRecipeInfo` incluye `learned`, `recipeID`, `skillLineAbilityID`, salida/flags y otros metadatos.
- `GetRecipeOutputItemData` existe para resolver la salida, pero no toda receta fabrica un único item (encantamiento, gathering, recraft, salidas múltiples).

### 3.6 PvP

- Propios: `UnitHonor`, `UnitHonorMax`, `UnitHonorLevel`; cambios mediante `HONOR_XP_UPDATE`.
- `GetPVPSessionStats` → HK/DK de sesión; `GetPVPYesterdayStats` → HK/DK de ayer; `GetPVPLifetimeStats` → HK históricas y rango máximo.
- La UI Camelot de inspección usa `GetInspectHonorData` e `INSPECT_HONOR_UPDATE`, incluyendo HK de hoy/históricas y progreso de honor. Esto solo aplica al flujo de inspección.
- `PVP_MATCH_COMPLETE` entrega `winner` y `duration`; también existen estado, tipo y ganador del match.
- `GetScoreInfo`/`GetScoreInfoByPlayerGuid` tienen `SecretInActivePvPMatch`: el marcador detallado no debe darse por legible durante la partida.
- Existen APIs de arena/rated, pero su presencia no demuestra que el modo esté habilitado en Forever.

## 4. Investigación de GRS

### Hechos públicos

- Proyecto oficial: **GRS — Gnome Removal Service**, autor `schoolie`, CurseForge ID 1810396.
- Versión examinada: **0.13.7.1**, publicada el 20-11-2026 para Forever 1.60.1, `Interface: 16001`.
- Licencia: **All Rights Reserved unless otherwise explicitly stated**. No se ha copiado código, arte, sonidos ni otro recurso.
- No hay una API pública estable documentada para terceros. Sus comandos `/grs` son interfaz de usuario, no API programática.
- El prefijo/protocolo `GRSIND1` v1 está documentado como mecanismo GRS↔GRS, no como contrato público de integración.

### Comportamiento declarado por su autor

- Killing blows sobre jugadores gnomo en mundo abierto, propios o de mascota.
- Exclusión de asistencias, BG, arenas e instancias.
- Raza desconocida no contada; misma víctima puede repetir tras 15 s y hay protección contra duplicados.
- Clasificaciones, recuperación offline, insignias, rachas y sincronización sin servidor externo.
- La identificación estática del paquete contiene referencias a `PARTY_KILL`, consultas de raza/GUID y eventos de unidad, coherentes con la alternativa propuesta para ODD. Estas referencias no prueban por sí solas el resultado de cada llamada en ejecución.

### Límites reconocidos por el propio GRS

- La detección **Enhanced (Experimental)** de mascotas puede omitir o atribuir incorrectamente.
- Su documentación indica que ciertos casos de mascota y recuperación entre ordenadores no estaban verificados en Forever.
- Por tanto, GRS demuestra que existe una implementación pública con ese objetivo, **no que todos los casos sean fiables ni que ODD deba reproducir sus heurísticas**.

### Decisión de integración

No hay base para una integración directa estable. ODD desarrollará una implementación independiente basada en eventos/APIs verificados. No leerá la base interna de GRS, no usará `GRSIND1` y no dependerá de GRS instalado. En pruebas puede compararse observablemente el resultado de ambos addons, sin tratar a GRS como oráculo.

## 5. Dudas pendientes que bloquean funciones concretas

| Pregunta | Bloquea |
|---|---|
| ¿`PARTY_KILL` llega en solo, grupo y con mascota en la build actual? ¿Su atacante es legible? | Conteo de kills propias/mascota. |
| ¿Puede resolverse `targetGUID` a raza no secreta aunque el jugador cambie de objetivo? | Víctimas/rachas/log de gnomos. |
| ¿Qué ocurre al cambiar de fase/instancia durante el evento? | Exclusión fiable de BG/arena/instancias. |
| ¿Cuál es el límite/throttle efectivo y qué mensajes devuelve el envío real? | Fragmentación y tiempos de sincronización. |
| ¿CBOR + Deflate + Base64 hace ida y vuelta en dos clientes sin transformar datos? | Codec de red. |
| ¿`GetProfessionSpells` enumera todas las recetas con la ventana cerrada? | Escaneo automático de Talleres. |
| ¿Qué datos del marcador siguen siendo legibles al terminar un match? | Estadísticas detalladas BG. |
| ¿Cómo se representan empate, abandono y facción en `PVP_MATCH_COMPLETE`? | Victorias/derrotas. |
| ¿Qué modos rated están habilitados realmente? | Panel de arenas/ratings. |

Estas preguntas se convierten en pruebas explícitas en `05-validacion-y-plan.md`; no se resolverán mediante suposiciones de Retail.
