local addonName, M = ...

-- Chimaerus the Undreamt God — The Voidspire (Midnight 12.0) — Mythique
-- NOTE: COMBAT_LOG_EVENT_UNFILTERED bloqué en Midnight (Secret Values Blizzard).
-- Toute détection se fait via ENCOUNTER_TIMELINE_EVENT_ADDED + UNIT_AURA sur player.
local ENCOUNTER_ID = 3306

-- ─── Spell IDs (icônes / sons — non utilisés pour identifier en combat) ──────
local ALNDUST_UPHEAVAL_ID  = 1262289
local RIFT_MADNESS_ID      = 1264756
local CONSUMING_MIASMA_ID  = 1257087
local CONSUMING_MIASMA2_ID = 1257085  -- Phase 2
local RENDING_TEAR_ID      = 1272726
local CAUSTIC_PHLEGM_ID    = 1246653
local CAUSTIC_PHLEGM2_ID   = 1246621  -- Phase 2
local CONSUME_ID           = 1245396
local CORRUPTED_DEV_ID     = 1245486
local RAVENOUS_DIVE_ID     = 1245406
local DISSONANCE_ID        = 1267201

-- ─── Timeline duration → ability (Mythic, source BigWigs + NorthernSkyTools) ─
-- math.floor(eventInfo.duration + 0.5) = durée arrondie
-- Phase 1 :
--   14       → Alndust Upheaval #1
--   73 occ1  → Alndust Upheaval #2
--   24/26/48 → Caustic Phlegm
--   32       → Consuming Miasma (1er)
--   51       → Consuming Miasma (2ème)
--   37       → Consuming Miasma (3ème+)
--   36       → Rending Tear
--   65/66    → Consume
--   10       → Transition Phase 2
--   510      → Enrage
-- Phase 2 :
--   8        → Corrupted Devastation (début)
--   12 impair→ Corrupted Devastation
--   12 pair  → Caustic Phlegm P2
--   9/18     → Caustic Phlegm P2
--   23/29    → Consuming Miasma P2
--   20       → Ravenous Dive (retour P1, Mythic)

-- ─── Rotation de dispel ──────────────────────────────────────────────────────
local miasmaCount = 0

