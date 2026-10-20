# Shared Resources — Age of Empires IV

Mod de tipo **Game Mode** para **Age of Empires IV en PC (Steam)**. Es el **modo estándar oficial** con una diferencia: los aliados de cada equipo comparten una única reserva de comida, madera, oro y piedra. Durante la partida, cada jugador puede **dejar de compartir** un recurso, o todos, quedándose con lo que aportó, y volver a compartirlo después. El bloqueo es **por jugador**: los demás siguen compartiendo entre ellos.

**Estado:** probado **fuera del juego** con 73 pruebas automáticas sobre un motor simulado. La reserva compartida y los botones de bloqueo ya se han probado en el juego. Falta probar en el juego la población máxima compartida, la producción compartida y la traducción al inglés; ver [docs/PRUEBAS_EN_JUEGO.md](docs/PRUEBAS_EN_JUEGO.md).

*English:* an Age of Empires IV game mode based on the official standard mode. Allies share a single pool of food, wood, gold and stone. Each player can lock any resource at any time and keep what they contributed. Optional lobby checkboxes add a shared max population and shared production buildings. The mod's texts are in English and Spanish.

## Qué incluye

**Opciones del lobby**

| Sección | Opciones |
|---|---|
| Condiciones de victoria | Edificios distintivos, Maravilla, Lugares sagrados, Regicidio (sí/no cada una) |
| Recursos compartidos | Activados/Desactivados · Botones de bloqueo sí/no · Jugadores por reserva (hasta 2, 3 o 4; por defecto 4) · Incluir IA aliada sí/no · Avisos de depuración sí/no · **Población máxima compartida** sí/no · **Producción compartida** sí/no |
| Condiciones de inicio | Edad inicial · Recursos iniciales (estándar, medios, altos, muy altos) · Aldeanos extra (0, +6, +12, +20) · Velocidad de economía (x1, x2, x3) · Mapa (normal, explorado, revelado) · Mostrar puntuación |
| Diplomacia | Equipos fijos · Tributos |

Las victorias, la edad, la velocidad, el mapa y la diplomacia los gestiona el propio script oficial del modo estándar (`gamemodes/standard_mode.scar`). El mod usa las mismas claves de opción que el modo oficial, así que se comportan igual.

**En la partida**

- Una reserva común por equipo. Todo lo que recolecta o gasta cualquiera de los que comparten sale de ella.
- Una columna de botones **pegada al recuadro de recursos** (abajo a la izquierda), con **botones cuadrados** a la altura de cada recurso. Verde con el candado abierto significa que compartes; rojo con el candado cerrado, que lo tienes bloqueado. El texto aparece al pasar el ratón. Cada jugador ve y controla **solo su propio estado**.
- Un botón con marco dorado encima (**Bloquear todo / Compartir todo**) para todos tus recursos a la vez.
- Al dejar de compartir, te llevas **tu parte según lo que aportaste**: lo recolectado menos lo gastado, incluidos los recursos iniciales. **Nunca más de lo que aportaste.** Si gastaste más de lo que aportaste, no te llevas nada.
- Los demás siguen compartiendo lo que queda. Con 3 o 4 jugadores, si uno se sale, los otros siguen juntos.
- Al volver a compartir, tu saldo se suma otra vez a la reserva.
- Avisos en pantalla al activarse la reserva, cuando hay deuda por un gasto simultáneo y cuando un aliado deja o vuelve a compartir algo.

**Quién comparte**

**Extras opcionales** (casillas del lobby, activadas por defecto):

- **Población máxima compartida:** el equipo suma su tope de población. Por ejemplo, con 400 entre dos, uno puede llegar a 300 si el otro solo usa 100. Las casas siguen haciendo falta.
- **Producción compartida:** tus aliados pueden producir unidades e investigar en tus edificios, y tú en los suyos.

**Idiomas:** inglés y español. El juego elige según su idioma.

**Quién comparte**

Los equipos de hasta 4 jugadores (configurable en el lobby) con al menos un humano. Tus IA aliadas también comparten contigo (se puede desactivar en el lobby). Los equipos formados solo por IA, como los enemigos, juegan normal.

## Cómo funciona

En cada tick de simulación el mod lee el saldo de los dos aliados y suma a la reserva lo que ha cambiado cada uno desde la última vez. Luego fija el resultado a los dos. No hace falta interceptar gastos: recolección, producción, edificios, tecnologías, reembolsos, comercio y bonificaciones de civilización se contabilizan igual.

La simulación de AoE4 es determinista (*lockstep*), así que este cálculo da lo mismo en los dos clientes. Los botones son la excepción: un clic ocurre en un solo ordenador. Por eso se envía por red con `Network_CallEvent`, el mismo mecanismo que usan los tributos oficiales, y el cambio se aplica en los dos clientes en el mismo tick.

Detalle en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Estructura

