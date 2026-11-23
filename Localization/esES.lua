local addonName, addonTable = ...

-- Tabla de traducciones
local L = {}
addonTable.L = L

-- Por defecto esES (idioma principal del proyecto)
L["ADDON_TITLE"] = "Orgrimmar Desokupa Dashboard"
L["CMD_HELP_TITLE"] = "Comandos de Orgrimmar Desokupa Dashboard (ODD):"
L["CMD_HELP_SHOW"] = "  /odd show - Abre o cierra el panel principal."
L["CMD_HELP_STATUS"] = "  /odd status - Muestra el estado del entorno y las capacidades detectadas."
L["CMD_HELP_VERSION"] = "  /odd version - Muestra la versión instalada y la build del cliente."
L["CMD_UNKNOWN"] = "Comando no reconocido. Escribe /odd help para ver la lista."

-- Pestañas
L["TAB_HQ"] = "General"
L["TAB_GNOMOMETER"] = "Gnomómetro"
L["TAB_MEDALS"] = "Logros"
L["TAB_PVP"] = "PvP"
L["TAB_WORKSHOPS"] = "Profesiones"
L["TAB_ROSTER"] = "Miembros"
L["TAB_SETTINGS"] = "Ajustes"

-- Estados de datos y procedencia
L["STATUS_NO_DATA"] = "Sin datos disponibles"
L["STATUS_LOCAL_OBSERVED"] = "Observado localmente"
L["STATUS_DECLARED_BY"] = "Declarado por %s (no verificado)"
L["STATUS_UNAVAILABLE"] = "Capacidad no disponible en este cliente"
L["STATUS_PHASE_PENDING"] = "Módulo previsto para fase posterior (%s)"

-- Ajustes
L["SETTINGS_PRIVACY_HEADER"] = "Privacidad y sincronización"
L["SETTINGS_SHARE_PRESENCE"] = "Compartir presencia y versión de ODD"
L["SETTINGS_SHARE_PROFILE"] = "Compartir rol y personajes secundarios declarados"
L["SETTINGS_SHARE_STATS"] = "Compartir estadísticas de combate declaradas"
L["SETTINGS_SHARE_TRADES"] = "Compartir recetas y profesiones conocidas"
L["SETTINGS_ANNOUNCE_GUILD"] = "Anunciar bajas de gnomos por el chat de hermandad (/g)"
L["SETTINGS_SAVE_BUTTON"] = "Guardar cambios"
