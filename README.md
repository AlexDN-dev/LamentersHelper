# LamentersHelper

> **Private World of Warcraft addon for the Lamenters guild — The Voidspire, Midnight Season 1.**

---

## Why this addon exists

BigWigs and NorthernSkyTools already cover generic raid timers and bar overlays.
What they can't do is know **who** is supposed to act.

LamentersHelper is a **guild-specific alert layer** built on top of those addons. Its job is to answer questions like:

- *Which healer has the dispel this time?*
- *Am I the one targeted by this debuff?*
- *Is this add in range to kick?*
- *Is it my group's turn to soak?*

Every alert that BigWigs already handles is intentionally left out. LamentersHelper only fires when it can add something those addons cannot: **your name, your role, or your group's turn.**

---

## Features

### Named rotation alerts
Dispel, kick, and cover assignments are driven by **configurable player lists** set by the RL or an officer directly in the addon options (`/lh`). Instead of a generic "dispel someone", the right healer sees their own private alert — everyone else sees nothing.

### Progress bars
Real-time countdown bars for key abilities (interrupts, phase transitions, tank debuffs). These are not available in BigWigs or NorthernSkyTools and were the original motivation for building this addon.

### Nameplate kick overlays
On bosses with kickable adds, each add's nameplate shows a live **KICK / LOIN** indicator based on your character's actual interrupt range — updated every 0.1 seconds via `C_Spell.IsSpellInRange()`. Works for all interrupt ranges across all specs.

### Private alerts
Targeted abilities fire a private on-screen alert only for the player affected. Everyone else sees the global version (or nothing, if BigWigs already covers it generically).

### Group-aware soak assignments
Some mechanics alternate between group A (groups 1 & 3) and group B (groups 2 & 4). LamentersHelper detects your raid group and highlights only when it's your turn.

### CLEU-based detection
All alerts are driven by `COMBAT_LOG_EVENT_UNFILTERED` (`SPELL_CAST_START` / `SPELL_AURA_APPLIED`), not pre-calculated timers. This means alerts fire at the **exact real-game moment** the ability is cast or applied, with no timer drift across pulls.

---

## Bosses covered

### 1. Imperator Averzian

| Mechanic | Type | Alert |
|---|---|---|
| Shadow's Advance | 🌐 Global | `SHADOW'S ADVANCE — PHASE PLATEAU !` |
| Oblivion's Wrath | 🌐 Global | `OBLIVION'S WRATH — BOUGEZ !` |
| Void Fall | 🌐 Global | `VOID FALL — ÉVITEZ LES ZONES !` |
| Umbral Collapse | 🌐 Global | `UMBRAL COLLAPSE — SOAK !` |
| Umbral Collapse *(targeted player)* | 🔒 Private | `UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !` |
| Void Marked | 🌐 Global | `[VOID MARKED] — [player name]` |
| Void Marked *(assigned healer)* | 💊 Dispel | `DISPELL [player name] !` |

**Dispel rotation:** up to 4 healers, configured by RL. Each application cycles to the next healer in the list.

---

### 2. Vorasius

| Mechanic | Type | Alert |
|---|---|---|
| Void Breath | 🌐 Global | `VOID BREATH — ÉVITEZ LE CÔNE !` |
| Shadowclaw Slam | 🌐 Global | `SHADOWCLAW SLAM — ÉLOIGNEZ-VOUS !` |
| Primordial Roar | 🌐 Global | `PRIMORDIAL ROAR — TENEZ VOTRE POSITION !` |
| Parasite Expulsion | 🌐 Global | `BLISTERCREEPS — FOCUS LES ADDS !` |
| Parasite Expulsion *(healer)* | 🔒 Private | `BLISTERCREEPS — SOINS RAID !` |
| Parasite Expulsion *(tank)* | 🔒 Private | `BLISTERCREEPS — PICK UP LES ADDS !` |
| Focused Aggression *(tank)* | 🔒 Private | `⚠ ENRAGE — DPS MAXIMUM !` |
| Smashed ×1 *(tank hit)* | 🌐 Global | `SMASHED ×1 — [name] — SWAP TANK !` |
| Smashed ×N *(tank hit)* | 🌐 Global | `SMASHED ×N — [name] — SWAP TANK !` |

---

### 3. Fallen-King Salhadaar

| Mechanic | Type | Alert |
|---|---|---|
| Fractured Projection *(add cast)* | 🌐 Global | `FRACTURED IMAGE — KICK !` |
| Entropic Unraveling | 🌐 Global | `ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !` |
| Void Convergence | 🌐 Global | `VOID CONVERGENCE !` |
| Twisting Obscurity | 🌐 Global | `TWISTING OBSCURITY — SOINS RAID !` |
| Shattering Twilight | 🌐 Global | `SHATTERING TWILIGHT — ATTENTION !` |
| Despotic Command | 🌐 Global | `DESPOTIC COMMAND — UN JOUEUR CIBLÉ !` |
| Despotic Command *(targeted player)* | 🔒 Private | `DESPOTIC COMMAND — BOUGEZ !` |
| Umbral Beams *(targeted player)* | 🔒 Private | `UMBRAL BEAMS — BOUGEZ !` |
| Destabilizing Strikes ×1 *(tank)* | 🔒 Private | `DESTABILIZING STRIKES ×1` |
| Destabilizing Strikes ×5 *(tank)* | 🔒 Private | `DESTABILIZING STRIKES ×5 — SWAP TANK !` |

