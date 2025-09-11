hs.application.enableSpotlightForNameSearches(true)

hs.hotkey.bind({"alt"}, "d", function() hs.reload() end)

hs.hotkey.bind({"alt","shift"}, "h", function() hs.hints.windowHints() end)

hs.hotkey.bind({"alt","cmd"}, "h", function() hs.toggleConsole() end)
hs.hints.style = "vimperator"

function frame(fn)
  return function()
    local win = hs.window.focusedWindow()
    local f = win:frame()
    local screen = win:screen()
    local s = screen:frame()
    fn(f, s)
    win:setFrame(f)
  end
end

for i = 1,9 do
  -- Skip alt-1 (reserved for 1Password), but keep other alt-1 combinations
  if i ~= 1 then
    hs.hotkey.bind(
        { "alt" }, tostring(i),
        frame(
            function(f, s)
              f.x = s.x + s.w * (10 - i) / 10
              f.w = s.w * i / 10
              f.y = s.y
              f.h = s.h
            end
        )
    )
  end

  hs.hotkey.bind(
      { "alt", "shift" }, tostring(i),
      frame(
          function(f, s)
            f.x = s.x
            f.w = s.w * i / 10
            f.y = s.y
            f.h = s.h
          end
      )
  )
  hs.hotkey.bind(
      { "alt", "ctrl" }, tostring(i),
      frame(
          function(f, s)
            f.x = s.x
            f.w = s.w
            f.y = s.y
            f.h = s.h * i / 10
          end
      )
  )
  hs.hotkey.bind(
      { "alt", "ctrl", "shift" }, tostring(i),
      frame(
          function(f, s)
            f.x = s.x
            f.w = s.w
            f.y = s.y + s.h * (10 - i) / 10
            f.h = s.h * i / 10
          end
      )
  )
end

hs.hotkey.bind(
    {'alt'}, '0',
    frame(
        function(f, s)
          f.x = s.x
          f.w = s.w
          f.y = s.y
          f.h = s.h
        end
    )
)

M = 10
N = 10

-- Create canvases for on-screen indicators (one per monitor)
local resizeModeIndicators = {}

k = hs.hotkey.modal.new('alt', 'a')
function k:entered()
  hs.alert 'Resize mode'

  -- Show indicator on all screens
  local allScreens = hs.screen.allScreens()
  for i, screen in ipairs(allScreens) do
    local screenFrame = screen:frame()
    local indicator = hs.canvas.new({
      x = screenFrame.x + screenFrame.w - 200,
      y = screenFrame.y + 30,
      w = 180,
      h = 40
    })
    indicator:appendElements({
      type = "rectangle",
      fillColor = { red = 0.2, green = 0.2, blue = 0.2, alpha = 0.9 },
      roundedRectRadii = { xRadius = 10, yRadius = 10 }
    }, {
      type = "text",
      text = "🔧 WINDOW MGMT MODE",
      textAlignment = "center",
      textColor = { white = 1 },
      textSize = 16,
      frame = { x = 0, y = 10, w = 180, h = 20 }
    })
    indicator:show()
    resizeModeIndicators[i] = indicator
  end
end

function k:exited()
  hs.alert 'Exited resize mode'

  -- Hide all on-screen indicators
  for _, indicator in ipairs(resizeModeIndicators) do
    indicator:delete()
  end
  resizeModeIndicators = {}
end
k:bind('alt', 'a', function() k:exit() end)
k:bind('', 'escape', function() k:exit() end)
k:bind('', 'J', 'Pressed J',function() print 'let the record show that J was pressed' end)

max = math.max
min = math.min

function bind(mods, keys, fn)
  for i,key in ipairs(keys) do
    k:bind(mods, key, frame(fn))
  end
end

