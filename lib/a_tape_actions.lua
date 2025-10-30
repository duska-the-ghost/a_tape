-- lib/a_tape_actions.lua
-- Uses lib/a_tape_utility.lua to route all per-target actions cleanly
-- actions: grid + key/enc handlers

local A    = {}
local U    = include("lib/a_tape_utility")
local util = require "util"

-- reference to UI-owned state (synced via ui.set_states / ui.get_state)
local ui 
local state

-- track record state per address for UI/debug (1..2)
A._rec_on = { [1]=false, [2]=false }

-- freq slots for y=6 ladder (v/8 style offsets)
local freq_slots = {
  [6]=-0.50,[7]=-0.40,[8]=-0.30,[9]=-0.20,[10]=-0.10,
  [11]=0.00,[12]=0.10,[13]=0.20,[14]=0.30,[15]=0.40,[16]=0.50,
}

-- track current physical press state for simultaneous detection (target row)
A._tgt_down   = { w1 = false, w2 = false }

-- loop button (y=5,x=1) long press state
A._loop_down_t = nil
A._loop_hold_s = 2.0  -- seconds to disable looping
local last_press_time = { [1]=0, [2]=0 } -- per button x if you expand later
local HOLD_SEC = 0.4

-- ------------------------------------------------------------
-- helpers (hoisted and shared)
-- ------------------------------------------------------------

-- resolve active mode from UI toggles (1, 2, or 3 for broadcast)
local function mode_now()
  return (ATAPE and ATAPE.get_active_mode and ATAPE.get_active_mode()) or 1
end

-- simple linear mapping for ladder columns x -> [0..1] in 11 steps (6..16)
local function ladder_0_1_from_x(x)
  if x < 6 then return 0 elseif x > 16 then return 1 end
  return (x - 6) / (16 - 6)
end

-- ensure a per-address slot exists before writing into it
local function ensure_slot(a)
  local st = ui.get_state() or {}
  if not st[a] then
    st[a] = {
      play=0, loop_active=0, loop_started=false, loop_has_end=false,
      loop_start_pos=0, loop_end_pos=0, timestamp=0, speed=1.0
    }
  end
  state = st            -- keep our upvalue in sync
  return st[a]
end

-- convenience to set play across the current mode and update cached state
local function set_play_for_mode(mode, v)
  U.play(mode, v)
  for _, addr in ipairs(U.addresses(mode)) do
    ensure_slot(addr).play = v
  end
  ui.set_states(state)
end

-- ------------------------------------------------------------
-- init: seed state reference and start background clock
-- ------------------------------------------------------------
function A.init(_ui)
  ui = _ui
  state = ui.get_state()

  -- background poll to keep UI loop bars/play state in sync with device
  clock.run(function()
    while true do
      clock.sleep(0.1) -- ~10 Hz poll is plenty
      local st = ui.get_state() or {}
      local changed = false

      for a=1,2 do
        st[a] = st[a] or {}
        -- Read fresh values from the device (first addr for that mode)
        local ts = U.get_timestamp(a)
        if ts ~= nil then st[a].timestamp = ts; changed = true end

        local ls = U.get_loop_start(a)
        if ls ~= nil then st[a].loop_start = ls; changed = true end

        local le = U.get_loop_end(a)
        if le ~= nil then st[a].loop_end = le; changed = true end

        local la = U.get_loop_active(a)
        if la ~= nil then st[a].loop_active = la and 1 or 0; changed = true end

        local pl = U.get_play(a)
        if pl ~= nil then st[a].play = pl; changed = true end

        local rc = U.get_recording(a)
        if rc ~= nil then A._rec_on[a] = rc end

      end

      if changed then
        ui.set_states(st)
        ui.request_redraw()
      end
    end
  end)
end

-- ------------------------------------------------------------
-- loop button helpers
-- ------------------------------------------------------------
function A.loop_button_press()
  A._loop_down_t = util.time()
end

function A.loop_button_release(mode)
  local st  = ui.get_state() or {}
  local t0  = A._loop_down_t or util.time()
  A._loop_down_t = nil
  local held = (util.time() - t0) >= A._loop_hold_s
  local addrs = U.addresses(mode)

  if held then
    -- disable looping
    U.loop_active(mode, 0)
    for _,a in ipairs(addrs) do ensure_slot(a).loop_active = 0 end
    ui.set_states(st); ui.request_redraw()
    return
  end

  -- 1) no start set? -> set start on all selected
  local any_no_start = false
  for _,a in ipairs(addrs) do if not ensure_slot(a).loop_started then any_no_start = true; break end end
  if any_no_start then
    U.loop_start(mode)
    for _,a in ipairs(addrs) do ensure_slot(a).loop_started = true end
    ui.set_states(st); ui.request_redraw()
    return
  end

  -- 2) start exists but no end? -> set end on all + enable
  local any_no_end = false
  for _,a in ipairs(addrs) do if not ensure_slot(a).loop_has_end then any_no_end = true; break end end
  if any_no_end then
    U.loop_end(mode)
    for _,a in ipairs(addrs) do
      local s = ensure_slot(a)
      s.loop_has_end = true
      s.loop_active  = 1
    end
  else
    -- 3) both exist -> nudge/retrigger window (0=retrigger)
    U.loop_next(mode, 0)
  end

  ui.set_states(st)
  ui.request_redraw()
