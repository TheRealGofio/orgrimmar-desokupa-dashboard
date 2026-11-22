# Fuentes de Fase 0

Consulta: 2026-11-22. Se priorizan fuentes del cliente y documentación específica de Forever. Las páginas comunitarias no se consideran prueba propia de ejecución.

## Código de interfaz Forever

Espejo inspeccionado: `Gethe/wow-ui-source`, rama `forever`, commit [`734f065329cff4992835b01a84f210a297db91b6`](https://github.com/Gethe/wow-ui-source/commit/734f065329cff4992835b01a84f210a297db91b6), 20-11-2026.

Base para enlaces: `https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/`.

- [Constantes de proyecto Camelot](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_ProjectConstants/Camelot/ProjectConstants.lua): `WOW_PROJECT_CAMELOT = 18`.
- [ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): mensajería, prefijos, recepción y restricciones.
- [EncodingUtilDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncodingUtilDocumentation.lua): CBOR, JSON, compresión y Base64.
- [CombatLogDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua) y [CombatLogSecureDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogSecureDocumentation.lua): presencia de APIs y restricciones; no evidencia de legibilidad.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua): `PARTY_KILL`, raza, GUID, honor y predicados secretos.
- [ClubDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClubDocumentation.lua): roster y estructura `ClubMemberInfo`.
- [CommunitiesUtil.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_FrameXMLUtil/CommunitiesUtil.lua): uso nativo de miembros del club.
- [GuildRoster.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_Communities/GuildRoster.lua): actualización y presentación del roster.
- [TradeSkillUIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua) y [TradeSkillUITypesDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua): profesiones, recetas y estructuras.
- [UI de profesiones Camelot](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua): uso de `GetProfessions`/`GetProfessionInfo` en Forever.
- [PlayerScriptDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerScriptDocumentation.lua): estadísticas HK de sesión/ayer/históricas.
- [PvpInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_APIDocumentationGenerated/PvpInfoDocumentation.lua): match, marcador y restricciones.
- [UI de inspección PvP Camelot](https://github.com/Gethe/wow-ui-source/blob/734f065329cff4992835b01a84f210a297db91b6/Interface/AddOns/Blizzard_InspectUI/Camelot/InspectPVPFrame.lua): flujo `GetInspectHonorData`/`INSPECT_HONOR_UPDATE`.

## Documentación de API y cliente

- [Warcraft Wiki — Patch 1.60.1 API changes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes): TOC 16001, game type Forever/Camelot, correcciones y diferencias.
- [Warcraft Wiki — C_ChatInfo.SendAddonMessage](https://warcraft.wiki.gg/wiki/API:C_ChatInfo.SendAddonMessage): límites, resultados, canales, throttling y restricciones de cuentas.
- [Warcraft Wiki — C_ChatInfo.RegisterAddonMessagePrefix](https://warcraft.wiki.gg/wiki/API:C_ChatInfo.RegisterAddonMessagePrefix): registro y resultados.
- [Warcraft Wiki — PARTY_KILL](https://warcraft.wiki.gg/wiki/Event:PARTY_KILL): payload `attackerGUID`, `targetGUID` y predicado de identidad.
- [Warcraft Wiki — Secret Values](https://warcraft.wiki.gg/wiki/Secret_Values): operaciones prohibidas y predicados.
- [Blizzard — Developer Q&A del 17-09-2026](https://www.youtube.com/watch?v=Y5zzSMSVhRo&t=4852s): respuesta sobre enfoque moderno de addons; fuente audiovisual, no prueba de cada API.
- [wow-forever.gg — Build Changelog](https://wow-forever.gg/changelog/): última build de datos observada al consultar, 1.60.1.71037 del 21-11-2026. Sitio fan-made.

## Medición pública de terceros

- [Grimoire — FOREVER-API.md](https://github.com/Golorom/Grimoire/blob/main/docs/FOREVER-API.md): mediciones del autor en build 70938, incluida ausencia de entrega de combat log en mundo abierto y secretos. No son pruebas de ODD ni una garantía para builds posteriores.
- [WoW Forever Guides — Addon Development Guide](https://wowforeverguides.com/addons/developers) y [API Cheat Sheet](https://wowforeverguides.com/addons/api-cheatsheet): referencias secundarias usadas para localizar fuentes; varias observaciones son beta y se han tratado como tales.
- [WoW Forever Wiki — Addons](https://wowforeverwiki.org/addons): resumen comunitario con niveles de evidencia.

## GRS

- [Proyecto oficial en CurseForge](https://www.curseforge.com/wow/addons/grs-gnome-removal-service).
- [Archivo v0.13.7.1](https://www.curseforge.com/wow/addons/grs-gnome-removal-service/files/9717960), publicado 20-11-2026 para Forever 1.60.1.
- [Historial de archivos](https://www.curseforge.com/wow/addons/grs-gnome-removal-service/files/all?page=1&pageSize=20&showAlphaFiles=hide).
- [Licencia](https://www.curseforge.com/wow/addons/grs-gnome-removal-service/license): All Rights Reserved unless otherwise explicitly stated.
- [Galería/documentación visual](https://www.curseforge.com/wow/addons/grs-gnome-removal-service/gallery).
- [Dependencias declaradas de v0.13.7.1](https://www.curseforge.com/wow/addons/grs-gnome-removal-service/files/9717960/dependencies).

El paquete público v0.13.7.1 se examinó estáticamente para documentación e identificadores; no se copiaron implementaciones ni recursos. Su SHA-256 fue `4fff7270ac517e5ab17e801e37dee5b31958a50b7b42b56ebab56f1e9aff123d`.

## OpenCode (configuración local del proyecto)

- [Configuración V2](https://opencode.ai/docs/config).
- [Permisos V2](https://opencode.ai/docs/permissions): reglas `permissions`, acciones `allow`/`ask`/`deny`; aplicadas solo al archivo `opencode.jsonc` de este proyecto.
