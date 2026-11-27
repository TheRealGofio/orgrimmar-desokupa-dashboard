# Orgrimmar Desokupa Dashboard (ODD)

[![WoW Forever](https://img.shields.io/badge/WoW%20Forever-1.60.1%20(Interface%2016001)-orange.svg)](https://github.com/TheRealGofio/orgrimmar-desokupa-dashboard)
[![Release](https://img.shields.io/github/v/release/TheRealGofio/orgrimmar-desokupa-dashboard?color=red)](https://github.com/TheRealGofio/orgrimmar-desokupa-dashboard/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> *«La Horda no negocia con inquilinos ilegales de 90 centímetros. Donde haya un gnomo, habrá un desahucio exprés.»*

---

## 🎯 ¿Qué es Orgrimmar Desokupa Dashboard?

**Orgrimmar Desokupa Dashboard (ODD)** es un addon nativo en clave de humor para hermandades de la **Horda** en **World of Warcraft Forever (1.60.1 / Interface 16001)**.

Nacido originalmente para la hermandad *Orgrimmar Desokupa*, el addon está diseñado para que **cualquier hermandad de la Horda** pueda instalarlo y disfrutarlo al instante de forma completamente autónoma. Transforma el PvP de mundo abierto en una divertida «empresa de desalojo de gnomos», gamificando la caza de la Alianza con clasificaciones internas, contratos semanales, logros de hermandad, memes sonoros y estadísticas de combate.

---

## ⚔️ Características Principales

### 🏢 1. Cuartel General (HQ)
- **Ficha del Desokupador:** Muestra tu personaje, rol declarado (DPS, Tanque, Sanador, Desokupador, Artesano) y un **modelo 3D nativo e interactivo** que puedes rotar en tiempo real.
- **Resumen Global de Bajas:** Contadores de bajas personales (totales, hoy y esta semana), bajas globales de la hermandad y puntos de logro acumulados.
- **Contratos Semanales de Desalojo:** Objetivos deterministas que se reinician semanalmente para toda la hermandad (por ejemplo: *Operación Desahucio en Trabalomas* o *Cazarratas de las Sombras*).

### 📏 2. Gnomómetro & Leaderboard
- **Ranking de Hermandad en Vivo:** Tabla de clasificación ordenada por bajas de gnomos o puntos de logro con colores de clase y títulos honoríficos.
- **Rigor en los Datos:** Distingue entre bajas **Verificadas** (observadas directamente en tu cliente) y **Declaradas** (recibidas por P2P de compañeros de guild).
- **Radar de Proximidad:** Alerta visual y sonora instantánea cuando un gnomo enemigo aparece cerca o en tus placas de nombre (*nameplates*).

### 🏆 3. Medallas y Logros de Hermandad
- **19 Logros Temáticos:** Desde *Primer Desalojo*, *Rompeengranajes* y *Azote de Gnomeregan* hasta hazañas por clase (*Pisa-diablillos*, *Cortahechizos*) y gnomos de nivel calavera (*David contra Goliat al Revés*).
- **Compartir en Chat:** Modal emergente para inspeccionar logros y botón para compartirlos con enlace interactivo en `/g` o en tu grupo.

### 📜 4. Registro de Desahucios & Zonas Calientes
- **Heatmap de Zonas:** Identifica los territorios más conflictivos donde vuestra hermandad está concentrando las operaciones.
- **Historial Detallado:** Registro cronológico con fecha, ejecutor, gnomo eliminado, zona y modificadores especiales (*[Comiendo]*, *[Montura]*, *[Grupo Guild]*).

### 🔊 5. Soundboard de Hermandad
- **25 Audios y Memes Clásicos:** Reproduce sonidos célebres (*El Butano*, *Bruh*, *Discord Ping*, *Txapote*, *Me están matando*, etc.) que se transmiten instantáneamente a los miembros de tu grupo o banda.
- **Ventana Flotante:** Posibilidad de abrir el soundboard en una mini-ventana independiente y arrastrable.
- **Atajos y Macros:** `Shift + Clic` en cualquier sonido para crear automáticamente una macro en tus barras de acción.

### 🛡️ 6. Frente PvP & Lista de Némesis
- Estadísticas oficiales de honor de WoW Forever (Hoy, Ayer, Histórico y Rango militar).
- Historial de victorias y derrotas en Campos de Batalla (BGs).
- **Lista Negra de Némesis:** Rastrea a los enemigos de la Alianza que más te han matado en mundo abierto para planear tu venganza.

### 👥 7. Roster Dinámico de Hermandad
- Listado de miembros en tiempo real con indicador de conexión, nivel, zona y rango.
- Buscador rápido por texto y filtro para mostrar solo compañeros conectados.

### 🎨 8. Personalización y Temas Visuales
- **Selector de Temas Desplegable:** Cambia el aspecto estético del marco principal entre 7 estilos únicos:
  - 🪓 *Orco Clásico*
  - 🔥 *Hierro y Magma*
  - 🧪 *Añublo Vil*
  - ❄️ *Hielo Rasganorte*
  - 🎭 *Vudú Trol*
  - 🍃 *Espíritu Druida*
  - ☀️ *Luz Sagrada (Paladín)*
- **Bordes y Florituras Dinámicas:** Las cajas y secciones adaptan su borde ornamental al color característico del tema elegido sobre fondos oscuros de alto contraste.
- **Escala de Interfaz y Zoom:** Botones para ajustar el tamaño del dashboard o auto-adaptarlo según la resolución de tu pantalla.
- **HUD Flotante:** Pequeño rastreador compacto en pantalla para monitorizar tus bajas del día sin abrir la ventana grande.

---

## 🌐 ¿Cómo Funciona la Sincronización entre Jugadores?

- **100% P2P (Sin Servidores Externos):** ODD no requiere servidores web, bases de datos externas ni registros de usuario. Toda la sincronización viaja por el canal de chat interno de la hermandad (`C_ChatInfo.SendAddonMessage`).
- **Completamente Aislado por Hermandad:** Si otra hermandad instala el addon, sus miembros sincronizarán exclusivamente entre ellos. Los datos nunca se mezclan ni interfieren entre guilds.
- **Respeto a la Privacidad:** Desde la pestaña *Ajustes*, cada jugador puede decidir si desea compartir su presencia, sus estadísticas de combate o silenciar anuncios en el chat.

---

## 📦 Instalación

1. Descarga el archivo más reciente desde [Releases](https://github.com/TheRealGofio/orgrimmar-desokupa-dashboard/releases) (`OrgrimmarDesokupaDashboard-vX.Y.Z-alpha.zip`).
2. Descomprime el contenido en la carpeta de addons de tu cliente de WoW Forever:
   ```text
   World of Warcraft\_forever_\Interface\AddOns\
   ```
3. Asegúrate de que la carpeta resultante se llame exactamente:
   ```text
   OrgrimmarDesokupaDashboard
   ```
4. Inicia el juego o escribe `/reload` si ya estás conectado.

---

## 🕹️ Comandos del Chat

| Comando | Acción |
| :--- | :--- |
| `/odd` | Abre o cierra el Dashboard principal. |
| `/odd sync` | Solicita una sincronización manual de bajas y presencia con los miembros de la hermandad en línea. |
| `/odd hud` | Muestra u oculta el HUD flotante compacto en pantalla. |
| `/odd reset` | Restablece la posición central del marco si se ha movido fuera de la pantalla. |
| `/odd help` | Muestra la ayuda rápida en el chat. |

---

## ⚖️ Política de Addons y Juego Limpio

Este addon cumple estrictamente con la **World of Warcraft Add-On Development Policy** de Blizzard:
- **Gratuito y de Código Abierto:** Sin micropagos, sin suscripciones y sin funciones de pago.
- **Sin Automatización ni Botting:** No realiza acciones de combate automáticas, no hackea memoria y opera 100% dentro del entorno protegido de la API oficial de Blizzard.
- **Sin Publicidad:** Cero anuncios comerciales y sin recaudación de donaciones dentro del juego.

---

## 🛠️ Documentación Técnica & Arquitectura

Para desarrolladores y curiosos del motor de WoW Forever (Interface 16001), la investigación de compatibilidad de API y arquitectura modular se encuentra documentada en la carpeta `docs/fase-0/`:
- [Informe de Investigación de APIs de Forever](docs/fase-0/01-investigacion.md)
- [Matriz de Viabilidad Funcional](docs/fase-0/02-viabilidad.md)
- [Diseño del Protocolo P2P y Codecs](docs/fase-0/03-protocolo.md)
- [Arquitectura de Módulos y Persistencia](docs/fase-0/04-arquitectura.md)
- [Plan de Validación en Juego](docs/fase-0/05-validacion-y-plan.md)
- [Fuentes y Referencias del Cliente](docs/fase-0/06-fuentes.md)

---

## 👥 Créditos

Desarrollado con orgullo y sed de venganza por el equipo de **Orgrimmar Desokupa** para toda la comunidad de **WoW Forever**. ¡Por la Horda!
