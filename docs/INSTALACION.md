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

### Colocar los botones

Por defecto (`layout = "left"`), el panel va **a la izquierda, alineado con los iconos del juego y anclado abajo, justo encima del recuadro de población y recursos**. Así no tapa los contadores de maravilla, edificios distintivos y lugares sagrados, y no le afecta cuántos iconos haya arriba (crecen hacia abajo según el mapa):

- arriba, el texto «Equipo: usada/capacidad»;
- debajo, una columna de botones cuadrados: «Todos» (marco dorado) y comida, madera, oro y piedra, cada uno con el icono del recurso y un candado pequeño;
- verde con candado abierto = compartiendo; rojo con candado cerrado = bloqueado.

El último número de `margin` es la distancia desde abajo: súbelo si el panel toca el recuadro de recursos y bájalo para acercarlo.

Las medidas salen de una captura a 1080p con la escala de interfaz normal. Si con tu resolución o escala no cuadra, edita `STR_CONFIG.ui` en [str_config.scar](../assets/scar/sharedteamresources/str_config.scar). Solo hace falta escribir lo que quieras cambiar:

```lua
ui = {
	layout = "left",         -- left (debajo de los iconos) | top (fila arriba) | column (junto a los recursos) | row
	margin = "22,0,0,250",   -- izquierda, arriba, derecha, abajo (píxeles)
	button_size = 30,        -- lado de cada botón cuadrado
},
```

- Panel demasiado a la izquierda/derecha: cambia el primer número de `margin`.
- Panel demasiado arriba/abajo: cambia el último número de `margin` (distancia desde abajo).
- Para la fila arriba, a la derecha de los iconos: `layout = "top"` (por defecto `margin = "70,12,0,0"`). Ojo: ahí salen los contadores de maravilla y similares.
- Botones más grandes o más pequeños: cambia `button_size`.
- Para la columna junto al recuadro de recursos de abajo: `layout = "column"`. Sus valores por defecto son `margin = "200,0,0,15"`, `row_height = 39` y `button_size = 35`.

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
| Los textos salen como `$01f4...:13` | El juego está en un idioma sin textos (solo hay inglés y español). |
| Al compilar: *Required header [SourceText] not found* | Un CSV de traducción (no el inglés) tiene el formato de origen. Las traducciones usan `ID,SourceText,TranslatedText`; regenera con `node tools/genrdo.js`. |
| Desync en multijugador | Algo de la simulación depende del jugador local. Ver [ARQUITECTURA.md](ARQUITECTURA.md#determinismo). |
