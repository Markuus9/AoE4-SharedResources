# Pruebas en el juego

Las pruebas automáticas (`npm test`) usan un motor simulado. Estas otras **solo se pueden hacer en el juego**.

Versión del juego: `__________`  Fecha: `__________`

## 1. El modo carga y las opciones funcionan

Partida: tú + IA aliada contra IA.

- [ ] Compila sin errores (*Build → Build Mod*).
- [ ] Aparece **Shared Resources (Estándar)** con la imagen nueva y su descripción.
- [ ] Se ven las cuatro secciones de opciones con sus textos en español.
- [ ] Con "Avisos de depuración" activado, al empezar aparece "reserva creada con N jugadores" y "panel de botones creado".
- [ ] Con 3 jugadores en tu equipo y "Jugadores por reserva" en *Hasta 2*, el aviso explica que no comparte; en *Hasta 3* o *Hasta 4*, comparte.
- [ ] "Incluir IA aliada" en *no*: tus IA aliadas dejan de compartir.
- [ ] `warnings.log` no tiene errores de carga del mod (busca `SharedTeamResources`).
- [ ] **Victorias:**
  - [ ] Solo "Edificios distintivos": la maravilla y los lugares sagrados no dan la victoria.
  - [ ] Solo "Maravilla".
  - [ ] Solo "Lugares sagrados".
  - [ ] Todas en *no*: se gana por aniquilación.
- [ ] **Edad inicial** Feudal: todos empiezan en Feudal.
- [ ] **Recursos iniciales** Medios: la reserva empieza con 2000 / 2000 / 1200 / 800 (la suma de los dos).
- [ ] **Aldeanos extra** +12: aparecen junto al centro urbano. Probar también con inicio nómada.
- [ ] **Velocidad** x2 y **Mapa** revelado funcionan.
- [ ] **Equipos fijos** y **Tributos** funcionan como en el estándar.

## 2. Botones de bloqueo

- [ ] La columna de botones aparece pegada a la derecha del recuadro de recursos, cada botón a la altura de su recurso. Si no, ajusta `STR_CONFIG.ui` (ver [INSTALACION.md](INSTALACION.md#colocar-los-botones-junto-a-los-recursos)).
- [ ] Hay cuatro iconos de recursos con "Compartido" y un botón "Bloquear todo".
- [ ] Clic en oro:
  - [ ] el icono se atenúa y pone "Bloqueado";
  - [ ] aparece el aviso "… ha bloqueado el oro";
  - [ ] cada uno tiene su parte según lo aportado.
- [ ] Con el oro bloqueado, lo que recolectas no le llega al aliado y viceversa. Los demás recursos siguen compartidos.
- [ ] Clic otra vez: se vuelven a sumar.
- [ ] "Bloquear todo" y "Compartir todo".
- [ ] Tras varios bloqueos y desbloqueos, la suma de lo que tenéis cuadra con lo recolectado menos lo gastado (no aparecen ni desaparecen recursos).

## 3. Dos humanos en Steam

Partida personalizada: A + B contra IA, con "Avisos de depuración" activado.

| # | Caso | Resultado esperado | OK |
|---|---|---|---|
| 1 | A recolecta, B gasta | B gasta lo que recolectó A | [ ] |
| 2 | Ambos gastan a la vez con el saldo justo | Aviso de deuda; se paga después | [ ] |
| 3 | A bloquea la comida | B ve el aviso y su botón cambia también | [ ] |
| 4 | B desbloquea lo que bloqueó A | Funciona desde cualquiera de los dos | [ ] |
| 5 | Los dos pulsan el mismo botón casi a la vez | Queda en un estado coherente, igual en ambos (bloqueado y desbloqueado = vuelve a compartido) | [ ] |
| 6 | Bloquear todo y seguir jugando 10 minutos | Cada uno con su economía, sin desync | [ ] |
| 7 | Un jugador se rinde o es eliminado | El otro conserva el saldo; el panel del eliminado desaparece | [ ] |
| 8 | Partida de 20 minutos o más con varios bloqueos | **Sin desync** | [ ] |
| 9 | Al final, comparar los recursos de ambos en la pantalla de estadísticas | Coherentes en los dos ordenadores | [ ] |

## Registro de incidencias

| Fecha | Caso | Qué pasó | Log adjunto |
|---|---|---|---|
| | | | |
