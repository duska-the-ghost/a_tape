# a_tape — Dual W/ Controller for Norns + Crow + Grid

`a_tape` is a Norns script that enables **simultaneous control of two Whimsical Raps W/** (wtape) modules via **Crow** and **Monome Grid**, using the **Flora library’s `w_slash`** parameter layer. 
It provides a flexible interface for playback, looping, overdubbing, and monitoring — across individual or broadcast (dual) control modes.

---

## REQUIREMENTS

### **Hardware**
- **Monome Norns** or **Norns Shield**
- **Monome Grid** (128 recommended / other sizes not tested)
- **Monome Crow** (connected via USB to Norns)
- **Two Whimsical Raps W/** modules connected via **i2c** (some functionality still available with one Whimsical Raps W/)
- **Eurorack system** with power and i2c connection between W/ and Crow

### **Software**
- Norns firmware **2.8+** (tested on 2.9.3)
- Crow firmware supporting **`ii.wtape`** namespace
- Flora library installed (`flora/lib/w_slash.lua`)
- Monome Grid API (included in Norns)
- Lua 5.3 runtime (standard on Norns)

---

## INSTALLATION

1. Clone or download this repository into your Norns code folder:
   ```bash
   cd ~/dust/code/
   git clone https://github.com/<yourname>/a_tape.git
   ```

2. Ensure the Flora library is installed and accessible:
   ```
   ~/dust/code/flora/lib/w_slash.lua
   ```

3. Reboot your Norns or reload the script menu.

4. On Norns, go to:
   ```
   SELECT → a_tape
   ```

5. Confirm Crow is connected and W/ devices respond to:
   ```lua
   crow.ii.wtape[1]
   crow.ii.wtape[2]
   ```

---

## DEPENDENCIES

- [`flora/lib/w_slash.lua`](https://github.com/jaseknighter/flora/blob/main/lib/w_slash.lua) 
  Provides parameter mapping for W/ (wtape) devices.
- [`monome/crow`](https://github.com/monome/crow) 
  Handles ii communication to Eurorack modules.
- [`monome grid`](https://monome.org/docs/norns/api/modules/grid.html) 
  For visual + tactile control.
- Norns standard Lua libraries:
  - `util`
  - `controlspec`
  - `params`
  - `clock`

---

## OVERVIEW

`a_tape` bridges Norns, Crow, and W/ modules, giving you hands-on, synchronized control of **two tape heads** from a **Monome Grid**. 
It’s designed for real-time manipulation, composition, and performance.

Key features:
- **Dual W/ control**: Operate each module independently or together (broadcast mode)
- **Grid-based control surface**: Manage play, reverse, looping, and recording visually
- **Parameter mirroring**: Syncs Norns parameters with `flora/lib/w_slash`
- **Crow-safe communication**: Uses robust ii calls with per-address verification
- **Loop and playback UI feedback**: LED bars display current playback speed and loop positions

---

## NORNS UI

Displays current mode and device state:
- Active target (`W1`, `W2`, or `both`)
- Playback speed (v/8)
- Erase level
- Loop activity

Encoders:
- **E2** – Adjust playback speed (0.25× – 2.0×)
- **E3** – Adjust erase strength (0–1)

Screen updates to reflect device state and broadcast mode.

---

## GRID UI

### Layout Summary

| Row | Function | Description |
|------|-----------|-------------|
| 1 | W1 loop position | Always visible |
| 2 | W2 loop position | Always visible |
| 3 | Record Level Ladder | x=6–16 Sets input gain per device |
| 4 | Monitor Level Ladder | x=6–16 Adjusts input→output gain |
| 5 | Loop Button (x=1) | Tap = start/end loop, Hold (2s) = disable |
| 6 | Transport & Freq | x=1 play, x=2 reverse, x=6–16 frequency slots |
| 7 | Record / Echo / Erase | x=1 record toggle, x=2 echo mode, x=6–16 erase strength ladder |
| 8 | Target Toggles | x=1=W1, x=2=W2; press both = broadcast mode |

**Visual Feedback**
- Dual brightness indicates W1/W2 difference in broadcast mode.
- Loop bars (rows 1–2) display position and loop window.
- Active play/reverse states highlighted in row 6.

---

## CROW I/O

Crow acts as the i2c interface to your W/ modules.
- IN 1 | TBD
- IN 2 | TBD
- OUT 1 | TBD
- OUT 2 | TBD
- OUT 3 | TBD
- OUT 4 | TBD

### Supported ii calls:
- `play(-1|0|1)`
- `freq(v/8)`
- `record(0|1)`
- `rec_level(0–1)`
- `monitor_level(0–1)`
- `erase_strength(0–1)`
- `loop_start`, `loop_end`, `loop_active`, `loop_next(0)`
- `echo_mode(0|1)`

### Safety and Error Handling
- TBD

---

## IDEAS for FUTURE ENHANCEMENTS
**Norns**
- LFO matrix
- Graphic UI
- FX (bitcrush, wobble, hiss)
- Just Friends support

**Grid UI**
- Timestamp slots with applied frequencies
- Tape stop with slowdown/speedup
- Freeze approximation 
- LFO support (assign, modify)
- Just Friends sequencing page
- Norns FX faders page
- W/ Seek FF/Rev and Loop Next/Previous

**Crow**
- IN 1 | TBD
- IN 2 | TBD
- OUT 1 | TBD
- OUT 2 | TBD
- OUT 3 | TBD
- OUT 4 | TBD

---

## CREDITS

- **Lead Developer:** (@duskatheghost)
- **Libraries:** [Flora / w_slash](https://github.com/jaseknighter/flora) by Jonathan Snyder (@jaseknighter)
- **Hardware & Frameworks:** [Monome](https://monome.org), [Whimsical Raps](https://whimsicalraps.com) 
- **Inspiration & Support:** Norns community, Lines forum contributors

---

## REFERENCES

- Flora `w_slash.lua`:  
  <https://github.com/jaseknighter/flora/blob/main/lib/w_slash.lua>  
- Crow ii wtape bindings:  
  <https://github.com/monome/crow/blob/main/lua/ii/wtape.lua>  
- Monome Grid API:  
  <https://monome.org/docs/norns/api/modules/grid.html>  
- Crow reference:  
  <https://monome.org/docs/crow/reference/>  
- W/ (wtape) ii Wiki:  
  <https://github.com/whimsicalraps/wslash/wiki/Tape#ii>  
