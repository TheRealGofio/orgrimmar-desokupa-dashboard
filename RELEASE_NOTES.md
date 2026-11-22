# Release Notes: Orgrimmar Desokupa Dashboard v0.1.0-alpha

## Novedades en esta versión

- **Marco Temático Ornamental Horda / Orgrimmar:** Arte personalizado con madera envejecida, remaches de hierro forjado, pinchos y cabezas de gnomo derrotados como trofeos de caza en las esquinas.
- **Renderizado prioritario en la interfaz:** La ventana y el marco utilizan `FrameStrata = HIGH` y `Toplevel`, asegurando que el dashboard siempre permanezca visible al frente de la interfaz.
- **Visualizador 3D nativo del personaje:** Previsualización del modelo 3D en tiempo real con fondo 100% transparente y soporte para rotación interactiva en 360° con el ratón.
- **Refresco automático por pestaña:** Eliminados los botones manuales innecesarios; las pestañas de **Roster** y **Talleres** solicitan y actualizan automáticamente la información en cuanto se hace clic en ellas.
- **Gnomómetro y 19 Logros:** Sistema de tracking estricto de bajas de gnomos en mundo abierto (deduplicación por cooldown, validación GUID/raza) con avisos informativos en pantalla (toasts) y sonido nativo del juego.
- **Frente PvP y Talleres:** Estadísticas de honor e historial de BGs, junto a un directorio de artesanos con recetas y niveles de oficio.
- **Sincronización P2P:** Comunicación bidireccional entre miembros de la hermandad mediante canales de addon protegidos con control de tráfico (token bucket).
- **Comando de reinicio:** `/odd reset` para purgar datos locales o temporales en un solo paso.

---

## Instalación

### Opción 1: A través de WowUp (Recomendado)
1. Abre WowUp.
2. Ve a **Get Addons** > **Install from URL**.
3. Pega el enlace: `https://github.com/TheRealGofio/orgrimmar-desokupa-dashboard`
4. Selecciona la carpeta de **WoW Forever** e instala.

### Opción 2: Instalación Manual
Descarga el archivo adjunto `OrgrimmarDesokupaDashboard-v0.1.0-alpha.zip` y descomprímelo dentro de tu carpeta:
`World of Warcraft\_forever_\Interface\AddOns\`
