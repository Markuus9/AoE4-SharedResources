-- Motor simulado de AoE4 para probar los scripts SCAR fuera del juego.
--
-- Imita solo lo que usa el mod. Lo más importante que reproduce:
--   * Cada jugador tiene su propio saldo y el motor solo permite gastar
--     si ESE jugador tiene suficiente (igual que el juego real).
--   * Las reglas (Rule_Add / Rule_AddInterval) se ejecutan en cada Mock_Tick().
--   * Las órdenes de varios jugadores dentro del mismo tick se procesan antes
--     que las reglas de SCAR (caso de gasto simultáneo).
--   * Network_CallEvent no llega al instante: el mensaje se entrega al inicio
--     del siguiente tick, como un comando de red.
--   * Los imports de scripts del juego (cardinal.scar, gamemodes/...) se
--     ignoran; solo se cargan los archivos de este proyecto.

MOCK = {}

RT_Food = "RT_Food"
RT_Wood = "RT_Wood"
RT_Gold = "RT_Gold"
RT_Stone = "RT_Stone"

R_ALLY = "R_ALLY"
R_ENEMY = "R_ENEMY"
R_NEUTRAL = "R_NEUTRAL"

GE_ConstructionComplete = "GE_ConstructionComplete"
GE_UpgradeComplete = "GE_UpgradeComplete"

ECV_Queue = "ECV_Queue"
BA_VILLAGER = "BA_VILLAGER"
FILTER_KEEP = "FILTER_KEEP"
nothing = function() end

MOCK_TICK_SECONDS = 0.125

-- spec = { { team = 1, human = true, food = 200, wood = 0, gold = 0, stone = 0, race = "english", name = "Ana" }, ... }
function Mock_Reset(spec, scar_root)
	MOCK.scar_root = scar_root or MOCK.scar_root
	MOCK.res = {}
	MOCK.team = {}
	MOCK.human = {}
	MOCK.rules = {}
	MOCK.events = {}
	MOCK.modules = {}
	MOCK.imported = {}
	MOCK.engine_imports = {}
	MOCK.log = {}
	MOCK.cues = {}
	MOCK.delegate_calls = {}
	MOCK.options = {}
	MOCK.network_events = {}
	MOCK.network_queue = {}
	MOCK.network_sent = 0
	MOCK.ui = {}
	MOCK.spawned = {}
	MOCK.set_calls = 0
	MOCK.time = 0
	MOCK.replay = false
	PLAYERS = {}
	for i, p in ipairs(spec) do
		-- En el juego los ids son userdata; aquí, tablas (también se comparan por identidad).
		local id = { slot = i }
		MOCK.res[id] = {
			[RT_Food] = p.food or 0,
			[RT_Wood] = p.wood or 0,
			[RT_Gold] = p.gold or 0,
			[RT_Stone] = p.stone or 0,
		}
		MOCK.team[id] = p.team
		MOCK.human[id] = (p.human ~= false)
		table.insert(PLAYERS, {
			id = id,
			index = i,
			slotIndex = i - 1,
			isLocal = (i == (p.local_index or 1)),
			isEliminated = false,
			raceName = p.race or "english",
			startingPos = { x = i * 100, y = 0 },
			name = p.name or ("Jugador" .. i),
		})
	end
end

function Mock_Player(n)
	return PLAYERS[n]
end

function Mock_Res(n, rt)
	return MOCK.res[PLAYERS[n].id][rt]
end

-- Cambia qué jugador es el de "este cliente".
function Mock_SetLocal(n)
	for i, p in ipairs(PLAYERS) do
		p.isLocal = (i == n)
	end
end

-- Recolección: el motor suma al jugador que deposita.
function Mock_Gather(n, rt, amount)
	local id = PLAYERS[n].id
	MOCK.res[id][rt] = MOCK.res[id][rt] + amount
end

-- Gasto: el motor comprueba el saldo DEL JUGADOR. Devuelve true si se pudo.
function Mock_Spend(n, rt, amount)
	local id = PLAYERS[n].id
	if MOCK.res[id][rt] + 1e-9 < amount then
		return false
	end
	MOCK.res[id][rt] = MOCK.res[id][rt] - amount
	return true
end

