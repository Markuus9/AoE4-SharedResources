-- Pruebas fuera del juego de Shared Resources.
--
-- Ejecutar desde la carpeta del proyecto:
--     lua tests/run_tests.lua
-- o, sin Lua instalado:
--     npm install && npm test
--
-- Compatible con Lua 5.1+ (la versión de SCAR).

local ROOT = (arg and arg[0] and arg[0]:match("^(.*)tests[/\\][^/\\]*$")) or "./"
local SCAR_ROOT = ROOT .. "assets/scar/"

dofile(ROOT .. "tests/mock_engine.lua")

local tests = {}
local function test(name, fn) table.insert(tests, { name = name, fn = fn }) end

local function fail(msg) error(msg, 3) end
local function eq(actual, expected, what)
	if math.abs((actual or 0) - (expected or 0)) > 0.001 or (actual == nil) ~= (expected == nil) then
		fail((what or "valor") .. ": esperado " .. tostring(expected) .. ", obtenido " .. tostring(actual))
	end
end
local function ok(cond, what) if not cond then fail(what or "condición falsa") end end

local ALL = { RT_Food, RT_Wood, RT_Gold, RT_Stone }
local GUID = "01f4238017c449e580234f6bd61fca21"
local function LOC(row) return "$" .. GUID .. ":" .. row end

-- Arranca una partida simulada con solo el módulo de la reserva.
local function start(spec, config)
	Mock_Reset(spec, SCAR_ROOT)
	Mock_LoadMod()
	STR_CONFIG.log_level = 0
	for k, v in pairs(config or {}) do STR_CONFIG[k] = v end
	Mock_StartGame()
end

-- Arranca una partida simulada con el script principal del Game Mode.
-- lobby = { shared = "shared_on"|"shared_off"|nil, buttons = bool|nil, resources = key, villagers = key }
local function start_game_mode(spec, lobby)
	lobby = lobby or {}
	Mock_Reset(spec, SCAR_ROOT)
	if lobby.shared ~= nil then
		Mock_SetEnumOption("shared_section", "shared_mode", { "shared_on", "shared_off" }, lobby.shared)
	end
	if lobby.buttons ~= nil then
		Mock_SetBoolOption("shared_section", "shared_lock_buttons", lobby.buttons)
	end
	if lobby.resources ~= nil then
		Mock_SetEnumOption("section_starting_conditions", "str_start_resources",
			{ "str_resources_standard", "str_resources_medium", "str_resources_high", "str_resources_very_high" }, lobby.resources)
	end
	if lobby.pool_size ~= nil then
		Mock_SetEnumOption("shared_section", "shared_pool_size", { "shared_pool_2", "shared_pool_3", "shared_pool_4" }, lobby.pool_size)
	end
	if lobby.ai_allies ~= nil then
		Mock_SetBoolOption("shared_section", "shared_ai_allies", lobby.ai_allies)
	end
	if lobby.debug ~= nil then
		Mock_SetBoolOption("shared_section", "shared_debug", lobby.debug)
	end
	if lobby.villagers ~= nil then
		Mock_SetEnumOption("section_starting_conditions", "str_extra_villagers",
			{ "str_villagers_0", "str_villagers_6", "str_villagers_12", "str_villagers_20" }, lobby.villagers)
	end
	Mock_LoadGameMode()
	STR_CONFIG.log_level = 0
	Mock_StartGame()
end

-- Coop típico: 2 humanos (equipo 1) contra 2 IA (equipo 2).
local function coop(res_a, res_b)
	return {
		{ team = 1, human = true, name = "Ana", food = res_a or 0, wood = res_a or 0, gold = res_a or 0, stone = res_a or 0 },
		{ team = 1, human = true, name = "Beto", food = res_b or 0, wood = res_b or 0, gold = res_b or 0, stone = res_b or 0 },
		{ team = 2, human = false, food = 300, wood = 300, gold = 300, stone = 300 },
		{ team = 2, human = false, food = 300, wood = 300, gold = 300, stone = 300 },
	}
end

local function pool1() return STR_GetPoolForPlayer(Mock_Player(1).id) end

-- Ejecuta una acción de bloqueo como si llegara por red desde el jugador n.
local function lock_action(n, action)
	STR_OnLockToggleNtw(Mock_Player(n).id, tostring(n) .. "," .. action)
end

---------------------------------------------------------------------------------------------------
-- Contabilidad pura
---------------------------------------------------------------------------------------------------

test("ledger: recursos iniciales de ambos se suman", function()
	Mock_Reset({}, SCAR_ROOT)
	import("sharedteamresources/str_ledger.scar")
	local pool = STR_Ledger_New(ALL)
	STR_Ledger_AddMember(pool, "A", { [RT_Food] = 200, [RT_Wood] = 150, [RT_Gold] = 100, [RT_Stone] = 0 })
	STR_Ledger_AddMember(pool, "B", { [RT_Food] = 200, [RT_Wood] = 150, [RT_Gold] = 100, [RT_Stone] = 0 })
	local targets = STR_Ledger_Sync(pool, {
		A = { [RT_Food] = 200, [RT_Wood] = 150, [RT_Gold] = 100, [RT_Stone] = 0 },
		B = { [RT_Food] = 200, [RT_Wood] = 150, [RT_Gold] = 100, [RT_Stone] = 0 },
	})
	eq(targets[RT_Food], 400, "comida"); eq(targets[RT_Wood], 300, "madera"); eq(targets[RT_Gold], 200, "oro")
	ok(STR_Ledger_CheckInvariant(pool), "invariante")
end)

