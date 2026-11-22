# Arquitectura y persistencia propuestas

**Estado:** diseño de Fase 0; todavía no implementado.

## 1. Estructura

El paquete se instalará como `OrgrimmarDesokupaDashboard` dentro de `World of Warcraft/_forever_/Interface/AddOns/`.

```text
OrgrimmarDesokupaDashboard/
  OrgrimmarDesokupaDashboard.toc
  Core/
    Init.lua
    Events.lua
    Capabilities.lua
  Database/
    Database.lua
    Migrations.lua
    Schema.lua
  API/
    Forever.lua
    Units.lua
    Guild.lua
    PvP.lua
    Professions.lua
  Gnomes/
    Tracker.lua
    Statistics.lua
  PvP/
    Tracker.lua
    Statistics.lua
  Guild/
    Roster.lua
    Profiles.lua
  Professions/
    Scanner.lua
    Recipes.lua
  Achievements/
    Rankings.lua
    Medals.lua
  Network/
    Protocol.lua
    Codec.lua
    Queue.lua
    Fragments.lua
    Sync.lua
    Validation.lua
  UI/
    Dashboard.lua
    Dashboard.xml
    Components.lua
    Tabs/
  Commands/
    Slash.lua
  Localization/
    esES.lua
    enUS.lua
  Media/
```

La estructura es una guía, no una obligación de crear archivos vacíos. Los módulos se añadirán cuando su fase tenga capacidades validadas.

## 2. Dependencias

```text
Core -> Database + API/Capabilities
Domain (Guild/PvP/Gnomes/Professions) -> API + Database
Achievements -> datos de dominio, nunca APIs de combate directamente
Network -> DTOs de dominio + Database + API de chat
UI -> modelos de lectura de dominio; no consulta combate ni red directamente
Commands -> Core/UI/Network mediante acciones públicas
```

Reglas:

- `API` es la única capa que conoce detalles variables del cliente y comprueba `issecretvalue` antes de operaciones no permitidas.
- Los módulos de dominio registran hechos y su procedencia; la UI no “completa” datos ausentes con ceros.
- `Network` no decide qué es una kill ni modifica reglas de negocio. Solo transporta registros validados.
- La recepción de red nunca ejecuta Lua ni acepta funciones, metatablas, enlaces de ruta ni claves de esquema desconocidas.

## 3. Identidad y procedencia

Cada registro debe conservar, como mínimo:

| Campo | Significado |
|---|---|
| `schemaVersion` | Versión para migraciones. |
| `ownerKey` | Personaje propietario normalizado, cuando sea legible y esté permitido. |
| `origin` | `local_observed`, `local_declared`, `remote_reported` o `derived`. |
| `observedAt` | Momento del hecho local; `nil` si no existe. |
| `receivedAt` | Momento de recepción en este cliente. |
| `sender` | Remitente informado por `CHAT_MSG_ADDON`, no por el payload. |
| `sourceRevision` | Revisión del propietario para sincronización incremental. |
| `confidence` | Naturaleza del dato; nunca equivalente a “verificado por servidor”. |

Un valor leído de una API oficial puede ser `local_observed`. Un main/alt o rol elegido por el usuario es `local_declared`/`remote_reported`. Un ranking calculado es `derived` y hereda las limitaciones de sus entradas.

La identidad de red se vincula al remitente del evento y a su presencia en el roster. Un mensaje no puede publicar estadísticas en nombre de otro personaje.

## 4. SavedVariables

Propuesta inicial:

- `ODDDB`: configuración de cuenta, perfiles conocidos, caché de roster, datos recibidos, índices de deduplicación y metadatos de sincronización.
- `ODDCharacterDB`: configuración privada del personaje, revisiones propias, observaciones de PvP/Gnomómetro y profesiones escaneadas.

Inicialización en `ADDON_LOADED` para ODD, nunca en el ámbito de archivo. `PLAYER_LOGOUT` solo para tareas finales imprescindibles; el estado debe quedar consistente al producirse cada cambio por si el cliente cierra inesperadamente.

Separación:

- Datos propios canónicos, distintos de la caché remota. Una sincronización jamás sobrescribe observaciones propias.
- Estadísticas agregadas derivadas de registros cuando sea viable, evitando duplicar totales e historial sin reconciliación.
- Índices acotados y purga documentada por antigüedad/tamaño, sin borrar silenciosamente información necesaria para rankings activos.
- Migraciones secuenciales, idempotentes y con copia de seguridad lógica del bloque anterior antes de sustituirlo.

## 5. Privacidad propuesta

| Categoría | Valor inicial propuesto |
|---|---|
| Presencia, versión de ODD y capacidades | Compartir; necesario para interoperar. |
| Nombre, nivel, clase y raza básicos | Compartir; ya pertenecen al contexto público de hermandad. |
| Main/alts y roles declarados | Configurable. |
| Estadísticas Gnomómetro/PvP | Configurable; nunca edición manual de kills. |
| Profesiones y recetas | Configurable y revisión independiente por volumen. |
| Disponibilidad como crafter | No compartir hasta elección del usuario. |
| Notas de oficial, notas privadas y campos no usados | Nunca transmitir. |
| Datos recibidos de terceros | No reenviar como propios. |

La UI debe mostrar qué se comparte antes de la primera sincronización de cada categoría opcional. La privacidad se aplica al construir el DTO, no únicamente ocultando campos en pantalla.

## 6. UI

Dashboard con seis pestañas: Cuartel General, Gnomómetro, Frente PvP, Talleres, Roster y Ajustes. No existe la pestaña Eventos.

Componentes nativos Lua/XML y templates de Blizzard cuando estén disponibles en Forever. Los estados deben distinguir:

- `sin datos`: no hay observación.
- `observado localmente`: dato de este cliente.
- `declarado por <remitente>`: dato remoto no verificado.
- `no disponible en este cliente`: capacidad ausente/restringida.
- `pendiente`, `enviando`, `sincronizado` y `error`: estado de comunicación.

Cero solo se muestra cuando el cero es un valor observado; no como sustituto de `nil` o de una API bloqueada.

## 7. Capacidades y degradación

`Capabilities` registrará por build la existencia y el resultado de pruebas concretas, no una bandera global `isRetail`.

- Comprobar `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` cuando la constante exista e `Interface 16001` mediante `GetBuildInfo`.
- Probar cada función/espacio de nombres antes de usarlo.
- Tratar cualquier retorno potencialmente secreto antes de comparar, ordenar, serializar, calcular longitud o imprimir.
- Mantener capacidad `unknown` hasta que una prueba real la confirme; `false` significa ausencia observada, no “todavía no probado”.
- No usar `pcall` como permiso para llamadas protegidas ni para convertir datos restringidos en estadísticas aparentemente válidas.
