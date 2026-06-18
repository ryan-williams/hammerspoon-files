-- Unicode text expander for Hammerspoon
-- Type a trigger (e.g. ";r"), get unicode replacement (e.g. "→")
-- Uses hs.eventtap to monitor keystrokes

local M = {}

local shortcuts = {
    -- Arrows (single char suffix)
    [";r"]   = "→",   -- right arrow
    [";l"]   = "←",   -- left arrow
    [";u"]   = "↑",   -- up arrow
    [";dn"]  = "↓",   -- down arrow (`;d` is δ)

    -- Arrows (multi-char)
    [";lr"]  = "↔",   -- left-right arrow
    [";R"]   = "⇒",   -- double right arrow
    [";L"]   = "⇐",   -- double left arrow
    [";D"]   = "⇔",   -- double left-right arrow
    [";lR"]  = "⟹",   -- long double right arrow
    [";lL"]  = "⟸",   -- long double left arrow
    [";lD"]  = "⟺",   -- long left-right double arrow
    [";ll"]  = "⟷",   -- long left-right arrow
    [";rl"]  = "⇄",   -- right arrow over left arrow

    -- Math / comparison
    [";~"]   = "≈",   -- almost equal
    [";!"]   = "≠",   -- not equal
    [";<"]   = "≤",   -- less than or equal
    [";>"]   = "≥",   -- greater than or equal
    [";+"]   = "±",   -- plus-minus
    [";pm"]  = "±",   -- plus-minus (alias)
    [";in"]  = "∈",   -- element of
    [";inf"] = "∞",   -- infinity
    [";o"]   = "°",   -- degree
    [";deg"] = "°",   -- degree (alias)
    [";m"]   = "μ",   -- mu
    [";v"]   = "√",   -- square root
    [";x"]   = "×",   -- multiplication
    [";/"]   = "÷",   -- division

    -- Greek letters
    [";S"]   = "Σ",   -- capital sigma (sum)
    [";s"]   = "σ",   -- lowercase sigma
    [";ep"]  = "ε",   -- epsilon
    [";mu"]  = "μ",   -- mu (alias for `;m`)
    [";a"]   = "α",   -- alpha
    [";bt"]  = "β",   -- beta (`;b` is bullet)
    [";g"]   = "γ",   -- gamma
    [";G"]   = "Γ",   -- capital gamma
    [";d"]   = "Δ",   -- capital delta (↓ is `;dn`, `;D` is ⇔)
    [";dl"]  = "δ",   -- lowercase delta
    [";th"]  = "θ",   -- theta
    [";Th"]  = "Θ",   -- capital theta
    [";pi"]  = "π",   -- pi (`;p` left unbound — too broad)
    [";PI"]  = "Π",   -- capital pi (product)
    [";ph"]  = "φ",   -- phi
    [";Ph"]  = "Φ",   -- capital phi
    [";w"]   = "ω",   -- omega
    [";W"]   = "Ω",   -- capital omega
    [";lm"]  = "λ",   -- lambda

    -- Fractions (named to avoid `;1`/`;2`/... superscript conflicts)
    [";hf"]  = "½",   -- half
    [";tr"]  = "⅓",   -- third
    [";tw"]  = "⅔",   -- two-thirds
    [";qt"]  = "¼",   -- quarter
    [";tq"]  = "¾",   -- three-quarters

    -- Superscript digits (both `;\d` and `;^\d` forms)
    [";0"]   = "⁰", [";^0"]  = "⁰",
    [";1"]   = "¹", [";^1"]  = "¹",
    [";2"]   = "²", [";^2"]  = "²",
    [";3"]   = "³", [";^3"]  = "³",
    [";4"]   = "⁴", [";^4"]  = "⁴",
    [";5"]   = "⁵", [";^5"]  = "⁵",
    [";6"]   = "⁶", [";^6"]  = "⁶",
    [";7"]   = "⁷", [";^7"]  = "⁷",
    [";8"]   = "⁸", [";^8"]  = "⁸",
    [";9"]   = "⁹", [";^9"]  = "⁹",

    -- Subscript digits
    [";_0"]  = "₀",
    [";_1"]  = "₁",
    [";_2"]  = "₂",
    [";_3"]  = "₃",
    [";_4"]  = "₄",
    [";_5"]  = "₅",
    [";_6"]  = "₆",
    [";_7"]  = "₇",
    [";_8"]  = "₈",
    [";_9"]  = "₉",

    -- Modifier keys (for docs)
    [";cmd"] = "⌘",
    [";opt"] = "⌥",
    [";ctl"] = "⌃",
    [";shf"] = "⇧",
    [";tab"] = "⇥",
    [";ret"] = "⏎",
    [";bsp"] = "⌫",
    [";del"] = "⌦",
    [";esc"] = "⎋",

    -- Emoji
    [";grin"]  = "😀",
    [";grim"]  = "😬",
    [";think"] = "🤔",
    [";thnk"]  = "🤔",
    [";laugh"] = "😂",

    -- Common symbols
    [";."]   = "…",   -- ellipsis
    [";-"]   = "—",   -- em dash
    [";n"]   = "–",   -- en dash
    [";b"]   = "•",   -- bullet
    [";y"]   = "✓",   -- check mark
    [";X"]   = "✗",   -- x mark
}

