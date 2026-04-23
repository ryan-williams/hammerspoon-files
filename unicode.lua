-- Unicode text expander for Hammerspoon
-- Type a trigger (e.g. ";r"), get unicode replacement (e.g. "→")
-- Uses hs.eventtap to monitor keystrokes

local M = {}

local shortcuts = {
    -- Arrows (single char suffix)
    [";r"]   = "→",   -- right arrow
    [";l"]   = "←",   -- left arrow
    [";u"]   = "↑",   -- up arrow
    [";d"]   = "↓",   -- down arrow

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
    [";inf"] = "∞",   -- infinity
    [";o"]   = "°",   -- degree
    [";m"]   = "μ",   -- mu
    [";v"]   = "√",   -- square root
    [";x"]   = "×",   -- multiplication
    [";/"]   = "÷",   -- division

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

    local function doReplace(trigger, replacement, deleteCount)
        buffer = ""
        -- Delete the trigger characters already in the text
        -- Use ~10ms keyDown/keyUp gap so apps (e.g. WhatsApp) process in order
        for i = 1, deleteCount do
            hs.eventtap.keyStroke({}, "delete", 10000)
        end
        -- Paste replacement via clipboard (more reliable than keyStrokes for unicode)
        local prev = hs.pasteboard.getContents()
        hs.pasteboard.setContents(replacement)
        -- Delay paste to ensure deletes are processed first
        hs.timer.doAfter(0.03, function()
            hs.eventtap.keyStroke({"cmd"}, "v", 10000)
            if prev then
                hs.timer.doAfter(0.1, function() hs.pasteboard.setContents(prev) end)
            end
        end)
    end

    local watcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
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
            hadPending = {trigger = pendingTimer._trigger, replacement = pendingTimer._replacement}
            pendingTimer:stop()
            pendingTimer = nil
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
                    pendingTimer = hs.timer.doAfter(0.3, function()
                        if M.debug then
                            print("[unicode] firing delayed: " .. t .. " -> " .. r)
                        end
                        doReplace(t, r, #t)
                        pendingTimer = nil
                    end)
                    pendingTimer._trigger = t
                    pendingTimer._replacement = r
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

return M
