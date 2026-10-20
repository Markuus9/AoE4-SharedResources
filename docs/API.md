# Funciones SCAR usadas y de dónde salen

Fuentes, de más a menos fiable:

- **Doc oficial:** aparece en `Age of Empires IV\scardocs\api\Essence_ScarFunctions.api`, la lista oficial instalada con el juego.
- **Script oficial:** se usa igual en los scripts del propio juego (`Data.sga`: `standard_mode.scar`, `classic_start.scar`, `diplomacy.scar`, `network.scar`, `empire_wars.scar`, el modo Combat, etc.).
- **Plantilla:** aparece en la plantilla de Game Mode que generó tu Content Editor.

Marca la última columna cuando lo compruebes en el juego.

## Reserva y opciones

| Función / valor | Uso | Fuente | ¿Probado? |
|---|---|---|---|
| `import("gamemodes/standard_mode.scar")` | Modo estándar completo | Script oficial (lo importa Empire Wars) | [ ] |
| Claves `section_inner_win_conditions.option_win_condition_*`, `section_starting_conditions.option_start_age/_speed/_fow/_score`, `section_diplomacy.*` | Opciones del lobby | Script oficial (`standard_mode.scar`, `classic_start.scar`) | [ ] |
| `Setup_GetWinConditionOptions(t)` | Leer opciones | Script oficial + plantilla | [x] |
| `Core_RegisterModule`, `Core_UnregisterModule`, delegados `_OnGameSetup/_OnInit/_Start/_OnPlayerDefeated/_OnGameOver` | Ciclo de vida | Plantilla + script oficial | [x] |
| `Player_GetResource`, `Player_SetResource` ("ignora el tope de ingresos y el reparto de recursos") | Reserva | Doc oficial | [x] |
| `Player_IsHuman` ("humano, no muerto y no sustituido por IA") | Equipos | Doc oficial | [x] |
| `Player_GetTeam`, `Player_ObserveRelationship`, `R_ALLY` | Equipos | Script oficial | [x] |
| `Rule_Add`, `Rule_AddInterval`, `Rule_Exists`, `Rule_Remove` | Sincronización | Script oficial | [x] |

## Botones de bloqueo y red

| Función / valor | Uso | Fuente | ¿Probado? |
|---|---|---|---|
| `Network_RegisterEvent("Func")`, `Network_CallEvent("Func", msg)` → `Func(player, msg)` en todos los clientes | Enviar el clic | Script oficial (`network.scar`; lo usan los tributos y el modo Combat) | [ ] |
| `Command_PlayerBroadcastMessage` / `GE_BroadcastMessage` | Lo que usa `Network_*` por debajo | Doc oficial | — |
| `Core_GetPlayersTableEntryFromIndex(i)`, `player.index` | Identificar a quien pulsa | Script oficial (modo Combat) | [ ] |
| `UI_AddChild("ScarDefault", "XamlPresenter", nombre, {IsHitTestVisible, Xaml, DataContext})` | Crear el panel | Doc oficial + script oficial | [ ] |
| `UI_CreateDataContext`, `UI_SetDataContext`, `UI_Remove` | Actualizar o quitar el panel | Doc oficial + script oficial | [ ] |
| `UI_CreateCommand("Func")` + `CommandParameter` → `Func(parametro)` | Clic | Script oficial (tributos: `Diplomacy_IncreaseTribute(parameter)`) | [ ] |
| Estilo `PrimaryRaisedTextButton` | Fondo y clic de los botones (su plantilla solo dibuja texto, por eso el contenido va encima) | Script oficial (modo Combat) + plantilla en `UI.sga` | [x] |
| Iconos `pack://application:,,,/WPFGUI;component/images/fe/fe_unlocked_icon.png` y `fe_locked_icon.png` | Candado abierto/cerrado | XAML oficial en `UI.sga` | [ ] |
| Estilo `HUDGray80BodyTextBlock14ptStyle`, efecto `DropShadowTextStyle`, `Foreground="{Binding [x]}"` con `"#AARRGGBB"` | Texto de los botones | Script oficial (modo Combat, sin diccionarios extra) | [ ] |
| `UI_IsReplay()` | No mostrar botones en repeticiones | Doc oficial | [ ] |
| `Player_GetDisplayName(id)` como parámetro de `Loc_FormatText` | Nombre en los avisos | Doc oficial + script oficial | [ ] |

## Recursos y aldeanos iniciales

| Función / valor | Uso | Fuente | ¿Probado? |
|---|---|---|---|
| `Player_SetResource` en `OnInit` | Recursos iniciales | Script oficial (`standard_mode.scar`, opción de recursos altos) | [ ] |
| `BP_GetSquadArchetypeBlueprintForPlayer(id, BA_VILLAGER)` | Aldeano de cada civilización | Script oficial (`empire_wars.scar`) | [ ] |
| `Player_GetEntities` + `EGroup_Filter(eg, "town_center", FILTER_KEEP)` + `Entity_GetPosition` | Centro urbano | Plantilla | [ ] |
| `Util_GetOffsetPosition`, `SGroup_CreateIfNotFound`, `UnitEntry_DeploySquads` | Crear los aldeanos | Plantilla | [ ] |
| `player.startingPos` | Posición si no hay centro urbano (nómada) | Script oficial (`classic_start.scar`) | [ ] |

## Preguntas abiertas

1. **Posición del panel.** ¿Dónde queda respecto a la barra de recursos? Ajustar `STR_CONFIG.ui.margin`.
2. **Aspecto de los botones.** ¿Se ven el candado y el texto encima del botón? Si el icono no aparece, la alternativa es `icons/common/locked.png`.
3. **Estadísticas.** ¿`Player_SetResource` cuenta en las estadísticas finales de recursos recolectados?
4. **Aldeanos extra.** ¿Superan el límite de población? El juego los crea igualmente, pero no podrás producir más hasta tener casas.
