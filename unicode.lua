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
    [";cmd"] = "⌘",   -- command
    [";meta"] = "⌘",  -- command (alias)
    [";opt"] = "⌥",   -- option
    [";ctl"] = "⌃",   -- control
    [";shf"] = "⇧",   -- shift
    [";tab"] = "⇥",   -- tab
    [";ret"] = "⏎",   -- return
    [";bsp"] = "⌫",   -- backspace
    [";del"] = "⌦",   -- forward delete
    [";esc"] = "⎋",   -- escape

    -- Emoji
    [";grin"]  = "😀",   -- grinning face
    [";grim"]  = "😬",   -- grimacing face
    [";think"] = "🤔",   -- thinking face
    [";thnk"]  = "🤔",   -- thinking face
    [";laugh"] = "😂",   -- face with tears of joy

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

local emojiByCharCache = nil
local function loadEmojiByChar()
    if emojiByCharCache ~= nil then return emojiByCharCache end
    emojiByCharCache = {}
    for _, e in ipairs(loadEmojiDb()) do
        emojiByCharCache[e.emoji] = e
    end
    return emojiByCharCache
end

-- Picker history (MRU sort: last-picked floats to top, count is tiebreaker)
-- is persisted via hs.settings, which serializes Lua tables under
-- NSUserDefaults — no SQLite needed.
local HISTORY_KEY = "unicode.picker.history"

local function loadHistory()
    return hs.settings.get(HISTORY_KEY) or {}
end

local function recordPick(char)
    local history = loadHistory()
    local entry = history[char] or { count = 0 }
    entry.count = (entry.count or 0) + 1
    entry.last  = os.time()
    history[char] = entry
    hs.settings.set(HISTORY_KEY, history)
end

-- Render `char` as an hs.image, used as each row's left-hand icon (replacing
-- the chooser's default blue arrow with a big preview of the actual character).
-- Cached per char for the life of the HS session; reuses one shared canvas so
-- we avoid allocating ~2000 of them when the picker is first opened.
local IMG_SIZE = 40
local imageCache = {}
local sharedRenderCanvas = nil
local function imageForChar(char)
    local cached = imageCache[char]
    if cached then return cached end
    if not sharedRenderCanvas then
        sharedRenderCanvas = hs.canvas.new({ x = 0, y = 0, w = IMG_SIZE, h = IMG_SIZE })
    end
    sharedRenderCanvas[1] = {
        type = "text",
        text = hs.styledtext.new(char, {
            font = { size = IMG_SIZE * 0.65 },
            -- White so non-emoji symbols (→, α, ∈, …) show up on the chooser's
            -- dark background. Color emoji ignore this and stay full-color.
            color = { white = 1 },
            paragraphStyle = { alignment = "center" },
        }),
        frame = { x = 0, y = IMG_SIZE * 0.1, w = IMG_SIZE, h = IMG_SIZE },
    }
    local img = sharedRenderCanvas:imageFromCanvas()
    imageCache[char] = img
    return img
end

-- Pick the row's main text. If we have a description, that's the text;
-- otherwise show the trigger so the row is still useful.
local function rowText(name, trigger, char)
    if name and name ~= "" and name ~= char then return name end
    return trigger
end

-- Pick a display name + collect fuzzy-search bits for a curated shortcut.
-- Falls back: inline `--` comment → gemoji description → derived name.
local function describeShortcut(trigger, char, descs, emojiByChar)
    local entry = emojiByChar[char]
    local name = descs[trigger]
    if (not name or name == "") and entry then name = entry.description end
    if not name or name == "" then name = deriveName(trigger, char) end
    local bits = { trigger }
    if name and name ~= "" and name ~= char then table.insert(bits, name) end
    if entry then
        for _, a in ipairs(entry.aliases or {}) do
            if a and a ~= "" then table.insert(bits, ":" .. a .. ":") end
        end
        for _, t in ipairs(entry.tags or {}) do
            if t and t ~= "" then table.insert(bits, t) end
        end
    end
    return name, bits
end

local SUB_SEP = "   ·   "