**Nameplate overlay:** Fractured Image adds show a live KICK / LOIN indicator in range for your interrupt.

**Progress bars:**
- Slot 3 — Fractured Image cast countdown (12s)
- Slot 4 — Entropic Unraveling phase duration (100s)

---

### 4. Vaelgor & Ezzorak

| Mechanic | Type | Alert |
|---|---|---|
| Nullbeam | 🌐 Global | `NULLBEAM — TANK SOAK !` |
| Void Howl | 🌐 Global | `VOID HOWL — GROUPEZ-VOUS !` |
| Gloom | 🌐 Global | `GLOOM — ÉQUIPE SOAK EN POSITION !` |
| Midnight Flames *(intermission)* | 🌐 Global | `INTERMISSION — STACK DANS LE BARRIER !` |
| Nullzone | 🌐 Global | `NULLZONE — ROMPEZ LES LIENS !` |
| Nullzone Implosion | 🌐 Global | `NULLZONE IMPLOSION — SOINS RAID !` |
| Twilight Bond | 🌐 Global | `TWILIGHT BOND — ÉQUILIBREZ LES PV !` |
| Dread Breath *(targeted player)* | 🔒 Private | `DREAD BREATH — SORTEZ SUR LE CÔTÉ !` |
| Diminish *(player who soaked Gloom)* | 🔒 Private | `DIMINISH — NE SOAKEZ PLUS GLOOM !` |

---

### 5. Lightblinded Vanguard

#### Commander Venel Lightblood

| Mechanic | Type | Alert |
|---|---|---|
| Execution Sentence | 🌐 Global | `EXECUTION SENTENCE — SOAK LES CERCLES !` |
| Execution Sentence *(targeted player)* | 🔒 Private | `EXECUTION SENTENCE — NE SUPERPOSEZ PAS !` |
| Sacred Toll | 🌐 Global | `SACRED TOLL — CD DE SOIN !` |
| Aura of Wrath *(100 energy)* | 🌐 Global | `AURA OF WRATH — VENEL SUR LE BORD !` |

#### General Amias Bellamy

| Mechanic | Type | Alert |
|---|---|---|
| Divine Toll | 🌐 Global | `DIVINE TOLL — ÉVITEZ LES BOUCLIERS !` |
| Aura of Devotion *(100 energy)* | 🌐 Global | `AURA OF DEVOTION — BELLAMY SUR LE BORD !` |

#### War Chaplain Senn

| Mechanic | Type | Alert |
|---|---|---|
| Sacred Shield | 🌐 Global | `SACRED SHIELD — BURST LE BOUCLIER !` |
| Blinding Light | 🌐 Global | `BLINDING LIGHT — INTERROMPRE !` |
| Searing Radiance | 🌐 Global | `SEARING RADIANCE — SOINS RAID !` |
| Aura of Peace *(100 energy)* | 🌐 Global | `AURA OF PEACE — SENN SUR LE BORD !` |
| Elekk Charge | 🌐 Global | `ELEKK CHARGE — ESQUIVEZ !` |

#### All bosses

