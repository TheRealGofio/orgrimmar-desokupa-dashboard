# Diseño del protocolo ODD v1

**Estado:** propuesta de Fase 0, pendiente de pruebas multicliente. No se ha implementado ni se afirma que los envíos funcionen ya en una sesión real.

## 1. Transporte verificado en el código del cliente

- Prefijo: `ODD` (3 caracteres, por debajo del máximo documentado de 16).
- Canal principal: `GUILD`.
- Recepción: `CHAT_MSG_ADDON`, cuyo remitente procede del cliente y no del contenido.
- Envío: `C_ChatInfo.SendAddonMessage`, que devuelve `Enum.SendAddonMessageResult`.
- Registro: `C_ChatInfo.RegisterAddonMessagePrefix` en cada carga/reload.
- Límite documentado para Forever: 255 caracteres por mensaje. ODD medirá bytes con `#wire` y aplicará el límite conservador de **255 bytes**, incluida toda la cabecera.
- El resultado `Success` significa **encolado para envío**, no recibido ni aplicado por otros clientes.
- Se comprobarán los resultados `AddonMessageThrottle`, `ChannelThrottle`, `NotInGuild`, `AddOnMessageLockdown`, `TargetOffline` y demás errores sin tratarlos como éxito.
- Antes de sincronizar se consultarán `AreOutgoingAddonChatMessagesRestricted` e `InChatMessagingLockdown` cuando estén disponibles. La documentación de Forever también señala que las cuentas trial/veteran no pueden enviar mensajes de addon.

No se usará `SendAddonMessageLogged` para el protocolo binario: está destinado a texto legible y registrado. Tampoco se usará chat visible, canales personalizados ni servicios externos.

## 2. Principios anti-tormenta

1. **Anunciar revisiones, no volcar bases de datos.** Un manifiesto pequeño permite decidir qué falta.
2. **Solo el propietario publica sus datos.** No hay retransmisión en cadena ni autoridad central.
3. **Sin respuestas en cascada.** `HELLO`, `MANIFEST`, `DELTA` y `SNAPSHOT` nunca exigen otra difusión equivalente inmediata.
4. **Petición dirigida lógica.** Aunque viaje por `GUILD`, cada mensaje incluye destinatario cuando solo un cliente debe actuar; los demás lo descartan tras validación mínima.
5. **Jitter.** Las respuestas colectivas se retrasan aleatoriamente para evitar que toda la hermandad conteste en el mismo segundo.
6. **Coalescencia.** Varias revisiones pendientes del mismo dominio se sustituyen por la más reciente antes de enviar.
7. **Cota de trabajo.** Colas, fragmentos, tamaño descomprimido, historial y reintentos tienen límites explícitos.

## 3. Mensajes

| Tipo | Función | Respuesta permitida |
|---|---|---|
| `HELLO` | Presencia, versión de addon/protocolo y capacidades al entrar. | Un `MANIFEST` propio solo si procede, con jitter; nunca una cadena de `HELLO`. |
| `MANIFEST` | Revisiones y resúmenes/hash por dominio. | `REQUEST` de un dominio concreto si el receptor está desactualizado. |
| `REQUEST` | Solicita snapshot, página o cursor al propietario. | Datos o `ERROR` acotado. |
| `DELTA` | Cambios nuevos desde la última revisión anunciada. | `ACK` solo cuando se necesita confirmar una operación manual/negotiation. |
| `SNAPSHOT` | Dominio completo o página fragmentada. | `ACK` de aplicación o `REQUEST` de reparación. |
| `ACK` | Confirma mensaje lógico y revisión aplicada. | Ninguna. |
| `ERROR` | Versión incompatible, esquema inválido, capacidad ausente o recurso agotado. | Ninguna automática. |
| `BYE` | Disponibilidad opcional al salir si el cliente entrega el evento a tiempo. | Ninguna; la ausencia se resuelve por TTL, no por fiabilidad de `BYE`. |

La sincronización manual usa `MANIFEST`/`REQUEST`, no un tipo especial que obligue a todos a transmitir snapshots completos.

## 4. Formato de cable

Mensajes de control y cabeceras de fragmentos en ASCII:

```text
1|HELLO|messageId|payload
1|MANIFEST|messageId|payload
1|REQUEST|messageId|payload
1|SNAPSHOT|messageId|part|parts|codec|payload
1|ACK|messageId|ackedMessageId|revision
1|ERROR|messageId|relatedMessageId|code
```

Reglas:

- `messageId`: identificador opaco de longitud acotada generado por el emisor; deduplicación con `(sender, messageId)`.
- `part` empieza en 1; `parts` se valida antes de reservar memoria.
- `codec`: perfil de serialización/versionado, no código ejecutable.
- Se calcula el presupuesto real para `payload` a partir de cada cabecera. Como punto de partida conservador se usarán como máximo **200 bytes de payload por fragmento** y 255 bytes completos por envío.
- Ningún campo textual puede contener `|` ni NUL. Los datos arbitrarios viajan dentro del codec, no concatenados sin escape.

### Codec de datos

El código fuente de Forever declara `C_EncodingUtil.SerializeCBOR`/`DeserializeCBOR`, `CompressString`/`DecompressString` y `EncodeBase64`/`DecodeBase64`.

Perfil propuesto `CB1`:

1. Validar y convertir el DTO a tipos simples.
2. `SerializeCBOR`.
3. Deflate solo si reduce el tamaño total; el perfil/cabecera indica si se usó.
4. Base64 para impedir NUL y otros bytes problemáticos en el canal.
5. Al recibir: límite de entrada → Base64 → límite descomprimido → CBOR → validación estricta de esquema.

