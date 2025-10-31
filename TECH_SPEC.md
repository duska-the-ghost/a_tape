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
<!-- TODO: Add project summary, intent, and audience -->

---

## 2. Table of Contents

1. Overview
2. System Architecture
   - Hardware Diagram
   - Software Data Flow
3. Component & File Structure
4. Functional Requirements
5. Non-Functional Requirements
6. UI Specifications
   - Norns Screen UI
   - Grid UI (button + LED map)
   - Encoders / Keys
   - Parameters & w_slash Integration
7. Control Logic & State Model
   - Target Selection Rules (W1 / W2 / Broadcast)
   - Looping State Machine
   - Transport Behavior
8. Crow / ii Interface Contract
   - Supported Calls
   - Error Handling & Fallbacks
9. Edge Cases & Failure Modes
10. Testing Plan
11. Open Source Contribution Notes
12. Roadmap (Milestone-based)
13. Future Extensions / Ideas
14. Revision History

---

## 3. System Architecture
<!-- TODO: Add data-flow diagram showing Norns → Grid/Crow → W/ -->

```
[NORNS]  --grid-->  UI event handlers
   |                 |
   |                 v
   |           a_tape_actions.lua  --updates--> internal state
   |                 |
   v                 v
params <------ a_tape.lua ------> crow.ii.wtape[x]  ---->  W/ modules (1 & 2)
   ^
   |
screen + grid redraw via a_tape_ui.lua
```

<!-- TODO: Add hardware diagram showing Norns USB → Crow i2c → W/ -->

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