-- Elimina a un jugador. El motor puede vaciar sus recursos (caso pesimista).
function Mock_Eliminate(n, zero_resources)
	local player = PLAYERS[n]
	player.isEliminated = true
	if zero_resources then
		for rt, _ in pairs(MOCK.res[player.id]) do
			MOCK.res[player.id][rt] = 0
		end
	end
	Mock_CallDelegates("OnPlayerDefeated", player, "test")
end

function Mock_Tick(count)
	for _ = 1, (count or 1) do
		MOCK.time = MOCK.time + MOCK_TICK_SECONDS
		-- Los comandos de red pendientes llegan al principio del tick.
		local queue = MOCK.network_queue
		MOCK.network_queue = {}
		for _, msg in ipairs(queue) do
			_G[msg.func](msg.sender, msg.message)
		end
		-- Copia para que las reglas puedan añadirse/quitarse durante el tick.
		local rules = {}
		for i, r in ipairs(MOCK.rules) do rules[i] = r end
		for _, r in ipairs(rules) do
			if not r.removed and MOCK.time + 1e-9 >= r.next then
				r.next = MOCK.time + r.interval
				r.fn()
			end
		end
	end
end

-- Carga solo el módulo de la reserva.
function Mock_LoadMod()
	import("sharedteamresources/str_main.scar")
end

-- Carga el script principal del Game Mode (como hace el juego).
function Mock_LoadGameMode()
	import("SharedTeamResources.scar")
end

-- Llama a las funciones <Modulo>_<suffix> de los módulos registrados (como cardinal).
function Mock_CallDelegates(suffix, ...)
	local modules = {}
	for i, m in ipairs(MOCK.modules) do modules[i] = m end
	for _, name in ipairs(modules) do
		local fn = _G[name .. "_" .. suffix]
		if fn ~= nil then
			fn(...)
		end
	end
end

-- Simula el arranque de partida en el orden del framework.
function Mock_StartGame()
	Mock_CallDelegates("OnGameSetup")
	Mock_CallDelegates("PreInit")
	Mock_CallDelegates("OnInit")
	Mock_CallDelegates("PostInit")
	Mock_CallDelegates("Start")
end

-- Opción de lista del .rdo: section.option = item elegido.
function Mock_SetEnumOption(section, option, items, selected)
	local enum_items = {}
	for i, key in ipairs(items) do enum_items[key] = i end
	MOCK.options[section] = MOCK.options[section] or {}
	MOCK.options[section][option] = { enum_value = enum_items[selected], enum_items = enum_items }
end

-- Opción sí/no del .rdo.
function Mock_SetBoolOption(section, option, value)
	MOCK.options[section] = MOCK.options[section] or {}
	MOCK.options[section][option] = value
end

-- Simula un clic del jugador local en el panel de bloqueo.
function Mock_Click(parameter)
	local data = MOCK.ui.STR_LockUI and MOCK.ui.STR_LockUI.data
	if data == nil then
		error("no hay panel de bloqueo")
	end
	_G[data.click.callback](parameter)
end

---------------------------------------------------------------------------------------------------
-- API de SCAR simulada
---------------------------------------------------------------------------------------------------

local function is_project_file(path)
	return path == "SharedTeamResources.scar" or string.sub(path, 1, 20) == "sharedteamresources/"
end

function import(path)
	if MOCK.imported[path] then
		return
	end
	MOCK.imported[path] = true
	if is_project_file(path) then
		dofile(MOCK.scar_root .. path)
	else
		table.insert(MOCK.engine_imports, path)
	end
end

function print(text)
	table.insert(MOCK.log, tostring(text))
	if MOCK.verbose then
		io.write(tostring(text), "\n")
	end
end

function Player_GetResource(id, rt)
	return MOCK.res[id][rt]
end

function Player_SetResource(id, rt, value)
	MOCK.set_calls = MOCK.set_calls + 1
	MOCK.res[id][rt] = value
end

function Player_GetTeam(id)
	return MOCK.team[id]
end

function Player_IsHuman(id)
	return MOCK.human[id]
end

function Player_GetDisplayName(id)
	local p = Core_GetPlayersTableEntry(id)
	return p and p.name
end

function Player_ObserveRelationship(a, b)
	if a == b or MOCK.team[a] == MOCK.team[b] then
		return R_ALLY
	end
	return R_ENEMY
end

function Game_GetLocalPlayer()
	for _, p in ipairs(PLAYERS) do
		if p.isLocal then return p.id end
	end
	return nil
end

