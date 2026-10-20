// Genera las opciones del lobby (.rdo de la win condition) y el .csv de textos.
//
// Uso (desde la carpeta del proyecto):
//   node tools/genrdo.js <carpeta de salida> assets/scar/winconditions/SharedTeamResources.rdo
// Escribe en <carpeta de salida>:
//   SharedTeamResources.rdo        -> copiar a assets/scar/winconditions/
//   SharedTeamResources_es.csv     -> copiar a assets/locdb/
//
// Para añadir o cambiar opciones, edita las secciones de abajo y vuelve a generar.
// Las filas 1..25 del .csv son fijas: las usan el .rdo raíz, mod.rdo y los scripts.
// Cada ejecución genera identificadores nuevos (eso es normal).
const fs = require('fs'), crypto = require('crypto');
const out = process.argv[2];
const MOD = { p2: 1800348544, p3: 566894550, p0: 32777088, p1: 1239750596 };
const ROOT_ID = '5289025950789250161', OWNER = '5261356515755594554';
const used = new Set([ROOT_ID, OWNER, '5142933949835374479', '5516925314979355433', '5518204963152512710']);
function id() {
  for (;;) {
    const v = (crypto.randomBytes(8).readBigUInt64BE() >> 1n).toString();
    if (!used.has(v) && v.length > 15) { used.add(v); return v; }
  }
}
const rows = [];
function row(text, notes) {
  if (/[,"]/.test(text)) throw new Error('coma o comillas en: ' + text);
  rows.push([notes || '', text]);
  return rows.length;
}
const T = (n) => '\t'.repeat(n);
function loc(prop, owner, key, ind) {
  const i = id();
  return T(ind) + '<DataProperty Name="' + prop + '" Type="Object">\n' +
    T(ind + 1) + '<DataValue Name="util::ReflectLocString">' + i + '</DataValue>\n' +
    T(ind + 1) + '<DataObject Name="" Type="util::ReflectLocString" Id="' + i + '" OwnerId="' + owner + '">\n' +
    T(ind + 2) + '<DataProperty Name="m_modPart2" Type="UInt32" Value="' + MOD.p2 + '"/>\n' +
    T(ind + 2) + '<DataProperty Name="m_modPart3" Type="UInt32" Value="' + MOD.p3 + '"/>\n' +
    T(ind + 2) + '<DataProperty Name="m_modPart0" Type="UInt32" Value="' + MOD.p0 + '"/>\n' +
    T(ind + 2) + '<DataProperty Name="m_modPart1" Type="UInt32" Value="' + MOD.p1 + '"/>\n' +
    T(ind + 2) + '<DataProperty Name="m_locStringKey" Type="Int32" Value="' + key + '"/>\n' +
    T(ind + 1) + '</DataObject>\n' + T(ind) + '</DataProperty>\n';
}
function head(type, i, owner, key, ind) {
  return T(ind) + '<DataObject Name="" Type="' + type + '" Id="' + i + '" OwnerId="' + owner + '">\n' +
    T(ind + 1) + '<DataProperty Name="#BaseTypes" Type="String" Value="WinCondition::OptionUIDescriptor#0|"/>\n' +
    T(ind + 1) + '<DataProperty Name="m_key" Type="String" Value="' + key + '"/>\n';
}
// Opción sí/no. o = { key, def, name, tip } (o nameRow/tipRow para reutilizar filas)
function boolOpt(o, owner, ind) {
  const i = id();
  const n = o.nameRow || row(o.name, 'Option name');
  const t = o.tipRow || row(o.tip, 'Option tooltip');
  return { type: 'WinCondition::BooleanOptionUIDescriptor', id: i, xml:
    head('WinCondition::BooleanOptionUIDescriptor', i, owner, o.key, ind) +
    T(ind + 1) + '<DataProperty Name="m_defaultValue" Type="Bool" Value="' + o.def + '"/>\n' +
    loc('m_feSummaryName', i, n, ind + 1) + loc('m_feDescriptionTooltip', i, t, ind + 1) + loc('m_feName', i, n, ind + 1) +
    T(ind) + '</DataObject>\n' };
}
// Opción de lista. items = [[key, texto | fila, fila resumen?], ...], def = índice por defecto
function enumOpt(o, owner, ind) {
  const i = id();
  const n = o.nameRow || row(o.name, 'Option name');
  const t = o.tipRow || row(o.tip, 'Option tooltip');
  const items = o.items.map(function (item, k) {
    const j = id();
    const nameRow = typeof item[1] === 'number' ? item[1] : row(item[1], 'Option item');
    const sumRow = item[2] || nameRow;
    return { id: j, xml:
      T(ind + 3) + '<DataObject Name="" Type="WinCondition::OptionEnumItemUIDescriptor" Id="' + j + '" OwnerId="' + i + '">\n' +
      T(ind + 4) + '<DataProperty Name="m_key" Type="String" Value="' + item[0] + '"/>\n' +
      loc('m_feSummaryName', j, sumRow, ind + 4) + loc('m_feName', j, nameRow, ind + 4) +
      T(ind + 4) + '<DataProperty Name="m_isDefaultValue" Type="Bool" Value="' + (k === (o.def || 0)) + '"/>\n' +
      T(ind + 4) + '<DataProperty Name="m_devOnly" Type="Bool" Value="false"/>\n' +
      T(ind + 3) + '</DataObject>\n' };
  });
  return { type: 'WinCondition::EnumerationOptionUIDescriptor', id: i, xml:
    head('WinCondition::EnumerationOptionUIDescriptor', i, owner, o.key, ind) +
    T(ind + 1) + '<DataProperty Name="m_enumItems" Type="Object">\n' +
    items.map(function (x) { return T(ind + 2) + '<DataValue Name="WinCondition::OptionEnumItemUIDescriptor">' + x.id + '</DataValue>\n'; }).join('') +
    items.map(function (x) { return x.xml; }).join('') +
    T(ind + 1) + '</DataProperty>\n' +
    loc('m_feSummaryName', i, n, ind + 1) + loc('m_feDescriptionTooltip', i, t, ind + 1) + loc('m_feName', i, n, ind + 1) +
    T(ind) + '</DataObject>\n' };
}
function section(key, nameRow, featured, options) {
  const i = id();
  const built = options.map(function (o) { return (o.items ? enumOpt : boolOpt)(o, i, 7); });
  return { id: i, xml:
    T(5) + '<DataObject Name="" Type="WinCondition::OptionSectionUIDescriptor" Id="' + i + '" OwnerId="' + OWNER + '">\n' +
    T(6) + '<DataProperty Name="m_featured" Type="Bool" Value="' + featured + '"/>\n' +
    T(6) + '<DataProperty Name="m_key" Type="String" Value="' + key + '"/>\n' +
    T(6) + '<DataProperty Name="m_options" Type="Object">\n' +
    built.map(function (b) { return T(7) + '<DataValue Name="' + b.type + '">' + b.id + '</DataValue>\n'; }).join('') +
    built.map(function (b) { return b.xml; }).join('') +
    T(6) + '</DataProperty>\n' + loc('m_feName', i, nameRow, 6) + T(5) + '</DataObject>\n' };
}

// --- Filas fijas 1..25 (las usan el .rdo raíz, mod.rdo y los scripts) ---
row('Shared Resources', 'Mod name.');
row('Modo estándar en el que los aliados comparten comida - madera - oro y piedra. Puedes bloquear cada recurso en cualquier momento.', 'Mod description.');
row('Shared Resources (Estándar)', 'Game mode name.');
const SECTION_SHARED = row('Recursos compartidos', 'Lobby section.');
const OPT_SHARED = row('Recursos compartidos', 'Lobby option name.');
const OPT_SHARED_TIP = row('Si está activado los aliados de cada equipo comparten una única reserva de recursos', 'Lobby option tooltip.');
const ON = row('Activados', 'Option item: on.');
const OFF = row('Desactivados', 'Option item: off.');
const ON_S = row('Los aliados comparten todos sus recursos', 'Option item summary: on.');
const OFF_S = row('Cada jugador tiene sus propios recursos', 'Option item summary: off.');
['comida', 'madera', 'oro', 'piedra'].forEach(function (r) { row('Gasto simultáneo: el equipo debe %1AMOUNT% de ' + r, 'Event cue. %1AMOUNT% = debt.'); });
row('Recursos compartidos activados con tu aliado', 'Event cue at start.');
['la comida', 'la madera', 'el oro', 'la piedra'].forEach(function (r) { row('%1PLAYER% deja de compartir ' + r + ' y se queda con lo que aportó', 'Event cue. %1PLAYER% = player.'); });
['la comida', 'la madera', 'el oro', 'la piedra'].forEach(function (r) { row('%1PLAYER% vuelve a compartir ' + r, 'Event cue. %1PLAYER% = player.'); });
row('%1PLAYER% deja de compartir todos sus recursos', 'Event cue. %1PLAYER% = player.');
row('%1PLAYER% vuelve a compartir todos sus recursos', 'Event cue. %1PLAYER% = player.');
if (rows.length !== 25) throw new Error('filas fijas: ' + rows.length);

// --- Secciones del lobby ---
// Las claves section_* y option_* son las que lee el modo estándar oficial
// (gamemodes/standard_mode.scar y startconditions/classic_start.scar). No cambiarlas.
const secWin = section('section_inner_win_conditions', row('Condiciones de victoria', 'Lobby section.'), true, [
  { key: 'option_win_condition_conquest', def: true, name: 'Edificios distintivos', tip: 'Gana el equipo que destruya todos los edificios distintivos de sus enemigos' },
  { key: 'option_win_condition_wonder', def: true, name: 'Maravilla', tip: 'Gana el equipo que mantenga en pie una maravilla durante el tiempo indicado' },
  { key: 'option_win_condition_religious', def: true, name: 'Lugares sagrados', tip: 'Gana el equipo que controle todos los lugares sagrados durante el tiempo indicado' },
  { key: 'option_win_condition_regicide', def: false, name: 'Regicidio', tip: 'Cada jugador tiene un rey: si muere el rey el jugador pierde' },
]);
// Filas añadidas después (73+). Se reservan aquí y se escriben al final del .csv
// para no renumerar las filas anteriores.
const LATE = {
  POOL_NAME: 73, POOL_TIP: 74, POOL_2: 75, POOL_3: 76, POOL_4: 77,
  AI_NAME: 78, AI_TIP: 79, DEBUG_NAME: 80, DEBUG_TIP: 81,
};
const LATE_ROWS = [
  ['Option name', 'Jugadores por reserva'],
  ['Option tooltip', 'Máximo de jugadores de un mismo equipo que comparten la reserva'],
  ['Option item', 'Hasta 2'],
  ['Option item', 'Hasta 3'],
  ['Option item', 'Hasta 4'],
  ['Option name', 'Incluir IA aliada'],
  ['Option tooltip', 'Las IA de tu equipo también comparten la reserva (los equipos solo de IA nunca comparten)'],
  ['Option name', 'Avisos de depuración'],
  ['Option tooltip', 'Muestra en pantalla por qué se crea o no la reserva y el estado de los botones'],
  ['Debug cue. %1COUNT% = players.', 'Depuración: reserva creada con %1COUNT% jugadores de tu equipo'],
  ['Debug cue. %1COUNT% %2MAX%.', 'Depuración: tu equipo no comparte porque tiene %1COUNT% jugadores y el máximo es %2MAX%'],
  ['Debug cue. %1COUNT% = players.', 'Depuración: tu equipo no comparte porque solo hay %1COUNT% jugador elegible (revisa Incluir IA aliada)'],
  ['Debug cue.', 'Depuración: recursos compartidos desactivados en el lobby'],
  ['Debug cue.', 'Depuración: no estás en ningún equipo que comparta recursos'],
  ['Debug cue.', 'Depuración: panel de botones creado'],
  ['Debug cue.', 'Depuración: no se pudo crear el panel de botones'],
  ['Debug cue.', 'Depuración: los botones no están disponibles (sin eventos de red)'],
];
const secShared = section('shared_section', SECTION_SHARED, true, [
  { key: 'shared_mode', nameRow: OPT_SHARED, tipRow: OPT_SHARED_TIP, items: [['shared_on', ON, ON_S], ['shared_off', OFF, OFF_S]] },
  { key: 'shared_lock_buttons', def: true, name: 'Botones de bloqueo', tip: 'Muestra en partida un botón por recurso para dejar de compartirlo y otro para todos' },
  { key: 'shared_pool_size', nameRow: LATE.POOL_NAME, tipRow: LATE.POOL_TIP, def: 2,
    items: [['shared_pool_2', LATE.POOL_2], ['shared_pool_3', LATE.POOL_3], ['shared_pool_4', LATE.POOL_4]] },
  { key: 'shared_ai_allies', def: true, nameRow: LATE.AI_NAME, tipRow: LATE.AI_TIP },
  { key: 'shared_debug', def: true, nameRow: LATE.DEBUG_NAME, tipRow: LATE.DEBUG_TIP },
]);
const secStart = section('section_starting_conditions', row('Condiciones de inicio', 'Lobby section.'), false, [
  { key: 'option_start_age', name: 'Edad inicial', tip: 'Edad con la que empiezan todos los jugadores',
    items: [['option_start_age_1', 'Alta Edad Media'], ['option_start_age_2', 'Edad Feudal'], ['option_start_age_3', 'Edad de los Castillos'], ['option_start_age_4', 'Edad Imperial']] },
  { key: 'str_start_resources', name: 'Recursos iniciales', tip: 'Recursos con los que empieza cada jugador (comida / madera / oro / piedra)',
    items: [['str_resources_standard', 'Estándar'], ['str_resources_medium', 'Medios: 1000 / 1000 / 600 / 400'], ['str_resources_high', 'Altos: 3000 / 3000 / 2000 / 1500'], ['str_resources_very_high', 'Muy altos: 10000 / 10000 / 7500 / 5000']] },
  { key: 'str_extra_villagers', name: 'Aldeanos extra', tip: 'Aldeanos adicionales junto al centro urbano al empezar',
    items: [['str_villagers_0', 'Ninguno'], ['str_villagers_6', '+6 aldeanos'], ['str_villagers_12', '+12 aldeanos'], ['str_villagers_20', '+20 aldeanos']] },
  { key: 'option_speed', name: 'Velocidad de economía', tip: 'Multiplica la velocidad de recolección - construcción - producción e investigación',
    items: [['option_speed_1x', 'Normal'], ['option_speed_2x', 'x2'], ['option_speed_3x', 'x3']] },
  { key: 'option_fow', name: 'Mapa', tip: 'Cómo empieza la niebla de guerra',
    items: [['option_fow_default', 'Normal'], ['option_fow_explore', 'Explorado'], ['option_fow_reveal', 'Revelado']] },
  { key: 'option_score', def: false, name: 'Mostrar puntuación', tip: 'Muestra la puntuación real de todos los jugadores' },
]);
const secDip = section('section_diplomacy', row('Diplomacia', 'Lobby section.'), false, [
  { key: 'option_diplomacy_teams', def: true, name: 'Equipos fijos', tip: 'Las alianzas no se pueden cambiar durante la partida' },
  { key: 'option_diplomacy_tribute', def: true, name: 'Tributos', tip: 'Permite enviar recursos a otros jugadores' },
]);
const sections = [secWin, secShared, secStart, secDip];
if (rows.length !== 72) throw new Error('filas antes de las tardías: ' + rows.length);
LATE_ROWS.forEach(function (r) { row(r[1], r[0]); });
if (rows.length !== 89) throw new Error('filas totales: ' + rows.length);

const optionsXml =
  T(2) + '<DataProperty Name="m_optionsUIDescriptor" Type="Object">\n' +
  T(3) + '<DataValue Name="WinCondition::OptionsUIDescriptor">' + OWNER + '</DataValue>\n' +
  T(3) + '<DataObject Name="" Type="WinCondition::OptionsUIDescriptor" Id="' + OWNER + '" OwnerId="' + ROOT_ID + '">\n' +
  T(4) + '<DataProperty Name="m_optionSections" Type="Object">\n' +
  sections.map(function (s) { return T(5) + '<DataValue Name="WinCondition::OptionSectionUIDescriptor">' + s.id + '</DataValue>\n'; }).join('') +
  sections.map(function (s) { return s.xml; }).join('') +
  T(4) + '</DataProperty>\n' + T(3) + '</DataObject>\n' + T(2) + '</DataProperty>\n';

const src = fs.readFileSync(process.argv[3], 'utf8');
const start = src.indexOf('\t\t<DataProperty Name="m_optionsUIDescriptor"');
const end = src.indexOf('\t\t<DataProperty Name="m_precacheList"');
if (start < 0 || end < 0) throw new Error('no encuentro el bloque de opciones');
const rdo = src.slice(0, start) + optionsXml + src.slice(end);
fs.writeFileSync(out + '/SharedTeamResources.rdo', rdo);
const csv = '﻿ID,Pipeline,PipelineStage,Notes,TranslationNotes,Tags,Text\n' +
  rows.map(function (r, k) { return (k + 1) + ',,,' + r[0] + ',,,' + r[1]; }).join('\n') + '\n';
fs.writeFileSync(out + '/SharedTeamResources_es.csv', csv);

// Validación
const st = []; let ok = true; const re = /<(\/?)(DataObject|DataProperty|DataValue|DataWarehouse)\b[^>]*?(\/?)>/g; let m;
while ((m = re.exec(rdo))) { if (m[3]) continue; if (m[1]) { if (st.pop() !== m[2]) { ok = false; break; } } else st.push(m[2]); }
const ids = [...rdo.matchAll(/ Id="(\d+)"/g)].map(function (x) { return x[1]; });
const keys = [...rdo.matchAll(/m_locStringKey" Type="Int32" Value="(\d+)"/g)].map(function (x) { return +x[1]; });
console.log('xml balanceado:', ok && st.length === 0, '| ids:', ids.length, 'únicos:', new Set(ids).size,
  '| filas csv:', rows.length, '| fila max usada:', Math.max.apply(null, keys), '| bytes:', rdo.length);
