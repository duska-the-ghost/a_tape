-- lib/a_tape_ui.lua
-- Always show y=1 (W1 loop) and y=2 (W2 loop). Rest reflects active module.
-- In broadcast view, show dual brightness when W1/W2 differ.

local ui = {}
local util = require "util" -- needed for util.clamp used below
-- --- debug helpers ---------------------------------------------------
local DEBUG_UI = true
local function dprint(...)
  if DEBUG_UI then print("[ui]", ...) end
end

local g

-- cache from actions
local state -- per-module table
local tgt   = { w1_on = true, w2_on = false } -- default focus on W1
local freq_x = 11
ui._dirty = true

-- v/8 ladder slots (x -> value) for y=6
local _freq_slots = {
  [6]=-0.50,[7]=-0.40,[8]=-0.30,[9]=-0.20,[10]=-0.10,
  [11]=0.00,[12]=0.10,[13]=0.20,[14]=0.30,[15]=0.40,[16]=0.50,
}

local function _nearest_freq_slot(v8)
  if type(v8) == "table" then v8 = v8.speed end
  v8 = tonumber(v8) or 0
  local best_x, best_d
  for x,val in pairs(_freq_slots) do
    local d = math.abs((v8 or 0) - val)
    if not best_d or d < best_d then
      best_d, best_x = d, x
    end
  end
  return best_x or 11
end

function ui.get_tgt()
  dprint(string.format("get_tgt -> w1=%s w2=%s",
    tostring(tgt and tgt.w1_on), tostring(tgt and tgt.w2_on)))
  return tgt
end
function ui.get_state() return state end
function ui.set_freq_selection(x)
  freq_x = x
  dprint("set_freq_selection x=", x)
  ui._dirty = true
end
function ui.request_redraw()
  dprint("request_redraw")
  ui._dirty = true
end
function ui.set_states(_state, _tgt)
  local changed = false

  -- update state table if provided
  if _state ~= nil then
    if state ~= _state then
      state = _state
      changed = true
    end
  end

  -- update target toggles if provided
  if _tgt ~= nil then
    local w1_new = _tgt.w1_on and true or false
    local w2_new = _tgt.w2_on and true or false
    local w1_old = tgt and tgt.w1_on or false
    local w2_old = tgt and tgt.w2_on or false
    if (w1_new ~= w1_old) or (w2_new ~= w2_old) then
      tgt = { w1_on = w1_new, w2_on = w2_new }
      changed = true
      -- optional debug:
      print(string.format("[ui]\tset_states: tgt w1=%s w2=%s", tostring(w1_new), tostring(w2_new)))
    end
  end


  if changed then
    -- (optional) print once:
    print("[ui]\tset_states: state updated")
    ui._dirty = true
  end
end


-- (Active mode is owned by a_tape.lua via ATAPE.get_active_mode())

-- draw 16-step loop bar with a moving playhead (best-effort)
local function draw_loop_row(y, s)
  s = s or {}
  local start = tonumber(s.loop_start) or 0
  local endp  = tonumber(s.loop_end)
  -- If no end yet, show a “cursor” only
  local pos_s = tonumber(s.timestamp) or start
  local lvl_bar = (s.loop_active==1) and 8 or 3
  for x=1,16 do g:led(x,y,lvl_bar) end
  if not endp then
    -- no loop window yet: just show current position cursor
    local x = 1 + (math.floor((pos_s*10)) % 16)
    g:led(x, y, 15)
    return
  end
  local len = math.max(0.0001, math.abs(endp - start))
  -- normalize pos to [0,1) within loop window, wrap both directions
  local rel = (pos_s - start) / len
  rel = rel - math.floor(rel)
  local x = 1 + math.min(15, math.floor(rel * 16))
  g:led(x, y, 15)
end

local function ladder_dual(y, getter, set_led)
  local v1 = getter(1) or 0
  local v2 = getter(2) or 0
  local x1 = 6 + math.floor(v1*10+0.5)
  local x2 = 6 + math.floor(v2*10+0.5)
  for x=6,16 do g:led(x,y,5) end
  g:led(util.clamp(x1,6,16), y, 12) -- W1
  g:led(util.clamp(x2,6,16), y, 15) -- W2
end

local function ladder_single(y, v)
  local x = 6 + math.floor(v*10+0.5)
  for i=6,16 do g:led(i,y,5) end
  g:led(util.clamp(x,6,16), y, 15)
end

