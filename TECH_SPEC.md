# Technical Specification
Project: a_tape – Dual W/ Controller for Norns
Tech Spec Version: 0.1
Script Version: 0.1.0-alpha
Status: Work in progress
Author: @duskatheghost
License: GPL-3.0
Repository: https://github.com/duska-the-ghost/a_tape

---

## 1. Overview
`a_tape` is a Norns script designed to provide real-time control of two Whimsical Raps W/ (wtape) modules using a Monome Grid and Monome Crow. The script enables independent or synchronized (broadcast) tape operations such as play, reverse, looping, overdubbing, monitoring, recording, and parameter control via the Flora `w_slash` library interface.

The goal of the project is to create a clear, performant, and musically expressive interface for dual-W/ control that allows users to treat the two tape modules as independent sound sources or as a linked stereo or mirrored system. The grid interface acts as the primary performance surface, while the Norns screen provides state feedback and parameter context. All communication with the W/ modules is handled over i2c via Crow.

This project is being developed as an open-source tool for the Norns and modular community, and the technical specification is intended to:

- Document the system architecture and interaction flow

- Establish a maintainable structure for future contributors

- Define feature expectations and control logic before full implementation

- Serve as reference material for users who want to fork, extend, or port the script

The intended audience for this document includes:

- Developers contributing to the project

- Norns users who want to understand or customize the internal behavior

- Hardware users looking to integrate two W/ modules with performance controls

- Anyone studying Lua-based Norns scripts as part of learning the ecosystem

---

## 2. Table of Contents

1. Overview
2. Table of Contents
3. System Architecture
   - Hardware Diagram
   - Software Data Flow
4. Component & File Structure
5. Functional Requirements
6. Non-Functional Requirements
7. UI Specifications
   - Norns Screen UI
   - Grid UI (button + LED map)
   - Encoders / Keys
   - Parameters & w_slash Integration
8. Control Logic & State Model
   - Target Selection Rules (W1 / W2 / Broadcast)
   - Looping State Machine
   - Transport Behavior
9. Crow / ii Interface Contract
   - Supported Calls
   - Error Handling & Fallbacks
10. Edge Cases & Failure Modes
11. Testing Plan
12. Open Source Contribution Notes
13. Roadmap (Milestone-based)
14. Future Extensions / Ideas
15. Revision History

---

## 3. System Architecture

`a_tape` operates as a layered system that connects user input (Grid, Encoders, Keys) to real-time tape control over i2c. The architecture is divided into three primary layers:

1. **User Interaction Layer** – Grid, encoders, and keys generate events  
2. **Script Logic Layer** – a_tape Lua modules interpret and translate events into actions  
3. **Hardware Execution Layer** – Crow forwards ii calls to W/ modules  

### 3.1 High-Level Flow

[User] → Grid / Encoders / Keys
→ a_tape_actions.lua (event handlers)
→ a_tape_utility.lua (ii-safe function calls)
→ crow.ii.wtape[1] and crow.ii.wtape[2]
→ W/ hardware responds

[W/ state] → polled via crow.ii → UI state cache → a_tape_ui.lua → Screen + Grid redraw


- Grid input is treated as the primary control surface for performance operations  
- Norns encoders & keys handle parameter changes and navigation  
- Crow functions as the bridge between Norns and W/ devices  
- State is cached inside the script so UI updates do not require constant hardware reads  

### 3.2 Hardware Architecture

+------------------+ USB +-----------+ i2c +----------+
| Norns | <----------------> | Crow | <-------------> | W/ 1 |
| (Script runtime) | | (ii host) | <-------------> | W/ 2 |
+------------------+ (address 1 & 2) +----------+
|
| Grid cable
v
+------------------+
| Monome Grid |
+------------------+


- Norns communicates with Crow over USB serial  
- Crow exposes two independent W/ devices on the i2c bus (`addr 1`, `addr 2`)  
- Broadcast mode refers to issuing the same ii commands to both addresses  
- The script does not modify or replace firmware on W/ or Crow  

### 3.3 Software Architecture

| Layer | Component | Responsibility |
|--------|-----------|----------------|
| **UI Layer** | `a_tape_ui.lua` | Draws screen + grid, reads cached state |
| **Input Layer** | `a_tape_actions.lua` | Translates Grid/Enc/Key events into state changes and commands |
| **Core Script Layer** | `a_tape.lua` | Initializes params, grid, crow, and links modules together |
| **Utility Layer** | `a_tape_utility.lua` | Handles crow.ii calls, fail-safes, and loop abstractions |
| **Dependency Layer** | `flora/lib/w_slash.lua` | Provides param bindings for W/ exposed as Norns params |

### 3.4 Data Handling Model

- State is mirrored in Lua tables, not queried from hardware on every UI update  
- Polling loop (~10 Hz) refreshes values such as:  
  - tape position (`timestamp`)  
  - loop markers  
  - record status  
  - play direction  
- UI redraw is event-based, not continuous, to minimize CPU usage  
- Crow calls are wrapped in `pcall()` to prevent Norns crashes if a device is missing  

### 3.5 Broadcast Logic

| UI Target | Mode | Affected W/ |
|-----------|------|--------------|
| W1 only | `mode = 1` | addr 1 |
| W2 only | `mode = 2` | addr 2 |
| Both | `mode = 3` | addr 1 & 2 |

Target mode is determined in the UI based on Grid button state and passed downward into function calls.

---

## 4. Component & File Structure
<!-- TODO: Add purpose + responsibility list for each Lua file -->

| File | Role | Notes |
|------|------|-------|
| `a_tape.lua` | Main script | Initializes grid, crow, params, UI |
| `lib/a_tape_actions.lua` | Input handling | Maps grid/enc/key events to behavior |
| `lib/a_tape_ui.lua` | Rendering | Screen + grid LED updates |
| `lib/a_tape_utility.lua` | Crow helpers | Safe ii calls, loop abstractions |
| `flora/lib/w_slash.lua` | Dependency | Provides wtape param API |

---

## 5. Functional Requirements
<!-- TODO -->

---

## 6. Non-Functional Requirements
<!-- TODO -->

---

## 7. UI Specifications
<!-- TODO -->

---

## 8. Control Logic & State Model
<!-- TODO -->

---

## 9. Crow / ii Interface Contract
<!-- TODO -->

---

## 10. Edge Cases & Failure Modes
<!-- TODO -->

---

## 11. Testing Plan
<!-- TODO -->

---

## 12. Open Source Contribution Notes
<!-- TODO -->

---

## 13. Roadmap (Milestone-based)
<!-- TODO -->

---

## 14. Future Extensions / Ideas
<!-- TODO -->

---

## 15. Revision History
<!-- TODO -->