| Mechanic | Type | Alert |
|---|---|---|
| Tyr's Wrath | 🌐 Global | `TYR'S WRATH — ROTATIONNEZ LA POSITION !` |
| Retribution *(boss death)* | 🌐 Global | `RETRIBUTION — ÉQUILIBREZ LES PV !` |

---

### 6. Crown of the Cosmos *(Alleria Windrunner)*

#### Phase 1 — Undying Sentinels

| Mechanic | Type | Alert |
|---|---|---|
| Silverstrike Arrow | 🌐 Global | `SILVERSTRIKE ARROW — VISE UN SENTINEL !` |
| Silverstrike Arrow *(targeted player)* | 🔒 Private | `SILVERSTRIKE ARROW — VISE UN SENTINEL !` |
| Grasp of Emptiness *(targeted player)* | 🔒 Private | `GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !` |
| Null Corona *(targeted player)* | 🔒 Private | `NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !` |
| Void Expulsion | 🌐 Global | `VOID EXPULSION — RANGED BAITEZ !` |
| Interrupting Tremor | 🌐 Global | `INTERRUPTING TREMOR — STOP LES SORTS !` |
| Dark Hand | 🌐 Global | `DARK HAND — INTERROMPRE !` |
| Ravenous Abyss | 🌐 Global | `RAVENOUS ABYSS — SORTEZ DE LA ZONE !` |

#### Phase 2 — Alleria + Rift Simulacrum

| Mechanic | Type | Alert |
|---|---|---|
| Null Corona *(targeted player)* | 🔒 Private | `NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !` |
| Ranger Captain's Mark *(targeted player)* | 🔒 Private | `RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !` |
| Voidstalker Sting *(targeted player)* | 🔒 Private | `VOIDSTALKER STING — DOT SUR TOI (25s) !` |
| Void Expulsion | 🌐 Global | `VOID EXPULSION — RANGED BAITEZ !` |
| Cosmic Barrier | 🌐 Global | `COSMIC BARRIER — BURST LE SIMULACRUM !` |
| Call of the Void | 🌐 Global | `CALL OF THE VOID — ADDS SPAWN !` |

#### Phase 3

| Mechanic | Type | Alert |
|---|---|---|
| Null Corona *(targeted player)* | 🔒 Private | `NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !` |
| Aspect of the End | 🌐 Global | `ASPECT OF THE END — RANGED > MÊLÉE > TANK !` |
| Aspect of the End *(targeted player)* | 🔒 Private | `ASPECT OF THE END — RESTEZ EN PLACE !` |
| Devouring Cosmos | 🌐 Global | `DEVOURING COSMOS — PRENEZ LES PLUMES !` |

---

### 7. Chimaerus the Undreamt God *(Mythic)*

| Mechanic | Type | Alert |
|---|---|---|
| Consuming Miasma *(assigned healer)* | 💊 Dispel | `DISPELL [player name] !` |
| Rift Madness *(targeted player)* | 🔒 Private | `RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !` |
| Alndust Upheaval — Group A | 🌐 Global | `[UPHEAVAL] GROUPE A (1&3) — SOAK !` |
| Alndust Upheaval — Group B | 🌐 Global | `[UPHEAVAL] GROUPE B (2&4) — SOAK !` |
| Alndust Upheaval *(your group's turn)* | 🔒 Private | `TON TOUR DE SOAK — GROUPE A/B` |
| Rending Tear *(tank hit)* | 🔒 Private | `RENDING TEAR SUR TOI — ATTEND LE TAUNT !` |
| Rending Tear *(other tank)* | 🔒 Private | `RENDING TEAR — TAUNT [name] !` |
| Fearsome Cry *(Haunting Essence add)* | 🌐 Global | `FEARSOME CRY — INTERROMPRE !` |
| Consume *(boss channel)* | 🌐 Global | `CONSUME — TUEZ LES ADDS RESTANTS !` |
| Corrupted Devastation *(Phase 2)* | 🌐 Global | `CORRUPTED DEVASTATION — ÉVITEZ LA LIGNE !` |
| Ravenous Dive *(Phase 2 → Phase 1)* | 🌐 Global | `RAVENOUS DIVE — RETOUR PHASE 1 !` |
| Caustic Phlegm | 🌐 Global | `CAUSTIC PHLEGM — DOT RAID !` |
| Dissonance *(wrong realm)* | 🔒 Private | `DISSONANCE — CHANGE DE REALM !` |

**Dispel rotation:** up to 4 healers, RL-configurable. Each Consuming Miasma application cycles to the next healer.

**Nameplate overlay:** Haunting Essence adds show a live KICK / LOIN indicator during the intermission.

**Progress bars:**
- Slot 1 — Consume channel countdown (10s)
- Slot 2 — Rift Madness return timer

---

### 8. Belo'ren

| Mechanic | Type | Alert |
|---|---|---|
| Radiant Echoes | 🌐 Global | `RADIANT ECHOES — BOUGEZ !` |
| Guardian Edict *(targeted player)* | 🔒 Private | `GUARDIAN EDICT — SÉPAREZ-VOUS !` |
| *(other mechanics via BigWigs)* | — | — |

---

## Options & commands

| Command | Description |
|---|---|
| `/lh` | Open the main options panel |
| `/lh debug` | Toggle encounter debug logging |
| `/lhimpertest [void\|umbral\|phase\|reset]` | Test Imperator alerts |
| `/lhsaltest [fracture\|entropic\|despotic]` | Test Salhadaar alerts |
| `/lhchimaertest [upheaval\|miasma\|madness\|rending\|fearsome\|consume\|devastation\|phlegm\|dissonance]` | Test Chimaerus alerts |
| `/lhcrowntest` | Test Crown alerts |

RL and officer options (dispel/kick rotations, group assignments) are only visible to raid leaders and assistants.

---

## Technical notes

- **Detection method:** `COMBAT_LOG_EVENT_UNFILTERED` — `SPELL_CAST_START` / `SPELL_AURA_APPLIED`. Alerts fire at the exact game moment, not from a pre-calculated timer.
- **Spell IDs:** Cross-referenced with BigWigs source files (`BigWigs-master/TheVoidspire/` and `TheDreamrift/`) to ensure accuracy.
- **CLEU registration:** Lazily registered on `ENCOUNTER_START` and unregistered on `ENCOUNTER_END` to avoid `ADDON_ACTION_FORBIDDEN` taint issues specific to Midnight.
- **Anti-spam guards:** Abilities that apply to multiple players simultaneously (raid-wide auras) use a cooldown boolean reset via `C_Timer.After()` to prevent duplicate alerts.
- **Saved variables:** Rotation configurations persist across sessions in `LamentersHelperDB`.

---

*Built by Thiriall & Sacha for the Lamenters raid team.*