function ui.redraw()
  if not ui._dirty then return end
  dprint("redraw start")

  -- SCREEN HEADER
  screen.clear()
  screen.level(15); screen.move(10,12); screen.text("a_tape")

  local mode = (ATAPE and ATAPE.get_active_mode and ATAPE.get_active_mode()) or 1
  local mode_txt = (mode==1 and "W1") or (mode==2 and "W2") or "both"

  local s1_speed = (state and state[1] and state[1].speed) or 0.0
  local s2_speed = (state and state[2] and state[2].speed) or 0.0
  local erase = params:get("wtape_erase_strength") or 0.5
  dprint(string.format("mode=%d(%s) s1=%.2f s2=%.2f erase=%.2f", mode, mode_txt, s1_speed, s2_speed, erase))

  screen.level(5); screen.move(10,26); screen.text("Target: "..mode_txt)
  screen.level(3); screen.move(10,38)
  if mode == 1 then
    screen.text(string.format("Freq (v/8) %.2f   Erase %.2f", s1_speed, erase))
  elseif mode == 2 then
    screen.text(string.format("Freq (v/8) %.2f   Erase %.2f", s2_speed, erase))
  else
    screen.text(string.format("Freq W1 %.2f | W2 %.2f   Erase %.2f", s1_speed, s2_speed, erase))
  end
  screen.update()

  if not g then
    dprint("no grid; redraw done (screen only)")
    ui._dirty = false
    return
  end

  g:all(0)

  -- y=1/2 loop bars (nil-safe)
  local s1 = (state and state[1]) or {play=0, loop_active=0, timestamp=0, speed=0}
  local s2 = (state and state[2]) or {play=0, loop_active=0, timestamp=0, speed=0}
  draw_loop_row(1, s1)
  draw_loop_row(2, s2)

  -- y=3 rec level ladder
  if mode == 3 then
    ladder_dual(3, function(_) return params:get("wtape_rec_level") end)
  else
    ladder_single(3, params:get("wtape_rec_level") or 0)
  end

  -- y=4 monitor level ladder
  if mode == 3 then
    ladder_dual(4, function(_) return params:get("wtape_monitor_level") end)
  else
    ladder_single(4, params:get("wtape_monitor_level") or 0)
  end

  -- y=5 loop button LED (reflect active module or both in broadcast)
  if mode == 3 then
     -- Dual brightness: medium if one active, full if both active
     local b1 = ((s1.loop_active or 0) == 1) and 12 or 7
     local b2 = ((s2.loop_active or 0) == 1) and 15 or 0
     g:led(1,5, math.max(b1, b2))
  else
     local active = (mode == 1 and s1.loop_active == 1) or (mode == 2 and s2.loop_active == 1)
     g:led(1,5, active and 15 or 7)
  end


  -- y=6 Freq (v/8) ladder (dual-aware) + transport (as you have)
  g:led(4,6,10); g:led(5,6,10)
  for x=6,16 do g:led(x,6, (x==11) and 7 or 5) end

  if mode == 3 then
    local x1 = _nearest_freq_slot(s1_speed)
    local x2 = _nearest_freq_slot(s2_speed)
    if x1 then g:led(x1,6, math.max(12, (x1==11) and 7 or 5)) end
    if x2 then g:led(x2,6, math.max(15, (x2==11) and 7 or 5, (x2==x1) and 12 or 0)) end
  else
    local xv = (mode==1) and _nearest_freq_slot(s1_speed) or _nearest_freq_slot(s2_speed)
    if xv then g:led(xv,6, 15) end
  end

  if mode == 3 then
    local b1_play = ((s1.play or 0) ~= 0) and 12 or 5
    local b2_play = ((s2.play or 0) ~= 0) and 15 or 0
    g:led(1,6, math.max(b1_play, b2_play))
    local b1_rev = ((s1.play or 0) == -1) and 12 or 7
    local b2_rev = ((s2.play or 0) == -1) and 15 or 0
    g:led(2,6, math.max(b1_rev, b2_rev))
  else
    local ps = (mode==1) and (s1.play or 0) or (s2.play or 0)
    g:led(1,6, (ps~=0) and 15 or 5)
    g:led(2,6, (ps==-1) and 15 or 7)
  end

  -- y=7 record/echo + erase ladder
  local rec_on = (params:get("wtape_record") == 2)
  local echo_on = (params:get("wtape_echo_mode") == 2)
  g:led(1,7, rec_on and 15 or 5)
  g:led(2,7, echo_on and 15 or 7)
  if mode==3 then
    ladder_dual(7, function(_) return params:get("wtape_erase_strength") end)
  else
    ladder_single(7, params:get("wtape_erase_strength") or 0)
  end

  -- y=8 target toggles
  g:led(1,8, tgt.w1_on and 15 or 5)
  g:led(2,8, tgt.w2_on and 15 or 5)

  g:refresh()
  dprint("redraw done (grid+screen)")
  ui._dirty = false
end


function ui.init(_g)
  g = _g
  if ui._clock_running then return end
  ui._clock_running = true
  clock.run(function()
    while true do
      clock.sleep(1/20)
      if ui._dirty then
        local ok, err = pcall(ui.redraw)
        if not ok then
          print("[ui] redraw error:", err)
        end
      end
    end
  end)
end


return ui