test("ledger: un miembro no se puede añadir dos veces", function()
	Mock_Reset({}, SCAR_ROOT)
	import("sharedteamresources/str_ledger.scar")
	local pool = STR_Ledger_New(ALL)
	ok(STR_Ledger_AddMember(pool, "A", { [RT_Gold] = 100 }))
	ok(not STR_Ledger_AddMember(pool, "A", { [RT_Gold] = 100 }), "segunda vez debe fallar")
	eq(pool.balance[RT_Gold], 100, "oro")
end)

test("ledger: decimales (recolección fraccionaria) no se pierden", function()
	Mock_Reset({}, SCAR_ROOT)
	import("sharedteamresources/str_ledger.scar")
	local pool = STR_Ledger_New({ RT_Food })
	STR_Ledger_AddMember(pool, "A", { [RT_Food] = 0 })
	STR_Ledger_AddMember(pool, "B", { [RT_Food] = 0 })
	local a, b = 0, 0
	for _ = 1, 100 do
		a = a + 0.37
		local t = STR_Ledger_Sync(pool, { A = { [RT_Food] = a }, B = { [RT_Food] = b } })
		a, b = t[RT_Food], t[RT_Food]
	end
	eq(pool.balance[RT_Food], 37, "comida")
end)

test("ledger: los aportes suman siempre el saldo", function()
	Mock_Reset({}, SCAR_ROOT)
	import("sharedteamresources/str_ledger.scar")
	local pool = STR_Ledger_New({ RT_Gold })
	STR_Ledger_AddMember(pool, "A", { [RT_Gold] = 100 })
	STR_Ledger_AddMember(pool, "B", { [RT_Gold] = 50 })
	STR_Ledger_Sync(pool, { A = { [RT_Gold] = 400 }, B = { [RT_Gold] = 50 } })    -- A +300, B 0
	eq(pool.contrib.A[RT_Gold], 400, "aporte A"); eq(pool.contrib.B[RT_Gold], 50, "aporte B")
	eq(pool.balance[RT_Gold], 450, "saldo")
	STR_Ledger_Sync(pool, { A = { [RT_Gold] = 450 }, B = { [RT_Gold] = 250 } })   -- A 0, B -200
	eq(pool.contrib.B[RT_Gold], -150, "aporte B tras gastar")
	ok(STR_Ledger_CheckInvariant(pool), "invariante")
end)

---------------------------------------------------------------------------------------------------
-- Casos de la sección 8 del documento (integración con el motor simulado)
---------------------------------------------------------------------------------------------------

test("8.1 A recolecta 500 de oro: la reserva sube 500 y ambos la ven", function()
	start(coop(0, 0))
	Mock_Gather(1, RT_Gold, 500)
	Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 500, "A"); eq(Mock_Res(2, RT_Gold), 500, "B")
end)

test("8.2 B gasta 200 de oro: la reserva baja 200", function()
	start(coop(500, 0))
	Mock_Tick()
	ok(Mock_Spend(2, RT_Gold, 200), "B debe poder gastar")
	Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 300, "A"); eq(Mock_Res(2, RT_Gold), 300, "B")
end)

test("8.3 A y B gastan a la vez más del saldo: se crea deuda y se paga después", function()
	start(coop(500, 500))
	Mock_Tick()
	ok(Mock_Spend(1, RT_Gold, 800)); ok(Mock_Spend(2, RT_Gold, 800))
	Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 0, "A ve 0"); eq(Mock_Res(2, RT_Gold), 0, "B ve 0")
	eq(STR_Ledger_GetDebt(pool1(), RT_Gold), 600, "deuda")
	ok(not Mock_Spend(1, RT_Gold, 1), "con deuda no se puede gastar")
	Mock_Gather(1, RT_Gold, 400); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 0, "la deuda absorbe los ingresos")
	Mock_Gather(2, RT_Gold, 300); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 100, "deuda pagada, sobran 100")
	eq(Mock_Res(2, RT_Gold), 100, "B también ve 100")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante")
end)

test("8.3b gastos simultáneos que caben en el saldo no crean deuda", function()
	start(coop(500, 500))
	Mock_Tick()
	ok(Mock_Spend(1, RT_Wood, 400)); ok(Mock_Spend(2, RT_Wood, 500))
	Mock_Tick()
	eq(Mock_Res(1, RT_Wood), 100, "A"); eq(Mock_Res(2, RT_Wood), 100, "B")
	eq(pool1().stats.debt_events, 0, "sin deudas")
end)

test("8.4 A recolecta madera y B construye con ella", function()
	start(coop(0, 0))
	Mock_Gather(1, RT_Wood, 150); Mock_Tick()
	ok(Mock_Spend(2, RT_Wood, 150), "B construye con madera recolectada por A")
	Mock_Tick()
	eq(Mock_Res(1, RT_Wood), 0, "A"); eq(Mock_Res(2, RT_Wood), 0, "B")
end)

test("8.5 B no tiene recursos propios pero el equipo sí", function()
	start(coop(1000, 0))
	eq(Mock_Res(2, RT_Food), 1000, "B ve el saldo común desde el inicio")
	ok(Mock_Spend(2, RT_Food, 1000), "B gasta la comida del equipo")
end)