function resizeBindings(base, far, k, sk, S)

  function extendBase(f, s)
    local cur = f[k]
    f[k] = max(s[k], f[k] - s[sk] / S)
    local increase = cur - f[k]
    f[sk] = f[sk] + increase
  end

  function shrinkBase(f, s)
    local cur = f[k]
    f[k] = min(s[k] + s[sk], f[k] + s[sk] / S)
    local decrease = f[k] - cur
    f[sk] = f[sk] - decrease
  end

  function throwBase(f, s)
    local cur = f[k]
    f[k] = s[k]
    local increase = cur - f[k]
    f[sk] = f[sk] + increase
  end

  function extendFar(f, s) f[sk] = min(s[sk] - (f[k] - s[k]), f[sk] + s[sk] / S) end
  function shrinkFar(f, s) f[sk] = max(0, f[sk] - s[sk] / S) end
  function throwFar(f, s) f[sk] = s[sk] - (f[k] - s[k]) end

  function nudgeBase(f, s) f[k] = max(s[k], f[k] - s[sk] / S) end
  function flushBase(f, s) f[k] = s[k] end

  function nudgeFar(f, s) f[k] = min(s[sk] - f[sk] + s[k], f[k] + s[sk] / S) end
  function flushFar(f, s) f[k] = s[sk] - f[sk] + s[k] end

  -- For the "base" (left or top) edge:
  -- - default: extend
  -- - shift: contract
  -- - ctrl: extend to edge
  bind('', base, extendBase)
  bind('shift', base, shrinkBase)
  bind('ctrl', base, throwBase)

  -- Same three bindings, but for the "far" edge (right or bottom)
  bind('', far, extendFar)
  bind('shift', far, shrinkFar)
  bind('ctrl', far, throwFar)

  -- cmd: "nudge" in the "base" direction
  -- cmd+ctrl: move all the way to "base" edge
  bind("cmd", base, nudgeBase)
  bind({"cmd", "ctrl"}, base, flushBase)

  -- Same two "move" bindings, but toward the "far" edge
  bind("cmd", far, nudgeFar)
  bind({"cmd", "ctrl"}, far, flushFar)
end

resizeBindings({ 'h', 'left' }, { 'l', 'right' }, 'x', 'w', M)
resizeBindings({ 'k',   'up' }, { 'j',  'down' }, 'y', 'h', N)

-- Helper function to check if screen is laptop/small
local function isSmallScreen(screen)
  local name = screen:name():lower()
  return name:find("color lcd") or name:find("built%-in retina display")
end

