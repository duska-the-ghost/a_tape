-- lib/a_tape_utility.lua
-- Helpers to target W/ (wtape) devices safely via crow ii using bracket addressing.
-- Broadcast handled per-call. Uses official W/Tape ii method names.

local U = {}

----------------------------------------------------------------
-- Addressing / mode helpers
----------------------------------------------------------------

-- Resolve "mode" (1=W1, 2=W2, 3=broadcast) if not provided
local function mode_or_current(mode)
  if mode ~= nil then return mode end
  if _G.ATAPE and ATAPE.get_active_mode then
    return ATAPE.get_active_mode()
  end
  return 3 -- sensible default: broadcast
end

-- Return list of ii addresses given a mode
function U.addresses(mode)
  if type(mode) == "table" then return mode end
  if     mode == 1 then return {1}
  elseif mode == 2 then return {2}
  else                   return {1,2} end
end

----------------------------------------------------------------
-- crow / wtape device access
----------------------------------------------------------------
local function _dev_for_addr(addr)
  -- crow.ii.wtape can be a table-of-functions or a callable that returns one
  local root = (crow and crow.ii and crow.ii.wtape) and crow.ii.wtape or nil
  if not root then return nil end
  local d = root[addr] or root[tostring(addr)]
  if type(d) == "function" then
    -- some hosts return a ctor that yields the callable table
    local ok, out = pcall(d)
    if ok then d = out end
  end
  return (type(d) == "table") and d or nil
end

-- Capability cache so we only probe once per addr/name
local _cap = {}  -- _cap[addr] = { name=true/false }
local function has_fn(addr, name)
  _cap[addr] = _cap[addr] or {}
  if _cap[addr][name] ~= nil then return _cap[addr][name] end
  local dev = _dev_for_addr(addr)
  local ok = (dev and type(dev[name]) == "function") or false
  _cap[addr][name] = ok
  if not ok then
    print(string.format("[wtape] addr=%s fn=%s not found", tostring(addr), tostring(name)))
  end
  return ok
end

local function call(addr, name, ...)
  local dev = _dev_for_addr(addr)
  if not dev then
    print(string.format("[wtape] addr=%s (no device table)", tostring(addr)))
    return false
  end
  if type(dev[name]) ~= "function" then
    print(string.format("[wtape] addr=%s fn=%s not found", tostring(addr), tostring(name)))
    return false
  end
  local ok, err = pcall(dev[name], ...)
  if not ok then
    print(string.format("[wtape] addr=%s fn=%s call error: %s", tostring(addr), tostring(name), tostring(err)))
  end
  return ok
end

local function each_addr(mode, f)
  for _, addr in ipairs(U.addresses(mode_or_current(mode))) do f(addr) end
end

----------------------------------------------------------------
-- Public: quick diagnostics
----------------------------------------------------------------
function U.dump_wtape_api()
  for _, addr in ipairs({1,2}) do
    local dev = _dev_for_addr(addr)
    if type(dev) == "table" then
      print(string.format("[wtape/api] addr=%d fns:", addr))
      for k,v in pairs(dev) do
        if type(v)=="function" then print("  - "..k) end
      end
    else
      print(string.format("[wtape/api] addr=%d (no device table)", addr))
    end
  end
end

function U.ping()
  -- harmless: query a getter we expect to exist (freq or speed)
  each_addr(nil, function(addr)
    if has_fn(addr, "get") then
      local ok, val = pcall(_dev_for_addr(addr).get, "freq")
      print(string.format("[wtape/ping] addr=%d get('freq') ok=%s", addr, tostring(ok)))
    else
      print(string.format("[wtape/ping] addr=%d no get() present", addr))
    end
  end)
end

----------------------------------------------------------------
-- Core setters / transport per W/Tape ii spec
-- Ref: https://github.com/whimsicalraps/wslash/wiki/Tape#ii
----------------------------------------------------------------

-- PLAY / STOP / REVERSE
-- dir =  1 -> play forward, 0 -> stop, -1 -> play reverse
function U.play_dir(dir, mode)
  each_addr(mode, function(addr)
    if dir == -1 then
      -- Either use play(-1) directly (preferred),
      -- or fallback to reverse() then play(1) if play(-1) is missing.
      if has_fn(addr, "play") then
        call(addr, "play", -1)
      elseif has_fn(addr, "reverse") and has_fn(addr, "play") then
        call(addr, "reverse"); call(addr, "play", 1)
      else
        print(string.format("[wtape] addr=%d cannot set reverse play (missing play/reverse)", addr))
      end
    elseif dir == 0 then
      if has_fn(addr, "play") then call(addr, "play", 0) end
    else
      if has_fn(addr, "play") then call(addr, "play", 1) end
    end
  end)
