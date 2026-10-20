# Arquitectura

## Base: el modo estándar oficial

[SharedTeamResources.scar](../assets/scar/SharedTeamResources.scar) importa `gamemodes/standard_mode.scar`, el script del modo estándar del juego. *Empire Wars* también se construye sobre él. Ese script lee las opciones del lobby con las claves oficiales:

| Clave en el `.rdo` | Qué hace (en `standard_mode.scar` / `classic_start.scar`) |
|---|---|
| `section_inner_win_conditions.option_win_condition_conquest / _wonder / _religious / _regicide` | Si está en *no*, quita el módulo de esa victoria (`Core_UnregisterModule`) |
| `section_starting_conditions.option_start_age` (`option_start_age_1..4`) | Concede las edades iniciales |
| `section_starting_conditions.option_speed` (`option_speed_2x/_3x`) | Multiplica recolección, construcción, producción e investigación |
| `section_starting_conditions.option_fow` (`option_fow_explore/_reveal`) | Niebla de guerra |
| `section_starting_conditions.option_score` | Puntuación visible |
| `section_diplomacy.option_diplomacy_teams / _tribute` | Equipos fijos y tributos |

Opciones propias del mod, leídas en `STRGameMode_OnGameSetup`:

| Clave | Uso |
|---|---|
| `shared_section.shared_mode` (`shared_on/shared_off`) | Activa la reserva |
| `shared_section.shared_lock_buttons` | Muestra los botones de bloqueo |
| `section_starting_conditions.str_start_resources` | Recursos iniciales, fijados en `OnInit`, antes de crear la reserva |
| `section_starting_conditions.str_extra_villagers` | Aldeanos extra junto al centro urbano (`UnitEntry_DeploySquads`) |

El `.rdo` y el `.csv` se generan con [tools/genrdo.js](../tools/genrdo.js).

## Contabilidad por diferencias

En cada tick, para cada recurso **compartido**:

1. Se lee el saldo de cada miembro.
2. Se calcula la diferencia de cada uno respecto al último valor que el mod le fijó: `delta_j`.
3. `balance += Σ delta_j` y `aporte_j += delta_j`.
4. Se fija `max(balance, 0)` a todos los miembros.

Cualquier cosa que cambie los recursos de un jugador termina como un delta: recolección, producción, edificios, tecnologías, reembolsos, comercio, tributos o bonificaciones de civilización.

## Bloqueo de recursos

El bloqueo es **por jugador y por recurso** (`pool.out[id][rt]`): cada jugador decide qué comparte él, y solo le afecta a él.

| Acción del jugador P sobre el recurso R | Qué pasa |
|---|---|
| **Dejar de compartir** | Se sincroniza lo pendiente. Se calcula la parte justa de cada uno de los que comparten R: el saldo visible repartido **en proporción a los aportes positivos** (a partes iguales si nadie tiene aporte positivo). P se lleva **su parte**, que nunca supera lo que aportó. Si gastó más de lo que aportó, se lleva 0. Los demás siguen compartiendo el resto y cada uno pasa a aportar exactamente su parte justa. |
| Dejar de compartir con **deuda** | P se lleva 0; la deuda se la reparten a partes iguales los que siguen compartiendo. Si P era el último, la deuda queda pendiente en la reserva. |
| **Volver a compartir** | El saldo propio de P se suma a la reserva y P empieza aportando lo que trae. Si no compartía nadie y había deuda pendiente, la asume P. |
| **Todo** | Si P comparte algún recurso, deja de compartirlos todos; si no comparte ninguno, vuelve a compartirlos todos. |

Con 2 jugadores, que uno deje de compartir equivale a que cada uno tenga lo suyo: el otro se queda solo en la reserva de ese recurso. Ningún jugador puede cambiar el estado de otro.

### Invariantes

```
balance == inicial + ingresos − gastos − repartido + reincorporado
Σ aporte_j (de los que comparten R) == balance        (si alguien comparte R)
balance <= 0                                          (si nadie comparte R: solo deuda pendiente)
```

`STR_Ledger_CheckInvariant` los comprueba. La prueba aleatoria comprueba durante 5.000 ticks, con 3 jugadores y bloqueos al azar, que la reserva más los saldos propios de quien no comparte coincide con una contabilidad externa independiente.

## Red: botones de bloqueo

```
Clic (solo en el ordenador de quien pulsa)
  STR_UI_OnClick("3")
    -> Network_CallEvent("STR_OnLockToggleNtw", "<índice jugador>,3")
         ... red (como un tributo) ...
  En TODOS los clientes, en el mismo tick:
  STR_OnLockToggleNtw(sender, "<índice>,3")
    -> STR_ApplyLockAction -> Ledger Lock/Unlock -> Player_SetResource
    -> aviso y actualización del panel (locales)
```

- El evento se registra con `Network_RegisterEvent` en `OnInit`, en el mismo orden en todos los clientes, como hace `diplomacy.scar`.
- Si `Network_RegisterEvent` no existiera, **no se crean botones**. Nunca hay cambios que se apliquen solo en un cliente.
- Un clic de un jugador eliminado, o de alguien fuera de la reserva, se ignora.

## Panel de botones (XAML)

[str_ui.scar](../assets/scar/sharedteamresources/str_ui.scar) crea con `UI_AddChild("ScarDefault", "XamlPresenter", …)` una columna de 5 botones:

Son **cuadrados** (`STR_CONFIG.ui.button_size`, 35 por defecto):

- Uno general arriba, con marco dorado: "Bloquear todo" o "Compartir todo". El candado muestra lo que hará al pulsarlo.
- Uno por recurso:
  - compartiendo: marco y fondo verdes con el candado oficial abierto (`images/fe/fe_unlocked_icon.png`);
  - bloqueado: marco y fondo rojos con el candado cerrado (`images/fe/fe_locked_icon.png`).
- El texto ("Compartido", "Bloqueado"…) sale como `ToolTip` al pasar el ratón.

Cada botón es un `Grid` con dos capas:

1. Un `Button` con el estilo oficial `PrimaryRaisedTextButton` y `Content=""`: pone el fondo, el efecto al pasar el ratón, el `ToolTip` y recibe el clic.
2. Encima, un `Border` con `IsHitTestVisible="False"` (para que el clic llegue al botón), con `BorderBrush` y `Background` enlazados al color del estado y la `Image` del candado centrada.

Se hace así porque la plantilla de `PrimaryRaisedTextButton` solo dibuja `Content` como texto (en mayúsculas y recortado) e ignora imágenes. Por eso la primera versión salía vacía o con «BLOQUE...».

Cada jugador local ve **su** estado. El panel se actualiza con `UI_SetDataContext` y se quita si el jugador es eliminado o termina la partida. La posición se configura en `STR_CONFIG.ui`.

## Determinismo

- Todo lo que toca recursos se ejecuta en la simulación (regla de sincronización o evento de red) y recorre las listas con `ipairs` (orden fijo).
- `player.isLocal` y `Game_GetLocalPlayer()` solo se usan para la interfaz: dibujar el panel, enviar el clic y mostrar avisos.
- La interfaz va dentro de `pcall`: un fallo de UI no detiene la sincronización.

## Eliminación de un jugador

El eliminado sale de la reserva **sin** contar sus cambios del último tick, porque el motor puede vaciar sus recursos. Su aporte pasa al superviviente, que conserva el saldo común y la deuda pendiente.

## Población máxima compartida ([str_team.scar](../assets/scar/sharedteamresources/str_team.scar))

Al crear la reserva se guarda el tope inicial de cada miembro (`Player_GetMaxPopulationCap`, normalmente 200). En cada tick:

```
tope_equipo = Σ tope_inicial (de los miembros que quedan)
libre       = max(tope_equipo − Σ usada, 0)
tope_j      = usada_j + libre
```

- Si A usa 100 y B usa 50 (equipo 400), A puede llegar a 350 y B a 300. Cuando uno crece, el hueco del otro se reduce.
- Solo se mueve el **tope** (`Player_SetMaxCapPopulation`); la capacidad de las casas sigue haciendo falta.
- El motor suma modificadores encima del valor fijado. La primera vez se mide la diferencia entre lo fijado y lo efectivo, y luego se compensa.
- Si un miembro es eliminado, su tope deja de contar y el superviviente vuelve a su propio tope.
- Si dos producen a la vez la última unidad que cabe, el equipo puede pasarse por una unidad (como la deuda de recursos).

## Producción compartida ([str_team.scar](../assets/scar/sharedteamresources/str_team.scar))

`Entity_SetSharedProductionQueue(edificio, true)` en cada edificio con cola de producción (`Entity_HasProductionQueue`) de los miembros de una reserva:

- al empezar, recorriendo `Player_GetEntities` con `EGroup_ForEach`;
- en cada `GE_ConstructionComplete` de un miembro;
- con un repaso cada 15 s, para edificios que aparezcan de otra forma.

Los aliados producen pagando con *sus* recursos; con la reserva, son los comunes (o los propios si los tienen bloqueados).

## Idiomas

`assets/locdb/SharedTeamResources_en.csv` y `_es.csv` tienen la misma numeración de filas (97). El `.locdb` registra los dos idiomas, con el inglés primero, como en AGS. Los dos CSV tienen formatos distintos:

- El inglés es el **idioma origen**: `ID,Pipeline,PipelineStage,Notes,TranslationNotes,Tags,Text`.
- El español es una **traducción**: `ID,SourceText,TranslatedText`. Si se le pone el formato de origen, el compilador falla con *Required header [SourceText] not found*. Todos los textos del lobby, de los avisos y de los botones (al pasar el ratón) salen de ahí. [tools/genrdo.js](../tools/genrdo.js) genera los dos CSV: el español está en el propio script y el inglés en [tools/locale_en.js](../tools/locale_en.js), y el script comprueba que coinciden fila a fila.

## Formación de reservas

- Una reserva por equipo (`Player_GetTeam`), con entre 2 y `max_players_per_pool` miembros elegibles (opción del lobby "Jugadores por reserva": 2, 3 o 4; por defecto 4). La contabilidad y el reparto al bloquear funcionan igual con cualquier número.
- Con "Avisos de depuración", el jugador local ve al empezar si su equipo comparte o el motivo por el que no (`STR_DebugReportLocalTeam`).
- El equipo debe tener **al menos un humano**: los equipos solo de IA no comparten.
- Con `ai_allies = true` (por defecto), una IA aliada de un humano también entra.
- Los miembros deben ser aliados mutuos.
