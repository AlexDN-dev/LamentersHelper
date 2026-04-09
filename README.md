# LamentersHelper

Addon WoW privé pour le raid **The Lamenters** — *The Voidspire* & *The Dreamrift* (Midnight 12.0).

Affiche des alertes texte (globales et/ou privées) et des barres de progression en réponse aux mécaniques de boss, détectées via le combat log, les auras joueur, et la timeline de rencontre.

> **Compatibilité :** Midnight 12.0 — Difficulté Mythique  
> **Auteurs :** Sacha, Thyrial

---

## Fonctionnalités principales

| Fonctionnalité | Description |
|---|---|
| **Alertes globales** | Texte affiché à l'écran pour tout le raid |
| **Alertes privées** | Texte visible uniquement par le joueur concerné (rôle, aura, ciblage) |
| **Barres de progression** | Countdown personnalisé pour les mécaniques non couvertes par BigWigs |
| **Rotation de dispel** | Assignation automatique des dispels par ordre de rotation |
| **Jeu de mémoire L'ura** | Panneau caller + diagramme circulaire partagé via addon message |
| **Grille Imperator** | Résolution automatique du Tic-Tac-Toe Vide/Lumière |
| **Sync de version** | Vérification que tout le raid a l'addon à jour (`/lhcheck`) |

---

## Commandes