function Core_GetPlayersTableEntry(id)
	for _, p in ipairs(PLAYERS) do
		if p.id == id then return p end
	end
	return nil
end

function Core_GetPlayersTableEntryFromIndex(index)
	return PLAYERS[index]
end

function Core_RegisterModule(name)
	table.insert(MOCK.modules, name)
end

function Core_UnregisterModule(name)
	for i, m in ipairs(MOCK.modules) do
		if m == name then
			table.remove(MOCK.modules, i)
			return
		end
	end
end

function Core_CallDelegateFunctions(suffix, ...)
	table.insert(MOCK.delegate_calls, suffix)
end

function Setup_GetWinConditionOptions(target)
	for k, v in pairs(MOCK.options) do target[k] = v end
end

local function add_rule(fn, interval)
	table.insert(MOCK.rules, { fn = fn, interval = interval, next = MOCK.time + interval })
end

function Rule_Add(fn) add_rule(fn, MOCK_TICK_SECONDS) end
function Rule_AddInterval(fn, seconds) add_rule(fn, seconds) end

function Rule_Exists(fn)
	for _, r in ipairs(MOCK.rules) do
		if r.fn == fn and not r.removed then return true end
	end
	return false
end

function Rule_Remove(fn)
	for _, r in ipairs(MOCK.rules) do
		if r.fn == fn then r.removed = true end
	end
end

function Rule_AddGlobalEvent(fn, event)
	MOCK.events[event] = MOCK.events[event] or {}
	table.insert(MOCK.events[event], fn)
end

function Mock_FireEvent(event, context)
	for _, fn in ipairs(MOCK.events[event] or {}) do
		fn(context)
	end
end

-- Red (network.scar): el evento se registra por nombre y llega en el siguiente tick.
function Network_RegisterEvent(name)
	MOCK.network_events[name] = true
end

function Network_CallEvent(name, message)
	if not MOCK.network_events[name] then
		error("evento de red no registrado: " .. tostring(name))
	end
	MOCK.network_sent = MOCK.network_sent + 1
	table.insert(MOCK.network_queue, { func = name, sender = Game_GetLocalPlayer(), message = message })
end

-- Texto localizado: devuelve "clave|arg1" para poder comprobarlo.
function Loc_FormatText(key, ...)
	local parts = { key }
	for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
	return table.concat(parts, "|")
end

function UI_CreateEventCueClickable(...)
	local args = { ... }
	table.insert(MOCK.cues, args[5])   -- 5º parámetro: el texto
end

-- Interfaz XAML
function UI_IsReplay() return MOCK.replay end
function UI_CreateCommand(name) return { callback = name } end
function UI_CreateDataContext(t) return t end

function UI_AddChild(parent, type_name, name, props)
	MOCK.ui[name] = { parent = parent, type = type_name, xaml = props.Xaml, data = props.DataContext }
end

function UI_SetDataContext(name, data)
	if MOCK.ui[name] == nil then error("UI inexistente: " .. tostring(name)) end
	MOCK.ui[name].data = data
end

function UI_Remove(name)
	MOCK.ui[name] = nil
end

-- Entidades y unidades (solo lo necesario para los aldeanos extra)
function Player_GetEntities(id)
	return { owner = id, items = { { type = "town_center", pos = { x = 1, y = 2 } } } }
end
function EGroup_Filter(eg, type_name, mode)
	local kept = {}
	for _, e in ipairs(eg.items) do if e.type == type_name then kept[#kept + 1] = e end end
	eg.items = kept
end
function EGroup_Count(eg) return #eg.items end
function EGroup_GetEntityAt(eg, i) return eg.items[i] end
function Entity_GetPosition(e) return e.pos end
function Util_GetOffsetPosition(pos, a, b) return { x = pos.x + a, y = pos.y + b } end
function BP_GetSquadArchetypeBlueprintForPlayer(id, archetype) return "villager_bp" end
function SGroup_CreateIfNotFound(name) return { name = name } end
function UnitEntry_DeploySquads(id, sgroup, units, pos)
	for _, u in ipairs(units) do
		table.insert(MOCK.spawned, { player = id, sbp = u.sbp, count = u.numSquads, pos = pos })
	end
end

function Mock_LogContains(text)
	for _, line in ipairs(MOCK.log) do
		if string.find(line, text, 1, true) then
			return true
		end
	end
	return false
end
