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
    [";md"]  = "·",   -- middle dot
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

-- Bundled Unicode-name database (generated by data/gen_unicode.py from
-- Python's `unicodedata`). Covers printable BMP symbol/punctuation/math/arrow
-- blocks — the stuff not in gemoji but that users still want to look up (↳,
-- ‰, ‡, †, ∴, ∎, etc.). Rebuild with `python3 data/gen_unicode.py`.
local unicodeDbCache = nil
local function loadUnicodeDb()
    if unicodeDbCache ~= nil then return unicodeDbCache end
    local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
    local path = (dir or "") .. "data/unicode.json"
    local f = io.open(path, "r")
    if not f then unicodeDbCache = {}; return unicodeDbCache end
    local content = f:read("*all")
    f:close()
    local ok, data = pcall(hs.json.decode, content)
    unicodeDbCache = (ok and type(data) == "table") and data or {}
    return unicodeDbCache
end

-- Local keyword overlay for the picker: extra search terms that gemoji's
-- aliases/tags miss. Purely additive to the fuzzy-search index (never shown as
-- a row's name) — add freely.
local EXTRA_KEYWORDS = {
    ["❌"] = { "red x", "red cross", "wrong", "no", "cancel" },
    ["🙏"] = { "thank you hands", "thanks", "thank you", "gratitude", "namaste" },
}

local function appendExtraKeywords(bits, char)
    local extra = EXTRA_KEYWORDS[char]
    if not extra then return end
    for _, kw in ipairs(extra) do bits[#bits + 1] = kw end
end

-- Crude English stemmer: unifies suffix variants so "raised"/"raising" both
-- reduce to "rais", "hands" → "hand", "folded" → "fold". No dictionary, just
-- rules — good enough for the short, common words in emoji/symbol names. Used
-- to (a) augment each choice's search index with stems and (b) stem query
-- tokens before matching, so a differently-inflected query still hits.
local function stem(word)
    local n = #word
    if n >= 6 and word:sub(-3) == "ing" then return word:sub(1, -4) end
    if n >= 6 and word:sub(-3) == "ies" then return word:sub(1, -4) .. "y" end
    if n >= 6 and word:sub(-3) == "ied" then return word:sub(1, -4) .. "y" end
    if n >= 5 and word:sub(-2) == "ed"  then return word:sub(1, -3) end
    if n >= 5 and word:sub(-2) == "es"  then
        if word:sub(-4, -3) == "ss" or word:sub(-4, -3) == "ch"
            or word:sub(-4, -3) == "sh" or word:sub(-3, -3):match("[xzo]") then
            return word:sub(1, -3)   -- boxes → box, dishes → dish
        end
        return word:sub(1, -2)       -- faces → face
    end
    if n >= 4 and word:sub(-1) == "s" and word:sub(-2) ~= "ss" then
        return word:sub(1, -2)       -- hands → hand
    end
    if n >= 5 and word:sub(-1) == "e" then
        return word:sub(1, -2)       -- raise → rais (agrees with raising/raised)
    end
    return word
end

-- Append the stems of each (letters-only) word to `text`, leaving the original
-- intact so trigger tokens (";pray") and colon-aliases (":raising_hand_man:")
-- still match verbatim. The appended stems let a stemmed query token
-- substring-hit when the surface forms differ ("raised" vs "raising").
local function withStems(text)
    local extra, seen = {}, {}
    for w in text:gmatch("%a+") do
        local s = stem(w)
        if s ~= w and not seen[s] then seen[s] = true; extra[#extra + 1] = s end
    end
    if #extra == 0 then return text end
    return text .. " " .. table.concat(extra, " ")
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

-- Query-conditioned pick history: which char did the user pick, given the
-- query text at pick time? Used to bias ranking so a repeatedly-picked result
-- floats up when its query (or a related prefix) is typed again.
-- Shape: { [query_lower] = { [char] = { count, last } } }
local QUERY_HISTORY_KEY = "unicode.picker.query_history"

local function loadQueryHistory()
    return hs.settings.get(QUERY_HISTORY_KEY) or {}
end

local function recordQueryPick(query, char)
    if not query or query == "" then return end
    local qh = loadQueryHistory()
    qh[query] = qh[query] or {}
    local entry = qh[query][char] or { count = 0 }
    entry.count = (entry.count or 0) + 1
    entry.last  = os.time()
    qh[query][char] = entry
    hs.settings.set(QUERY_HISTORY_KEY, qh)
end

-- Given the current query q, build a `char -> boost` map from recorded picks.
-- Rules:
--   - Only recorded queries in a prefix relationship with q count (one is a
--     prefix of the other). "sunset" won't inherit boosts from "sung".
--   - Boost = count * common_prefix_len * K * decay, where decay falls off as
--     |q| and |recQ| diverge in length (a much longer q suggests different
--     intent even if the earlier query was a prefix).
--   - Take the max across recorded queries per char (rather than summing) so a
--     single overwhelmingly-picked entry doesn't pile up boosts.
local BOOST_K = 200
local function buildBoostMap(q, qh)
    local boosts = {}
    for recQ, chars in pairs(qh) do
        local common = 0
        local lim = math.min(#q, #recQ)
        for i = 1, lim do
            if q:sub(i, i) == recQ:sub(i, i) then common = i else break end
        end
        if common > 0 and common == lim then
            local delta = math.abs(#q - #recQ)
            local decay = math.max(0, 1 - delta * 0.3)
            if decay > 0 then
                local factor = common * BOOST_K * decay
                for ch, entry in pairs(chars) do
                    local candidate = (entry.count or 0) * factor
                    if candidate > (boosts[ch] or 0) then
                        boosts[ch] = candidate
                    end
                end
            end
        end
    end
    return boosts
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
    -- Comments like "degree (alias)" / "mu (alias for `;m`)" annotated a trigger
    -- as an alias back when each trigger was its own row; now that triggers
    -- merge per char, that parenthetical is noise in the title — strip it.
    if name then name = name:gsub("%s*%(alias[^)]*%)%s*$", "") end
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

    -- 1. The curated ;-shortcuts (arrows, math, Greek, modifier keys, etc.).
    -- Multiple triggers can map to the same char (";think"/";thnk" → 🤔,
    -- ";m"/";mu" → μ, ";o"/";deg" → °); collapse them into ONE row that lists
    -- every trigger, rather than emitting a duplicate row per trigger.
    local triggersByChar = {}
    local charOrder = {}
    for trigger, char in pairs(shortcuts) do
        local ts = triggersByChar[char]
        if not ts then
            ts = {}; triggersByChar[char] = ts; charOrder[#charOrder + 1] = char
        end
        ts[#ts + 1] = trigger
    end
    for _, ts in pairs(triggersByChar) do table.sort(ts) end
    table.sort(charOrder, function(a, b)
        return triggersByChar[a][1] < triggersByChar[b][1]
    end)
    for _, char in ipairs(charOrder) do
        local triggers = triggersByChar[char]
        local name, bits = describeShortcut(triggers[1], char, descs, emojiByChar)
        -- Splice the additional triggers in right after the primary (bits[1]).
        for i = #triggers, 2, -1 do table.insert(bits, 2, triggers[i]) end
        appendExtraKeywords(bits, char)
        local text    = rowText(name, triggers[1], char)
        local subText = table.concat(bits, SUB_SEP)
        table.insert(choices, {
            image          = imageForChar(char),
            text           = text,
            subText        = subText,
            char           = char,
            _prio          = 1,  -- curated + emoji outrank the bulk Unicode db
            _textLower     = text:lower(),
            -- Search on a plain-space-joined variant so the display SUB_SEP
            -- ("·") isn't matched by every query that contains it.
            _subTextLower  = withStems(table.concat(bits, " "):lower()),
        })
        seenChar[char] = true
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
            appendExtraKeywords(bits, e.emoji)
            local text    = rowText(name, aliases[1] or e.emoji, e.emoji)
            local subText = table.concat(bits, SUB_SEP)
            table.insert(choices, {
                image          = imageForChar(e.emoji),
                text           = text,
                subText        = subText,
                char           = e.emoji,
                _prio          = 1,  -- curated + emoji outrank the bulk Unicode db
                _textLower     = text:lower(),
                _subTextLower  = withStems(table.concat(bits, " "):lower()),
            })
            seenChar[e.emoji] = true
        end
    end

    -- 3. Bundled Unicode-name db (arrows, math, punct, symbols, ...) for
    -- everything not already covered above. Searchable by name, block, or
    -- codepoint (e.g. "U+21B3" or "21b3").
    for _, e in ipairs(loadUnicodeDb()) do
        if not seenChar[e.char] then
            local bits = { e.name, e.block, "U+" .. e.cp }
            table.insert(choices, {
                image          = imageForChar(e.char),
                text           = e.name,
                subText        = table.concat(bits, SUB_SEP),
                char           = e.char,
                _prio          = 0,  -- bulk db: below curated + emoji
                _textLower     = e.name,  -- already lowercase from generator
                _subTextLower  = withStems(table.concat(bits, " "):lower()),
            })
            seenChar[e.char] = true
        end
    end

    -- Stamp canonical build-order for use as a stable tiebreaker in later MRU
    -- sorts. Kept on the choice — must NOT be wiped after sorting or the next
    -- sort loses the "before any picks" ordering.
    for i, c in ipairs(choices) do c._canonical = i end
    return choices
end

-- Re-order `choices` in place: most recently picked floats to the top, count
-- breaks ties (so a frequent favorite still beats a never-picked entry once
-- their `last` timestamps tie at 0), then canonical build-order preserves the
-- curated → emoji → unicode section grouping within the never-picked tier.
local function sortChoicesByMRU(choices)
    local history = loadHistory()
    for _, c in ipairs(choices) do
        local entry  = history[c.char]
        c._last  = (entry and entry.last)  or 0
        c._count = (entry and entry.count) or 0
    end
    table.sort(choices, function(a, b)
        if a._last  ~= b._last  then return a._last  > b._last  end
        if a._count ~= b._count then return a._count > b._count end
        return a._canonical < b._canonical
    end)
end

-- Cache the raw choice list across shows: rendering ~4600 char images through
-- hs.canvas is the slow part (a few hundred ms) and doesn't change between
-- opens. The MRU sort re-runs on each show since pick history is mutable.
local pickerChoicesCache = nil

-- Ranking is a small feature-weighted linear model: final score is a MATCH
-- component (one of the mutually-exclusive match tiers below — the single best
-- way this query hits this row) PLUS additive per-choice priors applied by the
-- caller (prio, recency, frequency, query-conditioned history). Hand-set weights
-- for now; the table is the substrate a learned/online-updated weight vector
-- would drop into later. Tune ranking here — one table, not scattered literals.
--
-- MATCH tiers (descending), each on a token vs. a row:
--   1200 literal_char  query IS the char             ("·"    → middle dot)
--   1000 exact_text    text == token                 ("fire" → "fire")
--    800 prefix_text   text starts with token        ("fire" → "fireworks")
--    600 word_text     whole-word hit inside text     ("fire" → "heart on fire")
--    500 phrase_sub    bounded alias/keyword in subText ("red x" → ❌)
--    400 substr_text   substring of text              ("fire" → "campfire-x")
--    300 prefix_sub    subText starts with token      (";fir" → ";fire …")
--    200 substr_sub    substring of subText           ("smile" → grin's tags)
--    150 stem_sub      stemmed token hits subText     ("raise" → "raising")
--    100 subseq_text   fuzzy subsequence of text      ("dwn"  → "down arrow")
-- ADDITIVE priors (per choice, applied in makeQueryCallback):
--    prio       * _prio   curated/emoji outrank the bulk Unicode db
--    recency    * decay   exp-decay of time since last pick   (in (0,1])
--    frequency  * ln(1+n) log of lifetime pick count
--    query_hist           buildBoostMap: picks made under this query prefix
-- Within a text tier, shorter text wins (so "fire" beats "firefighter"); ties
-- fall back to the choices' original (MRU) order via the caller's stable sort.
local W = {
    literal_char = 1200,
    exact_text   = 1000,
    prefix_text  = 800,
    word_text    = 600,
    phrase_sub   = 500,
    substr_text  = 400,
    prefix_sub   = 300,
    substr_sub   = 200,
    stem_sub     = 150,
    subseq_text  = 100,
    -- additive priors --
    prio         = 250,
    recency      = 300,
    frequency    = 60,
}

-- Is `q` a subsequence of `t` whose first char lands on a word boundary? Returns
-- the matched span length (last matched index − first + 1) so the caller can
-- reward tighter matches, else nil. The word-boundary anchor curbs the noise a
-- bare subsequence test invites over ~4600 rows.
local function subseqSpan(q, t)
    local ti, first = 1, nil
    for qi = 1, #q do
        local ch = q:sub(qi, qi)
        local hit = nil
        while ti <= #t do
            if t:sub(ti, ti) == ch then hit = ti; ti = ti + 1; break end
            ti = ti + 1
        end
        if not hit then return nil end
        if qi == 1 then
            if hit ~= 1 and t:sub(hit - 1, hit - 1):match("%w") then return nil end
            first = hit
        end
    end
    return (ti - 1) - first + 1
end

local function scoreToken(qLower, choice)
    if qLower == "" then return 0 end
    -- Literal-char match: typing the char itself surfaces it (e.g. "·" finds
    -- middle dot). Beats even exact text match — if you paste the character,
    -- you're clearly looking for that character.
    if qLower == choice.char then return W.literal_char end
    local t = choice._textLower
    if t == qLower then return W.exact_text end
    if #qLower <= #t and t:sub(1, #qLower) == qLower then
        return W.prefix_text - (#t - #qLower)
    end
    local pos = t:find(qLower, 1, true)
    if pos then
        local before = pos == 1
            or not t:sub(pos - 1, pos - 1):match("%w")
        local after = pos + #qLower - 1 == #t
            or not t:sub(pos + #qLower, pos + #qLower):match("%w")
        if before and after then return W.word_text - (#t - #qLower) end
        return W.substr_text - (#t - #qLower)
    end
    local s = choice._subTextLower
    -- Bounded phrase in subText: the query sits at word boundaries on both sides
    -- (a whole alias/keyword like "red x" or ":x:"), a deliberate-keyword signal
    -- that should beat loose token-AND matches on unrelated rows.
    local sp = s:find(qLower, 1, true)
    if sp then
        local before = sp == 1 or not s:sub(sp - 1, sp - 1):match("%w")
        local eend = sp + #qLower - 1
        local after = eend == #s or not s:sub(eend + 1, eend + 1):match("%w")
        if before and after then return W.phrase_sub end
    end
    if #qLower <= #s and s:sub(1, #qLower) == qLower then return W.prefix_sub end
    if sp then return W.substr_sub end
    -- Stemmed fallback: reduce the query token to its stem and retry against the
    -- stem-augmented index, so "raised"/"raising" cross-match. Below all literal
    -- tiers so exact hits always win.
    local qs = stem(qLower)
    if qs ~= qLower and #qs >= 3 and s:find(qs, 1, true) then return W.stem_sub end
    -- Fuzzy subsequence over text (last resort): catches typos/abbreviations
    -- ("dwn" → "down arrow"). Weighted below every literal tier and scaled by
    -- tightness (query len / matched span) so a gappy hit ranks lowest.
    if #qLower >= 3 then
        local span = subseqSpan(qLower, t)
        if span then return math.floor(W.subseq_text * #qLower / span) end
    end
    return -1
end

-- Score a multi-word query. Word order is allowed to differ from the choice's
-- text — e.g. "heart green" still finds 💚 green heart. Strategy:
--   1. Try the whole query as one token (catches exact / starts-with cleanly).
--   2. Split on whitespace, require ALL tokens to match somewhere; score by
--      their per-token average minus a small constant so a literal exact match
--      (1000) still outranks a multi-token AND match.
-- The MAX of the two wins, so a single-token query keeps its original score.
-- Returns the pure MATCH component (negative = no match); the caller adds the
-- per-choice additive priors (prio/recency/frequency/query_hist).
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

-- Additive per-choice priors, independent of the query text (only applied to a
-- row that already matched). Recency uses an exp half-life so a just-picked char
-- gets ~full weight and a day-old pick ~half; frequency is a gentler lifetime
-- prior. _last/_count are stamped by sortChoicesByMRU before the callback runs.
local RECENCY_HALFLIFE = 86400  -- seconds (1 day)
local function personalBoost(choice, now)
    local b = (choice._prio or 0) * W.prio
    local last = choice._last or 0
    if last > 0 then
        local age = now - last
        if age < 0 then age = 0 end
        b = b + W.recency * 0.5 ^ (age / RECENCY_HALFLIFE)
    end
    local count = choice._count or 0
    if count > 0 then b = b + W.frequency * math.log(1 + count) end
    return b
end

-- Build the queryChangedCallback bound to a specific chooser + choice list.
-- Extracted so we can install it either up-front (warm cache) or after the
-- cold-cache build finishes.
local function makeQueryCallback(chooser, choices)
    return function(query)
        if query == "" then
            chooser:choices(choices)
            return
        end
        local q = query:lower()
        local boosts = buildBoostMap(q, loadQueryHistory())
        local now = os.time()
        local scored = {}
        for i, c in ipairs(choices) do
            local s = scoreQuery(q, c)
            if s >= 0 then
                local score = s + personalBoost(c, now) + (boosts[c.char] or 0)
                scored[#scored + 1] = { c = c, score = score, idx = i }
            end
        end
        table.sort(scored, function(a, b)
            if a.score ~= b.score then return a.score > b.score end
            return a.idx < b.idx
        end)
        local filtered = {}
        for j, x in ipairs(scored) do filtered[j] = x.c end
        chooser:choices(filtered)
    end
end

local function ensureChoicesCache()
    if pickerChoicesCache then return end
    local t0 = hs.timer.secondsSinceEpoch()
    pickerChoicesCache = buildPickerChoices()
    print(string.format("[unicode] built %d picker choices in %.2fs",
        #pickerChoicesCache, hs.timer.secondsSinceEpoch() - t0))
end

function M.show_picker()
    local chooser
    chooser = hs.chooser.new(function(choice)
        -- Guard: the "loading…" placeholder row has no `.char`, so a stray
        -- Enter while we're still building is a no-op instead of a silent
        -- dismiss with nothing typed.
        if not choice or not choice.char then return end
        recordPick(choice.char)
        local q = (chooser:query() or ""):lower()
        recordQueryPick(q, choice.char)
        hs.eventtap.keyStrokes(choice.char)
    end)

    if pickerChoicesCache then
        sortChoicesByMRU(pickerChoicesCache)
        chooser:choices(pickerChoicesCache)
        chooser:queryChangedCallback(makeQueryCallback(chooser, pickerChoicesCache))
        chooser:show()
        return
    end

    -- Cold cache: pop the chooser up immediately with a visible "loading" row
    -- and a placeholder in the input field, then build in the next runloop
    -- tick so the chooser actually renders before we block the main thread.
    -- The alternative (block, then show) leaves the user staring at nothing
    -- after hitting the hotkey.
    chooser:placeholderText("Building Unicode picker…")
    chooser:choices({{
        text    = "⏳ Building Unicode picker…",
        subText = "loading ~4600 characters, one moment",
    }})
    chooser:show()
    hs.timer.doAfter(0, function()
        ensureChoicesCache()
        sortChoicesByMRU(pickerChoicesCache)
        local qcb = makeQueryCallback(chooser, pickerChoicesCache)
        chooser:queryChangedCallback(qcb)
        chooser:choices(pickerChoicesCache)
        chooser:placeholderText("")
        -- If the user typed while we were building, apply that query now —
        -- the callback we just registered wouldn't fire retroactively.
        local curq = chooser:query()
        if curq and curq ~= "" then qcb(curq) end
    end)
end

-- Expose for debugging / manual reset.
function M.clear_picker_history()
    hs.settings.set(HISTORY_KEY, {})
    hs.settings.set(QUERY_HISTORY_KEY, {})
    hs.alert.show("Unicode picker history cleared", 1)
end

-- Prebuild picker choices ~1s after module load so the first hotkey press
-- doesn't hang while we render ~4600 canvas images. Deferred so it doesn't
-- lengthen `hs.reload()`; if the user beats the timer, show_picker's alert
-- fallback covers it.
hs.timer.doAfter(1.0, ensureChoicesCache)

return M
