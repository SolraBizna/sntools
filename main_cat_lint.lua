#!/usr/bin/env lua

-- (begin "local require" code)
if arg[0] then
   local split = {}
   for component in package.config:gmatch("[^\n]+") do
      split[#split+1] = component
   end
   assert(#split >= 3, "package.config is not valid")
   local dirsep = split[1]
   local compsep = split[2]
   local pathsub = split[3]
   local dirpath
   for n=#arg[0] - #dirsep + 1, 1, -1 do
      if arg[0]:sub(n, n+#dirsep-1) == dirsep then
         dirpath = arg[0]:sub(1, n)
         break
      end
   end
   if dirpath and dirpath ~= "" then
      package.path = dirpath .. "lib" .. dirsep .. pathsub .. ".lua"
         .. compsep .. package.path
   end
end
-- (end "local require" code)

if #arg < 2 then
   io.write[[
Usage: main_cat_lint.lua main_catalog.utxt <list of source files to search>
]]
   os.exit(1)
end

local lpeg = require "lpeg"
local catloader = require "catloader"
local cat = catloader(arg[1])

local C_keyscraper = lpeg.P{
   (lpeg.V"string_run" + lpeg.V"nonstring_skip") * lpeg.Cp();
   nonstring_skip = ((lpeg.V"char_constant" + 1) - lpeg.P'"')^1 * lpeg.Cc(false,false);
   char_constant = lpeg.P"'" * ((lpeg.V"escaped"+1)-lpeg.P"'")^0 * lpeg.P"'";
   escaped = lpeg.P"\\"*1;
   string_run = lpeg.Ct((lpeg.V"string" * lpeg.V"eat_whitespace")^1)
      /table.concat*(lpeg.V"eat_whitespace"*lpeg.P"_Key"*lpeg.Cc(true)+lpeg.Cc(false));
   string = lpeg.P'"' * lpeg.C(((lpeg.V"escaped"+1)-lpeg.P'"')^0) * lpeg.P'"';
   eat_whitespace = lpeg.S" \t\r\n\f\v"^0;
}

local missing = {}

for n=2,#arg do
   local f = assert(io.open(arg[n], "rb"))
   local a = assert(f:read("*a"))
   f:close()
   local pos = 1
   while pos < #a do
      local str, is_key, next = lpeg.match(C_keyscraper, a, pos)
      if str and str ~= "" and is_key then
         if cat.messages[str] then
            cat.messages[str].seen = true
         else
            missing[str] = true
         end
      end
      pos = next
   end
end

if next(missing) ~= nil then
   print("The following messages are MISSING from the catalog:\n")
   local t = {}
   for k in pairs(missing) do t[#t+1] = k end
   table.sort(t)
   for n=1,#t do print(t[n]) end
end

local t = {}
for id,msg in pairs(cat.messages) do
   if not msg.seen then
      t[#t+1] = msg
   end
end

if #t > 0 then
   if next(missing) ~= nil then print() end
   print("The following messages in the catalog are UNUSED:\n")
   table.sort(t, function(a,b) return a.lineno < b.lineno end)
   local cur_section
   for n=1,#t do
      if t[n].section ~= cur_section then
         print("...")
         print(t[n].section)
         print("...")
         cur_section = t[n].section
      end
      print("Line "..t[n].lineno..": "..t[n].id)
   end
end