test("8.6 sin comida suficiente no se puede comprar", function()
	start(coop(25, 25))
	ok(not Mock_Spend(2, RT_Food, 60), "60 > 50: el motor lo rechaza")
	ok(Mock_Spend(2, RT_Food, 50))
end)

test("los ingresos de ambos en el mismo tick se suman", function()
	start(coop(0, 0))
	Mock_Gather(1, RT_Stone, 10); Mock_Gather(2, RT_Stone, 15)
	Mock_Tick()
	eq(Mock_Res(1, RT_Stone), 25, "A"); eq(Mock_Res(2, RT_Stone), 25, "B")
end)

test("reembolso (cancelar producción) vuelve a la reserva", function()
	start(coop(100, 100))
	Mock_Tick()
	ok(Mock_Spend(1, RT_Food, 50)); Mock_Tick()
	Mock_Gather(1, RT_Food, 50)
	Mock_Tick()
	eq(Mock_Res(2, RT_Food), 200, "B")
end)

---------------------------------------------------------------------------------------------------
-- Formación de reservas
---------------------------------------------------------------------------------------------------

test("los equipos solo de IA (enemigos) no comparten", function()
	start(coop(100, 100))
	Mock_Gather(3, RT_Gold, 1000); Mock_Tick(10)
	eq(Mock_Res(3, RT_Gold), 1300, "IA 1 conserva lo suyo"); eq(Mock_Res(4, RT_Gold), 300, "IA 2")
	eq(#STR_STATE.pools, 1, "solo la reserva de los humanos")
end)

test("ai_allies=true: un humano comparte con su aliado IA", function()
	start({
		{ team = 1, human = true, gold = 100 },
		{ team = 1, human = false, gold = 100 },
		{ team = 2, human = false, gold = 100 },
	})
	eq(Mock_Res(1, RT_Gold), 200, "humano"); eq(Mock_Res(2, RT_Gold), 200, "IA aliada")
	eq(Mock_Res(3, RT_Gold), 100, "IA enemiga")
end)

test("ai_allies=false: un humano con aliado IA no comparte", function()
	start({ { team = 1, human = true, gold = 100 }, { team = 1, human = false, gold = 100 } }, { ai_allies = false })
	Mock_Tick(5)
	eq(Mock_Res(1, RT_Gold), 100, "humano"); eq(Mock_Res(2, RT_Gold), 100, "IA")
end)

test("equipos de 3 y 4 comparten (máximo por defecto: 4)", function()
	start({ { team = 1, gold = 100 }, { team = 1, human = false, gold = 100 }, { team = 1, human = false, gold = 100 },
		{ team = 2, human = false } })
	eq(Mock_Res(1, RT_Gold), 300, "tú + 2 IA aliadas"); eq(Mock_Res(3, RT_Gold), 300, "IA aliada")
	Mock_Gather(2, RT_Gold, 30); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 330, "lo que recolecta una IA aliada llega a todos")
	start({ { team = 1, gold = 100 }, { team = 1, gold = 100 }, { team = 1, gold = 100 }, { team = 1, gold = 100 } })
	eq(Mock_Res(4, RT_Gold), 400, "4 humanos")
end)

test("con 3 jugadores, bloquear reparte según lo aportado entre los 3", function()
	start({ { team = 1, gold = 0 }, { team = 1, gold = 0 }, { team = 1, gold = 0 } })
	Mock_Gather(1, RT_Gold, 600); Mock_Gather(2, RT_Gold, 300); Mock_Gather(3, RT_Gold, 100); Mock_Tick()
	ok(Mock_Spend(3, RT_Gold, 500)); Mock_Tick()      -- aportes: 600, 300, -400 -> quedan 500
	lock_action(1, "3")
	eq(Mock_Res(1, RT_Gold), 500 * 600 / 900, "A"); eq(Mock_Res(2, RT_Gold), 500 * 300 / 900, "B")
	eq(Mock_Res(3, RT_Gold), 0, "C gastó más de lo que aportó")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante")
end)