local function GetMiasmaRotation()
    return (M.config and M.config.chimerusMiasmaRotation) or
           { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" }
end

local function IsHealer()
    return M:GetRole() == "HEALER"
end

-- ─── Groupe soak ─────────────────────────────────────────────────────────────
local soakCount   = 0
local breathCount = 0

local function GetPlayerRaidGroup()
    for i = 1, GetNumGroupMembers() do
        local name, _, group = GetRaidRosterInfo(i)
        if name == UnitName("player") then return group end
    end
    return nil
end

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight       = false
local stage         = 1     -- 1 = Phase 1, 2 = Phase 2
local activeTimers  = {}
local trackedAuras  = {}
local durationCount = {}    -- occurrences par durée arrondie (reset par phase)

local frame = CreateFrame("Frame")

-- ─── Helpers alertes ─────────────────────────────────────────────────────────
local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

local function ShowDispel(msg, spellID)
    M:ShowDispelText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("dispel") end
end

-- ─── Consuming Miasma : rotation de dispel ───────────────────────────────────
-- Note: CLEU étant bloqué, le nom de la cible n'est pas disponible.
local function OnMiasmaDetected(spellID)
    miasmaCount = miasmaCount + 1
    local rot      = GetMiasmaRotation()
    local idx      = ((miasmaCount - 1) % #rot) + 1
    local assigned = rot[idx]
    local myName   = UnitName("player")
    local sid      = spellID or CONSUMING_MIASMA_ID

    if IsHealer() then
        ShowPrivate("DISPELS !", sid)
    end
    if myName == assigned then
        ShowDispel("DISPELL !", sid)
    end

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r Miasma #%d → assigné %s [%d/%d]",
            miasmaCount, assigned, idx, #rot))
    end
end

-- ─── Rift Madness : alerte privée (UNIT_AURA sur player) ─────────────────────
local function OnRiftMadnessApplied()
    ShowPrivate("RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !", RIFT_MADNESS_ID)
    trackedAuras.riftBar = true
    C_Timer.After(0, function()
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(RIFT_MADNESS_ID)
        local dur  = aura and aura.duration or 30
        M:ProgressBarCountdown(2, dur, "RIFT MADNESS", "phase", RIFT_MADNESS_ID)
    end)
end

-- ─── Rending Tear : alerte tank (UNIT_AURA sur player) ───────────────────────
local function OnRendingTearApplied()
    ShowPrivate("RENDING TEAR SUR TOI — ATTEND LE TAUNT !", RENDING_TEAR_ID)
end

-- ─── Alndust Upheaval : soak alterné groupes ─────────────────────────────────
local function OnUpheavalDetected()
    soakCount = soakCount + 1
    local isGroupA   = (soakCount % 2 == 1)
    local groupLabel = isGroupA and "GROUPE A (1&3)" or "GROUPE B (2&4)"

    ShowAlert("[UPHEAVAL]  " .. groupLabel .. "  — SOAK !", "soak", ALNDUST_UPHEAVAL_ID)
    M:ProgressBarFill(3, 4, "ADDS SPAWN", "phase", ALNDUST_UPHEAVAL_ID)

    local myGroup = GetPlayerRaidGroup()
    local myTurn  = myGroup and (
        isGroupA and (myGroup == 1 or myGroup == 3) or
        (not isGroupA) and (myGroup == 2 or myGroup == 4)
    )
    if myTurn then
        M:ShowPrivateText("TON TOUR DE SOAK  — " .. groupLabel, ALNDUST_UPHEAVAL_ID)
    end
end

-- ─── Consume : canal boss 10s ────────────────────────────────────────────────
local function OnConsumeCast()
    ShowAlert("CONSUME — TUEZ LES ADDS RESTANTS !", "phase", CONSUME_ID)
    ShowPrivate("CONSUME !", CONSUME_ID)
    M:ProgressBarCountdown(1, 10, "CONSUME", "phase", CONSUME_ID)
    C_Timer.After(7, function()
        if inFight then ShowPrivate("CONSUME — 3 SEC !", CONSUME_ID) end
    end)
end

-- ─── Corrupted Devastation : Phase 2 breath numéroté ────────────────────────
local function OnCorruptedDevCast()
    breathCount = breathCount + 1
    local label = "BREATH " .. breathCount
    ShowAlert(label .. " — ÉVITEZ LA LIGNE !", "phase", CORRUPTED_DEV_ID)
    M:ProgressBarFill(1, 4, label, "phase", CORRUPTED_DEV_ID)
end

-- ─── Ravenous Dive : retour Phase 1 ─────────────────────────────────────────
local function OnRavenousDiveCast()
    breathCount = 0
    stage       = 1
    wipe(durationCount)
    ShowAlert("RAVENOUS DIVE — RETOUR PHASE 1 !", "phase", RAVENOUS_DIVE_ID)
end

-- ─── Caustic Phlegm : DoT raid ───────────────────────────────────────────────
local function OnCausticPhlegm(isPhase2)
    local sid = isPhase2 and CAUSTIC_PHLEGM2_ID or CAUSTIC_PHLEGM_ID
    ShowAlert("CAUSTIC PHLEGM — DOT RAID !", "global", sid)
end

-- ─── UNIT_AURA : debuffs sur le joueur ────────────────────────────────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    -- Dissonance (mauvais realm)
    local dissonance = C_UnitAuras.GetPlayerAuraBySpellID(DISSONANCE_ID)
    if dissonance and not trackedAuras.dissonance then
        trackedAuras.dissonance = true
        ShowPrivate("DISSONANCE — CHANGE DE REALM !", DISSONANCE_ID)
    elseif not dissonance then
        trackedAuras.dissonance = nil
    end

    -- Rift Madness (Mythic, debuff sur soi)
    local riftMadness = C_UnitAuras.GetPlayerAuraBySpellID(RIFT_MADNESS_ID)
    if riftMadness and not trackedAuras.riftMadness then
        trackedAuras.riftMadness = true
        OnRiftMadnessApplied()
    elseif not riftMadness then
        trackedAuras.riftMadness = nil
        if trackedAuras.riftBar then
            M:ProgressBarHide(2)
            trackedAuras.riftBar = nil
        end
    end

    -- Rending Tear (sur soi = je suis le tank avec le debuff)
    local rendingTear = C_UnitAuras.GetPlayerAuraBySpellID(RENDING_TEAR_ID)
    if rendingTear and not trackedAuras.rendingTear then
        trackedAuras.rendingTear = true
        OnRendingTearApplied()
    elseif not rendingTear then
        trackedAuras.rendingTear = nil
    end
end

-- ─── Timeline : identification par durée arrondie ────────────────────────────
local function OnTimelineAdded(eventInfo)
    if not eventInfo then return end
    if eventInfo.source and eventInfo.source ~= 0 then return end

    local d = math.floor(eventInfo.duration + 0.5)
    durationCount[d] = (durationCount[d] or 0) + 1
    local n = durationCount[d]

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r TIMELINE P%d d=%d occ=%d spellID=%s",
            stage, d, n, tostring(eventInfo.spellID)))
    end

    local cb = nil

    if stage == 1 then
        if d == 65 or d == 66 then
            cb = function() OnConsumeCast() end
        elseif d == 14 then
            cb = function() OnUpheavalDetected() end
        elseif d == 73 and n == 1 then
            cb = function() OnUpheavalDetected() end
        elseif d == 32 or d == 51 or d == 37 then
            cb = function() OnMiasmaDetected(CONSUMING_MIASMA_ID) end
        elseif d == 36 then
            cb = function()
                if M:GetRole() == "TANK" then
                    ShowPrivate("RENDING TEAR — SWAP !", RENDING_TEAR_ID)
                end
            end
        elseif d == 24 or d == 26 or d == 48 then
            cb = function() OnCausticPhlegm(false) end
        elseif d == 10 then
            cb = function()
                stage = 2
                wipe(durationCount)
                ShowAlert("PHASE 2 !", "phase")
            end
        end

    elseif stage == 2 then
        if d == 8 then
            cb = function() OnCorruptedDevCast() end
        elseif d == 12 then
            -- Alternance : impair = Corrupted Dev, pair = Caustic Phlegm P2
            if n % 2 == 1 then
                cb = function() OnCorruptedDevCast() end
            else
                cb = function() OnCausticPhlegm(true) end
            end
        elseif d == 9 or d == 18 then
            cb = function() OnCausticPhlegm(true) end
        elseif d == 23 or d == 29 then
            cb = function() OnMiasmaDetected(CONSUMING_MIASMA2_ID) end
        elseif d == 20 then
            cb = function() OnRavenousDiveCast() end
        end
    end

    if cb then
        activeTimers[eventInfo.id] = cb
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == 2 then
        local cb = activeTimers[eventID]
        if cb then cb() end
    end
    if state == 2 or state == 3 then
        activeTimers[eventID] = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight       = false
    stage         = 1
    activeTimers  = {}
    trackedAuras  = {}
    durationCount = {}
    miasmaCount   = 0
    soakCount     = 0
    breathCount   = 0
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    M:ProgressBarHide(3)
    M:ProgressBarHide(4)
