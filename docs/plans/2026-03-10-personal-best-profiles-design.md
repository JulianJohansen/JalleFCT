# Personal Best Flash + Profiles + Import/Export

## Personal Best System

- `personalBests[spellId] = number` — per-spell highest crit, persisted
- `globalBest = { spellId, amount }` — all-time highest across all spells
- On crit: check if amount > personalBests[spellId], update if so
- Then check if amount > globalBest.amount — if yes, flag as `isGlobalBest`
- Global best triggers special animation: 2.0x scale pop + 6-8 star burst particles
- Stars use WoW atlas textures, pre-pooled frames, radiate outward with fade
- Toggle: "Personal Best Flash" in General tab (default on)
- `/jfctreset` wipes all records

## Profile System

SavedVariables restructured:
```
JalleFCT_Config = {
    activeProfile = "Default",
    profiles = { ["Default"] = { ...settings... } },
    personalBests = { ... },
    globalBest = { ... },
    knownSpells = { ... },
}
```

- personalBests, globalBest, knownSpells shared across profiles
- All preferences (fonts, colors, scales, filters, animation, anchor) per-profile
- Migration: old flat format auto-wrapped into profiles["Default"]
- SwitchProfile(name) updates JFCT.db reference and refreshes UI

## Import/Export

- Serialize: recursive table-to-string (literals only)
- Encode: pure-Lua base64 encoder (~30 lines)
- Decode: base64 decode + recursive parser (no loadstring)
- Validation: missing keys filled from DEFAULTS
- Malformed strings show chat error

## File Changes

- Config.lua — profile structure, migration, CRUD, personal best check
- Display.lua — check personal best on crits, pass isGlobalBest to animation
- Animations.lua — PlayGlobalBest (bigger scale + star burst)
- Core/UI/Panel.lua — 5th "Profiles" tab
- Core/UI/Profiles.lua (new) — dropdown, new/delete/rename, import/export
- JalleFCT.lua — /jfctreset slash command
- JalleFCT.toc — add Profiles.lua