-- Build trie for prefix-aware matching
-- Shorter triggers must not fire if they're a prefix of a longer one
-- that's still being typed. We handle this with a small delay.

-- Find the longest trigger length
local maxLen = 0
for k, _ in pairs(shortcuts) do
    if #k > maxLen then maxLen = #k end
end

-- Build prefix set: triggers that are prefixes of other triggers
local prefixes = {}
for k1, _ in pairs(shortcuts) do
    for k2, _ in pairs(shortcuts) do
        if k1 ~= k2 and k2:sub(1, #k1) == k1 then
            prefixes[k1] = true
            break
        end
    end
end

M.debug = false

function M.toggle_debug()
    M.debug = not M.debug
    hs.alert.show("Unicode debug " .. (M.debug and "ON" or "OFF"), 1)
end

function M.setup()
    local buffer = ""
    local pendingTimer = nil
    local pendingTrigger = nil
    local pendingReplacement = nil

    -- Tag our synthesized events so the eventtap handler can ignore them when
    -- they propagate back through (otherwise our own deletes/cmd+v get parsed
    -- as if the user typed them, polluting buffer state).
    local SYNTH_TAG = 0x554E4943  -- "UNIC"
    local userDataProp = hs.eventtap.event.properties.eventSourceUserData

    local function postTaggedKey(modifiers, key, isDown)
        local ev = hs.eventtap.event.newKeyEvent(modifiers, key, isDown)
        ev:setProperty(userDataProp, SYNTH_TAG)
        ev:post()
    end

    local function doReplace(trigger, replacement, deleteCount)
        buffer = ""
        for i = 1, deleteCount do
            postTaggedKey({}, "delete", true)
            hs.timer.usleep(10000)
            postTaggedKey({}, "delete", false)
        end
        -- Paste replacement via clipboard (more reliable than keyStrokes for unicode).
        local prev = hs.pasteboard.getContents()
        hs.pasteboard.setContents(replacement)
        postTaggedKey({"cmd"}, "v", true)
        hs.timer.usleep(10000)
        postTaggedKey({"cmd"}, "v", false)
        if prev then
            -- 500ms (not 100ms) so async paste handlers (Google Docs JS, etc.) finish reading
            -- the pasteboard before we restore the previous contents.
            hs.timer.doAfter(0.5, function() hs.pasteboard.setContents(prev) end)
        end
    end

    local watcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        -- Skip our own synthesized events
        if event:getProperty(userDataProp) == SYNTH_TAG then
            return false
        end

        local char = event:getCharacters()
        if not char or #char == 0 then return false end

        -- Reset on modifier keys (except shift)
        local flags = event:getFlags()
        if flags.cmd or flags.ctrl or flags.alt then
            if M.debug and #buffer > 0 then
                print("[unicode] reset buffer (modifier): " .. buffer)
            end
            buffer = ""
            if pendingTimer then pendingTimer:stop(); pendingTimer = nil end
            return false
        end

        buffer = buffer .. char

        if M.debug then
            print("[unicode] char=" .. char .. " buffer=" .. buffer)
        end

        -- Keep buffer trimmed
        if #buffer > maxLen then
            buffer = buffer:sub(-maxLen)
        end

        -- Cancel any pending replacement
        local hadPending = nil
        if pendingTimer then
            hadPending = {trigger = pendingTrigger, replacement = pendingReplacement}
            pendingTimer:stop()
            pendingTimer = nil
            pendingTrigger = nil
            pendingReplacement = nil
        end

        -- Check if buffer ends with any trigger
        local matched = false
        for trigger, replacement in pairs(shortcuts) do
            if buffer:sub(-#trigger) == trigger then
                matched = true
                if prefixes[trigger] then
                    -- This trigger is a prefix of a longer one; wait briefly
                    local t = trigger
                    local r = replacement
                    pendingTrigger = t
                    pendingReplacement = r
                    pendingTimer = hs.timer.doAfter(0.3, function()
                        if M.debug then
                            print("[unicode] firing delayed: " .. t .. " -> " .. r)
                        end
                        doReplace(t, r, #t)
                        pendingTimer = nil
                        pendingTrigger = nil
                        pendingReplacement = nil
                    end)
                    return false
                else
                    -- No ambiguity, fire immediately
                    -- Current keystroke not yet inserted (suppressed by return true),
                    -- so only delete #trigger - 1
                    if M.debug then
                        print("[unicode] firing: " .. trigger .. " -> " .. replacement)
                    end
                    doReplace(trigger, replacement, #trigger - 1)
                    return true
                end
            end
        end

        -- If we cancelled a pending trigger and nothing new matched, fire it now
        -- All pending trigger chars are in the text, current char not yet inserted
        if hadPending and not matched then
            if M.debug then
                print("[unicode] firing cancelled pending: " .. hadPending.trigger .. " -> " .. hadPending.replacement)
            end
            doReplace(hadPending.trigger, hadPending.replacement, #hadPending.trigger)
        end

        return false
    end)
    watcher:start()
    M.watcher = watcher
    print("Unicode expander loaded (" .. maxLen .. " max trigger, " ..
          tostring(#prefixes) .. " prefix triggers)")
end

-- ---------------------------------------------------------------------------
-- Unicode picker: a fuzzy-search chooser over the shortcuts table.
-- Bind to a hotkey (e.g. alt-;) → search by char, trigger, or description.

local function deriveName(trigger, char)
    local d = trigger:match("^;_(%d)$")
    if d then return "subscript " .. d end
    d = trigger:match("^;%^?(%d)$")
    if d then return "superscript " .. d end
    return char
end

local function loadDescriptions()
    -- Parse this file's source for per-line comment descriptions.
    local src = debug.getinfo(1, "S").source:sub(2)
    local descs = {}
    local f = io.open(src, "r")
    if not f then return descs end
    for line in f:lines() do
        local trigger, _, name = line:match('%[%s*"([^"]+)"%s*%]%s*=%s*"([^"]+)"%s*,?%s*%-%-%s*(.+)$')
        if trigger then
            descs[trigger] = (name or ""):gsub("%s+$", "")
        end
    end
    f:close()
    return descs
end

local emojiDbCache = nil
local function loadEmojiDb()
    if emojiDbCache ~= nil then return emojiDbCache end
    local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local path = (dir or "") .. "data/emoji.json"
    local f = io.open(path, "r")
    if not f then emojiDbCache = {}; return emojiDbCache end
    local content = f:read("*all")
    f:close()
    local ok, data = pcall(hs.json.decode, content)
    emojiDbCache = (ok and type(data) == "table") and data or {}
    return emojiDbCache
end

local function buildPickerChoices()
    local descs = loadDescriptions()
    local choices = {}
    local seenChar = {}

    -- 1. The curated ;-shortcuts (arrows, math, Greek, etc.)
    local entries = {}
    for trigger, char in pairs(shortcuts) do
        local name = descs[trigger] or deriveName(trigger, char)
        table.insert(entries, { trigger = trigger, char = char, name = name })
    end
    table.sort(entries, function(a, b) return a.trigger < b.trigger end)
    for _, e in ipairs(entries) do
        table.insert(choices, {
            text    = e.char .. "    " .. e.name,
            subText = e.trigger,
            char    = e.char,
        })
        seenChar[e.char] = true
    end

    -- 2. The full emoji database (gemoji), skipping any already shown above
    for _, e in ipairs(loadEmojiDb()) do
        if not seenChar[e.emoji] then
            local aliases = e.aliases or {}
            local tags    = e.tags    or {}
            local searchBits = { e.description or "" }
            for _, a in ipairs(aliases) do table.insert(searchBits, ":" .. a .. ":") end
            for _, t in ipairs(tags)    do table.insert(searchBits, t) end
            table.insert(choices, {
                text    = e.emoji .. "    " .. (e.description or (aliases[1] or "")),
                subText = table.concat(searchBits, "  "),
                char    = e.emoji,
            })
            seenChar[e.emoji] = true
        end
    end

    return choices
end

function M.show_picker()
    local choices = buildPickerChoices()
    local chooser = hs.chooser.new(function(choice)
        if choice and choice.char then
            hs.eventtap.keyStrokes(choice.char)
        end
    end)
    chooser:choices(choices)
    chooser:searchSubText(true)
    chooser:show()
end

return M