-- Helper function to determine default window sizing for a screen and app
local function getDefaultSizing(screen, win)
  local app = win:application()
  if not app then return { x = 0, y = 0, w = 1, h = 1 } end

  local appName = app:name()
  local isSmall = isSmallScreen(screen)

  -- Define app-specific sizing preferences
  local appSizing = {
    -- Apps that should always be fullscreen
    ["iTerm2"] = { small = { x = 0, y = 0, w = 1, h = 1 }, big = { x = 0, y = 0, w = 1, h = 1 } },
    ["Signal"] = { small = { x = 0, y = 0, w = 1, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
    ["WhatsApp"] = { small = { x = 0, y = 0, w = 1, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },

    -- Apps that go half-screen on big monitors
    ["Google Chrome"] = { small = { x = 0, y = 0, w = 1, h = 1 }, big = { x = 0, y = 0, w = 0.5, h = 1 } },
    ["IntelliJ IDEA"] = { small = { x = 0.1, y = 0, w = 0.9, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
    ["Code"] = { small = { x = 0.1, y = 0, w = 0.9, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
    ["Slack"] = { small = { x = 0.1, y = 0, w = 0.9, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
    ["Safari"] = { small = { x = 0.1, y = 0, w = 0.9, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
    ["Calendar"] = { small = { x = 0.1, y = 0, w = 0.9, h = 1 }, big = { x = 0.5, y = 0, w = 0.5, h = 1 } },
  }

  local sizing = appSizing[appName]
  if sizing then
    return isSmall and sizing.small or sizing.big
  end

  -- Default sizing for unknown apps
  if isSmall then
    return { x = 0.1, y = 0, w = 0.9, h = 1 }  -- Almost full on laptop
  else
    return { x = 0.5, y = 0, w = 0.5, h = 1 }  -- Right half on big screen
  end
end

-- Show monitor information (bind to 'd' for "display" in window mode)
k:bind('', 'd', function()
  local screens = hs.screen.allScreens()
  local info = "=== Monitor Information ===\n"
  local namesOnly = {}
  for i, screen in ipairs(screens) do
    local name = screen:name()
    local frame = screen:frame()
    local isSmall = isSmallScreen(screen)
    info = info .. string.format("%d. %s\n   Size: %dx%d\n   Type: %s\n",
      i, name, frame.w, frame.h, isSmall and "Small/Laptop" or "Big/External")
    table.insert(namesOnly, name)
  end

  -- Copy monitor names to clipboard
  local namesList = table.concat(namesOnly, "\n")
  hs.pasteboard.setContents(namesList)

  hs.alert(info .. "\n📋 Names copied to clipboard!", 5)  -- Show for 5 seconds
  print(info)  -- Also print to console
  print("Copied to clipboard:\n" .. namesList)
end)

-- Throw window to other monitor with default sizing
k:bind('', 't', function()
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert("No focused window")
    return
  end

  local currentScreen = win:screen()
  local allScreens = hs.screen.allScreens()

  if #allScreens <= 1 then
    hs.alert("Only one screen available")
    return
  end

  -- Find current screen index
  local currentIndex = nil
  for i, screen in ipairs(allScreens) do
    if screen == currentScreen then
      currentIndex = i
      break
    end
  end

  -- Calculate next screen index (cycle)
  local nextIndex = currentIndex % #allScreens + 1
  local targetScreen = allScreens[nextIndex]

  -- Move window to target screen
  win:moveToScreen(targetScreen)

  -- Apply default sizing for this app and screen
  local targetFrame = targetScreen:frame()
  local sizing = getDefaultSizing(targetScreen, win)
  win:setFrame({
    x = targetFrame.x + targetFrame.w * sizing.x,
    y = targetFrame.y + targetFrame.h * sizing.y,
    w = targetFrame.w * sizing.w,
    h = targetFrame.h * sizing.h
  })
end)

-- Open Hammerspoon console (bind to 'c' for "console")
k:bind('', 'c', function()
  hs.toggleConsole()
end)

-- Apply laptop-only layout (bind to 'o' for "only laptop")
k:bind('', 'o', function()
  local laptop = findscreen('Color LCD') or findscreen('Built-in Retina Display')
  if laptop == nil then
    hs.alert("Laptop screen not found")
    return nil
  end
  layout(laptopOnly(laptop))
end)

-- Apply multi-monitor layout (same as cmd-ctrl-m)
k:bind('', 'm', function()
  local laptop = findscreen({'Color LCD', 'Built%-in Retina Display'})
  -- Updated to catch more monitor variations
  local external = findscreen({'LG', 'DELL U3415W', 'DELL U2715H', 'SB220Q'})

  if laptop == nil or external == nil then
    -- Show detailed debug info when screens aren't found
    local screens = hs.screen.allScreens()
    local screenList = ""
    for _, s in ipairs(screens) do
      screenList = screenList .. "\n  - " .. s:name()
    end
    hs.alert('Missing screen!\nLaptop: '..(laptop and laptop:name() or 'NOT FOUND')..
            '\nExternal: '..(external and external:name() or 'NOT FOUND')..
            '\n\nAvailable screens:' .. screenList, 5)
    return nil
  end

  layout(bigsmall(external, laptop))
end)

-- Throw window to other monitor - left half
k:bind('shift', 't', function()
  local win = hs.window.focusedWindow()
  if not win then
    hs.alert("No focused window")
    return
  end

  local currentScreen = win:screen()
  local allScreens = hs.screen.allScreens()

  if #allScreens <= 1 then
    hs.alert("Only one screen available")
    return
  end

  -- Find current screen index
  local currentIndex = nil
  for i, screen in ipairs(allScreens) do
    if screen == currentScreen then
      currentIndex = i
      break
    end
  end

  -- Calculate next screen index (cycle)
  local nextIndex = currentIndex % #allScreens + 1
  local targetScreen = allScreens[nextIndex]

  -- Move window to target screen
  win:moveToScreen(targetScreen)

  -- Apply left half sizing
  local targetFrame = targetScreen:frame()
  win:setFrame({
    x = targetFrame.x,
    y = targetFrame.y,
    w = targetFrame.w * 0.5,
    h = targetFrame.h
  })
end)

-- Number keys for vertical height control in resize mode
for i = 1, 9 do
  -- Regular number keys: pin to top, adjust height
  k:bind('', tostring(i), function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local screenFrame = screen:frame()
    local f = win:frame()

    f.y = screenFrame.y
    f.h = screenFrame.h * i / 10
    win:setFrame(f)
  end)

  -- Shift+number keys: pin to bottom, adjust height
  k:bind('shift', tostring(i), function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local screenFrame = screen:frame()
    local f = win:frame()

    f.h = screenFrame.h * i / 10
    f.y = screenFrame.y + screenFrame.h - f.h
    win:setFrame(f)
  end)

  -- Ctrl+number keys: pin to left, adjust width
  k:bind('ctrl', tostring(i), function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local screenFrame = screen:frame()
    local f = win:frame()

    f.x = screenFrame.x
    f.w = screenFrame.w * i / 10
    win:setFrame(f)
  end)

  -- Ctrl+Shift+number keys: pin to right, adjust width
  k:bind({'ctrl', 'shift'}, tostring(i), function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local screen = win:screen()
    local screenFrame = screen:frame()
    local f = win:frame()

    f.w = screenFrame.w * i / 10
    f.x = screenFrame.x + screenFrame.w - f.w
    win:setFrame(f)
  end)
end

-- 0 key for full height
k:bind('', '0', function()
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen()
  local screenFrame = screen:frame()
  local f = win:frame()

  f.y = screenFrame.y
  f.h = screenFrame.h
  win:setFrame(f)
end)

k:bind('shift', '0', function()
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen()
  local screenFrame = screen:frame()
  local f = win:frame()

  f.y = screenFrame.y
  f.h = screenFrame.h
  win:setFrame(f)
end)

-- Ctrl+0 for full width
k:bind('ctrl', '0', function()
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen()
  local screenFrame = screen:frame()
  local f = win:frame()

  f.x = screenFrame.x
  f.w = screenFrame.w
  win:setFrame(f)
end)

k:bind({'ctrl', 'shift'}, '0', function()
  local win = hs.window.focusedWindow()
  if not win then return end
  local screen = win:screen()
  local screenFrame = screen:frame()
  local f = win:frame()

  f.x = screenFrame.x
  f.w = screenFrame.w
  win:setFrame(f)
end)

function map(tbl, f)
  local t = {}
  for k,v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

function mapToArr(tbl, f)
  local t = {}
  local i = 1
  for k,v in pairs(tbl) do
    t[i] = f(k, v)
    i = i + 1
  end
  return t
end

function reduce(tbl, f)
  local t = nil
  for k,v in pairs(tbl) do
    if t == nil then
      t = v
    else
      t = f(t, v)
    end
  end
  return t
end

function foldLeft(tbl, z, f)
  local t = z
  for k,v in pairs(tbl) do
    t = f(t, v)
  end
  return t
end

function str(o)
  if type(o) == 'table' then
    return '{ '..table.concat(mapToArr(o, function(k, v) return k..': '..str(v) end), ', ')..' }'
  else
    return tostring(o)
  end
end

function bigsmall(big, sml)
  return {
  [   "Google Chrome" ] = { screen = big, shape = { x=0  , y=0, w=0.5, h=1 } },
  [          "iTerm2" ] = { screen = big, shape = { x=0  , y=0, w=1  , h=1 } },
  [   "IntelliJ IDEA" ] = { screen = big, shape = { x=0.5, y=0, w=0.5, h=1 } },
  [            "Code" ] = { screen = big, shape = { x=0.5, y=0, w=0.5, h=1 } },
  [           "Slack" ] = { screen = big, shape = { x=0.5, y=0, w=0.5, h=1 } },
  [          "Safari" ] = { screen = big, shape = { x=0.5, y=0, w=0.5, h=1 } },
  [          "Signal" ] = { screen = sml, shape = { x=0  , y=0, w=1  , h=1 } },
  [        "WhatsApp" ] = { screen = sml, shape = { x=0  , y=0, w=1  , h=1 } },
}
end

function laptopOnly(laptop)
  local right = { x=0.1, y=0, w=0.9, h=1 }
  local  full = { x=0  , y=0, w=1  , h=1 }
  return {
    [   "Google Chrome" ] = { screen = laptop, shape = right },
    [          "iTerm2" ] = { screen = laptop, shape =  full },
    [   "IntelliJ IDEA" ] = { screen = laptop, shape = right },
    [            "Code" ] = { screen = laptop, shape = right },
    [           "Slack" ] = { screen = laptop, shape = right },
    [          "Safari" ] = { screen = laptop, shape = right },
    [          "Signal" ] = { screen = laptop, shape =  full },
    [        "WhatsApp" ] = { screen = laptop, shape =  full },
  }
end

function layout(map)
  -- Filter out applications that aren't currently running
  local layoutTable = {}
  for appName, config in pairs(map) do
    local app = hs.application.find(appName)
    if app then
      table.insert(layoutTable, { appName, nil, config.screen, config.shape, nil, nil })
    end
  end

  if #layoutTable > 0 then
    hs.layout.apply(layoutTable)
  else
    hs.alert("No applications to layout")
  end
end

function screenstrs()
  local screens = hs.screen.allScreens()
  local names = map(screens, function(s) return s:name() end)
  print("screens: "..str(names))
  return table.concat(names, ',')
end

function msg(m)
  print(m)
  hs.alert(m)
end

function findscreen(...)
  if type(...) == 'string' then
    local screen = hs.screen.find(...)
    if screen ~= nil then
      return screen
    end
  elseif type(...) == 'array' then
    for s in ... do
      local screen = hs.screen.find(name)
      if screen ~= nil then
        return screen
      end
    end
  else
    for _, name in pairs(...) do
      print('\tchecking name: '..name)
      local screen = hs.screen.find(name:lower())
      if screen ~= nil then
        print('\t\tfound screen: '..name)
        return screen
      end
    end
  end
  msg("Couldn't find screens: "..str(...).." ("..type(...).."; available: "..screenstrs()..")")
end

hs.hotkey.bind(
    { 'cmd', 'ctrl' }, 'm',
    function()
      local laptop = findscreen({'Color LCD', 'Built%-in Retina Display'})
      -- Updated to catch more monitor variations
      local external = findscreen({'LG', 'DELL U3415W', 'DELL U2715H', 'SB220Q'})

      if laptop == nil or external == nil then
        -- Show detailed debug info when screens aren't found
        local screens = hs.screen.allScreens()
        local screenList = ""
        for _, s in ipairs(screens) do
          screenList = screenList .. "\n  - " .. s:name()
        end
        hs.alert('Missing screen!\nLaptop: '..(laptop and laptop:name() or 'NOT FOUND')..
                '\nExternal: '..(external and external:name() or 'NOT FOUND')..
                '\n\nAvailable screens:' .. screenList, 5)
        return nil
      end

      layout(bigsmall(external, laptop))
    end
)

hs.hotkey.bind(
    { 'cmd', 'ctrl' }, 'o',
    function()
      local laptop = findscreen('Color LCD') or findscreen('Built-in Retina Display')
      if laptop == nil then return nil end
      layout(laptopOnly(laptop))
    end
)

function focusApp(name)
  local app = hs.application.find(name)
  if app == nil then
    -- App not running, open it
    hs.alert('Opening '..name)
    hs.application.open(name, 0, true)
    return
  end

  -- Try to get a window to focus
  local windows = app:allWindows()
  if #windows > 0 then
    -- Has windows, focus the first one
    windows[1]:focus()
    return
  end

  -- App is running but has no windows
  -- For 1Password and similar apps, just re-open them
  if name == "1Password" then
    -- 1Password is a menu bar app, re-opening it should show the window
    hs.application.open(name)
  else
    -- For other apps, try activate first
    app:activate()
    -- If still no windows after a brief delay, try opening
    hs.timer.doAfter(0.5, function()
      if #app:allWindows() == 0 then
        hs.application.open(name)
      end
    end)
  end
end

function bindFocusApp(name, modifiers, hotkey)
  hs.hotkey.bind(modifiers, hotkey, function() focusApp(name) end)
end

appShortcuts = {
  [       "Activity Monitor" ] = { modifiers = { 'alt', 'cmd'   }, key = 'a' },
  [          "Google Chrome" ] = { modifiers = { 'alt', 'cmd'   }, key = 'c' },
  [                 "Safari" ] = { modifiers = { 'alt', 'cmd'   }, key = 's' },
  [                  "iTerm" ] = { modifiers =   'alt'           , key = 't' },
  [                  "Slack" ] = { modifiers =   'alt'           , key = 'k' },
  [                 "Signal" ] = { modifiers =   'alt'           , key = 'n' },
  [              "1Password" ] = { modifiers =   'alt'           , key = '1' },
  [          "Final Cut Pro" ] = { modifiers =   'alt'           , key = 'p' },
  [       "Quicktime Player" ] = { modifiers =   'alt'           , key = 'q' },
  [     "System Preferences" ] = { modifiers =   'alt'           , key = 's' },
  [                "Preview" ] = { modifiers =   'alt'           , key = 'v' },
  [               "WhatsApp" ] = { modifiers =   'alt'           , key = 'w' },
  [                "zoom.us" ] = { modifiers =   'alt'           , key = 'z' },
}

-- Handle Finder specially; open a new window if none exist
hs.hotkey.bind({ 'cmd', 'alt' }, 'f',
    function()
      local finder = hs.application.find('Finder')
      local window = finder:focusedWindow()
      if window == nil then
        print 'applescript…'
        hs.applescript([[
tell application "System Events"
  tell process "Finder"
    set frontmost to true
    click menu item "New Finder Window" of menu "File" of menu bar 1
  end tell
end tell
        ]])
      else
        window:focus()
      end
    end
)

mapToArr(
    appShortcuts,
    function(name, key)
      bindFocusApp(name, key.modifiers, key.key)
    end
)

function listAllWindows()
  local windows = hs.window.allWindows()
  print("=== All Windows ===")
  for i, win in ipairs(windows) do
    local app = win:application()
    local title = win:title() or "No Title"
    local bundleID = app:bundleID() or "No Bundle ID"
    local pid = app:pid()

    print(string.format("%d. App: %s (PID: %d)", i, app:name(), pid))
    print(string.format("   Bundle ID: %s", bundleID))
    print(string.format("   Window: %s", title))
    print(string.format("   Visible: %s", win:isVisible()))
    print("---")
  end
end

-- Bind to a hotkey for easy access
hs.hotkey.bind({'alt'}, 'y', listAllWindows)

function focusIntelliJ(isRemote)
  local apps = hs.application.applicationsForBundleID("com.jetbrains.intellij")

  for _, app in ipairs(apps) do
    local windows = app:allWindows()
    for _, win in ipairs(windows) do
      local title = win:title() or ""
      local hasHomePath = string.find(title, "/home/") ~= nil

      if isRemote == hasHomePath then
        win:focus()
        return
      end
    end
  end

  -- If no IntelliJ found, open it
  if not isRemote then
    hs.alert("Opening IntelliJ IDEA")
    hs.application.open("IntelliJ IDEA", 0, true)
  else
    hs.alert("IntelliJ Remote not found")
  end
end

-- Debug function to inspect IntelliJ windows
function debugIntelliJWindows()
  local apps = hs.application.applicationsForBundleID("com.jetbrains.intellij")
  print("=== IntelliJ Debug Info ===")

  for _, app in ipairs(apps) do
    local windows = app:allWindows()
    print("App PID: " .. app:pid())
    for i, win in ipairs(windows) do
      local title = win:title() or "(no title)"
      local hasHomePath = string.find(title, "/home/") ~= nil
      print(string.format("  Window %d: '%s'", i, title))
      print(string.format("    Has /home/: %s", hasHomePath))
      print("    ---")
    end
  end
end

hs.hotkey.bind({'alt'}, 'u', debugIntelliJWindows) -- Debug hotkey

hs.hotkey.bind({'alt'}, 'i', function() focusIntelliJ(false) end) -- Local
hs.hotkey.bind({'alt', 'shift'}, 'i', function() focusIntelliJ(true) end) -- Remote

hs.alert.show("Config loaded: "..hs.screen.mainScreen():name())
