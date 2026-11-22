# Matriz de viabilidad funcional

Fecha: 2026-11-22. **Viable en fuente** significa que la API/evento aparece en el código de interfaz inspeccionado; no sustituye una prueba dentro de WoW Forever. **Condicionada** exige una prueba de comportamiento antes de activar la función.

| Función | Clasificación | Evidencia y alcance | Condición/limitación |
|---|---|---|---|
| Dashboard Lua/XML con seis pestañas | **Viable en fuente** | Forever usa la UI moderna y admite addons; interfaz 16001. | Probar templates concretos y lockdown. No existe pestaña Eventos. |
| `/odd` | **Viable en fuente** | Comandos slash y SavedVariables forman parte de la arquitectura moderna. | Registrar globals únicamente para comandos. |
| SavedVariables | **Viable en fuente** | Documentación de ciclo de vida; el fallo beta de restauración figura corregido desde build 70009. | Prueba propia de `/reload`, logout y cambio de personaje. |
| Roster de hermandad | **Viable en fuente** | `C_Club.GetGuildClubId`, `GetClubMembers`, `GetMemberInfo`, `GUILD_ROSTER_UPDATE`; `ClubMemberInfo` incluye nombre, GUID, clase, raza, nivel, rango, conexión y dos profesiones. | Requiere clubs inicializados y roster actualizado. Datos pueden ser secretos durante chat lockdown; no serializar secretos. |
| Main/alts y roles | **Viable con alcance declarado** | Se pueden guardar perfiles y compartirlos. | Son declaraciones del usuario, no vínculos de cuenta verificados por servidor. No inferir main/alts desde achievement points u otros datos. |
| Presencia y sincronización `GUILD` | **Condicionada, base sólida** | Existen registro, envío, evento de recepción, resultados de error y codecs en la fuente; límite documentado 255 caracteres. | Prueba real de recepción, throttling y restricciones con 2+ clientes. Trial/veteran no pueden enviar; chat lockdown puede impedirlo. |
| Sincronización incremental bidireccional | **Viable como diseño propio** | Revisiones/manifiestos y deduplicación no necesitan APIs adicionales. | Solo tras validar transporte. Nunca afirmar recepción basándose en `Success`. |
| Gnomómetro: killing blow propio | **Condicionada** | `PARTY_KILL(attackerGUID, targetGUID)` y `UnitGUID` están en la fuente; GRS documenta que el comportamiento es posible. | Probar solo, grupo, asistencia y cambio de objetivo. Solo contar cuando atacante y víctima estén suficientemente identificados. |
| Gnomómetro: raza | **Condicionada** | `UnitRace` devuelve nombre localizado, nombre inglés y `raceID`; `UnitTokenFromGUID` está presente. GRS documenta identificación mediante raza/GUID. | La unidad puede no tener token disponible y los datos pueden ser secretos. Raza desconocida ⇒ descartar, nunca asumir gnomo. |
| Gnomómetro: mascota | **Condicionada/alto riesgo** | `PARTY_KILL` incluye atacante; existe `UnitGUID("pet")` como consulta candidata. | Probar hunter/warlock y mascota temporal. GRS reconoce que su Enhanced es experimental y puede fallar/atribuir mal. Sin evidencia directa no se concede kill. |
| Excluir BG/arena/instancias | **Condicionada, APIs presentes** | `C_PvP.IsActiveBattlefield`, `IsBattleground`, `IsArena` y eventos de instancia están presentes. | Probar transiciones; contexto desconocido no se cuenta como mundo abierto. |
| Cooldown por víctima | **Viable como lógica propia** | `targetGUID` y temporizadores permiten deduplicar. | Elegir y probar ventana; evita duplicados de evento, no convierte asistencias en kills. |
| Integración directa con GRS | **No disponible como integración estable** | GRS v0.13.7.1 no documenta API pública; `GRSIND1` es compatibilidad GRS↔GRS, no contrato de terceros. | Implementación independiente. No usar su protocolo interno ni copiar código/recursos. |
| Honor y nivel de honor propios | **Viable en fuente** | `UnitHonor`, `UnitHonorMax`, `UnitHonorLevel` y `HONOR_XP_UPDATE`. | Comparar con la UI nativa; etiquetar instantánea y fecha. |
| HK de sesión/ayer/históricas | **Viable en fuente** | `GetPVPSessionStats`, `GetPVPYesterdayStats`, `GetPVPLifetimeStats`; `PLAYER_PVP_KILLS_CHANGED` indica actualización. | El evento no identifica a la víctima. HK no equivale a killing blow ni a kill de gnomo. |
| Honor/HK de otro jugador | **Condicionada y limitada** | La UI Camelot usa `GetInspectHonorData` tras inspección/`INSPECT_HONOR_UPDATE`. | No es una consulta arbitraria de hermandad. Los datos compartidos por ODD son declarados por el propietario. |
| Victorias/derrotas BG/arena observadas | **Condicionada** | `PVP_MATCH_COMPLETE(winner,duration)`, `GetActiveMatchWinner`, estado/tipo de match. | Confirmar significado de winner, abandono, empate y facción propia. Solo registrar partidas cuyo desenlace se observa completo. |
| Marcador detallado de BG | **Condicionada/restringida** | `GetScoreInfo` y `GetScoreInfoByPlayerGuid` existen. | Ambos llevan `SecretInActivePvPMatch`; no se puede prometer lectura/agregación durante la partida. Probar post-match. |
| Arenas y estadísticas rated | **Condicionada por disponibilidad real** | Existen `CanPlayerUseRatedPVPUI`, `PVP_RATED_STATS_UPDATE` y APIs relacionadas. | La presencia de API no demuestra que Forever tenga ese modo habilitado. No mostrar ceros si la función no está disponible. |
| Profesiones y nivel | **Viable en fuente** | La UI Camelot usa `GetProfessions`/`GetProfessionInfo`; `C_TradeSkillUI` expone `ProfessionInfo` con nivel/máximo. | Probar profesiones primarias/secundarias y habilidades nuevas de Forever. |
| Recetas conocidas | **Condicionada, base sólida** | `C_TradeSkillUI.GetProfessionSpells`, `GetRecipeInfo` y campo `learned` están documentados. | Verificar enumeración completa con ventana abierta/cerrada y tras `TRADE_SKILL_*`/`NEW_RECIPE_LEARNED`. |
| Objeto fabricable por receta | **Condicionada** | `GetRecipeOutputItemData` y `TradeSkillRecipeInfo` están presentes. | Encantamientos, recetas múltiples, recraft y gathering pueden no producir un único objeto. No inventar salida. |
| Crafters de hermandad | **Viable con datos declarados** | Roster incluye dos profesiones; recetas detalladas pueden sincronizarse con ODD. | Privacidad, volumen y revisión. `QueryGuildMemberRecipes` existe pero no sustituye la validación de cobertura/formato. |
| Logros, medallas y rankings | **Viable como derivados** | Se calculan con datos de dominio. | Nunca por kills manuales. Datos remotos marcados como declarados; no antitrampas. |
| Tracking mediante combat log | **No viable como base actual** | La fuente contiene APIs restringidas, pero una medición en build 70938 no recibió eventos de combat log; `C_CombatLogSecure` marca restricciones. | ODD no usará `COMBAT_LOG_EVENT_UNFILTERED` como solución. Cualquier cambio futuro exige nueva investigación. |

## Decisiones de alcance

1. **Fase 1 no depende de combate.** Dashboard, persistencia, perfil y roster pueden avanzar después de una prueba de humo.
2. **Fase 2 se limita al transporte.** Primero presencia y perfil pequeño; recetas e historial se añaden tras medir fragmentación.
3. **Fase 3 comienza con `PARTY_KILL`, no con combat log.** Si raza o atacante no son legibles, se registra un diagnóstico y no una eliminación.
4. **PvP separa cuatro conceptos:** HK, killing blows, victorias de match y datos de marcador. No se intercambian entre sí.
5. **Talleres comparte IDs, no textos libres.** Reduce bytes y evita inconsistencias de localización.
6. **Lo remoto nunca se denomina verificado por servidor.** Solo es una copia de lo declarado por otro cliente ODD.
