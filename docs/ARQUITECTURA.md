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

| Acción | Qué pasa |
|---|---|
| **Bloquear** un recurso | Se sincroniza lo pendiente. El saldo visible se reparte **en proporción a los aportes positivos** de cada miembro: el que gastó más de lo que aportó no recibe nada. Si nadie tiene aporte positivo, se reparte a partes iguales. A partir de ahí, cada uno tiene su propio saldo y la reserva no toca ese recurso. |
| Bloquear con **deuda** | Los dos quedan en 0 y la deuda sigue pendiente en la reserva. |
| **Desbloquear** | Los saldos de los dos se suman a la reserva, menos la deuda pendiente. Cada uno empieza aportando lo que traía. |
| **Bloquear todo** | Si queda algún recurso compartido, se bloquean todos. Si no queda ninguno, se comparten todos. |

Cualquiera de los dos miembros puede bloquear o desbloquear. El estado es por equipo.

### Invariantes

```
balance == inicial + ingresos − gastos − repartido + reincorporado
Σ aporte_j == balance        (en recursos compartidos)
```

`STR_Ledger_CheckInvariant` los comprueba. `STR_DebugDump()` los vuelca al log al final de la partida. La prueba aleatoria comprueba durante 5.000 ticks, con bloqueos al azar, que lo que tienen los jugadores más la deuda coincide con una contabilidad externa independiente.

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

[str_ui.scar](../assets/scar/sharedteamresources/str_ui.scar) crea con `UI_AddChild("ScarDefault", "XamlPresenter", …)` una fila de 5 botones con el estilo oficial `PrimaryRaisedTextButton`:

- Uno por recurso: icono oficial del recurso (`icons/resources/resource_*_icon.png`) y el texto "Compartido" o "Bloqueado". El icono se atenúa al bloquear.
- Uno general: "Bloquear todo" o "Compartir todo".

Solo lo ve el jugador local que pertenece a una reserva. Se actualiza con `UI_SetDataContext` y se quita si el jugador es eliminado o termina la partida. La posición se configura en `STR_CONFIG.ui`.

## Determinismo

- Todo lo que toca recursos se ejecuta en la simulación (regla de sincronización o evento de red) y recorre las listas con `ipairs` (orden fijo).
- `player.isLocal` y `Game_GetLocalPlayer()` solo se usan para la interfaz: dibujar el panel, enviar el clic y mostrar avisos.
- La interfaz va dentro de `pcall`: un fallo de UI no detiene la sincronización.

## Eliminación de un jugador

El eliminado sale de la reserva **sin** contar sus cambios del último tick, porque el motor puede vaciar sus recursos. Su aporte pasa al superviviente, que conserva el saldo común y la deuda pendiente.

## Formación de reservas

- Una reserva por equipo (`Player_GetTeam`), con entre 2 y `max_players_per_pool` miembros elegibles (opción del lobby "Jugadores por reserva": 2, 3 o 4; por defecto 4). La contabilidad y el reparto al bloquear funcionan igual con cualquier número.
- Con "Avisos de depuración", el jugador local ve al empezar si su equipo comparte o el motivo por el que no (`STR_DebugReportLocalTeam`).
- El equipo debe tener **al menos un humano**: los equipos solo de IA no comparten.
- Con `ai_allies = true` (por defecto), una IA aliada de un humano también entra.
- Los miembros deben ser aliados mutuos.
