# Orgrimmar Desokupa Dashboard (ODD)

## Objetivo y cliente

Addon nativo para hermandades de la Horda, exclusivamente para **WoW Forever 1.60.1 / Interface 16001**. No dirigir el diseño a Retail, Cataclysm Classic ni WoW Classic 1.12. Forever usa la familia de API moderna, pero cada capacidad debe comprobarse en el cliente Forever de destino.

## Reglas no negociables

- Fiabilidad antes que cantidad de funciones. No inventar estadísticas ni atribuir kills sin evidencia.
- No añadir kills manualmente ni usar tracking incompatible con Forever.
- No dar por válido `COMBAT_LOG_EVENT_UNFILTERED`; investigar y validar alternativas antes de usarlo.
- No copiar código ni recursos de otros addons. GRS es solo una referencia de comportamiento; su licencia es All Rights Reserved.
- Sin frameworks web, librerías externas ni dependencias. Lua y XML nativos.
- Separar hechos verificados en el código del cliente, observaciones de terceros, hipótesis y pruebas propias pendientes.
- Documentar limitaciones antes de implementar sobre una API incierta. Usar comprobaciones de capacidad y degradación explícita.
- La pestaña Eventos está eliminada: no crear calendario ni gestión de eventos.

## Producto

Pestañas previstas: Cuartel General, Gnomómetro, Frente PvP, Talleres, Roster y Ajustes. Debe existir sincronización bidireccional entre clientes por mensajes de addon, sin servidor externo, con presencia al conectar y botón manual «Sincronizar hermandad». Cada copia local es independiente; los datos remotos se muestran como declarados por otro cliente, nunca como verificados por el servidor.

## Fases

0. Investigación y validación de Forever, incluida GRS, matriz de viabilidad, protocolo, arquitectura y riesgos.
1. Base: estructura, ciclo de vida, SavedVariables, `/odd`, dashboard, perfil y roster.
2. Comunicación y sincronización.
3. Gnomómetro.
4. PvP y Talleres.
5. Pulido, privacidad, rendimiento, pruebas multicliente y documentación.

No avanzar a funciones que dependan de APIs inciertas antes de presentar las conclusiones de Fase 0 y validar la capacidad correspondiente.

## Documentación y estilo

- La documentación de investigación vive en `docs/fase-0/` y debe incluir fuentes con fecha/build y una tabla de dudas pendientes.
- Mantener módulos con responsabilidades separadas: Core, Database, API, PvP, Gnomes, Guild, Professions, Achievements, Network, UI, Commands, Localization y Media.
- Cada archivo Lua usará el namespace del addon; evitar globals salvo SavedVariables, comandos e integraciones exigidas por el cliente.
- La comunicación necesita versión, cola/throttling, fragmentación, deduplicación, sincronización incremental, límites de entrada, reintentos y control de tormentas.
- Persistir esquema versionado y procedencia de cada dato. No sincronizar datos privados por defecto.
- Actualizar este archivo si cambian la arquitectura, las convenciones o los flujos descritos.

## Procedimiento Estricto de Release (Publicación y Empaquetado)

Para garantizar compatibilidad con **WowUp**, **CurseForge** y descargas manuales en WoW, el empaquetado del archivo `.zip` **NUNCA** debe contener los archivos sueltos en la raíz. Debe contener obligatoriamente una carpeta contenedora raíz llamada `OrgrimmarDesokupaDashboard`.

### Pasos obligatorios para cada Release:
1. **Actualizar Versión:**
   - En `OrgrimmarDesokupaDashboard.toc` (`## Version: X.Y.Z-alpha`).
   - En `Core/Init.lua` (`ODD.version = "X.Y.Z-alpha"`).
2. **Sincronizar en caliente al cliente local:**
   - Usar `[System.IO.File]::WriteAllText` o `WriteAllBytes` hacia `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\OrgrimmarDesokupaDashboard`.
3. **Empaquetado del ZIP (Staging con carpeta raíz):**
   - Crear directorio temporal en Desktop: `C:\Users\david\Desktop\staging_odd\OrgrimmarDesokupaDashboard`.
   - Copiar el código del addon dentro de esa carpeta contenedora (excluyendo `.git`, `.gemini`, `docs`, `*.zip`, `*.tmp`).
   - Comprimir `staging_odd` hacia `C:\Users\david\Desktop\OrgrimmarDesokupaDashboard-vX.Y.Z-alpha.zip`.
   - Eliminar el directorio temporal `staging_odd`.
   - *Verificación*: Las entradas del zip deben empezar siempre por `OrgrimmarDesokupaDashboard/`.
4. **Git Commit & Tag:**
   - `git add .`
   - `git commit -m "Release vX.Y.Z-alpha: ..."`
   - `git tag -a vX.Y.Z-alpha -m "..."`
   - `git push origin main`
   - `git push origin vX.Y.Z-alpha`
5. **Publicación en GitHub CLI:**
   - Usar la ruta completa: `& "C:\Program Files\GitHub CLI\gh.exe" release create vX.Y.Z-alpha "C:\Users\david\Desktop\OrgrimmarDesokupaDashboard-vX.Y.Z-alpha.zip" --title "..." --notes "..."`.

