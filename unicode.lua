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
    [";8"]   = "∞",   -- infinity
    [";o"]   = "°",   -- degree
    [";m"]   = "μ",   -- mu
    [";v"]   = "√",   -- square root
    [";x"]   = "×",   -- multiplication
    [";/"]   = "÷",   -- division

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

    local function doReplace(trigger, replacement)
        buffer = ""
        -- Delete the trigger characters
        for i = 1, #trigger do
            hs.eventtap.keyStroke({}, "delete", 0)
        end
        -- Type the replacement
        hs.eventtap.keyStrokes(replacement)
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
        if pendingTimer then pendingTimer:stop(); pendingTimer = nil end

        -- Check if buffer ends with any trigger
        for trigger, replacement in pairs(shortcuts) do
            if buffer:sub(-#trigger) == trigger then
                if prefixes[trigger] then
                    -- This trigger is a prefix of a longer one; wait briefly
                    local t = trigger
                    local r = replacement
                    pendingTimer = hs.timer.doAfter(0.3, function()
                        if M.debug then
                            print("[unicode] firing delayed: " .. t .. " -> " .. r)
                        end
                        doReplace(t, r)
                        pendingTimer = nil
                    end)
                    return false
                else
                    -- No ambiguity, fire immediately
                    if M.debug then
                        print("[unicode] firing: " .. trigger .. " -> " .. replacement)
                    end
                    doReplace(trigger, replacement)
                    return true
                end
            end
        end

        return false
    end)
    watcher:start()
    M.watcher = watcher
    print("Unicode expander loaded (" .. maxLen .. " max trigger, " ..
          tostring(#prefixes) .. " prefix triggers)")
end

return M