Estas funciones existen en la fuente, pero el perfil debe pasar una prueba de ida y vuelta en Forever antes de activarse. Si falta la capacidad, la sincronización queda `no disponible`; no se improvisa un parser inseguro ni se añade una librería externa.

## 5. Revisiones y sincronización incremental

Cada personaje mantiene una revisión monótona por dominio:

```text
profile / gnomes / pvp / professions
```

El manifiesto anuncia `revision`, un hash acotado del contenido y las capacidades. La recepción solo pide un dominio si la revisión/hash difiere y el dato local está ausente o es anterior según el estado conocido.

- **Perfil:** snapshot pequeño; última revisión válida del mismo propietario.
- **Profesiones:** lista ordenada de IDs y metadatos mínimos; páginas estables por hash. Los nombres se resuelven localmente cuando sea posible.
- **Gnomómetro:** eventos con `killId` único, nunca incrementos manuales. Un receptor deduplica por `(owner, killId)` y calcula sus agregados. La sincronización usa cursores/lotes para no reenviar todo el historial.
- **PvP:** observaciones agregadas propias y partidas observadas con identificador local. Se etiqueta siempre como dato declarado al reenviarlo a otro cliente.

Una revisión alta no repara por sí sola datos corruptos: si el hash no coincide tras aplicar un snapshot válido, se solicita una página concreta o se marca error. Los datos con esquema desconocido no sustituyen datos válidos.

## 6. Cola y throttling

Valores iniciales deliberadamente conservadores, ajustables tras medir el cliente:

- Token bucket local con capacidad 6 y reposición de 1 mensaje/segundo; la documentación general describe un máximo dinámico de 10 y reposición de 1/segundo, por lo que no se codifica como garantía del servidor.
- Separación mínima inicial de 1,05 s entre envíos por `GUILD`.
- Cola máxima de 128 mensajes lógicos; se coalescen manifiestos y se descartan primero deltas obsoletos, nunca silenciosamente fragmentos de un snapshot en curso.
- Máximo de un snapshot grande en vuelo por pareja emisor/receptor y un número pequeño global para evitar monopolizar la cola.
- `AddonMessageThrottle`: espera con backoff y reintento. `ChannelThrottle`: backoff mayor. `NotInGuild`/`AddOnMessageLockdown`: suspender y dejar estado pendiente; no reintentar en bucle.
- Backoff inicial ante fallos temporales: 5, 15, 45 y 120 s; después queda `pendiente` hasta nuevo login/cambio/acción manual.
- La cola persistente se reconstruye desde revisiones, no desde cientos de fragmentos guardados.

## 7. Fragmentación y defensa de entrada

Límites iniciales:

- 64 fragmentos por mensaje lógico y 16 KiB codificados por snapshot de perfil/PvP.
- Profesiones e historial usan páginas; una página nunca supera esos límites.
- 64 KiB descomprimidos por página como tope absoluto, revisable a la baja tras pruebas.
- Reensamblado caduca a los 120 s; una nueva versión invalida la anterior.
- Se rechazan índices repetidos, fuera de rango, cambios de `parts`/codec, longitudes excesivas, tipos incorrectos, claves desconocidas y números fuera de rango.
- Se limitan mensajes aceptados por remitente y tiempo para impedir que un cliente malicioso o defectuoso consuma memoria/CPU.
- No se usa `loadstring`, ni se aceptan funciones, metatablas ni instrucciones de UI dentro del DTO.

## 8. Flujos

### Entrada al juego

1. Inicializar base local, capacidades y prefijo.
2. Esperar a que roster/chat estén listos y aplicar un retardo aleatorio de 10–30 s.
3. Enviar un único `HELLO` con versión/capacidades.
4. Publicar `MANIFEST` si hay datos compartibles o si otro cliente lo solicita.
5. Los clientes comparan revisiones y solicitan únicamente lo que falta.

### Botón «Sincronizar hermandad»

1. Aplicar privacidad y actualizar revisiones locales.
2. Emitir `MANIFEST` con nonce de operación.
3. Los pares responden con su manifiesto, con jitter, solo si hace falta o si el nonce solicita reevaluación.
4. Cada lado pide dominios desactualizados al propietario.
5. No hay respuestas a `ACK`, reenvíos ni ráfagas de snapshots completos sin cambios.

### Estados visibles

- `enviando`: hay mensajes en cola o snapshots en vuelo.
- `sincronizado`: los dominios compartidos están confirmados respecto a los pares conocidos y no quedan cambios pendientes; no significa que toda la hermandad offline esté actualizada.
- `pendiente`: no hay pares, faltan respuestas, el canal está restringido o quedan reintentos.
- `error`: validación/envío agotó reintentos o el protocolo es incompatible. El texto conserva el motivo y la última sincronización válida.

## 9. Confianza

El canal de hermandad y el remitente del evento ofrecen contexto, **no autenticidad de las estadísticas ni verificación por el servidor**. Un miembro puede modificar su addon o sus SavedVariables. Por eso:

- Se vincula cada payload al remitente real de `CHAT_MSG_ADDON` y se comprueba que pertenezca a la hermandad.
- Un cliente solo puede actualizar los registros remotos de ese remitente.
- La UI muestra «declarado por …» para datos ajenos.
- No se presentan rankings de hermandad como antitrampas ni como autoridad global.
