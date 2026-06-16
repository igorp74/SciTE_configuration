--[[
 ====================
  LUA functions for SciTE
 ====================

CHANGE LOG:
-----------------------------
📅 2026-06-09
~ Various fixes and optimizations (OnKey - added key binding for Lua functions )

📅 2026-06-07
+ Function optimization
+ _G.OnKey
+ Fixed SQL Format with sleek on Linux
~ AlignOnMulti - changed parameters declaration for comma
- Pretty Print JSON in Lua. Use only jq related.

📅 2026-04-30
+ Add AlignOnMulti
+ Add FormatTable

📅 2025-05-27
~ Changed time format

📅 2025-03-25
Added:
+ get_iso_week_number
+ insert_timestamp (with the new iso-week number)

📅 2025-03-22
Added:
+ BASE64 Encode
+ BASE64 Decode
+ Title Case
+ New Insert date (With Week number)
+ New Icons for all Lua tools

📅 2023-10-28
+ Split LINE ANALYSIS on 3 new functions (duplicate_lines, duplicate_lines_freq, unique_lines)

--]]

-- Cache hot functions and variables locally to avoid global dictionary lookups inside loops
local editor = editor
local string, table, math, os = string, table, math, os
local t_insert, t_concat, t_sort = table.insert, table.concat, table.sort
local s_sub, s_find, s_gsub, s_match, s_char = string.sub, string.find, string.gsub, string.match, string.char
local m_floor, m_max = math.floor, math.max

-- 💎💎💎  [HELPER FUNCTIONS START] 💎💎💎

-- 🚀 [Check if selected item numeric]
function is_numeric(x)
    return tonumber(x) ~= nil
end

function isWordChar(char)
    local strChar = s_char(char)
    return s_find(strChar, '^[%w_$]$') ~= nil
end

-- 🚀 [Collect lines]
function lines(str)
    local t = {}
    local i, lstr = 1, #str
    while i <= lstr do
        local x, y = s_find(str, "\r?\n", i)
        if x then
            t_insert(t, s_sub(str, i, x - 1))
            i = y + 1
        else
            break
        end
    end
    if i <= lstr then t_insert(t, s_sub(str, i)) end
    return t
end

-- 🚀[ Parse lines with separated values ]
function parseCSVLine(line, sep)
    local result = {}
    local from = 1
    while true do
        local start, finish = s_find(line, sep, from)
        if not start then
            t_insert(result, s_sub(line, from))
            break
        end
        t_insert(result, s_sub(line, from, start - 1))
        from = finish + 1
    end
    return result
end

-- 🚀[ Run shell command with collecting output]
local function cmd_output(cmd, param_string)
    local command_str = string.format("%s %s", cmd, param_string or "")
    local handle = io.popen(command_str)
    if not handle then return "" end
    local match = handle:read("*a")
    handle:close()
    return match
end

-- 🚀[ Difference between 2 Lua table structures]
function tbl_diff(a, b)
    local aa = {}
    for _, v in pairs(a) do aa[v] = true end
    for _, v in pairs(b) do aa[v] = nil end
    local ret = {}
    for _, v in pairs(a) do
        if aa[v] then t_insert(ret, v) end
    end
    return ret
end

-- 🚀[ Replace selected text ]
function replaceOrInsert(text)
    local sel = editor:GetSelText()
    if #sel ~= 0 then
        editor:ReplaceSel(text)
    else
        editor:AddText(text)
    end
end

local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do t_insert(a, n) end
    t_sort(a, f)
    local i = 0
    return function()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
end

function GetCurrentWord()
    local beginPos = editor.CurrentPos
    local endPos = beginPos
    if editor.SelectionStart ~= editor.SelectionEnd then
        return editor:GetSelText()
    end
    while isWordChar(editor.CharAt[beginPos-1]) do
        beginPos = beginPos - 1
    end
    while isWordChar(editor.CharAt[endPos]) do
        endPos = endPos + 1
    end
    return editor:textrange(beginPos, endPos)
end

function squeeze(char)
    if not char then char = editor.CharAt[editor.CurrentPos - 1] end
    local s, e = editor.CurrentPos - 1, editor.CurrentPos - 1
    while editor.CharAt[s] == char do s = s - 1 end
    while editor.CharAt[e] == char do e = e + 1 end
    editor:SetSel(s + 1, e)
    editor:ReplaceSel(s_char(char))
end

-- Title Case Helper function
function tchelper(first, rest)
    return first:upper() .. rest:lower()
end