| Commande | Description |
|---|---|
| `/lh` | Ouvre/ferme le panneau d'options |
| `/lhcheck` | Vérifie quels joueurs du raid ont l'addon installé |
| `/lhbeloren void\|light` | Définit manuellement ton aura Vide/Lumière (Belo'ren) |
| `/lhbeloren aura` | Affiche ton aura actuelle |

---

## Barres de progression

4 slots de barre, positionnés au centre de l'écran (position ajustable dans `/lh → Affichage`).  
Chaque type d'alerte a sa propre couleur de barre :

| Type | Couleur |
|---|---|
| `phase` | Bleu |
| `soak` | Jaune |
| `interrupt` | Rouge |
| `dispel` | Violet |
| `private` | Orange |
| `global` | Blanc |

---

## Alertes par boss

### The Voidspire

---

### 1. Imperator Averzian — ID 3176

| Mécanique | Type | Message |
|---|---|---|
| Shadow's Advance | 🌐 Global | `SHADOW'S ADVANCE — PHASE PLATEAU !` |
| Oblivion's Wrath | 🌐 Global | `OBLIVION'S WRATH — BOUGEZ !` |
| Void Rupture *(Voidshaper)* | 🌐 Global | `VOID RUPTURE — SOAK / INTERROMPRE !` |
| Pitch Bulwark *(Stalwart / Annihilator)* | 🌐 Global | `PITCH BULWARK — INTERROMPRE !` |
| Void Fall | 🌐 Global | `VOID FALL — ÉVITEZ LES ZONES !` |
| Umbral Collapse | 🌐 Global | `UMBRAL COLLAPSE — SOAK !` |
| Umbral Collapse *(joueur ciblé)* | 🔒 Privé | `UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !` |
| Imperator's Glory | 🌐 Global | `IMPERATOR'S GLORY — ÉLOIGNEZ LE BOSS !` |

> **Bonus :** Grille Tic-Tac-Toe automatique pour la phase Vide/Lumière (module `imperator/grid.lua`).

---

### 2. Vorasius — ID 3177

| Mécanique | Type | Message |
|---|---|---|
| Void Breath | 🌐 Global | `VOID BREATH — ÉVITEZ LE CÔNE !` |
| Shadowclaw Slam | 🌐 Global | `SHADOWCLAW SLAM — ÉLOIGNEZ-VOUS !` |
| Primordial Roar | 🌐 Global | `PRIMORDIAL ROAR — TENEZ VOTRE POSITION !` |
| Parasite Expulsion | 🌐 Global | `BLISTERCREEPS — FOCUS LES ADDS !` |
| Overpowering Pulse | 🌐 Global | `PULSE — APPROCHEZ LE BOSS !` |
| Focused Aggression | 🌐 Global | `⚠ ENRAGE — PUSH DPS MAXIMUM !` |
| Smashed ×1 *(tank)* | 🌐 Global | `SMASHED ×1 — [nom] — SWAP TANK !` |
| Smashed ×N *(tank, stacks)* | 🌐 Global + 📊 Barre | `SMASHED ×N — [nom] — SWAP TANK !` |
| Blisterburst | 🌐 Global + 📊 Barre | `BLISTERBURST — +100% DÉGÂTS (30s) !` |

> **Barres :** Slot 1 = Blisterburst (countdown 30s), Slot 2 = Smashed stacks.

---

### 3. Fallen-King Salhadaar — ID 3179

| Mécanique | Type | Message |
|---|---|---|
| Twisting Obscurity | 🌐 Global | `TWISTING OBSCURITY — SOINS RAID !` |
| Shattering Twilight | 🌐 Global | `SHATTERING TWILIGHT — ATTENTION !` |
| Fractured Projection | 🌐 Global | `FRACTURED IMAGE INVOQUÉ — INTERROMPEZ (12s) !` |
| Despotic Command | 🌐 Global | `DESPOTIC COMMAND — UN JOUEUR CIBLÉ !` |
| Despotic Command *(joueur ciblé)* | 🔒 Privé | `DESPOTIC COMMAND — BOUGEZ !` |
| Void Convergence | 🌐 Global | `VOID CONVERGENCE !` |
| Entropic Unraveling | 🌐 Global | `ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !` |
| Umbral Beams | 🌐 Global | `UMBRAL BEAMS — DÉPLACEZ-VOUS !` |
| Destabilizing Strikes ×1 *(tank)* | 🌐 Global | `DESTABILIZING STRIKES ×1 — [nom]` |
| Destabilizing Strikes ×N *(seuil)* | 🌐 Global | `DESTABILIZING STRIKES ×N — [nom] — SWAP TANK !` |

---

### 4. Vaelgor & Ezzorak — ID 3178

| Mécanique | Type | Message |
|---|---|---|
| Nullbeam | 🌐 Global | `NULLBEAM — TANK SOAK !` |
| Void Howl | 🌐 Global | `VOID HOWL — GROUPEZ-VOUS !` |
| Gloom | 🌐 Global | `GLOOM — ÉQUIPE SOAK EN POSITION !` |
| Midnight Flames *(intermission)* | 🌐 Global | `INTERMISSION — STACK DANS LE BARRIER !` |
| Nullzone | 🌐 Global | `NULLZONE — ROMPEZ LES LIENS !` |
| Nullzone Implosion | 🌐 Global | `NULLZONE IMPLOSION — SOINS RAID !` |
| Twilight Bond | 🌐 Global | `TWILIGHT BOND — ÉQUILIBREZ LES PV !` |
| Dread Breath *(joueur ciblé)* | 🔒 Privé | `DREAD BREATH — SORTEZ SUR LE CÔTÉ !` |
| Diminish *(après soak Gloom)* | 🔒 Privé | `DIMINISH — NE SOAKEZ PLUS GLOOM !` |

---

### 5. Lightblinded Vanguard — ID 3180

#### Commander Venel Lightblood

| Mécanique | Type | Message |
|---|---|---|
| Execution Sentence | 🌐 Global | `EXECUTION SENTENCE — SOAK LES CERCLES !` |
| Execution Sentence *(joueur ciblé)* | 🔒 Privé | `EXECUTION SENTENCE — NE SUPERPOSEZ PAS !` |
| Sacred Toll | 🌐 Global | `SACRED TOLL — CD DE SOIN !` |
| Aura of Wrath *(100 énergie)* | 🌐 Global | `AURA OF WRATH — VENEL SUR LE BORD !` |

#### General Amias Bellamy

| Mécanique | Type | Message |
|---|---|---|
| Divine Toll | 🌐 Global | `DIVINE TOLL — ÉVITEZ LES BOUCLIERS !` |
| Aura of Devotion *(100 énergie)* | 🌐 Global | `AURA OF DEVOTION — BELLAMY SUR LE BORD !` |

#### War Chaplain Senn

| Mécanique | Type | Message |
|---|---|---|
| Sacred Shield | 🌐 Global | `SACRED SHIELD — BURST LE BOUCLIER !` |
| Blinding Light | 🌐 Global | `BLINDING LIGHT — INTERROMPRE !` |
| Searing Radiance | 🌐 Global | `SEARING RADIANCE — SOINS RAID !` |
| Aura of Peace *(100 énergie)* | 🌐 Global | `AURA OF PEACE — SENN SUR LE BORD !` |
| Elekk Charge | 🌐 Global | `ELEKK CHARGE — ESQUIVEZ !` |

#### Tous les boss

| Mécanique | Type | Message |
|---|---|---|
| Tyr's Wrath | 🌐 Global | `TYR'S WRATH — ROTATIONNEZ LA POSITION !` |
| Retribution *(mort d'un boss)* | 🌐 Global | `RETRIBUTION — ÉQUILIBREZ LES PV !` |

---

### 6. Crown of the Cosmos *(Alleria Windrunner)* — ID 3181

#### Phase 1 — Undying Sentinels

| Mécanique | Type | Message |
|---|---|---|
| Void Expulsion | 🌐 Global | `VOID EXPULSION — RANGED BAITEZ !` |
| Interrupting Tremor *(Demair)* | 🌐 Global | `INTERRUPTING TREMOR — STOP LES SORTS !` |
| Silverstrike Arrow *(joueur ciblé)* | 🔒 Privé | `SILVERSTRIKE ARROW — VISE UN SENTINEL !` |
| Grasp of Emptiness *(joueur ancré)* | 🔒 Privé | `GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !` |
| Null Corona *(joueur ciblé)* | 🔒 Privé | `NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !` |

#### Intermissions (1 & 2)

| Mécanique | Type | Message |
|---|---|---|
| Silverstrike Barrage | 🌐 Global | `SILVERSTRIKE BARRAGE — PRENEZ UNE FLÈCHE PUIS ÉVITEZ !` |
| Singularity Eruption | 🌐 Global | `SINGULARITY ERUPTION — ÉVITEZ LES FLAQUES !` |

#### Phase 2 — Alleria + Rift Simulacrum

| Mécanique | Type | Message |
|---|---|---|
| Void Expulsion | 🌐 Global | `VOID EXPULSION — RANGED BAITEZ !` |
| Call of the Void | 🌐 Global | `CALL OF THE VOID — ADDS SPAWN !` |
| Void Barrage *(adds)* | 🌐 Global | `VOID BARRAGE — INTERROMPRE !` |
| Cosmic Barrier | 🌐 Global | `COSMIC BARRIER — BURST LE SIMULACRUM !` |
| Ranger Captain's Mark *(joueur ciblé)* | 🔒 Privé | `RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !` |
| Voidstalker Sting *(joueur ciblé)* | 🔒 Privé | `VOIDSTALKER STING — DOT SUR TOI (25s) !` |

#### Phase 3

| Mécanique | Type | Message |
|---|---|---|
| Aspect of the End | 🌐 Global + 📊 Barre | `ASPECT OF THE END — RANGED > MÊLÉE > TANK !` |
| Aspect of the End *(joueur lié)* | 🔒 Privé | `ASPECT OF THE END — RESTEZ EN PLACE !` |
| Devouring Cosmos | 🌐 Global | `DEVOURING COSMOS — PRENEZ LES PLUMES !` |

---

### 7. Belo'ren, Enfant d'Al'ar — ID 3182

> **Système d'auras :** Chaque joueur reçoit une aura **Vide** ou **Lumière** à chaque essai (auto-détectée via UNIT_AURA, ou définie manuellement via `/lhbeloren void|light`). L'aura détermine qui soak les plongées, qui ramasse les orbes, et qui interrompt les adds.

| Mécanique | Type | Message |
|---|---|---|
| Plongée Vide/Lumière *(marqué)* | 🔒 Privé | `TU ES MARQUÉ [AURA] — PLACE-TOI EN BORDURE !` |
| Plongée Vide/Lumière *(soakers)* | 🌐 Global + 🔒 Privé | `PLONGÉE [AURA] [nom] — [AURA] SOAKEZ !` |
| Piquants Infusés *(marqué)* | 🔒 Privé | `PIQUANT SUR TOI — [AURA] TE COUVRE !` |
| Piquants Infusés *(soakers)* | 🌐 Global + 🔒 Privé | `PIQUANT [AURA] [nom] — [AURA] SOAK !` |
| Édit du Gardien *(tank)* | 🌐 Global + 🔒 Privé | `ÉDIT DU GARDIEN — TANKS CÔNE COLORÉ BOSS +20% DMG !` |
| Échos Rayonnants *(orbes)* | 🌐 Global + 🔒 Privé | `ORBES — RAMASSEZ VOS COULEURS !` |
| Add Éruption *(interrupt matching)* | 🌐 Global + 🔒 Privé | `ADD ÉRUPTION [AURA] — INTERRUPT [AURA] !` |
| Renaissance *(œuf 15s)* | 🌐 Global + 📊 Barre | `RENAISSANCE — TUEZ L'ŒUF 15s !` + rappel à 5s restantes |
| Chute Mortelle *(transition P2)* | 🌐 Global | `CHUTE MORTELLE — ÉLOIGNEZ-VOUS DU CENTRE !` |
| Brûlures Éternelles *(tank + healers)* | 🔒 Privé | `BRÛLURES ÉTERNELLES — SOIGNE TON/L'ABSORB !` |
| Phase 2 — Incubation des Flammes | 🌐 Global + 🔒 Privé + 📊 Barre | `PHASE 2 — REJOIGNEZ VOS ZONES DPS L'ŒUF !` (30s) |
| Bénédiction Cendre *(stacks)* | 🌐 Global | `BÉNÉDICTION CENDRE [⚠ STACK N] — BURST MAX !` |
| Rappel d'aura | 🔒 Privé | `TON AURA : [VIDE/LUMIÈRE]` *(toutes les 60s)* |

> **Barres :** Slot 1 = Incubation des Flammes (30s), Slot 2 = Renaissance œuf (15s).

---

### The Dreamrift

---

### 8. Chimaerus the Undreamt God — ID 3306

| Mécanique | Type | Message |
|---|---|---|
| Consuming Miasma | 💜 Dispel | `DISPELL [nom] !` *(healers en rotation assignée)* |
| Rift Madness *(joueur ciblé)* | 🔒 Privé + 📊 Barre | `RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !` |
| Alndust Upheaval *(soak alterné)* | 🌐 Global + 🔒 Privé | `[UPHEAVAL] GROUPE A (1&3) / B (2&4) — SOAK !` |
| Rending Tear *(tankbuster → swap)* | 🔒 Privé | `RENDING TEAR SUR TOI` / `RENDING TEAR — TAUNT [nom] !` |
| Fearsome Cry *(add, fear AoE)* | 🌐 Global | `FEARSOME CRY — INTERROMPRE !` |
| Consume *(canal 10s à 100 énergie)* | 🌐 Global + 📊 Barre | `CONSUME — TUEZ LES ADDS RESTANTS !` (10s) |
| Corrupted Devastation *(Phase 2)* | 🌐 Global | `CORRUPTED DEVASTATION — ÉVITEZ LA LIGNE !` |
| Ravenous Dive *(retour Phase 1)* | 🌐 Global | `RAVENOUS DIVE — RETOUR PHASE 1 !` |
| Caustic Phlegm *(DoT raid)* | 🌐 Global | `CAUSTIC PHLEGM — DOT RAID !` |
| Dissonance *(mauvais realm)* | 🔒 Privé | `DISSONANCE — CHANGE DE REALM !` |

> **Barres :** Slot 1 = Consume (10s), Slot 2 = Rift Madness (durée du debuff).  
> **Rotation Miasma :** Configurable dans `/lh → Chimaerus` (ordre des healers dispel).

---

### 9. L'ura — ID 3183

> **Système de mémoire des runes :** L'ura demande au raid de mémoriser et reproduire une séquence de 5 runes. LamentersHelper propose un outil dédié RL + viewer pour tout le raid.

| Rôle | Fonctionnalité |
|---|---|
| **RL / Assistant** | Panneau caller : clique sur les runes dans l'ordre → *Envoyer* → séquence partagée au raid |
| **Tout le raid** | Diagramme circulaire auto-affiché à réception, avec numérotation de l'ordre |
| **Reset auto** | Le diagramme se cache automatiquement à T+32s, T+102s, T+172s (fin de chaque phase) |

**5 runes disponibles :** Triangle, Diamond, Cercle, Croix, T

> Le panneau caller s'ouvre via `/lh → L'ura` ou depuis les options.  
> Le diagramme est déplaçable à l'écran (hors combat).

---

## Développement

### Debug mode

Activez `debugEncounter` dans `/lh → Affichage → Développement` pour afficher dans le chat toutes les durées de timeline reçues — utile pour identifier de nouveaux spell IDs ou calibrer les timers.

**⚠ Désactivez avant un vrai raid** pour éviter le spam chat.

### Compatibilité Midnight 12.0 (taint)

- `aura.spellId` retourné par `GetAuraDataByIndex` est une **valeur secrète taintée** en Midnight — comparaison directe interdite.
- L'addon utilise exclusivement `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` pour la détection d'auras joueur.
- Les spell IDs du combat log (`CombatLogGetCurrentEventInfo`) ne sont **pas** taintés.
- Les `RegisterEvent` / `UnregisterEvent` depuis un handler CLEU sont différés via `C_Timer.After(0, ...)`.
