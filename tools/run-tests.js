// Ejecuta tests/run_tests.lua con Fengari (Lua escrito en JavaScript),
// para no necesitar Lua instalado. Uso: npm install && npm test
// Opcional: node tools/run-tests.js <carpeta del proyecto>
"use strict";

const path = require("path");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const root = path.resolve(process.argv[2] || path.join(__dirname, "..")).replace(/\\/g, "/") + "/";
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

// arg[0] para que run_tests.lua encuentre la raíz del proyecto.
lua.lua_createtable(L, 0, 1);
lua.lua_pushstring(L, to_luastring(root + "tests/run_tests.lua"));
lua.lua_rawseti(L, -2, 0);
lua.lua_setglobal(L, to_luastring("arg"));

const status = lauxlib.luaL_dofile(L, to_luastring(root + "tests/run_tests.lua"));
if (status !== lua.LUA_OK) {
	console.error(lua.lua_tojsstring(L, -1));
	process.exit(1);
}