test("un equipo por encima del máximo no comparte", function()
	start({ { team = 1, gold = 100 }, { team = 1, gold = 100 }, { team = 1, gold = 100 }, { team = 2, human = false } },
		{ max_players_per_pool = 2 })
	Mock_Tick(5)
	eq(Mock_Res(1, RT_Gold), 100, "sin reserva")
	eq(#STR_STATE.pools, 0, "ninguna reserva")
end)

test("dos equipos de humanos tienen reservas separadas", function()
	start({ { team = 1, gold = 100 }, { team = 2, gold = 50 }, { team = 1, gold = 100 }, { team = 2, gold = 50 } })
	eq(#STR_STATE.pools, 2, "dos reservas")
	eq(Mock_Res(1, RT_Gold), 200, "equipo 1"); eq(Mock_Res(2, RT_Gold), 100, "equipo 2")
	Mock_Gather(2, RT_Gold, 10); Mock_Tick()
	eq(Mock_Res(3, RT_Gold), 200, "equipo 1 no cambia"); eq(Mock_Res(4, RT_Gold), 110, "equipo 2")
end)

test("jugadores sin equipo (>=100) no comparten", function()
	start({ { team = 101, gold = 100 }, { team = 102, gold = 100 } })
	eq(#STR_STATE.pools, 0, "ninguna reserva")
end)

test("si un aliado es eliminado y el motor vacía sus recursos, la reserva no pierde nada", function()
	start(coop(500, 500))
	Mock_Tick()
	Mock_Eliminate(2, true)
	Mock_Tick(3)
	eq(Mock_Res(1, RT_Gold), 1000, "el superviviente conserva el saldo común")
	Mock_Gather(1, RT_Gold, 5); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 1005, "sigue funcionando")
	eq(Mock_Res(2, RT_Gold), 0, "al eliminado ya no se le escribe")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante (aportes)")
end)

test("eliminación detectada en la regla aunque no llegue OnPlayerDefeated", function()
	start(coop(500, 500))
	Mock_Tick()
	Mock_Player(2).isEliminated = true
	for rt, _ in pairs(MOCK.res[Mock_Player(2).id]) do MOCK.res[Mock_Player(2).id][rt] = 0 end
	Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 1000, "superviviente")
end)

---------------------------------------------------------------------------------------------------
-- Bloqueo de recursos
---------------------------------------------------------------------------------------------------

test("bloquear: el saldo se reparte según lo aportado", function()
	start(coop(0, 0))
	Mock_Gather(1, RT_Gold, 800); Mock_Gather(2, RT_Gold, 200); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 1000, "antes, ambos ven 1000")
	lock_action(1, "3")
	ok(not STR_Ledger_IsShared(pool1(), RT_Gold), "oro bloqueado")
	eq(Mock_Res(1, RT_Gold), 800, "A recibe lo que aportó"); eq(Mock_Res(2, RT_Gold), 200, "B recibe lo suyo")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante")
end)

test("bloquear: quien gastó más de lo que aportó no recibe nada", function()
	start(coop(0, 0))
	Mock_Gather(1, RT_Food, 1000); Mock_Tick()
	ok(Mock_Spend(2, RT_Food, 400)); Mock_Tick()      -- A aporta +1000, B -400
	lock_action(2, "1")
	eq(Mock_Res(1, RT_Food), 600, "A se queda con todo lo que queda"); eq(Mock_Res(2, RT_Food), 0, "B")
end)

test("bloquear: los recursos iniciales cuentan como aporte de cada uno", function()
	start(coop(300, 100))
	lock_action(1, "2")
	eq(Mock_Res(1, RT_Wood), 300, "A"); eq(Mock_Res(2, RT_Wood), 100, "B")
end)

test("bloquear: también cuenta lo ocurrido en el mismo tick antes del clic", function()
	start(coop(0, 0))
	Mock_Gather(2, RT_Stone, 50)          -- todavía sin sincronizar
	lock_action(1, "4")
	eq(Mock_Res(1, RT_Stone), 0, "A"); eq(Mock_Res(2, RT_Stone), 50, "B conserva lo que acaba de recolectar")
end)

test("bloqueado: cada uno recolecta y gasta lo suyo, el resto sigue compartido", function()
	start(coop(100, 100))
	lock_action(1, "3")
	Mock_Gather(1, RT_Gold, 50); Mock_Gather(1, RT_Wood, 50); Mock_Tick(3)
	eq(Mock_Res(1, RT_Gold), 150, "oro de A"); eq(Mock_Res(2, RT_Gold), 100, "oro de B no cambia")
	eq(Mock_Res(2, RT_Wood), 250, "la madera sigue compartida")
	ok(Mock_Spend(2, RT_Gold, 100)); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 150, "el gasto de B no afecta a A")
end)

test("desbloquear: los saldos vuelven a sumarse", function()
	start(coop(100, 100))
	lock_action(1, "3")
	Mock_Gather(1, RT_Gold, 400); Mock_Tick()
	lock_action(2, "3")                    -- cualquiera de los dos puede desbloquear
	ok(STR_Ledger_IsShared(pool1(), RT_Gold), "oro compartido")
	eq(Mock_Res(1, RT_Gold), 600, "A"); eq(Mock_Res(2, RT_Gold), 600, "B")
	Mock_Gather(2, RT_Gold, 10); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 610, "vuelve a sincronizar")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante")
end)

test("bloquear con deuda: la deuda queda pendiente y se descuenta al desbloquear", function()
	start(coop(500, 500))
	Mock_Tick()
	ok(Mock_Spend(1, RT_Gold, 800)); ok(Mock_Spend(2, RT_Gold, 800)); Mock_Tick()   -- deuda 600
	lock_action(1, "3")
	eq(Mock_Res(1, RT_Gold), 0, "A"); eq(Mock_Res(2, RT_Gold), 0, "B")
	Mock_Gather(1, RT_Gold, 500); Mock_Gather(2, RT_Gold, 300); Mock_Tick()
	eq(Mock_Res(1, RT_Gold), 500, "bloqueado: A tiene lo suyo")
	lock_action(1, "3")
	eq(Mock_Res(1, RT_Gold), 200, "800 - 600 de deuda"); eq(Mock_Res(2, RT_Gold), 200, "B")
	ok(STR_Ledger_CheckInvariant(pool1()), "invariante")
end)

