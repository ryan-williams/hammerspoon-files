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

function bind(mods, key, fn)
  k:bind(mods, key,
          frame(fn)
  )
end

function resizeBindings(base, size, k, sk, S)
  -- For the "base" (left or top) edge:
  -- - default: extend
  -- - shift: contract
  -- - ctrl: extend to edge
  bind(
          '', base,
          function(f, s)
            local cur = f[k]
            f[k] = max(s[k], f[k] - s[sk] / S)
            local increase = cur - f[k]
            f[sk] = f[sk] + increase
          end
  )
  bind(
          'shift', base,
          function(f, s)
            local cur = f[k]
            f[k] = min(s[k] + s[sk], f[k] + s[sk] / S)
            local decrease = f[k] - cur
            f[sk] = f[sk] - decrease
          end
  )
  bind(
          'ctrl', base,
          function(f, s)
            local cur = f[k]
            f[k] = s[k]
            local increase = cur - f[k]
            f[sk] = f[sk] + increase
          end
  )

  -- Same three bindings, but for the "far" edge (right or bottom)
  bind(
          '', size,
          function(f, s)
            local pos = f[k] - s[k]
            f[sk] = min(s[sk] - pos, f[sk] + s[sk] / S)
          end
  )
  bind(
          'shift', size,
          function(f, s)
            f[sk] = max(0, f[sk] - s[sk] / S)
          end
  )
  bind(
          'ctrl', size,
          function(f, s)
            local x = f[k] - s[k]
            f[sk] = s[sk] - x
          end
  )

  -- cmd: "nudge" in the "base" direction
  -- cmd+ctrl: move all the way to "base" edge
  bind(
          "cmd", base,
          function(f, s)
            f[k] = max(s[k], f[k] - s[sk] / S)
          end
  )
  bind(
          {"cmd", "ctrl"}, base,
          function(f, s)
            f[k] = s[k]
          end
  )

  -- Same two "move" bindings, but toward the "far" edge
  bind(
          "cmd", size,
          function(f, s)
            f[k] = min(s[sk] - f[sk] + s[k], f[k] + s[sk] / S)
          end
  )
  bind(
          {"cmd", "ctrl"}, size,
          function(f, s)
            f[k] = s[sk] - f[sk] + s[k]
          end
  )
end

resizeBindings('h', 'l', 'x', 'w', M)
resizeBindings('k', 'j', 'y', 'h', N)

hs.alert.show("Config loaded")