function get_iso_week_number(year, month, day)
    local t = os.time{year=year, month=month, day=day}
    local yday = tonumber(os.date("%j", t))  -- Day of the year

    -- Calculate the first Thursday of the year
    local jan1 = os.time{year=year, month=1, day=1}
    local jan1_wday = tonumber(os.date("%w", jan1)) -- 0 (Sun) to 6 (Sat)
    local first_thursday = 4 - ((jan1_wday - 1) % 7)

    if first_thursday < 1 then
        first_thursday = first_thursday + 7
    end

    -- Calculate week number
    local week = m_floor((yday - first_thursday + 10) / 7)

    -- Handle week 0 (belongs to last year's last week)
    if week < 1 then
        return get_iso_week_number(year - 1, 12, 31)
    end

    -- Handle week 53 cases
    local dec31 = os.time{year=year, month=12, day=31}
    local last_week = m_floor((tonumber(os.date("%j", dec31)) - first_thursday + 10) / 7)

    if week > last_week then
        return 1  -- First week of next year
    end

    return week
end

-- Helper: escape a string for use as a Lua pattern
function escapeForPattern(s)
    return (s_gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- 💎💎💎  [HELPER FUNCTIONS END] 💎💎💎


-- 🚀  [INSERT DATE]
function insert_short_timestamp()
    local t    = os.time()
    local date = os.date("%Y-%m-%d", t)
    local time = os.date("%H:%M:%S", t)
    replaceOrInsert(date .. " " .. time)
end

function insert_timestamp()
    local t           = os.time()
    local year        = os.date("%Y", t)
    local month       = os.date("%m", t)
    local day         = os.date("%d", t)
    local weekday     = os.date("%a", t)  -- Mon, Tue, etc.
    local time        = os.date("%H:%M:%S", t)

    replaceOrInsert(string.format("%s, %s-%s-%s %s", weekday, year, month, day, time))
--     replaceOrInsert(string.format("W%s#%02d %s %s-%s-%s %s", yr, week_number, weekday, year, month, day, time))
--     replaceOrInsert(string.format("%s-%s-%s | W%02d-%s | %s", year, month, day, week_number, weekday, time))
end

-- With custom weekday and month names
function get_timestamp()
    local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
    local weekdays = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

    local t             = os.time()
    local year          = os.date("%Y", t)
    local month_index   = tonumber(os.date("%m", t))
    local day           = os.date("%d", t)
    local week_number   = get_iso_week_number(year, month_index, day)
    local weekday_index = tonumber(os.date("%w", t)) + 1  -- Lua weeks start from Sunday (0)
    local time          = os.date("%H:%M:%S", t)

    replaceOrInsert(string.format("%s-%s-%s | W%02d-%s | %s", year, months[month_index], day, week_number, weekdays[weekday_index], time))
end

-- 🚀 [MARK CURRENT WORD]
function clearOccurrences()
    scite.SendEditor(SCI_SETINDICATORCURRENT, 0)
    scite.SendEditor(SCI_INDICATORCLEARRANGE, 0, editor.Length)
end

function markOccurrences()
    if editor.SelectionStart == editor.SelectionEnd then
        return
    end
    clearOccurrences()
    scite.SendEditor(SCI_INDICSETSTYLE, 0, INDIC_ROUNDBOX)
    scite.SendEditor(SCI_INDICSETFORE, 0, 255)
    local txt   = GetCurrentWord()
    local flags = SCFIND_WHOLEWORD
    local s, e  = editor:findtext(txt, flags, 0)
    while s do
        scite.SendEditor(SCI_INDICATORFILLRANGE, s, e - s)
        s, e = editor:findtext(txt, flags, e + 1)
    end
end

-- 🚀 [SORT SELECTED TEXT]
-- Sort ascending
function sort_text()
    local sel = editor:GetSelText()
    if #sel == 0 then return end
    local eol = s_match(sel, "\n$")
    local buf = lines(sel)
    t_sort(buf)
    local out = t_concat(buf, "\n")
    if eol then out = out .. "\n" end
    editor:ReplaceSel(out)
end

-- Sort descending
function sort_text_reverse()
    local sel = editor:GetSelText()
    if #sel == 0 then return end
    local eol = s_match(sel, "\n$")
    local buf = lines(sel)
    t_sort(buf, function(a, b) return a > b end)
    local out = t_concat(buf, "\n")
    if eol then out = out .. "\n" end
    editor:ReplaceSel(out)
end

-- 🚀 [REMOVE DUPLICATES]
function remove_duplicates()
    local sel = editor:GetSelText()
    if #sel == 0 then return end

    local hash = {}
    local res = {}
    local eol = s_match(sel, "\n$")
    local buf = lines(sel)

    for i = 1, #buf do
        local v = buf[i]
        if not hash[v] then
            res[#res+1] = v
            hash[v] = true
        end
    end

    local out = t_concat(res, "\n")
    if eol then out = out .. "\n" end
    editor:ReplaceSel(out)
end

-- 🚀 [ LINE ANALYSIS ]

-- Show only duplicate lines
function duplicate_lines()
    local sel = editor:GetSelText()
    if #sel == 0 then return end

    local hash  = {}
    local hash2 = {}
    local dup   = {}
    local dlc   = 0

    local eol = s_match(sel, "\n$")
    local buf = lines(sel)

    for i = 1, #buf do
        local v = buf[i]
        if not hash[v] then
            hash[v] = true
        else
            if not hash2[v] then
                t_insert(dup, v)
                hash2[v] = true
                dlc = dlc + 1
            end
        end
    end

    t_sort(dup)
    local duplicates = t_concat(dup, "\n")
    if eol then duplicates = duplicates .. "\n" end

    print('⚖ Duplicates: ' .. dlc)
    print('--------------------------------')
    print(duplicates)
end

-- Show only duplicate lines with frequencies
function duplicate_lines_freq()
    local sel = editor:GetSelText()
    if #sel == 0 then return end

    local hash  = {}
    local hash2 = {}
    local dup   = {}

    local eol = s_match(sel, "\n$")
    local buf = lines(sel)

    for i = 1, #buf do
        local v = buf[i]
        if not hash[v] then
            hash[v] = true
        else
            if not hash2[v] then
                t_insert(dup, v)
                hash2[v] = true
            end
        end
    end

    local res_cn = {}
    local dlc = #dup
    for x = 1, dlc do
        local y = dup[x]
        local dc = 0
        for z = 1, #buf do
            if y == buf[z] then
                dc = dc + 1
            end
        end
        res_cn[y] = dc
    end

    t_sort(dup)
    print('⚖ Duplicates: ' .. dlc)
    print('--------------------------------')
    for key, value in pairsByKeys(res_cn) do
        print(key .. "\t\t(" .. value .. ")")
    end
end

-- Show purely unique lines
function unique_lines()
    local sel = editor:GetSelText()
    if #sel == 0 then return end

    local hash  = {}
    local hash2 = {}
    local res   = {}
    local dup   = {}
    local tlc   = 0
    local dlc   = 0

    local eol = s_match(sel, "\n$")
    local buf = lines(sel)

    for i = 1, #buf do
        local v = buf[i]
        if not hash[v] then
            res[#res+1] = v
            hash[v] = true
            tlc = tlc + 1
        else
            if not hash2[v] then
                t_insert(dup, v)
                dlc = dlc + 1
                hash2[v] = true
            end
        end
    end

    local unq = tbl_diff(res, dup)
    t_sort(unq)
    local only_unique = t_concat(unq, "\n")

    if eol then only_unique = only_unique .. "\n" end

    print('👍 Genuinely unique: ' .. (tlc - dlc))
    print('-------------------------------')
    print(only_unique)
end

-- 🚀 [TRANSPOSE TO LINE]
-- Plain
function tran_2_line()
    local sel = editor:GetSelText()
    local buf = lines(sel)
    local out = t_concat(buf, " ")
    editor:ReplaceSel(out)
end

-- For API description (with CR)
function trans_2_line()
    local sel = editor:GetSelText()
    local eol = s_match(sel, "\n$")
    local buf = lines(sel)
    local out = t_concat(buf, "\\n")
    if eol then out = out .. "\n" end
    editor:ReplaceSel(out)
end

-- FOR SQL
function transpose_2_line()
    local sel = editor:GetSelText()
    local hash = {}
    local res = {}

    local eol = s_match(sel, "\n$")
    local buf = lines(sel)

    for i = 1, #buf do
        local v = buf[i]
        if is_numeric(v) then
            if not hash[v] then res[#res+1] = v end
        else
            local tmp = "'" .. v .. "'"
            if not hash[v] then res[#res+1] = tmp end
        end
        hash[v] = true
    end

    local out = t_concat(res, ", ")
    if eol then out = out .. "\n" end
    editor:ReplaceSel(out)
end

-- 🚀 [SPLIT VALUES]
-- Split words
function split_words()
    local str = editor:GetSelText()
    local tbl = {}
    str:gsub("[^%s]*", function(x)
        tbl[#tbl+1] = trim(x) .. '\n'
    end)
    editor:ReplaceSel(t_concat(tbl))
end

-- Split CSV for SQL
function split()
    local str = editor:GetSelText()
    local tbl = {}
    local res = {}

    str:gsub("[^,]*", function(x)
        tbl[#tbl+1] = trim(x) .. '\n'
    end)

    for i = 1, #tbl do
        local v = tbl[i]
        if is_numeric(v) then
            res[#res+1] = v
        else
            res[#res+1] = s_sub(v, 2, #v - 2) .. '\n'
        end
    end

    editor:ReplaceSel(t_concat(res))
end

-- 🚀 [TABS TO SPACES]
function tabs_to_spaces_obey_tabstop()
    for m in editor:match("[\\t][\\t ]*", SCFIND_REGEXP) do
        local posColumn = scite.SendEditor(SCI_GETCOLUMN, m.pos)
        local poslenColumn = scite.SendEditor(SCI_GETCOLUMN, m.pos + m.len)
        m:replace(string.rep(' ', poslenColumn - posColumn))
    end
end

-- 🚀 [ENCLOSE BRACES AUTOMATICALLY]
local last_start = 0
local last_end = 0
local had_selection = false

-- 1. Monitor selections and intercept keypresses
function _G.OnKey(key, shift, ctrl, alt)
    -- ==========================================
    -- HIDDEN SHORTCUTS (Must go first!)
    -- ==========================================

    -- DEBUG --
    -- -----------------------------------------------------------
--     if ctrl then print("Keycode pressed: " .. key) end
--     if alt then print("Keycode pressed: " .. key) end
--     if ctrl and alt then print("Keycode pressed: " .. key) end
    -- -----------------------------------------------------------

    -- GROUP A: Ctrl + Alt Shortcuts
    if ctrl and alt and not shift then
        if key == 190 or key == 46    then IncrementNumberLeft()      return true end -- Ctrl+Alt+.
        if key == 188 or key == 44    then DecrementNumberLeft()      return true end -- Ctrl+Alt+,
        if key == 117                 then title_case()               return true end -- Ctrl+Alt+U
        if key == 40  or key == 65362 then sort_text()                return true end -- Ctrl+Alt+Down
        if key == 38  or key == 65364 then sort_text_reverse()        return true end -- Ctrl+Alt+Up
    end

    -- GROUP B: Ctrl ONLY Shortcuts
    if ctrl and not alt and not shift then
        if key == 106              then join_lines()       return true end -- Ctrl + J
        if key == 188 or key == 44 then markOccurrences()  return true end -- Ctrl + ,
    end

    -- GROUP C: Alt ONLY Shortcuts
    if alt and not ctrl and not shift then
        if key == 188 or key == 44 then clearOccurrences() return true end -- Alt + ,
    end

    -- ==========================================
    -- AUTO-BRACKET SELECTION LOGIC
    -- ==========================================
    -- Now we safely ignore other Ctrl/Alt presses

    if ctrl or alt then
        return false
    end

    if editor.SelectionStart ~= editor.SelectionEnd then
        -- Store selection boundaries right before SciTE processes the key
        last_start = editor.SelectionStart
        last_end = editor.SelectionEnd
        had_selection = true
    else
        had_selection = false
    end


    return false -- Let SciTE insert the character normally
end

-- 2. Process character insertion for both wrapping and auto-closing
function _G.OnChar(char)
    -- Unified character mapping
    local wrap_pairs = {
        ["("] = { open = "(", close = ")" },
        ["["] = { open = "[", close = "]" },
        ["{"] = { open = "{", close = "}" },
        ["'"] = { open = "'", close = "'" },
        ['"'] = { open = '"', close = '"' }
    }

    local pair = wrap_pairs[char]
    if not pair then return false end

    -- CASE A: There WAS a text selection when the key was pressed
    if had_selection then
        had_selection = false -- Reset toggle

        editor:BeginUndoAction()

        -- Target the newly inserted character and undo it to recover selection
        editor:SetSel(last_start, last_start + #char)
        editor:Undo()

        local sel_text = editor:GetSelText()

        -- Wrap and re-select
        editor:ReplaceSel(pair.open .. sel_text .. pair.close)
        editor:SetSel(last_start + #pair.open, last_start + #pair.open + #sel_text)

        editor:EndUndoAction()
        return true

    -- CASE B: No selection (Regular typing). Auto-close the bracket/quote!
    else
        editor:BeginUndoAction()

        local current_pos = editor.CurrentPos
        -- Insert the closing character right after the one just typed
        editor:InsertText(current_pos, pair.close)

        editor:EndUndoAction()
        return false -- Return false so SciTE leaves the caret right before the closing character
    end
end


-- 🚀[JOIN LINES ]
function join_lines()
    editor:BeginUndoAction()
    editor:LineEnd()
    editor:Clear()
    editor:AddText(' ')
    squeeze()
    editor:EndUndoAction()
end

-- 🚀[ PRINT FILTER RESULTS ]
function print_marked_lines()
    local ml = 0
    local lines_buf = {}
    while true do
        ml = editor:MarkerNext(ml, 2)
        if ml == -1 then break end
        t_insert(lines_buf, editor:GetLine(ml))
        ml = ml + 1
    end
    print(t_concat(lines_buf))
end

-- 🚀[ PRINT SELECTED PATTERN ]
function print_selected_patterns()
    local sel = editor:GetSelText()
    for m in editor:match(sel .. "\\w+", SCFIND_REGEXP) do
        print(editor:textrange(m.pos, m.pos + m.len))
    end
end

function print_contained_patterns()
    local sel = editor:GetSelText()
    for m in editor:match("\\w*" .. sel .. "\\w*", SCFIND_REGEXP) do
        print(editor:textrange(m.pos, m.pos + m.len))
    end
end

function print_contained_lines()
    local sel = editor:GetSelText()
    for m in editor:match(".*" .. sel .. ".*", SCFIND_REGEXP) do
        print(editor:textrange(m.pos, m.pos + m.len))
    end
end

function print_matched_patterns()
    local sel = editor:GetSelText()
    for m in editor:match(sel, SCFIND_REGEXP) do
        print(editor:textrange(m.pos, m.pos + m.len))
    end
end

-- 🚀 [TRIM LEADING AND TRAILING SPACE AROUND STRING]
function trim(s)
    return s_match(s, "^%s*(.-)%s*$") or ""
end

-- 🚀 [DELETE EMPTY LINES]
function del_empty_lines()
    local txt = editor:GetText()
    if #txt == 0 then return end
    local chg = false
    while true do
        local n
        txt, n = s_gsub(txt, "\n%s*\r?\n", "\n")
        if n == 0 then break end
        chg = true
    end
    if chg then
        editor:SetText(txt)
        editor:GotoPos(0)
    end
end

-- 🚀[ STRIP TRAILING SPACES]
function stripTrailingSpaces(reportNoMatch)
    local count = 0
    local fs, fe = editor:findtext("[ \\t]+$", SCFIND_REGEXP)
    if fe then
        repeat
            count = count + 1
            editor:remove(fs, fe)
            fs, fe = editor:findtext("[ \\t]+$", SCFIND_REGEXP, fs)
        until not fe
    end
    return count
end


-- 🚀[Function to alter the number to the left of the cursor by a specific delta]
local function alter_number_left(delta)
    local pos = editor.CurrentPos
    local line_num = editor:LineFromPosition(pos)
    local line_start = editor:PositionFromLine(line_num)

    -- Get all text on the current line up to the cursor
    local text_before = editor:textrange(line_start, pos)

    -- Match a number at the very end of the string (left of the cursor)
    local num_str = string.match(text_before, "-?%d+%.?%d*$")

    if num_str then
        local num = tonumber(num_str)
        if num then
            local new_num = num + delta

            -- Keep integers as integers
            if math.floor(num) == num and math.floor(delta) == delta then
                new_num = math.floor(new_num)
            end

            local new_num_str = tostring(new_num)

            -- Calculate the start position of the number to replace
            local start_replace = pos - #num_str

            -- Replace the old number with the new one
            editor:SetSel(start_replace, pos)
            editor:ReplaceSel(new_num_str)

            -- Place cursor at end of the new number
            local new_pos = start_replace + #new_num_str
            editor:SetSel(new_pos, new_pos)
        end
    end
end

-- Wrapper functions for SciTE commands
function IncrementNumberLeft()
    alter_number_left(1)
end

function DecrementNumberLeft()
    alter_number_left(-1)
end

-- 🚀[ FIGLETS]
function figlet()
    local str = editor:GetSelText()
    local res = cmd_output("figlet -f Roman", str)
    editor:ReplaceSel(res)
end

-- encoding
function b64enc()
    local data = editor:GetSelText()
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    editor:ReplaceSel((s_gsub(data, '.', function(x)
        local r, byte_val = '', x:byte()
        for i = 8, 1, -1 do r = r .. (byte_val % 2^i - byte_val % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2^(6-i) or 0) end
        return b:sub(c + 1, c + 1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

-- decoding
function b64dec()
    local data = editor:GetSelText()
    local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    data = s_gsub(data, '[^' .. b .. '=]', '')

    editor:ReplaceSel(s_gsub(data, '.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2^(8-i) or 0) end
        return s_char(c)
    end))
end

function title_case()
    local sel = editor:GetSelText()
    sel = s_gsub(sel, "(%a)([%w_']*)", tchelper)
    editor:ReplaceSel(sel)
end

function transposeText()
    local sel = editor:GetSelText()
    if #sel == 0 then
        print("No text selected!")
        return
    end

    local rows = {}
    for line in sel:gmatch("[^\r\n]+") do
        local row = {}
        for element in line:gmatch("%S+") do
            t_insert(row, element)
        end
        if #row > 0 then
            t_insert(rows, row)
        end
    end

    if #rows == 0 then return end

    local rowCount = #rows
    local colCount = #rows[1]
    local transposed = {}

    for i = 1, colCount do
        local newRow = {}
        for j = 1, rowCount do
            t_insert(newRow, rows[j][i] or "")
        end
        t_insert(transposed, t_concat(newRow, " "))
    end

    editor:ReplaceSel(t_concat(transposed, "\n"))
end

function align_columns()
    local str = editor:GetSelText()
    if #str == 0 then return end

    local gap        = 1
    local alignRight = false
    local space = string.rep(" ", gap)

    local rows = {}
    for line in str:gmatch("[^\r\n]+") do
        local trimmed = s_gsub(s_gsub(line, "^%s+", ""), "%s+$", "")
        if #trimmed > 0 then
            t_insert(rows, trimmed)
        end
    end

    if #rows == 0 then return end

    local table2d = {}
    local maxCols = 0
    for i = 1, #rows do
        local words = {}
        for word in rows[i]:gmatch("%S+") do
            t_insert(words, word)
        end
        table2d[i] = words
        if #words > maxCols then maxCols = #words end
    end

    local colWidths = {}
    for c = 1, maxCols do colWidths[c] = 0 end

    for i = 1, #table2d do
        local row = table2d[i]
        for c = 1, #row do
            local word = row[c]
            if #word > colWidths[c] then
                colWidths[c] = #word
            end
        end
    end

    local outLines = {}
    for i = 1, #table2d do
        local row = table2d[i]
        local parts = {}
        local last  = #row
        for c = 1, last do
            local word = row[c]
            local width = colWidths[c]
            if c == last and not alignRight then
                parts[c] = word
            elseif alignRight then
                parts[c] = string.rep(" ", width - #word) .. word
            else
                parts[c] = word .. string.rep(" ", width - #word)
            end
        end
        t_insert(outLines, t_concat(parts, space))
    end

    editor:ReplaceSel(t_concat(outLines, "\n"))
end


-- 🚀 [SciTE Strips]
function align_csv(opts)
    if editor:GetSelText() == "" then editor:SelectAll() end
    local str = editor:GetSelText()
    if #str == 0 then return end

    opts = opts or {}
    local delim      = opts.delim      or "|"
    local gap        = opts.gap        or 1
    local alignRight = opts.alignRight or false
    local outerPipes = opts.outerPipes
    local space      = string.rep(" ", gap)

    local rows = {}
    for line in str:gmatch("[^\r\n]+") do
        if s_match(line, "%S") then t_insert(rows, line) end
    end
    if #rows == 0 then return end

    local delim_pattern = escapeForPattern(delim)
    local detectedOuter = s_match(rows[1], "^%s*" .. delim_pattern)
                          and s_match(rows[1], delim_pattern .. "%s*$")
                          and true or false
    if outerPipes == nil then outerPipes = detectedOuter end

    local table2d = {}
    local maxCols = 0
    for i = 1, #rows do
        local row = rows[i]
        local trimmed = s_gsub(s_gsub(row, "^%s+", ""), "%s+$", "")
        trimmed = s_gsub(s_gsub(trimmed, "^" .. delim_pattern, ""), delim_pattern .. "$", "")

        local cells = {}
        local cursor = 1
        while true do
            local s, e = s_find(trimmed, delim, cursor, true)
            if not s then
                t_insert(cells, s_sub(trimmed, cursor))
                break
            end
            t_insert(cells, s_sub(trimmed, cursor, s - 1))
            cursor = e + 1
        end

        for j = 1, #cells do
            cells[j] = s_gsub(s_gsub(cells[j], "^%s+", ""), "%s+$", "")
        end

        table2d[i] = cells
        if #cells > maxCols then maxCols = #cells end
    end

    for i = 1, #table2d do
        local row = table2d[i]
        while #row < maxCols do t_insert(row, "") end
    end

    local colWidths = {}
    for c = 1, maxCols do colWidths[c] = 0 end
    for i = 1, #table2d do
        local row = table2d[i]
        for c = 1, maxCols do
            local cell = row[c]
            if #cell > colWidths[c] then colWidths[c] = #cell end
        end
    end

    local outLines = {}
    local sep = space .. delim .. space
    for i = 1, #table2d do
        local row = table2d[i]
        local parts = {}
        for c = 1, maxCols do
            local cell = row[c]
            local w = colWidths[c]
            local padding = string.rep(" ", w - #cell)

            -- Right alignment logic implemented here
            if alignRight then
                parts[c] = padding .. cell
            else
                parts[c] = cell .. padding
            end
        end
        local line = t_concat(parts, sep)
        if outerPipes then
            line = delim .. space .. line .. space .. delim
        end

        -- Safe trim trailing space if not right-aligning outer elements
        if not outerPipes and not alignRight then
            line = s_gsub(line, "%s+$", "")
        end

        t_insert(outLines, line)
    end

    editor:ReplaceSel(t_concat(outLines, "\n"))
end


-- 🚀 Aligning text in columns
function align_on_multi(delimiters, opts)
    local str = editor:GetSelText()
    if #str == 0 then
        print("align_on_multi: no selection")
        return
    end

    opts = opts or {}
    local spacing    = opts.spacing    or spacing    or 1
    local alignRight = opts.alignRight
    if alignRight == nil then alignRight = _G.alignRight or false end

    if type(delimiters) == "string" then
        delimiters = { delimiters }
    end

    local gap = string.rep(" ", spacing)

    local matchOrder = {}
    for i = 1, #delimiters do t_insert(matchOrder, delimiters[i]) end
    t_sort(matchOrder, function(a, b) return #a > #b end)

    local slotOf = {}
    for i = 1, #delimiters do
        slotOf[matchOrder[i]:upper()] = i
    end

    local function buildPattern(s)
        local specials = "^$()%.[]*+-?"
        local out = {}
        for i = 1, #s do
            local ch = s_sub(s, i, i)
            if s_match(ch, "%a") then
                out[#out + 1] = "[" .. ch:lower() .. ch:upper() .. "]"
            elseif s_find(specials, ch, 1, true) then
                out[#out + 1] = "%" .. ch
            else
                out[#out + 1] = ch
            end
        end
        return t_concat(out)
    end

    local function isWordDelim(d) return s_match(d, "^[%w_]+$") ~= nil end

    local compiled = {}
    for i = 1, #matchOrder do
        local d = matchOrder[i]
        compiled[#compiled + 1] = {
            raw     = d,
            pattern = buildPattern(d),
            word    = isWordDelim(d),
        }
    end

    local function findNext(line, fromPos)
        local bestS, bestE, bestText, bestRaw
        for i = 1, #compiled do
            local c = compiled[i]
            local s, e = s_find(line, c.pattern, fromPos)
            while s do
                local ok = true
                if c.word then
                    local before = s > 1     and s_sub(line, s - 1, s - 1) or ""
                    local after  = e < #line and s_sub(line, e + 1, e + 1) or ""
                    if s_match(before, "[%w_]") or s_match(after, "[%w_]") then
                        ok = false
                    end
                end
                if ok then break end
                s, e = s_find(line, c.pattern, e + 1)
            end
            if s then
                if not bestS or s < bestS or (s == bestS and e > bestE) then
                    bestS, bestE, bestText, bestRaw = s, e, s_sub(line, s, e), c.raw
                end
            end
        end
        return bestS, bestE, bestText, bestRaw
    end

    local lines_arr = {}
    for line in str:gmatch("[^\r\n]+") do
        t_insert(lines_arr, line)
    end

    local numSlots = #delimiters
    local colMaxWidths = {}
    local lineData     = {}

    for i = 1, #lines_arr do
        local line = lines_arr[i]
        local indent, rest = s_match(line, "^(%s*)(.*)$")

        local hits = {}
        local pos  = 1
        while true do
            local s, e, matched, raw = findNext(rest, pos)
            if not s then break end
            local slot = slotOf[raw:upper()]
            local lastSlot = #hits > 0 and hits[#hits].slot or 0
            if slot and slot > lastSlot then
                t_insert(hits, { s = s, e = e, matched = matched, slot = slot })
            end
            pos = e + 1
        end

        local segments  = {}
        local delimsHit = {}

        if #hits == 0 then
            local content = s_gsub(s_gsub(rest, "^%s+", ""), "%s+$", "")
            segments[1] = content
            colMaxWidths[1] = m_max(colMaxWidths[1] or 0, #content)
        else
            local cursor = 1
            local first  = hits[1]
            local before = s_gsub(s_gsub(s_sub(rest, cursor, first.s - 1), "^%s+", ""), "%s+$", "")
            segments[1] = before
            colMaxWidths[1] = m_max(colMaxWidths[1] or 0, #before)
            delimsHit[first.slot] = first.matched
            cursor = first.e + 1

            for h = 2, #hits do
                local hit = hits[h]
                local mid = s_gsub(s_gsub(s_sub(rest, cursor, hit.s - 1), "^%s+", ""), "%s+$", "")
                segments[hit.slot] = mid
                colMaxWidths[hit.slot] = m_max(colMaxWidths[hit.slot] or 0, #mid)
                delimsHit[hit.slot]    = hit.matched
                cursor = hit.e + 1
            end

            local lastHit  = hits[#hits]
            local tailSlot = lastHit.slot + 1
            local tail     = s_gsub(s_gsub(s_sub(rest, cursor), "^%s+", ""), "%s+$", "")
            segments[tailSlot] = tail
            colMaxWidths[tailSlot] = m_max(colMaxWidths[tailSlot] or 0, #tail)
        end

        lineData[i] = {
            indent    = indent,
            segments  = segments,
            delimsHit = delimsHit,
        }
    end

    local delimWidthAt = {}
    for slot = 1, numSlots do
        local w = 0
        for i = 1, #lineData do
            local d = lineData[i].delimsHit[slot]
            if d and #d > w then w = #d end
        end
        delimWidthAt[slot] = w
    end

    local alignedLines = {}
    for i = 1, #lines_arr do
        local data    = lineData[i]
        local newLine = data.indent

        for slot = 1, numSlots do
            local content = data.segments[slot] or ""
            local maxW    = colMaxWidths[slot] or 0
            local padding = string.rep(" ", maxW - #content)

            if alignRight then
                newLine = newLine .. padding .. content
            else
                newLine = newLine .. content .. padding
            end

            local delimText  = data.delimsHit[slot]
            local delimWidth = delimWidthAt[slot]
            if delimWidth > 0 then
                if delimText then
                    newLine = newLine .. gap .. delimText .. string.rep(" ", delimWidth - #delimText) .. gap
                else
                    newLine = newLine .. gap .. string.rep(" ", delimWidth) .. gap
                end
            end
        end

        local tail    = data.segments[numSlots + 1] or ""
        local tailMax = colMaxWidths[numSlots + 1] or 0
        if alignRight then
            newLine = newLine .. string.rep(" ", tailMax - #tail) .. tail
        else
            newLine = newLine .. tail
        end

        newLine = s_gsub(newLine, "%s+$", "")
        t_insert(alignedLines, newLine)
    end

    editor:ReplaceSel(t_concat(alignedLines, "\n"))
end

-- 🚀 [Universal Strips Wrapper]
function OnClear()
    scite.StripShow("")
end

function StripDlg(args)
    local t = {}
    for k, v in args:gmatch("(%w+)=([^ ]+)") do
        t[k] = v
    end

    if t["func"] then
        StripFunc = t["func"]
        if not t["dlg"] then
            t["dlg"] = "'" .. t["func"] .. "'(&Cancel)"
        end
        scite.StripShow(s_gsub(t["dlg"], '\\n', '\n'))
    else
        print("Invalid call")
    end
end

function OnStrip(control, change)
    if change == 1 then
        StripExec(scite.StripValue(1))
    end
end

function StripExec(val)
    if editor:GetSelText() == "" then editor:SelectAll() end
   if StripFunc == "AlignOnMulti" then
        local opts = { spacing = 1, alignRight = false }
        local cleaned = val

        cleaned = s_gsub(cleaned, "%-%-gap=(%d+)", function(n)
            opts.spacing = tonumber(n); return ""
        end)
        cleaned = s_gsub(cleaned, "%-g=(%d+)", function(n)
            opts.spacing = tonumber(n); return ""
        end)
        cleaned = s_gsub(cleaned, "%-%-right", function()
            opts.alignRight = true; return ""
        end)
        cleaned = s_gsub(cleaned, "%-r%f[%s\0]", function()
            opts.alignRight = true; return ""
        end)
        cleaned = s_gsub(s_gsub(cleaned, "^%s+", ""), "%s+$", "")

        local COMMA_ESC = "\0COMMA\0"
        cleaned = s_gsub(cleaned, "\\,", COMMA_ESC)

        local delims = {}
        for d in (cleaned .. ","):gmatch("([^,]*),") do
            d = s_gsub(s_gsub(d, "^%s+", ""), "%s+$", "")
            d = s_gsub(d, COMMA_ESC, ",")
            if #d > 0 then t_insert(delims, d) end
        end

        align_on_multi(delims, opts)
    end
    if StripFunc == "AlignCSV" then
        local opts = { delim = "|", gap = 1, alignRight = false }
        local COMMA_ESC = "\0COMMA\0"

        val = s_gsub(val, "\\,", COMMA_ESC)

        val = s_gsub(val, "%-d=(%S+)", function(d)
            d = s_gsub(d, COMMA_ESC, ",")
            opts.delim = d; return ""
        end)
        val = s_gsub(val, "%-%-gap=(%d+)", function(n)
            opts.gap = tonumber(n); return ""
        end)
        val = s_gsub(val, "%-g=(%d+)", function(n)
            opts.gap = tonumber(n); return ""
        end)
        val = s_gsub(val, "%-%-right", function()
            opts.alignRight = true; return ""
        end)
        val = s_gsub(val, "%-r", function()
            opts.alignRight = true; return ""
        end)
        val = s_gsub(val, "%-%-outer", function()
            opts.outerPipes = true; return ""
        end)
        val = s_gsub(val, "%-%-no%-outer", function()
            opts.outerPipes = false; return ""
        end)

        local remainder = s_gsub(s_gsub(s_gsub(val, COMMA_ESC, ","), "^%s+", ""), "%s+$", "")
        if #remainder > 0 and opts.delim == "|" then
            opts.delim = remainder
        end

        align_csv(opts)
    end
    if StripFunc == "RegExMatch" then print_regex_match(val) end
end