end

-- ------------------------------------------------------------
-- encoders (E2 speed param mirror, E3 erase param mirror)
-- ------------------------------------------------------------
function A.enc(n,d)
  if n == 2 then
    local v = params:get("wtape_speed") + d*0.01
    U.param_set("wtape_speed", math.min(2.0, math.max(0.25, v)))
  elseif n == 3 then
    local v = params:get("wtape_erase_strength") + d*0.02
    U.param_set("wtape_erase_strength", U.clamp01(v))
  end
  ui.request_redraw()
end

-- ------------------------------------------------------------
-- grid
-- y=1: W1 loop bar (display only)
-- y=2: W2 loop bar (display only)
-- y=3: rec level ladder (per-target ii + mirror)
-- y=4: monitor level ladder (per-target ii + mirror)
-- y=5: x=1 loop button (short: start/end/retrigger; hold 2s: deactivate)
-- y=6: x=1 play toggle; x=2 reverse toggle; freq slots (6..10 & 12..16), x=11 normal
-- y=7: x=1 record ; x=2 echo toggle ; x=6..16 erase ladder (per-target ii + mirror)
-- y=8: x=1 (W1) x=2 (W2) (target toggles W1/W2/Broadcast to both)
-- ------------------------------------------------------------
function A.grid_key(x, y, z)
  -- DO NOT shadow the helper; just fetch for logging
  local active_mode = ATAPE.get_active_mode()
  print(string.format("[grid] event x=%d y=%d z=%d -> mode_now=%d", x, y, z, active_mode))
  print(string.format("[grid] x=%d y=%d z=%d", x, y, z))

  -- display-only rows
  if y == 1 or y == 2 then return end

  -- TARGET SELECT (y=8) — apply on press (z==1)
  if y == 8 and (x == 1 or x == 2) then
    if z == 1 then
      print("[grid] target select press")
      if x == 1 then A._tgt_down.w1 = true else A._tgt_down.w2 = true end
      local both_down = A._tgt_down.w1 and A._tgt_down.w2
      if both_down then
        print("[grid] → broadcast ON (both down)")
        ui.set_states(nil, { w1_on = true,  w2_on = true  })
      elseif x == 1 then
        print("[grid] → W1 ON, W2 OFF")
        ui.set_states(nil, { w1_on = true,  w2_on = false })
      else
        print("[grid] → W2 ON, W1 OFF")
        ui.set_states(nil, { w1_on = false, w2_on = true  })
      end
      -- After updating target toggles (w1_on/w2_on), refresh param mirrors for new active target:
      local new_mode = ATAPE.get_active_mode()
      if new_mode ~= 3 then
         local erase = U.get_erase(new_mode)       -- get current erase_strength of the active W/
         if erase then params:set("wtape_erase_strength", erase, true) end
         local mon   = U.get_monitor(new_mode)
         if mon   then params:set("wtape_monitor_level", mon, true) end
         local rec   = U.get_rec_level(new_mode)
         if rec   then params:set("wtape_rec_level", rec, true) end
      end

      ui.request_redraw()
    else
      if x == 1 then A._tgt_down.w1 = false else A._tgt_down.w2 = false end
    end
    return
  end

  -- REC LEVEL (y=3) — apply to selected W/ only
  if y == 3 and z == 1 and U.between(x,6,16) then
    local mode = mode_now()
    local val  = ladder_0_1_from_x(x)
    -- send ii first (authoritative)
    U.rec_level(mode, val)                         -- calls 'rec_level' per addr
    -- optional: mirror a UI param *without* triggering anything else
    -- remove the *_ui param set if it causes route issues; UI will redraw from device polling
    print(string.format("[grid/ii] rec_level %.2f (mode=%d)", val, mode))
    ui.request_redraw()
    return
  end


  -- MONITOR LEVEL (y=4) — apply to selected W/ only
  if y == 4 and z == 1 and U.between(x,6,16) then
    local mode = mode_now()
    local val  = ladder_0_1_from_x(x)
    U.monitor_level(mode, val)
    print(string.format("[grid/ii] monitor_level %.2f (mode=%d)", val, mode))
    ui.request_redraw()
    return
  end



  -- LOOP BUTTON (y=5,x=1) — short tap cycles; long hold disables
  if y == 5 and x == 1 then
    if z == 1 then
      A._loop_down_t = util.time()
      print("[grid] loop press")
    else
      local mode = mode_now()
      local held = (util.time() - (A._loop_down_t or util.time())) >= A._loop_hold_s
      A._loop_down_t = nil

      if held then
        U.loop_active(mode, 0)
        print(string.format("[grid/ii] loop_active 0 (mode=%d)", mode))
      else
        local st = ui.get_state() or {}
        local addrs = U.addresses(mode)
        local any_no_start, any_no_end = false, false
        for _,a in ipairs(addrs) do
          st[a] = st[a] or {}
          if not st[a].loop_started then any_no_start = true end
          if not st[a].loop_has_end then any_no_end = true end
        end
        if any_no_start then
          U.loop_start(mode)
          print(string.format("[grid/ii] loop_start (mode=%d)", mode))
        elseif any_no_end then
          U.loop_end(mode)
          U.loop_active(mode, 1)
          print(string.format("[grid/ii] loop_end + active=1 (mode=%d)", mode))
        else
          U.loop_next(mode, 0)
          print(string.format("[grid/ii] loop_next 0 (mode=%d)", mode))
        end
      end
      ui.request_redraw()
    end
    return
  end


  -- TRANSPORT (y=6, x=1|2): toggle play/reverse for the selected mode
  if y == 6 and (x == 1 or x == 2) and z == 1 then
    local mode = mode_now()
    local st   = ui.get_state() or {}
    local want = (x == 1) and 1 or -1
    local new

    if mode == 3 then
      -- unify both devices on press; press same button again = stop both
      local p1 = (st[1] and tonumber(st[1].play)) or 0
      local p2 = (st[2] and tonumber(st[2].play)) or 0
      local both_same = (p1 == want) and (p2 == want)
      new = both_same and 0 or want
      U.play(3, new)
      st[1] = st[1] or {}; st[2] = st[2] or {}
      st[1].play, st[2].play = new, new
    else
      st[mode] = st[mode] or {}
      local cur = tonumber(st[mode].play) or 0
      new = (cur == want) and 0 or want
      U.play(mode, new)
      st[mode].play = new
    end
  
    print(string.format("[grid/ii] play -> %d (mode=%d)", new, mode))
    ui.set_states(st); ui.request_redraw()
    return
  end

  -- FREQ SLOT (y=6, x=6..16)
  if y == 6 and z == 1 and freq_slots[x] ~= nil then
    local v8   = freq_slots[x]
    local mode = mode_now()
    local addrs = U.addresses(mode)
    print(string.format("[grid] freq slot x=%d v8=%.2f mode=%d", x, v8, mode))
    if U.freq then U.freq(mode, v8) end
    for _,a in ipairs(addrs) do ensure_slot(a).speed = v8 end
    ui.set_freq_selection(x)
    ui.request_redraw()
    return
  end

  -- RECORD / ECHO / ERASE (y=7) — per-target ii + mirror params for UI (press only)
  if y == 7 and z == 1 then
    local mode = mode_now()
    local addrs = U.addresses(mode)
    print(string.format("[grid] y=7 control x=%d (mode=%d) addrs=%s", x, mode, table.concat(addrs,",")))
    if x == 1 then
      -- RECORD: toggle per-selected device(s), send ii directly
      local addrs = U.addresses(mode)
      for _, a in ipairs(addrs) do
        local next_on = not (A._rec_on[a] or false)
        U.record({a}, next_on and 1 or 0)
        A._rec_on[a] = next_on
        print(string.format("[grid/ii] record addr=%d -> %s", a, next_on and "on" or "off"))
      end
      -- don't touch wtape_record param; let poll + LEDs show true state
    elseif x == 2 then
      -- echo toggle
      local cur = params:get("wtape_echo_mode") or 1    -- 1=off, 2=on
      local nxt = (cur == 1) and 2 or 1
      params:set("wtape_echo_mode", nxt)                -- mirror
      if U.echo_mode then U.echo_mode(mode, (nxt == 2) and 1 or 0) end
      print(string.format("[ii] echo_mode -> %s (mode=%d)", (nxt==2) and "on" or "off", mode))
    elseif U.between(x,6,16) then
       -- ERASE ladder (x=6..16): set per target
       local mode = mode_now()
       local val  = U.clamp01((x - 6) / 10)
       if U.erase_strength then U.erase_strength(mode, val) end   -- apply to selected W/ or both:contentReference[oaicite:13]{index=13}
       params:set("wtape_erase_strength", val, true)             -- update param silently (no global ii call)
       print(string.format("[ii] erase_strength -> %.2f (mode=%d)", val, mode))
    end

    ui.request_redraw()
    return
  end

  -- ignore key-up events or unmapped presses quietly
  return
end

return A