test("bloquear todo y compartir todo", function()
	start(coop(100, 300))
	lock_action(1, "2")                    -- madera ya bloqueada
	lock_action(2, "all")                  -- queda algo compartido -> bloquea el resto
	for _, rt in ipairs(ALL) do ok(not STR_Ledger_IsShared(pool1(), rt), "todo bloqueado") end
	eq(Mock_Res(1, RT_Food), 100, "comida de A"); eq(Mock_Res(2, RT_Food), 300, "comida de B")
	lock_action(1, "all")                  -- nada compartido -> comparte todo
	for _, rt in ipairs(ALL) do ok(STR_Ledger_IsShared(pool1(), rt), "todo compartido") end
	eq(Mock_Res(1, RT_Gold), 400, "A"); eq(Mock_Res(2, RT_Gold), 400, "B")
end)

test("acciones inválidas o de jugadores fuera de la reserva se ignoran", function()
	start(coop(100, 100))
	lock_action(3, "1")                    -- IA enemiga
	lock_action(1, "9")                    -- recurso inexistente
	STR_OnLockToggleNtw(nil, "abc")
	for _, rt in ipairs(ALL) do ok(STR_Ledger_IsShared(pool1(), rt), "nada cambia") end
	Mock_Eliminate(2, false)
	lock_action(2, "1")                    -- eliminado
	ok(STR_Ledger_IsShared(pool1(), RT_Food), "el eliminado no bloquea")
end)

---------------------------------------------------------------------------------------------------
-- Botones (UI) y red
---------------------------------------------------------------------------------------------------

test("UI: el panel se crea solo para el jugador local de la reserva", function()
	start(coop(100, 100))
	ok(MOCK.ui.STR_LockUI ~= nil, "panel creado")
	local xaml = MOCK.ui.STR_LockUI.xaml
	for _, p in ipairs({ '"1"', '"2"', '"3"', '"4"', '"all"' }) do
		ok(string.find(xaml, 'CommandParameter=' .. p, 1, true), "falta botón " .. p)
	end
	for _, k in ipairs({ "food", "wood", "gold", "stone" }) do
		ok(string.find(xaml, "{Binding [" .. k .. "_icon]}", 1, true), "binding icono " .. k)
		ok(string.find(xaml, "{Binding [" .. k .. "_state]}", 1, true), "binding estado " .. k)
		ok(string.find(xaml, "{Binding [" .. k .. "_opacity]}", 1, true), "binding opacidad " .. k)
	end
	ok(not string.find(xaml, "]]", 1, true), "sin restos de cadenas Lua")

	Mock_Reset({ { team = 2, human = false }, { team = 1 }, { team = 1 } }, SCAR_ROOT)
	Mock_LoadMod(); STR_CONFIG.log_level = 0; Mock_StartGame()
	ok(MOCK.ui.STR_LockUI == nil, "un local fuera de la reserva no ve el panel")
end)