```
SharedTeamResources/
├─ SharedTeamResources.aoe4mod             proyecto del Content Editor
├─ assets/
│  ├─ mod.png                              imagen del mod (sustituir, ver abajo)
│  ├─ scar/
│  │  ├─ SharedTeamResources.scar          script del modo: estándar + recursos/aldeanos iniciales
│  │  ├─ sharedteamresources/
│  │  │  ├─ str_config.scar                opciones (IA aliada, intervalo, posición de botones, log…)
│  │  │  ├─ str_main.scar                  equipos, reservas, sincronización, bloqueo por red, avisos
│  │  │  ├─ str_ledger.scar                contabilidad pura: saldo, aportes, deuda, bloqueo
│  │  │  ├─ str_ui.scar                    panel XAML con los botones de bloqueo
│  │  │  ├─ str_team.scar                  población máxima y producción compartidas
│  │  │  ├─ str_log.scar                   registro con niveles
│  │  │  └─ str_diagnostics.scar           sonda de diagnóstico (solo observa)
│  │  └─ winconditions/SharedTeamResources.rdo   opciones del lobby
│  └─ locdb/SharedTeamResources_{en,es}.csv   97 textos en inglés y español
├─ tests/                                  motor simulado + 73 pruebas
├─ tools/
│  ├─ run-tests.js                         ejecuta las pruebas sin Lua instalado
│  ├─ genrdo.js                            regenera el .rdo y los .csv (es + en) de opciones
│  ├─ locale_en.js                         textos en inglés (misma numeración que el español)
│  └─ imagen/mod.html                      fuente de la imagen del mod
└─ docs/
   ├─ INSTALACION.md                       compilar, probar, publicar
   ├─ ARQUITECTURA.md                      diseño, bloqueo, determinismo
   ├─ API.md                               funciones SCAR usadas y de dónde salen
   └─ PRUEBAS_EN_JUEGO.md                  checklist en el juego
```

## Empezar

1. **Imagen:** copia `Descargas\SharedResources_mod.png` sobre `assets\mod.png`. Desde el Explorador funciona sin problema; la terminal no puede escribir en Documentos por el acceso controlado a carpetas.
2. En el **Content Editor**: *File → Save All* y luego *Build → Build Mod*.
3. En el juego, crea una escaramuza con el modo **Shared Resources (Estándar)**: tú + IA aliada contra IA.
4. Deja **Avisos de depuración** activado: al empezar te dirá si tu equipo comparte (y por qué no, si es el caso) y si se creó el panel de botones.
5. Sigue [docs/PRUEBAS_EN_JUEGO.md](docs/PRUEBAS_EN_JUEGO.md). Si la columna de botones no queda alineada con tus recursos, ajusta `STR_CONFIG.ui` en [str_config.scar](assets/scar/sharedteamresources/str_config.scar) (ver [docs/INSTALACION.md](docs/INSTALACION.md#colocar-los-botones-junto-a-los-recursos)).

## Pruebas automáticas

Con Node.js:

```bash
npm install
```

```bash
npm test
```

Con Lua 5.1+ instalado:

```bash
lua tests/run_tests.lua
```

> `npm install` dentro de `Documents` puede fallar por el acceso controlado a carpetas de Windows. En ese caso, añade Node.js a las aplicaciones permitidas o ejecuta las pruebas desde una copia fuera de `Documents`.

Las pruebas cubren:

- los casos de aceptación;
- el bloqueo por jugador: reparto según lo aportado (nunca más), los demás siguen compartiendo, 3 jugadores, deuda pendiente, bloquear todo y compartir todo;
- los clics enviados por red y aplicados en el siguiente tick;
- el panel de botones;
- las opciones del lobby: recursos y aldeanos iniciales;
- los avisos;
- 5.000 ticks aleatorios con 3 jugadores y bloqueos al azar, sin crear ni perder recursos.

**No** sustituyen a las pruebas en el juego.

## Nombre del mod

El nombre visible es **Shared Resources** y el del modo, **Shared Resources (Estándar)**, en las filas 1 y 3 del CSV. Los nombres internos de archivo (`SharedTeamResources.aoe4mod`, `.scar`, `.rdo`) no se han cambiado, para no romper las referencias del Content Editor. Si los quieres cambiar, hazlo desde el propio editor.

## Limitaciones conocidas

- **Empire Wars no está incluido.** El modo oficial necesita datos del mapa (edificios ya colocados) que un mod no puede reproducir con fiabilidad. Como alternativa para empezar avanzado: Edad inicial, Recursos iniciales y Aldeanos extra.
- Textos en inglés y español. Con el juego en otro idioma, los textos del mod pueden salir en inglés o sin traducir.
- Población máxima compartida: si dos jugadores producen a la vez la última unidad que cabe, el equipo puede pasarse por esa unidad.
- Equipos de más de 4 jugadores: no comparten.
- Los mensajes de `print()` (las líneas `[STR]`) **no se ven** en la versión normal del juego: ni en `warnings.log` ni en consola. Para saber qué pasa, activa **Avisos de depuración** en el lobby.
- Si los dos gastan el mismo saldo en el mismo tick se genera una deuda, que se paga con los ingresos siguientes y se avisa en pantalla.

## Referencias

- [Mods oficiales de AoE4](https://www.ageofempires.com/mods/)
- [Creating a Game Mode](https://support.ageofempires.com/hc/en-us/articles/4420081112340-Creating-a-Game-Mode)
- [Introduction to Scripting](https://support.ageofempires.com/hc/en-us/articles/4438362112660-Introduction-to-Scripting)
- Documentación SCAR incluida con el juego: `Age of Empires IV\scardocs\`
- [Advanced Game Settings (GitHub)](https://github.com/Woprok/AOE4-AdvancedGameSettings)

## Licencia

[MIT](LICENSE). Age of Empires IV y sus recursos (iconos, estilos, scripts del juego) pertenecen a sus propietarios; este repositorio solo contiene el código y los recursos propios del mod.
