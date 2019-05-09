hs.hotkey.bind({"alt"}, "d", function() hs.reload() end)

hs.hotkey.bind({"alt"}, "h", function() hs.hints.windowHints() end)
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

k = hs.hotkey.modal.new('alt', 'a')
function k:entered() hs.alert'Resize mode' end
function k:exited() hs.alert'Exited resize mode' end
k:bind('alt', 'a', function() k:exit() end)
k:bind('', 'escape', function() k:exit() end)
k:bind('', 'J', 'Pressed J',function() print'let the record show that J was pressed' end)

max = math.max
min = math.min

function bind(mods, keys, fn)
  for i,key in ipairs(keys) do
    print("Binding "..((type(mods)=='table') and table.concat(mods, ',') or mods)..' '..key)
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

hs.alert.show("Config loaded")
