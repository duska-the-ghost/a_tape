-- scriptname: a_tape
-- control two W/ (wtape) via crow + monome grid, using flora/lib/w_slash params
--  - 1=W1, 2=W2, 3=broadcast
--  - transport: play(-1|0|1) with two buttons (y=6,x=1 play; y=6,x=2 reverse)
--  - loop button (y=5,x=1): start -> end -> loop_next(0) ... ; HOLD 2s => loop_active(0)
--  - y=1 (W1) & y=2 (W2) loop position bars always visible
--  - rest of grid reflects active module; broadcast view shows both (dual brightness)

local cs       = require "controlspec"
local actions  = include("lib/a_tape_actions")
local ui       = include("lib/a_tape_ui")
local w_slash  = include("flora/lib/w_slash")

ATAPE = ATAPE or {}
g = nil

-- --------- i2c / crow helpers (NO edits to w_slash.lua) ----------
local function crow_ready()
  return crow and crow.ii and crow.ii.wtape
end



-- broadcast-aware: call ii.wtape[addr].<fn>(...) for each addr
local function ii_call(addrs, fn, ...)
  if not crow_ready() then return end
  local args = { ... }
  for _, addr in ipairs(addrs) do
    pcall(function()
      local dev = crow.ii.wtape[addr]
      if dev and dev[fn] then dev[fn](table.unpack(args)) end
    end)
  end
end




-- --------- Target selection: 1=W1, 2=W2, 3=broadcast ----------
-- Internally we keep toggles for W1/W2; view rule:
--  * if both ON or both OFF => broadcast (3)
--  * else whichever is ON is the active module (1 or 2)
-- Active mode derived from UI’s toggles.
function ATAPE.get_active_mode()
  local t = ui.get_tgt()
  local mode -- intended to prevent unintended side-effects from a stray global
  if t.w1_on and t.w2_on then mode = 3
  elseif t.w1_on then mode = 1
  elseif t.w2_on then mode = 2
  else mode = 1 end -- fallback to W1

  print(string.format("[atape] mode=%d (w1=%s w2=%s)", mode, tostring(t.w1_on), tostring(t.w2_on)))
  return mode
end

-- --------- param registration (from flora/lib/w_slash) ----------
local function add_params()
  params:add_separator("W/ (wtape) via w_slash")
  if w_slash and w_slash.wtape_add_params then
    w_slash.wtape_add_params()
  else
    print("w_slash.wtape_add_params not found")
  end

  -- UI mirrors (let encoders/ladder write nicer names but forward to w_slash params)
  params:add_control("wtape_speed_ui","Speed (UI)", cs.new(0.25, 2.0, "lin", 0, 1.0))
  params:set_action("wtape_speed_ui", function(v) params:set("wtape_speed", v) end)

  params:add_control("wtape_freq_ui","Freq (v/8, UI)", cs.new(-5, 5, "lin", 0, 0))
  params:set_action("wtape_freq_ui", function(v) params:set("wtape_freq", v) end)

  params:add_control("wtape_erase_ui","Erase Strength (UI)", cs.new(0, 1, "lin", 0, 0.5))
  params:set_action("wtape_erase_ui", function(v) params:set("wtape_erase_strength", v) end)

  params:add_control("wtape_monitor_ui","Monitor Level (UI)", cs.new(0, 1, "lin", 0, 0.5))
  params:set_action("wtape_monitor_ui", function(v) params:set("wtape_monitor_level", v) end)

  params:add_control("wtape_rec_level_ui","Record Level (UI)", cs.new(0, 1, "lin", 0, 0.5))
  params:set_action("wtape_rec_level_ui", function(v) params:set("wtape_rec_level", v) end)

  -- Echo Mode param exists in w_slash; we keep it and let grid toggle it
  -- id: "wtape_echo_mode" (options {"off","on"})
end

-- Attach helpers to ATAPE without overwriting the table
function ATAPE.addresses_for_mode(mode)
  if mode == 1 then return {1}
  elseif mode == 2 then return {2}
  else return {1,2} end
end
ATAPE.ii_call = ii_call

-- default target toggles and visual state (prevent nil in UI at boot)
local _boot_tgt = { w1_on=true, w2_on=false }
local _boot_state = {
  [1] = { play=0, loop_active=0, loop_started=false, loop_has_end=false, loop_start_pos=0, loop_end_pos=0, timestamp=0, speed=1.0 },
  [2] = { play=0, loop_active=0, loop_started=false, loop_has_end=false, loop_start_pos=0, loop_end_pos=0, timestamp=0, speed=1.0 },
}

-- --------- lifecycle ----------
function init()
  print("a_tape: init")
  g = grid and grid.connect()
  if g then
    print("grid connected")
    g.key = function(x,y,z) actions.grid_key(x,y,z) end
  else
    print("no grid")
  end

  pcall(function() if crow and crow.ii and crow.ii.pullup then crow.ii.pullup(true) end end)

  add_params()
  
  -- API confirmation
  clock.run(function()
  clock.sleep(0.5)
  U.dump_wtape_api()
end)

  -- seed the UI so redraw has sane values immediately
  ui.set_states(_boot_state, _boot_tgt)

  actions.init(ui)
  ui.init(g)
  ui.request_redraw() -- ensure first grid frame paints immediately
end


function key(n,z) actions.key(n,z) end
function enc(n,d) actions.enc(n,d) end
function redraw() ui.redraw() end
function cleanup() end