end

function U.reverse(mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "reverse") then call(addr, "reverse") end
  end)
end

-- FREQ / SPEED
function U.freq(v8, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "freq") then call(addr, "freq", v8) end
  end)
end

function U.speed(rate_or_num, denom, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "speed") then
      if denom ~= nil then call(addr, "speed", rate_or_num, denom)
      else call(addr, "speed", rate_or_num) end
    end
  end)
end

-- RECORD toggle (1 on / 0 off)
function U.record(set_on, mode)
  local v = set_on and 1 or 0
  each_addr(mode, function(addr)
    if has_fn(addr, "record") then call(addr, "record", v) end
  end)
end

-- REC LEVEL (y==3): gain to tape
function U.rec_level(gain, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "rec_level") then call(addr, "rec_level", gain)
    else print(string.format("[wtape/cap] addr=%d rec_level() not available", addr)) end
  end)
end

-- MONITOR LEVEL (y==4): dry IN->OUT gain
function U.monitor_level(gain, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "monitor_level") then call(addr, "monitor_level", gain)
    else print(string.format("[wtape/cap] addr=%d monitor_level() not available", addr)) end
  end)
end


-- aliases to match older call sites
function U.get_erase(mode)           return U.get_erase_strength(mode) end
function U.set_erase_strength_from_ui(val, mode)
  local v = math.max(0, math.min(1, val or 0))
  U.erase_strength(v, mode)
end

-- ERASE STRENGTH (0 overdub … 1 overwrite)
function U.erase_strength(level, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "erase_strength") then call(addr, "erase_strength", level) end
  end)
end

-- ECHO MODE (destructive looping head-order)
function U.echo_mode(active, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "echo_mode") then call(addr, "echo_mode", active and 1 or 0) end
  end)
end

----------------------------------------------------------------
-- Looping helpers
----------------------------------------------------------------

-- >>> DROP-IN: verbose loop controls (start / end / active) — Lua-correct

do
  -- local helpers (self-contained so you can paste anywhere in this file)
  local function _dev_for_addr(addr)
    local root = crow and crow.ii and crow.ii.wtape
    if not root then return nil end
    local dev = root[addr] or root[tostring(addr)]
    if type(dev) == "function" then
      local ok, res = pcall(dev)
      dev = ok and res or nil
    end
    return (type(dev) == "table" or type(dev) == "userdata") and dev or nil
  end

  local function _each_addr(mode, f)
    local addrs
    if type(mode) == "table" then
      addrs = mode
    elseif mode == 1 then
      addrs = {1}
    elseif mode == 2 then
      addrs = {2}
    else
      addrs = {1, 2} -- broadcast (mode==3 or nil)
    end
    for _, a in ipairs(addrs) do f(a) end
  end

-- ---loop controls with compat + logging ------

do
  -- Small local helpers (self-contained)
  local function _wtape_root()
    return crow and crow.ii and crow.ii.wtape or nil
  end

  local function _dev_for_addr(addr)
    local root = _wtape_root()
    if not root then return nil end
    local dev = root[addr] or root[tostring(addr)]
    if type(dev) == "function" then
      local ok, res = pcall(dev)
      dev = ok and res or nil
    end
    return (type(dev) == "table" or type(dev) == "userdata") and dev or nil
  end

  local function _each_addr(mode, f)
    local addrs
    if type(mode) == "table" then
      addrs = mode
    elseif mode == 1 then
      addrs = {1}
    elseif mode == 2 then
      addrs = {2}
    else
      addrs = {1,2} -- broadcast / default
    end
    for _, a in ipairs(addrs) do f(a) end
  end

  -- Try a list of method-name candidates; call the first one that exists.
  -- Returns true if we called something, false if unsupported.
  local function _call_compat(addr, candidates, ...)
    local dev = _dev_for_addr(addr)
    if not dev then
      print(string.format("[wtape] addr=%d (no device) fn~{%s}", addr, table.concat(candidates, ", ")))
      return false
    end
    for _, name in ipairs(candidates) do
      local fn = dev[name]
      if type(fn) == "function" then
        local ok, err = pcall(fn, ...)
        if ok then
          print(string.format("[wtape] -> addr=%d %s(%s)", addr, name,
            (select("#", ...) > 0) and table.concat({ ... }, ", ") or ""))
        else
          print(string.format("[wtape] addr=%d %s call error: %s", addr, name, tostring(err)))
        end
        return ok
      end
    end
    print(string.format("[wtape] addr=%d fn~{%s} not found (unsupported on this binding)",
      addr, table.concat(candidates, ", ")))
    return false
  end

  -- LOOP START
  function U.loop_start(mode)
    local candidates = { "loop_start", "set_loop_start", "mark_in" } -- try alternates
    _each_addr(mode, function(addr)
      _call_compat(addr, candidates)
    end)
  end

  -- LOOP END
  function U.loop_end(mode)
    local candidates = { "loop_end", "set_loop_end", "mark_out" }
    _each_addr(mode, function(addr)
      _call_compat(addr, candidates)
    end)
  end

  -- LOOP ACTIVE (on/off)
  function U.loop_active(mode, on)
    local v = (on and 1 or 0)
    local candidates = { "loop_active", "set_loop_active", "loop" }
    _each_addr(mode, function(addr)
      local ok = _call_compat(addr, candidates, v)
      -- Optional: confirm via getter if available
      if ok then
        local dev = _dev_for_addr(addr)
        if dev and type(dev.get) == "function" then
          local ok2, a = pcall(dev.get, "loop_active")
          if ok2 then
            print(string.format("[wtape]    addr=%d loop_active now %s", addr, tostring(a)))
          end
        end
      end
    end)
  end
