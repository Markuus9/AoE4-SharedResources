# Compilar, probar y publicar

## 0. Sustituir la imagen del mod (una sola vez)

La imagen nueva está en `Descargas\SharedResources_mod.png` (1920×1080). Cópiala desde el Explorador sobre:

```
Documents\SharedTeamResources\assets\mod.png
```

La fuente está en [tools/imagen/mod.html](../tools/imagen/mod.html). La cabecera de ese archivo indica cómo regenerarla con Edge.

## 1. Compilar

1. Abre `SharedTeamResources.aoe4mod` en el **Content Editor**.
2. Abre `assets/scar/winconditions/SharedTeamResources.rdo`. Deberías ver cuatro secciones de opciones: Condiciones de victoria, Recursos compartidos, Condiciones de inicio y Diplomacia. Si el editor marca algún error, mira [Problemas habituales](#problemas-habituales).
3. *File → Save All*.
4. *Build → Build Mod*.

## 2. Probar en solitario

1. Juego: *Un jugador → Escaramuza → Crear partida*.
2. *Configuración de partida → Editar*. Elige **Shared Resources (Estándar)**.
3. Equipos: tú + IA aliada en el equipo 1; IA enemiga en el equipo 2.
4. Revisa las opciones del modo: victorias, recursos compartidos, inicio y diplomacia.
5. En **Recursos compartidos**, deja **Avisos de depuración** activado. Al empezar la partida verás abajo a la derecha:
   - "Depuración: reserva creada con N jugadores de tu equipo", o el motivo por el que no se comparte (demasiados jugadores, IA aliada excluida, desactivado…);
   - "Depuración: panel de botones creado" (o el error si falla).

   Los mensajes de `print()` (líneas `[STR]`) **no se ven** en la versión normal del juego: no llegan a `warnings.log` ni hay consola. Por eso existen estos avisos.

### Colocar los botones junto a los recursos

Por defecto es una **columna de botones cuadrados pegada a la derecha del recuadro de recursos** (abajo a la izquierda): "Todos" (marco dorado) a la altura de la población y debajo un botón a la altura de comida, madera, oro y piedra. Verde y candado abierto = compartiendo; rojo y candado cerrado = bloqueado. Las medidas salen de una captura a 1080p con la escala de interfaz normal. Si con tu resolución o escala no cuadra, edita `STR_CONFIG.ui` en [str_config.scar](../assets/scar/sharedteamresources/str_config.scar):

```lua
ui = {
	layout = "column",       -- column (junto a cada recurso) | row (en fila)
	horizontal = "Left",     -- Left | Center | Right
	vertical = "Bottom",     -- Top | Center | Bottom
	margin = "200,0,0,15",   -- izquierda, arriba, derecha, abajo (píxeles)
	row_height = 39,         -- separación entre recursos
	button_size = 35,        -- lado de cada botón cuadrado
},
```

- Columna demasiado a la izquierda/derecha: cambia el primer número de `margin`.
- Botones desplazados hacia arriba/abajo respecto a los recursos: cambia el último número de `margin`.
- Botones más juntos o separados que los recursos: cambia `row_height`.
- Botones más grandes o más pequeños: cambia `button_size` (debe ser menor que `row_height`).

Vuelve a compilar después de cada cambio. Si me mandas una captura, te calculo los valores.

## 3. Probar con otra persona

Un modo local no se puede usar en un lobby con otros jugadores, salvo que:

- la otra persona copie el mod compilado en `Documents\My Games\Cardinal\mods\extension\local`, o
- lo publiques (*Mods → Mis mods → Publicar*). Al elegir el modo en el lobby, se descarga automáticamente a los demás.

Después: *Multijugador → Personalizada → Crear partida*. Poneos los dos en el mismo equipo y las IA en el otro.

## 4. Publicar

1. Comprueba que `assets/mod.png` es la imagen nueva.
2. El nombre (**Shared Resources**) y la descripción salen de las filas 1 y 2 de `assets/locdb/SharedTeamResources_en.csv` y `_es.csv` (el juego usa el de su idioma).
3. Compila y publica desde el juego: *Mods → Mis mods*.

## 5. Leer el log

```
Documents\My Games\Age of Empires IV\warnings.log
Documents\My Games\Age of Empires IV\LogFiles\
```

## Problemas habituales

| Síntoma | Causa probable |
|---|---|
| No aparece ningún aviso de depuración | "Avisos de depuración" está en *no*, el mod no se ha recompilado, o hay un error de script (busca `SharedTeamResources` y `error` en `warnings.log`; ahí sí salen los errores de carga). |
| "Tu equipo no comparte porque tiene N jugadores…" | Sube "Jugadores por reserva" en el lobby. |
| "…solo hay 1 jugador elegible…" | Activa "Incluir IA aliada" o pon a otro humano en tu equipo. |
| `import` de `gamemodes/standard_mode.scar` falla | El juego cambió el nombre del script. Búscalo con el editor (*clic derecho en el import → Open Document*). Si no existe, vuelve a la lista de imports de la plantilla. |
| No aparecen los botones | Mira el aviso de depuración: si dice "panel de botones creado", está fuera de pantalla o tapado (ajusta `margin`); si dice "no se pudo crear", el XAML falló. |
| Los botones salen pero no hacen nada | Aviso "los botones no están disponibles (sin eventos de red)". |
| El editor da error en el `.rdo` | Regenera con `node tools/genrdo.js <salida> assets/scar/winconditions/SharedTeamResources.rdo` y copia los dos archivos generados. |
| Los textos salen como `$01f4...:13` | El juego está en un idioma sin textos: solo hay `_es.csv`. |
| Desync en multijugador | Algo de la simulación depende del jugador local. Ver [ARQUITECTURA.md](ARQUITECTURA.md#determinismo). |