local function buildPickerChoices()
    local descs       = loadDescriptions()
    local emojiByChar = loadEmojiByChar()
    local choices     = {}
    local seenChar    = {}

    -- 1. The curated ;-shortcuts (arrows, math, Greek, modifier keys, etc.)
    local entries = {}
    for trigger, char in pairs(shortcuts) do
        table.insert(entries, { trigger = trigger, char = char })
    end
    table.sort(entries, function(a, b) return a.trigger < b.trigger end)
    for _, e in ipairs(entries) do
        local name, bits = describeShortcut(e.trigger, e.char, descs, emojiByChar)
        local text    = rowText(name, e.trigger, e.char)
        local subText = table.concat(bits, SUB_SEP)
        table.insert(choices, {
            image          = imageForChar(e.char),
            text           = text,
            subText        = subText,
            char           = e.char,
            _textLower     = text:lower(),
            _subTextLower  = subText:lower(),
        })
        seenChar[e.char] = true
    end

    -- 2. The full emoji database (gemoji), skipping any already shown above
    for _, e in ipairs(loadEmojiDb()) do
        if not seenChar[e.emoji] then
            local aliases = e.aliases or {}
            local tags    = e.tags    or {}
            local name    = e.description or aliases[1] or ""
            local bits    = {}
            if name and name ~= "" then table.insert(bits, name) end
            for _, a in ipairs(aliases) do
                if a and a ~= "" then table.insert(bits, ":" .. a .. ":") end
            end
            for _, t in ipairs(tags) do
                if t and t ~= "" then table.insert(bits, t) end
            end
            local text    = rowText(name, aliases[1] or e.emoji, e.emoji)
            local subText = table.concat(bits, SUB_SEP)
            table.insert(choices, {
                image          = imageForChar(e.emoji),
                text           = text,
                subText        = subText,
                char           = e.emoji,
                _textLower     = text:lower(),
                _subTextLower  = subText:lower(),
            })
            seenChar[e.emoji] = true
        end
    end

    -- 3. Re-rank MRU: most recently picked floats to the top, count breaks ties
    -- (so a frequent favorite still beats a never-picked entry once their `last`
    -- timestamps tie at 0). Original index preserves curated-section order
    -- within the never-picked tier.
    local history = loadHistory()
    for i, c in ipairs(choices) do
        local entry  = history[c.char]
        c._last      = (entry and entry.last)  or 0
        c._count     = (entry and entry.count) or 0
        c._tiebreak  = i
    end
    table.sort(choices, function(a, b)
        if a._last  ~= b._last  then return a._last  > b._last  end
        if a._count ~= b._count then return a._count > b._count end
        return a._tiebreak < b._tiebreak
    end)
    for _, c in ipairs(choices) do
        c._last = nil; c._count = nil; c._tiebreak = nil
    end

    return choices
end

-- Score a single token against a choice. Higher = better match; negative =
-- no match (filtered out). Tiers (descending):
--   1000  text exactly equals token                ("fire"  vs "fire")
--    800  text starts with token                   ("fire"  vs "fireworks")
--    600  whole-word match inside text             ("fire"  vs "heart on fire")
--    400  substring of text                        ("fire"  vs "campfire-x")
--    300  subText starts with token                (";fir"  vs ";fire …")
--    200  substring of subText (aliases, tags)     ("smile" vs grin's tags)
-- Within a tier, shorter text wins (so "fire" beats "firefighter"); ties fall
-- back to the choices' original (MRU) order via the caller's stable sort.
local function scoreToken(qLower, choice)
    if qLower == "" then return 0 end
    local t = choice._textLower
    if t == qLower then return 1000 end
    if #qLower <= #t and t:sub(1, #qLower) == qLower then
        return 800 - (#t - #qLower)
    end
    local pos = t:find(qLower, 1, true)
    if pos then
        local before = pos == 1
            or not t:sub(pos - 1, pos - 1):match("%w")
        local after = pos + #qLower - 1 == #t
            or not t:sub(pos + #qLower, pos + #qLower):match("%w")
        if before and after then return 600 - (#t - #qLower) end
        return 400 - (#t - #qLower)
    end
    local s = choice._subTextLower
    if #qLower <= #s and s:sub(1, #qLower) == qLower then return 300 end
    if s:find(qLower, 1, true) then return 200 end
    return -1
end

-- Score a multi-word query. Word order is allowed to differ from the choice's
-- text — e.g. "heart green" still finds 💚 green heart. Strategy:
--   1. Try the whole query as one token (catches exact / starts-with cleanly).
--   2. Split on whitespace, require ALL tokens to match somewhere; score by
--      their per-token average minus a small constant so a literal exact match
--      (1000) still outranks a multi-token AND match.
-- The MAX of the two wins, so a single-token query keeps its original score.
local function scoreQuery(qLower, choice)
    if qLower == "" then return 0 end
    local whole = scoreToken(qLower, choice)
    local tokens = {}
    for w in qLower:gmatch("%S+") do tokens[#tokens + 1] = w end
    if #tokens <= 1 then return whole end
    local total = 0
    for _, t in ipairs(tokens) do
        local s = scoreToken(t, choice)
        if s < 0 then return whole end
        total = total + s
    end
    local andScore = total / #tokens - 100
    return andScore > whole and andScore or whole
end

function M.show_picker()
    local t0 = hs.timer.secondsSinceEpoch()
    local choices = buildPickerChoices()
    local elapsed = hs.timer.secondsSinceEpoch() - t0
    if elapsed > 0.1 then
        print(string.format("[unicode] built %d picker choices in %.2fs",
            #choices, elapsed))
    end
    local chooser = hs.chooser.new(function(choice)
        if choice and choice.char then
            recordPick(choice.char)
            hs.eventtap.keyStrokes(choice.char)
        end
    end)
    chooser:choices(choices)
    chooser:queryChangedCallback(function(query)
        if query == "" then
            chooser:choices(choices)
            return
        end
        local q = query:lower()
        local scored = {}
        for i, c in ipairs(choices) do
            local s = scoreQuery(q, c)
            if s >= 0 then
                scored[#scored + 1] = { c = c, score = s, idx = i }
            end
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

-- Expose for debugging / manual reset.
function M.clear_picker_history()
    hs.settings.set(HISTORY_KEY, {})
    hs.alert.show("Unicode picker history cleared", 1)
end

return M
