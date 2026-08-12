-- actions.lua — small action registry + omnibar palette.
-- Every action gets an id, a display name, optional group/keywords, and a
-- function to invoke. Actions may optionally bind a hotkey OR a modal-key at
-- registration time, in which case the palette also displays the shortcut.
--
--   local actions = require("actions")
--   actions.register("hs.reload", {
--       name     = "Reload Hammerspoon",
--       group    = "Hammerspoon",
--       keywords = "restart config",
--       hotkey   = { "alt", "r" },        -- optional; binds AND labels
--   }, hs.reload)
--   hs.hotkey.bind({"alt"}, "p", actions.show_palette)
--
-- For actions already bound elsewhere (e.g. legacy `hs.hotkey.bind` calls in
-- init.lua that haven't been migrated), pass `hotkey_label` instead of
-- `hotkey` — palette shows the shortcut, no binding is installed.

local M = {}
M._actions = {}

local MOD_SYMBOL = { alt = "⌥", shift = "⇧", ctrl = "⌃", cmd = "⌘" }

local function hotkeyLabel(mods, key)
    local parts = {}
    local list = type(mods) == "string" and { mods } or (mods or {})
    for _, mod in ipairs(list) do
        table.insert(parts, MOD_SYMBOL[tostring(mod):lower()] or tostring(mod))
    end
    table.insert(parts, tostring(key):upper())
    return table.concat(parts)
end
M.hotkey_label = hotkeyLabel

-- Register an action.
--   id            required   unique registry key (dotted convention: "hs.reload")
--   opts.name     required   display name shown in the palette
--   opts.group    optional   grouping label ("Hammerspoon", "Windows", "Debug")
--   opts.keywords optional   space-separated extra search terms
--   opts.hotkey   optional   { mods, key } — binds via hs.hotkey.bind AND labels
--   opts.modal    optional   { modal_object, mods, key } — binds via modal:bind
--   opts.hotkey_label  optional   pre-formatted label (e.g. "⌥A → C") for
--                                 actions already bound elsewhere
function M.register(id, opts, fn)
    assert(id, "actions.register: id required")
    assert(opts and opts.name, "actions.register: opts.name required")
    assert(type(fn) == "function", "actions.register: fn must be a function")
    if M._actions[id] then
        print("[actions] overriding existing id: " .. id)
    end
    local entry = {
        id       = id,
        name     = opts.name,
        group    = opts.group or "",
        keywords = opts.keywords or "",
        fn       = fn,
    }
    if opts.hotkey then
        local mods, key = opts.hotkey[1], opts.hotkey[2]
        hs.hotkey.bind(mods, key, opts.name, fn)
        entry.hotkey_label = hotkeyLabel(mods, key)
    elseif opts.modal then
        local modal, mods, key = opts.modal[1], opts.modal[2], opts.modal[3]
        modal:bind(mods, key, opts.name, fn)
        entry.hotkey_label = (opts.modal_label or "modal") .. " → " .. hotkeyLabel(mods, key)
    end
    if opts.hotkey_label then entry.hotkey_label = opts.hotkey_label end
    M._actions[id] = entry
    return entry
end

-- ---------------------------------------------------------------------------
-- Palette

local SUB_SEP = "   ·   "

local function buildChoices()
    local choices = {}
    for _, e in pairs(M._actions) do
        local bits = {}
        if e.hotkey_label then table.insert(bits, e.hotkey_label) end
        if e.group ~= ""    then table.insert(bits, e.group) end
        if e.keywords ~= "" then table.insert(bits, e.keywords) end
        table.insert(choices, {
            text          = e.name,
            subText       = table.concat(bits, SUB_SEP),
            _fn           = e.fn,
            _textLower    = e.name:lower(),
            _searchLower  = (e.name .. " " .. e.group .. " " .. e.keywords):lower(),
        })
    end
    table.sort(choices, function(a, b) return a._textLower < b._textLower end)
    return choices
end

local function scoreChoice(qLower, c)
    -- Tiers, high → low: exact-name, name-starts-with, name-substring,
    -- keyword/group-substring. Shorter name wins within a tier.
    local t = c._textLower
    if t == qLower then return 1000 end
    if #qLower <= #t and t:sub(1, #qLower) == qLower then
        return 800 - (#t - #qLower)
    end
    if t:find(qLower, 1, true) then return 400 - (#t - #qLower) end
    if c._searchLower:find(qLower, 1, true) then return 200 end
    return -1
end

function M.show_palette()
    local choices = buildChoices()

    local chooser
    chooser = hs.chooser.new(function(choice)
        if choice and choice._fn then choice._fn() end
    end)
    chooser:choices(choices)
    chooser:placeholderText("Search actions…")
    chooser:rows(10)
    chooser:queryChangedCallback(function(query)
        if query == "" then chooser:choices(choices); return end
        local q = query:lower()
        local scored = {}
        for i, c in ipairs(choices) do
            local s = scoreChoice(q, c)
            if s >= 0 then scored[#scored + 1] = { c = c, score = s, idx = i } end
        end
        table.sort(scored, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.idx < b.idx
        end)
        local filtered = {}
        for j, x in ipairs(scored) do filtered[j] = x.c end
        chooser:choices(filtered)
    end)
    chooser:show()
end

-- ---------------------------------------------------------------------------
-- HS debug-logging toggle: flips hs.logger between 'warning' (HS default) and
-- 'debug'. Sets both the module-level default (for future loggers) AND every
-- existing logger via setModulesLogLevel.

local currentLogLevel = "warning"

function M.toggle_hs_debug_logging()
    currentLogLevel = (currentLogLevel == "debug") and "warning" or "debug"
    hs.logger.defaultLogLevel = currentLogLevel
    hs.logger.setModulesLogLevel(currentLogLevel)
    hs.alert.show("HS log level: " .. currentLogLevel, 1.5)
    print("[actions] HS log level → " .. currentLogLevel)
end

return M