end

-- ─── Slash commande de test ───────────────────────────────────────────────────
SLASH_LHCHIMAERTEST1 = "/lhchimaertest"
SlashCmdList["LHCHIMAERTEST"] = function(arg)
    if arg == "upheaval" then
        OnUpheavalDetected()
    elseif arg == "miasma" then
        OnMiasmaDetected(CONSUMING_MIASMA_ID)
    elseif arg == "madness" then
        ShowPrivate("RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !", RIFT_MADNESS_ID)
    elseif arg == "rending" then
        ShowPrivate("RENDING TEAR SUR TOI — ATTEND LE TAUNT !", RENDING_TEAR_ID)
    elseif arg == "consume" then
        OnConsumeCast()
    elseif arg == "devastation" then
        OnCorruptedDevCast()
    elseif arg == "phlegm" then
        ShowAlert("CAUSTIC PHLEGM — DOT RAID !", "global", CAUSTIC_PHLEGM_ID)
    elseif arg == "dissonance" then
        ShowPrivate("DISSONANCE — CHANGE DE REALM !", DISSONANCE_ID)
    elseif arg == "p2" then
        stage = 2
        wipe(durationCount)
        ShowAlert("PHASE 2 — TEST !", "phase")
    end
end

-- ─── Enregistrement des événements ───────────────────────────────────────────
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r START: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            ResetState()
            inFight = true
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if encounterID == ENCOUNTER_ID then
            ResetState()
            M:HideText()
            M:HidePrivateText()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetState()

    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        if not inFight then return end
        OnTimelineAdded(...)

    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        if not inFight then return end
        OnTimelineStateChanged(...)

    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)
    end
end)