end

-- ----------------------------------------------

-- Retrigger to loop start
function U.loop_retrigger(mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "loop_next") then call(addr, "loop_next", 0)
    else
      -- fallback: toggle play off->on to create an audible retrigger effect
      if has_fn(addr, "play") then call(addr, "play", 0); call(addr, "play", 1) end
    end
  end)
end

-- Move loop window by ±1x length
function U.loop_next(dir, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "loop_next") then call(addr, "loop_next", dir or 0) end
  end)
end

-- Scale loop (n>0 multiply, n<0 divide, 0 reset)
function U.loop_scale(n, mode)
  each_addr(mode, function(addr)
    if has_fn(addr, "loop_scale") then call(addr, "loop_scale", n or 0) end
  end)
end

----------------------------------------------------------------
-- High-level UI action glue (for your grid handlers)
----------------------------------------------------------------

-- TRANSPORT buttons (y==6, x==1 play, x==2 reverse, x==3 stop?) — latching, no flicker
function U.transport_press(kind, is_down, mode)
  -- kind: "fwd" | "rev" | "stop"
  if not is_down then return end
  if     kind == "fwd"  then U.play_dir( 1, mode)
  elseif kind == "rev"  then U.play_dir(-1, mode)
  elseif kind == "stop" then U.play_dir( 0, mode)
  end
end

-- LOOP BUTTON (y==5,x==1)
-- states are managed by UI; these do the ii calls
function U.loop_button(action, mode)
  -- action: "hold" | "start" | "end" | "retrigger" | "clear"
  if     action == "hold"      then U.loop_active(false, mode) -- cancel capture if used during capture in UI
  elseif action == "start"     then U.loop_start(mode)
  elseif action == "end"       then U.loop_end(mode); U.loop_active(true, mode)
  elseif action == "retrigger" then U.loop_retrigger(mode)
  elseif action == "clear"     then U.loop_active(false, mode) -- leaves marks; user can re-activate later
  end
end

-- RECORD TOGGLE (y==7,x==1)
function U.record_toggle(new_on, mode)
  U.record(new_on, mode)
end

----------------------------------------------------------------
-- Convenience setters with logging (for sliders / encs)
----------------------------------------------------------------

function U.set_rec_level_from_ui(val, mode)
  -- expect 0..1 from UI
  local v = math.max(0, math.min(1, val or 0))
  print(string.format("[grid/ii] rec_level %.2f (mode=%s)", v, tostring(mode_or_current(mode))))
  U.rec_level(v, mode)
end

function U.set_monitor_level_from_ui(val, mode)
  local v = math.max(-2, math.min(2, val or 0)) -- spec allows through-zero to 2x; clamp generously
  print(string.format("[grid/ii] monitor_level %.2f (mode=%s)", v, tostring(mode_or_current(mode))))
  U.monitor_level(v, mode)
end

function U.set_freq_from_ui(v8, mode)
  U.freq(v8, mode)
end

function U.set_erase_strength_from_ui(val, mode)
  local v = math.max(0, math.min(1, val or 0))
  U.erase_strength(v, mode)
end
-- --- erase getters  ------------------------------
-- If your actions code calls U.get_erase(mode), resolve to the typed getter.
-- This avoids "attempt to call a nil value (field 'get_erase_strength')".
function U.get_erase_strength(mode)
  return U.get(mode, 'erase_strength')
end

function U.get_erase(mode)
  return U.get(mode, 'erase_strength')
end
-- -------------------------------------------------

return U

