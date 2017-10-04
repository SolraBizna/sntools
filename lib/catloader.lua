local lpeg = require "lpeg"

local initial_line_parser = lpeg.P{
   (lpeg.V"escaped_line" + lpeg.V"comment_line" + lpeg.V"eom_line"
       + lpeg.V"regular_line") * lpeg.V"eol" * lpeg.Cp();
   -- EOL: CR, CRLF, LF, or the end of the file
   eol = (-1 + lpeg.P"\r" + lpeg.P"\r\n" + lpeg.P"\n");
   noneol = 1 - lpeg.V"eol";
   -- Escaped line: A line beginning with \: or \\, or the exact line "\."
   escaped_line = lpeg.P"\\" * lpeg.Cc"line"
      * lpeg.C((lpeg.S":\\" * lpeg.V"noneol"^0) + lpeg.P".");
   -- Comment line: A line beginning with :
   comment_line = lpeg.P":" * lpeg.Cc("comment") * lpeg.C(lpeg.V"noneol"^0);
   -- EOM line: A line consisting entirely of "."
   eom_line = lpeg.P"." * lpeg.Cc("eom", "");
   -- regular line: Any other line
   regular_line = lpeg.Cc("line") * lpeg.C(lpeg.V"noneol"^0);
}

local function parse_lines(a)
   local lines = {}
   local pos = 1
   while pos < #a do
      local type,text,next = lpeg.match(initial_line_parser, a, pos)
      assert(type)
      lines[#lines+1] = {lineno=#lines+1, type=type, text=text}
      pos = next
   end
   return lines
end

return function(path)
   local f = assert(io.open(path, "rb"))
   local a = f:read("*a")
   f:close()
   local lines = parse_lines(a)
   local cat = {}

   local headers = {}
   cat.headers = headers
   local messages = {}
   cat.messages = messages
   local global_comments = {}
   cat.global_comments = global_comments
   local section_comments = {}
   cat.section_comments = section_comments
   local cur_comment
   
   local cur_section = nil
   local cur_line = 1

   local function maybe_inter_comment_block()
      if cur_comment then
         if cur_section then
            section_comments[cur_section][#section_comments[cur_section]+1]
               = table.concat(cur_comment, "\n")
         else
            global_comments[#global_comments+1]
               = table.concat(cur_comment, "\n")
         end
         cur_comment = nil
      end
   end
   local function maybe_start_section()
      if lines[cur_line] == nil or lines[cur_line+1] == nil then return end
      if lines[cur_line].type == "comment"
      and lines[cur_line+1].type == "comment"
      and lines[cur_line].text:match("^:+$") then
         local ending_line
         for n=cur_line+2,#lines do
            if lines[cur_line].type == "comment"
            and lines[cur_line].text:match("^;+$") then
               ending_line = n
               break
            elseif lines[cur_line].type ~= "comment" then
               break
            end
         end
         if ending_line then
            maybe_inter_comment_block()
            local section_name = {}
            for n=cur_line+1,ending_line-1 do
               assert(lines[n].type == "comment")
               section_name[#section_name+1] = lines[n].text
            end
            section_name = table.concat(section_name, "\n")
            while section_comments[section_name] do
               print(path..": Duplicate section (on line "..(cur_line+1)..")")
               section_name = section_name .. " (again)"
            end
            section_comments[section_name] = {}
            cur_line = ending_line + 1
         end
      end
   end
   local function bar(comment)
      if comment:match("^:+$") then return ":"..comment
      else return comment end
   end
   local function maybe_read_comment_block()
      if lines[cur_line].type ~= "comment" then return end
      maybe_inter_comment_block()
      assert(not cur_comment)
      cur_comment = {bar(lines[cur_line].text)}
      cur_line = cur_line + 1
      while lines[cur_line] and lines[cur_line].type == "comment" do
         cur_comment[#cur_comment+1] = bar(lines[cur_line].text)
         cur_line = cur_line + 1
      end
   end
   -- Extracting headers
   while cur_line <= #lines do
      maybe_start_section()
      maybe_read_comment_block()
      local line = lines[cur_line]
      if not line then break end
      if line.type == "eom" then
         error(path..": Spurious end-of-message, line "..cur_line)
      else
         -- (all comment lines should have been eaten by maybe_start_section()
         -- or maybe_read_comment_block())
         assert(line.type == "line")
         if line.text == "" then
            -- blank line
         else
            local found = line.text:find(":", 1, true)
            if not found then break end -- not a header, must be a message
            -- header line
            local hed = line.text:sub(1,found-1)
            local foot = line.text:sub(found+1,-1)
            if not hed:match("^[-A-Za-z0-9]+$") then
               print(path..": Weird-looking header, line "..cur_line)
            end
            hed = hed:gsub("[A-Z]", function(x) return string.char(x:byte()|0x20) end)
            if headers[hed] then
               print(path..": Duplicate header, line "..cur_line)
            end
            headers[hed] = foot:gsub("^[ \t]+","")
         end
         cur_line = cur_line + 1
      end
   end
   if cur_line > #lines then
      error(path..": Catalog contains no messages")
   end
   while cur_line <= #lines do
      local line = lines[cur_line]
      if line.type == "comment" then
         maybe_inter_comment_block()
         maybe_start_section()
         maybe_read_comment_block()
      elseif line.type == "eom" then
         error(path..": Spurious end-of-message, line "..cur_line)
      elseif line.type == "line" and line.text == "" then
         -- blank line, ignore it
         cur_line = cur_line + 1
      else
         assert(line.type == "line")
         if cur_comment then
            cur_comment = table.concat(cur_comment, "\n")
         end
         local cur_message = {comment=cur_comment, section=cur_section,
                              id=line.text, lineno=cur_line}
         cur_comment = nil
         cur_line = cur_line + 1
         local t = {}
         while cur_line <= #lines do
            line = lines[cur_line]
            if line.type == "comment" then
               print(path..": Comment within message, line "..cur_line)
            elseif line.type == "eom" then
               break
            else
               assert(line.type == "line")
               t[#t+1] = line.text
            end
            cur_line = cur_line + 1
         end
         if cur_line > #lines then
            error(path..": Message starting on line "..cur_message.lineno.." does not have an end")
         end
         cur_message.text = table.concat(t, "\n")
         messages[cur_message.id] = cur_message
         cur_line = cur_line + 1
      end
   end
   return cat
end