test("UI: columna junto a los recursos (Todos arriba, luego comida-madera-oro-piedra)", function()
	start(coop(100, 100))
	local xaml = MOCK.ui.STR_LockUI.xaml
	ok(string.find(xaml, 'Orientation="Vertical" SnapsToDevicePixels', 1, true), "columna")
	ok(string.find(xaml, 'Margin="198,0,0,16"', 1, true), "margen por defecto")
	ok(string.find(xaml, 'Height="37"', 1, true), "alto de fila 39 - 2")
	local order = {}
	for p in string.gmatch(xaml, 'CommandParameter="([^"]+)"') do order[#order + 1] = p end
	ok(table.concat(order, ",") == "all,1,2,3,4", "orden: " .. table.concat(order, ","))
	start(coop(100, 100), { ui = { layout = "row", margin = "10,0,0,200" } })
	xaml = MOCK.ui.STR_LockUI.xaml
	order = {}
	for p in string.gmatch(xaml, 'CommandParameter="([^"]+)"') do order[#order + 1] = p end
	ok(table.concat(order, ",") == "1,2,3,4,all", "fila: " .. table.concat(order, ","))
	ok(string.find(xaml, 'Orientation="Horizontal" SnapsToDevicePixels', 1, true), "fila horizontal")
end)

test("UI: un clic viaja por la red y se aplica en el siguiente tick", function()
	start(coop(100, 100))
	Mock_Click("3")
	eq(MOCK.network_sent, 1, "enviado por red")
	ok(STR_Ledger_IsShared(pool1(), RT_Gold), "todavía no se aplica (es local)")
	Mock_Tick()
	ok(not STR_Ledger_IsShared(pool1(), RT_Gold), "aplicado al llegar el evento")
	local data = MOCK.ui.STR_LockUI.data
	eq(data.gold_state == "Bloqueado" and 1 or 0, 1, "texto del botón")
	eq(data.gold_opacity, 0.35, "icono atenuado")
	eq(data.food_opacity, 1, "comida sigue normal")
	eq(data.all_text == "Bloquear todo" and 1 or 0, 1, "botón general")
	Mock_Click("all"); Mock_Tick()
	eq(MOCK.ui.STR_LockUI.data.all_text == "Compartir todo" and 1 or 0, 1, "todo bloqueado")
end)

test("UI: el clic del aliado (otro cliente) también actualiza mi panel", function()
	start(coop(100, 100))
	Mock_SetLocal(2); Mock_Click("1"); Mock_SetLocal(1)   -- B pulsa en su ordenador
	Mock_Tick()
	eq(MOCK.ui.STR_LockUI.data.food_state == "Bloqueado" and 1 or 0, 1, "A ve la comida bloqueada")
end)

test("UI: sin la opción de botones no hay panel; en repeticiones tampoco", function()
	start(coop(100, 100), { lock_ui = false })
	ok(MOCK.ui.STR_LockUI == nil, "sin botones")
	Mock_Reset(coop(100, 100), SCAR_ROOT)
	MOCK.replay = true
	Mock_LoadMod(); STR_CONFIG.log_level = 0; Mock_StartGame()
	ok(MOCK.ui.STR_LockUI == nil, "repetición")
end)

test("UI: si el jugador local es eliminado, su panel desaparece", function()
	start(coop(100, 100))
	Mock_Eliminate(1, true)
	ok(MOCK.ui.STR_LockUI == nil, "panel quitado")
end)

test("sin Network_RegisterEvent no se crean botones (nunca cambios solo locales)", function()
	Mock_Reset(coop(100, 100), SCAR_ROOT)
	local saved = Network_RegisterEvent
	Network_RegisterEvent = nil
	Mock_LoadMod(); STR_CONFIG.log_level = 0
	local success, err = pcall(Mock_StartGame)
	Network_RegisterEvent = saved
	ok(success, tostring(err))
	ok(MOCK.ui.STR_LockUI == nil, "sin panel")
	eq(Mock_Res(2, RT_Gold), 200, "la reserva sí funciona")
end)

---------------------------------------------------------------------------------------------------
-- Otros
---------------------------------------------------------------------------------------------------

test("enabled=false: no hace nada", function()
	start(coop(100, 0), { enabled = false })
	Mock_Tick(5)
	eq(Mock_Res(2, RT_Gold), 0, "B no recibe nada")
	ok(MOCK.ui.STR_LockUI == nil, "sin panel")
end)

test("diagnostics_only: observa pero no modifica", function()
	start(coop(100, 0), { diagnostics = true, diagnostics_only = true, log_level = 1 })
	Mock_Gather(1, RT_Gold, 50)
	Mock_Tick(20)
	eq(Mock_Res(2, RT_Gold), 0, "B intacto")
	eq(MOCK.set_calls, 0, "ningún Player_SetResource")
	ok(Mock_LogContains("[diag]"), "la sonda escribe en el log")
	Mock_FireEvent(GE_ConstructionComplete, { player = Mock_Player(2).id, pbg = "house" })
	ok(Mock_LogContains("ConstructionComplete"), "registra eventos")
	ok(Mock_LogContains("jugador=p1"), "identifica al jugador del evento")
end)

test("sync_interval > 0 usa Rule_AddInterval", function()
	start(coop(0, 0), { sync_interval = 1 })
	Mock_Gather(1, RT_Gold, 10)
	Mock_Tick(1)
	eq(Mock_Res(2, RT_Gold), 0, "todavía no")
	Mock_Tick(8)
	eq(Mock_Res(2, RT_Gold), 10, "tras 1 s")
end)

test("sin Rule_Add en el motor se usa Rule_AddInterval de 0,125 s", function()
	Mock_Reset(coop(0, 0), SCAR_ROOT)
	Mock_LoadMod()
	STR_CONFIG.log_level = 0
	local saved = Rule_Add
	Rule_Add = nil
	local success, err = pcall(Mock_StartGame)
	Rule_Add = saved
	ok(success, tostring(err))
	Mock_Gather(1, RT_Gold, 10); Mock_Tick(1)
	eq(Mock_Res(2, RT_Gold), 10, "sincroniza cada tick")
end)

test("sin cambios no se llama a Player_SetResource", function()
	start(coop(100, 100))
	local before = MOCK.set_calls
	Mock_Tick(50)
	eq(MOCK.set_calls, before, "llamadas extra")
end)

test("OnGameOver detiene la sincronización, quita el panel y vuelca el estado", function()
	start(coop(100, 100), { log_level = 1 })
	Mock_CallDelegates("OnGameOver")
	ok(not Rule_Exists(STR_Rule_Sync), "regla quitada")
	ok(MOCK.ui.STR_LockUI == nil, "panel quitado")
	ok(Mock_LogContains("estado"), "volcado en el log")
end)

---------------------------------------------------------------------------------------------------
-- Script principal del Game Mode (assets/scar/SharedTeamResources.scar)
---------------------------------------------------------------------------------------------------

test("modo: importa el modo estándar oficial y registra su módulo", function()
	start_game_mode(coop(100, 100), { shared = "shared_on" })
	local found = false
	for _, p in ipairs(MOCK.engine_imports) do if p == "gamemodes/standard_mode.scar" then found = true end end
	ok(found, "falta import gamemodes/standard_mode.scar")
	local registered = false
	for _, m in ipairs(MOCK.modules) do if m == "STRGameMode" then registered = true end end
	ok(registered, "módulo STRGameMode")
end)

test("modo: opción 'Activados' comparte y 'Desactivados' no", function()
	start_game_mode(coop(100, 50), { shared = "shared_on" })
	eq(Mock_Res(2, RT_Gold), 150, "compartido")
	start_game_mode(coop(100, 50), { shared = "shared_off" })
	Mock_Gather(1, RT_Gold, 10); Mock_Tick(5)
	eq(Mock_Res(1, RT_Gold), 110, "A"); eq(Mock_Res(2, RT_Gold), 50, "B")
	eq(MOCK.set_calls, 0, "ningún Player_SetResource")
	ok(MOCK.ui.STR_LockUI == nil, "sin panel")
end)

test("modo: sin la opción en el lobby queda activado", function()
	start_game_mode(coop(100, 50), {})
	eq(Mock_Res(2, RT_Gold), 150, "B")
end)

test("modo: opción 'Botones de bloqueo' desactivada", function()
	start_game_mode(coop(100, 50), { shared = "shared_on", buttons = false })
	ok(MOCK.ui.STR_LockUI == nil, "sin panel")
	eq(Mock_Res(2, RT_Gold), 150, "la reserva funciona")
end)

test("modo: recursos iniciales del lobby se aplican antes de crear la reserva", function()
	start_game_mode(coop(0, 0), { resources = "str_resources_medium" })
	eq(Mock_Res(1, RT_Food), 2000, "comida 1000 + 1000"); eq(Mock_Res(1, RT_Gold), 1200, "oro 600 + 600")
	eq(Mock_Res(3, RT_Food), 1000, "la IA enemiga también recibe los suyos (sin compartir)")
	start_game_mode(coop(50, 50), { resources = "str_resources_standard" })
	eq(Mock_Res(1, RT_Food), 100, "estándar no toca nada")
end)

test("modo: aldeanos extra para cada jugador junto al centro urbano", function()
	start_game_mode(coop(0, 0), { villagers = "str_villagers_12" })
	eq(#MOCK.spawned, 4, "un grupo por jugador")
	eq(MOCK.spawned[1].count, 12, "12 aldeanos"); ok(MOCK.spawned[1].sbp == "villager_bp", "aldeano de su civilización")
	eq(MOCK.spawned[1].pos.x, 21, "junto al centro urbano")
	start_game_mode(coop(0, 0), { villagers = "str_villagers_0" })
	eq(#MOCK.spawned, 0, "ninguno")
end)

test("modo: avisos de activación, deuda y bloqueo con los textos del CSV", function()
	start_game_mode(coop(500, 500), { shared = "shared_on" })
	eq(#MOCK.cues, 1, "aviso de activación")
	ok(MOCK.cues[1] == LOC(15), "fila 15")
	Mock_Tick()
	ok(Mock_Spend(1, RT_Gold, 800)); ok(Mock_Spend(2, RT_Gold, 800)); Mock_Tick()
	ok(MOCK.cues[2] == LOC(13) .. "|600", "deuda de oro: " .. tostring(MOCK.cues[2]))
	Mock_Tick(5)
	eq(#MOCK.cues, 2, "la deuda no se repite")
	Mock_SetLocal(2); Mock_Click("1"); Mock_SetLocal(1); Mock_Tick()
	ok(MOCK.cues[3] == LOC(16) .. "|Beto", "bloqueo de comida por Beto: " .. tostring(MOCK.cues[3]))
	Mock_Click("1"); Mock_Tick()
	ok(MOCK.cues[4] == LOC(20) .. "|Ana", "desbloqueo: " .. tostring(MOCK.cues[4]))
	Mock_Click("all"); Mock_Tick()
	ok(MOCK.cues[5] == LOC(24) .. "|Ana", "bloquear todo: " .. tostring(MOCK.cues[5]))
	Mock_Click("all"); Mock_Tick()
	ok(MOCK.cues[6] == LOC(25) .. "|Ana", "compartir todo: " .. tostring(MOCK.cues[6]))
end)

test("modo: opción 'Jugadores por reserva' del lobby", function()
	local three = { { team = 1, gold = 100 }, { team = 1, human = false, gold = 100 }, { team = 1, human = false, gold = 100 },
		{ team = 2, human = false, gold = 100 } }
	start_game_mode(three, { pool_size = "shared_pool_2" })
	eq(#STR_STATE.pools, 0, "hasta 2: un equipo de 3 no comparte")
	start_game_mode(three, { pool_size = "shared_pool_3" })
	eq(Mock_Res(1, RT_Gold), 300, "hasta 3: comparte")
	start_game_mode(three, {})
	eq(Mock_Res(1, RT_Gold), 300, "sin opción: hasta 4")
end)

test("modo: opción 'Incluir IA aliada' del lobby", function()
	local spec = { { team = 1, gold = 100 }, { team = 1, human = false, gold = 100 }, { team = 2, human = false, gold = 100 } }
	start_game_mode(spec, { ai_allies = false })
	eq(#STR_STATE.pools, 0, "sin IA aliada no hay reserva")
	start_game_mode(spec, { ai_allies = true })
	eq(Mock_Res(1, RT_Gold), 200, "con IA aliada comparte")
end)

test("modo: avisos de depuración explican por qué se comparte o no", function()
	local three = { { team = 1, gold = 100 }, { team = 1, human = false }, { team = 1, human = false }, { team = 2, human = false } }
	start_game_mode(three, { debug = true, pool_size = "shared_pool_2" })
	ok(MOCK.cues[1] == LOC(83) .. "|3|2", "demasiados: " .. tostring(MOCK.cues[1]))

	start_game_mode({ { team = 1 }, { team = 1, human = false }, { team = 2, human = false } }, { debug = true, ai_allies = false })
	ok(MOCK.cues[1] == LOC(84) .. "|1", "pocos: " .. tostring(MOCK.cues[1]))

	start_game_mode(coop(100, 100), { debug = true, shared = "shared_off" })
	ok(MOCK.cues[1] == LOC(85), "desactivado: " .. tostring(MOCK.cues[1]))

	start_game_mode({ { team = 101 }, { team = 102 } }, { debug = true })
	ok(MOCK.cues[1] == LOC(86), "sin equipo: " .. tostring(MOCK.cues[1]))

	start_game_mode(three, { debug = true })
	ok(MOCK.cues[1] == LOC(82) .. "|3", "reserva creada: " .. tostring(MOCK.cues[1]))
	ok(MOCK.cues[2] == LOC(15), "activación")
	ok(MOCK.cues[3] == LOC(87), "panel creado: " .. tostring(MOCK.cues[3]))

	start_game_mode(three, { debug = false })
	eq(#MOCK.cues, 1, "sin depuración solo el aviso de activación")
end)

test("modo: aviso de depuración si el panel falla o no hay red", function()
	Mock_Reset(coop(100, 100), SCAR_ROOT)
	Mock_SetBoolOption("shared_section", "shared_debug", true)
	Mock_LoadGameMode(); STR_CONFIG.log_level = 0
	local saved = UI_AddChild
	UI_AddChild = function() error("XAML inválido") end
	Mock_StartGame()
	UI_AddChild = saved
	ok(MOCK.cues[#MOCK.cues] == LOC(88), "error de panel: " .. tostring(MOCK.cues[#MOCK.cues]))

	Mock_Reset(coop(100, 100), SCAR_ROOT)
	Mock_SetBoolOption("shared_section", "shared_debug", true)
	local saved_net = Network_RegisterEvent
	Network_RegisterEvent = nil
	Mock_LoadGameMode(); STR_CONFIG.log_level = 0
	Mock_StartGame()
	Network_RegisterEvent = saved_net
	ok(MOCK.cues[#MOCK.cues] == LOC(89), "sin red: " .. tostring(MOCK.cues[#MOCK.cues]))
end)

test("modo: un fallo de la UI no rompe la sincronización", function()
	start_game_mode(coop(500, 500), { shared = "shared_on" })
	local saved = UI_CreateEventCueClickable
	UI_CreateEventCueClickable = function() error("UI no disponible") end
	Mock_Tick()
	ok(Mock_Spend(1, RT_Gold, 800)); ok(Mock_Spend(2, RT_Gold, 800))
	local success, err = pcall(Mock_Tick)
	UI_CreateEventCueClickable = saved
	ok(success, tostring(err))
	eq(Mock_Res(1, RT_Gold), 0, "sincronizado")
end)

---------------------------------------------------------------------------------------------------
-- Prueba aleatoria de conservación (con bloqueos)
---------------------------------------------------------------------------------------------------

test("fuzz: 5.000 ticks aleatorios con bloqueos conservan los recursos", function()
	math.randomseed(12345)
	start(coop(200, 200))
	-- "verdad" externa: lo que realmente entró y salió del equipo.
	local truth = {}
	for _, rt in ipairs(ALL) do truth[rt] = Mock_Res(1, rt) + 0 end
	truth[RT_Food] = 400; truth[RT_Wood] = 400; truth[RT_Gold] = 400; truth[RT_Stone] = 400
	local pool = pool1()
	for _ = 1, 5000 do
		for n = 1, 2 do
			local rt = ALL[math.random(1, 4)]
			local r = math.random()
			if r < 0.5 then
				local amount = math.random(1, 20) + math.random()
				Mock_Gather(n, rt, amount); truth[rt] = truth[rt] + amount
			elseif r < 0.8 then
				local amount = math.random(1, 300)
				if Mock_Spend(n, rt, amount) then truth[rt] = truth[rt] - amount end
			elseif r < 0.81 then
				lock_action(n, tostring(math.random(1, 4)))
			elseif r < 0.812 then
				lock_action(n, "all")
			end
		end
		Mock_Tick()
		for _, rt in ipairs(ALL) do
			if STR_Ledger_IsShared(pool, rt) then
				eq(pool.balance[rt], truth[rt], "saldo vs verdad")
				eq(Mock_Res(1, rt), Mock_Res(2, rt), "ambos ven lo mismo")
				eq(Mock_Res(1, rt), math.max(truth[rt], 0), "visible")
			else
				-- Bloqueado: lo que tienen los dos + deuda pendiente = verdad.
				eq(Mock_Res(1, rt) + Mock_Res(2, rt) + pool.balance[rt], truth[rt], "bloqueado vs verdad")
			end
		end
	end
	local ok_inv, bad, diff = STR_Ledger_CheckInvariant(pool)
	ok(ok_inv, "invariante " .. tostring(bad) .. " " .. tostring(diff))
end)

---------------------------------------------------------------------------------------------------

local passed, failed = 0, 0
for _, t in ipairs(tests) do
	local success, err = pcall(t.fn)
	if success then
		passed = passed + 1
		io.write("  ok    ", t.name, "\n")
	else
		failed = failed + 1
		io.write("  FALLO ", t.name, "\n        ", tostring(err), "\n")
	end
end
io.write(string.format("\n%d pruebas, %d correctas, %d fallidas\n", passed + failed, passed, failed))
if failed > 0 then os.exit(1) end
