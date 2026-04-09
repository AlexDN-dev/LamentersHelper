local addonName, M = ...

-- Chimaerus the Undreamt God — The Voidspire (Midnight 12.0) — Mythique
-- IMPORTANT: eventInfo.spellID tainté en Midnight → identification par durée.
-- CLEU utilisé pour auras et casts adds/boss.
local ENCOUNTER_ID = 3306   -- confirmé BigWigs TheDreamrift/Chimaerus.lua

-- ─── Spell IDs ────────────────────────────────────────────────────────────────
-- Auras CLEU (SPELL_AURA_APPLIED)
local ALNDUST_UPHEAVAL_ID  = 1262289  -- Soak cercle tank → envoie soakers en Rift
local RIFT_MADNESS_ID      = 1264756  -- Mythic : debuff 2 joueurs Rift (pression croissante)
local CONSUMING_MIASMA_ID  = 1257087  -- Dispellable → explose et détruit flaques
local RENDING_TEAR_ID      = 1272726  -- Tankbuster frontal → debuff tank → SWAP
local CAUSTIC_PHLEGM_ID    = 1246621  -- DoT nature raid 12s
local DISSONANCE_ID        = 1267201  -- Mythic : dégâts si mauvais realm

-- Casts CLEU (SPELL_CAST_START)
local FEARSOME_CRY_ID      = 1249017  -- Add Haunting Essence : AoE fear → INTERROMPRE
local CONSUME_ID           = 1245396  -- Boss canal 10s à 100 énergie → tuer adds
local CORRUPTED_DEV_ID     = 1245486  -- Phase 2 : ligne boss → ÉVITER
local RAVENOUS_DIVE_ID     = 1245406  -- Phase 2 : saut → retour phase 1

-- ─── Rotation de dispel Consuming Miasma ─────────────────────────────────────
local miasmaCount = 0

local function GetMiasmaRotation()
    return (M.config and M.config.chimerusMiasmaRotation) or
           { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" }
end

-- ─── Helpers rôles ───────────────────────────────────────────────────────────
local function IsHealer()
    return M:GetRole() == "HEALER"
end

-- ─── Détection groupe raid (soak) ────────────────────────────────────────────
local soakCount  = 0
local breathCount = 0   -- compteur Corrupted Devastation (Phase 2)

local function GetPlayerRaidGroup()
    for i = 1, GetNumGroupMembers() do
        local name, _, group = GetRaidRosterInfo(i)
        if name == UnitName("player") then return group end
    end
    return nil
end

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight        = false
local activeTimers   = {}
local trackedAuras   = {}
local cleuRegistered = false

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

-- ─── CLEU ─────────────────────────────────────────────────────────────────────
local function RegisterCLEU()
    if not cleuRegistered then
        C_Timer.After(0, function()
            frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            cleuRegistered = true
        end)
    end
end

local function UnregisterCLEU()
    if cleuRegistered then
        C_Timer.After(0, function()
            frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            cleuRegistered = false
        end)
    end
end

-- ─── Consuming Miasma : rotation de dispel ───────────────────────────────────
local function OnMiasmaApplied(destName)
    miasmaCount = miasmaCount + 1
    local rot      = GetMiasmaRotation()
    local idx      = ((miasmaCount - 1) % #rot) + 1
    local assigned = rot[idx]
    local myName   = UnitName("player")

    -- Alerte générale pour tous les heals (texte privé 3 sec)
    if IsHealer() then
        ShowPrivate("DISPELS — |cffffff00" .. destName .. "|r !", CONSUMING_MIASMA_ID)
    end

    -- Alerte spécifique avec son dispel pour le heal assigné
    if myName == assigned then
        ShowDispel("DISPELL  |cffffff00" .. destName .. "|r  !", CONSUMING_MIASMA_ID)
    end

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Chimaerus|r Miasma #%d → %s → assigné %s [%d/%d]",
            miasmaCount, destName, assigned, idx, #rot))
    end
end

-- ─── Rift Madness : alerte privée uniquement ─────────────────────────────────
local function OnRiftMadnessApplied(destName)
    local myName = UnitName("player")

    if myName == destName then
        ShowPrivate("RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !", RIFT_MADNESS_ID)
        -- Countdown : combien de temps le joueur reste dans le Rift
        trackedAuras.riftBar = true
        C_Timer.After(0, function()
            local aura = C_UnitAuras.GetPlayerAuraBySpellID(RIFT_MADNESS_ID)
            local dur  = aura and aura.duration or 30
            M:ProgressBarCountdown(2, dur, "RIFT MADNESS", "phase", RIFT_MADNESS_ID)
        end)
    end

    -- RL voit le nom dans le chat (discret, pas d'alerte écran)
    if IsRaidOfficer() or UnitIsGroupLeader("player") then
        print("|cffff8000LH Chimaerus|r Rift Madness → " .. destName)
    end
end

-- ─── Alndust Upheaval : soak alterné groupes 1&3 / 2&4 ──────────────────────
local function OnUpheavalApplied(destName)
    soakCount = soakCount + 1
    local isGroupA   = (soakCount % 2 == 1)
    local groupLabel = isGroupA and "GROUPE A (1&3)" or "GROUPE B (2&4)"

    ShowAlert("[UPHEAVAL]  " .. groupLabel .. "  — SOAK !", "soak", ALNDUST_UPHEAVAL_ID)
    -- Barre fill : les adds apparaissent dans le Rift dans ~4 sec
    M:ProgressBarFill(3, 4, "ADDS SPAWN", "phase", ALNDUST_UPHEAVAL_ID)

    local myGroup = GetPlayerRaidGroup()
    local myTurn  = myGroup and (
        isGroupA and (myGroup == 1 or myGroup == 3) or
        (not isGroupA) and (myGroup == 2 or myGroup == 4)
    )
    if myTurn then
        -- Texte privé sans son supplémentaire (le son soak a déjà joué)
        M:ShowPrivateText("TON TOUR DE SOAK  — " .. groupLabel, ALNDUST_UPHEAVAL_ID)
    end

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Chimaerus|r Upheaval #%d → %s (groupe=%s, monTour=%s)",
            soakCount, groupLabel, tostring(myGroup), tostring(myTurn)))
    end
end

-- ─── Rending Tear : tankbuster → swap ────────────────────────────────────────
-- Le debuff est appliqué sur le tank actif → l'off-tank doit taunt
local function OnRendingTearApplied(destName)
    local myName = UnitName("player")
    local role   = M:GetRole()

    if myName == destName then
        ShowPrivate("RENDING TEAR SUR TOI — ATTEND LE TAUNT !", RENDING_TEAR_ID)
    elseif role == "TANK" then
        ShowPrivate("RENDING TEAR — TAUNT " .. destName .. " !", RENDING_TEAR_ID)
    end
end

-- ─── Fearsome Cry : cast add → interrompre ───────────────────────────────────
local fearCryCooldown = false

local function OnFearsomeCryCast()
    if fearCryCooldown then return end
    fearCryCooldown = true
    C_Timer.After(3, function() fearCryCooldown = false end)

    ShowAlert("FEARSOME CRY — INTERROMPRE !", "interrupt", FEARSOME_CRY_ID)
end

-- ─── Consume : canal boss → tuer les adds ────────────────────────────────────
local function OnConsumeCast()
    ShowAlert("CONSUME — TUEZ LES ADDS RESTANTS !", "phase", CONSUME_ID)
    ShowPrivate("CONSUME !", CONSUME_ID)
    M:ProgressBarCountdown(1, 10, "CONSUME", "phase", CONSUME_ID)
    -- Rappel 3 sec avant la fin du canal (T+7)
    C_Timer.After(7, function()
        if inFight then ShowPrivate("CONSUME — 3 SEC !", CONSUME_ID) end
    end)
end

-- ─── Corrupted Devastation : Phase 2 ligne ───────────────────────────────────
-- Chaque cast = un "Breath" numéroté. Barre fill 4 sec (cast time).
local function OnCorruptedDevCast()
    breathCount = breathCount + 1
    local label = "BREATH " .. breathCount
    ShowAlert(label .. " — ÉVITEZ LA LIGNE !", "phase", CORRUPTED_DEV_ID)
    M:ProgressBarFill(1, 4, label, "phase", CORRUPTED_DEV_ID)
end

-- ─── Ravenous Dive : transition retour phase 1 ───────────────────────────────
local function OnRavenousDiveCast()
    breathCount = 0   -- reset au retour P1 pour la prochaine transition
    ShowAlert("RAVENOUS DIVE — RETOUR PHASE 1 !", "phase", RAVENOUS_DIVE_ID)
end

-- ─── Timeline : Caustic Phlegm (DoT raid) ────────────────────────────────────
-- Durée 12s — confirmée BigWigs
local function BuildTimerCallback(d)
    if d == 12 then
        return function() ShowAlert("CAUSTIC PHLEGM — DOT RAID !", "global", CAUSTIC_PHLEGM_ID) end
    end
    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local d  = math.floor(eventInfo.duration + 0.5)
    local cb = BuildTimerCallback(d)
    if cb then
        activeTimers[eventInfo.id] = cb
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r CHIMAERUS TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
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

-- ─── UNIT_AURA : Dissonance (mauvais realm) ──────────────────────────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local dissonance = C_UnitAuras.GetPlayerAuraBySpellID(DISSONANCE_ID)
    if dissonance and not trackedAuras.dissonance then
        trackedAuras.dissonance = true
        ShowPrivate("DISSONANCE — CHANGE DE REALM !", DISSONANCE_ID)
    elseif not dissonance then
        trackedAuras.dissonance = nil
    end

    -- Cache la barre Rift Madness quand le debuff disparaît (guard : seulement si elle était active)
    if trackedAuras.riftBar and not C_UnitAuras.GetPlayerAuraBySpellID(RIFT_MADNESS_ID) then
        M:ProgressBarHide(2)
        trackedAuras.riftBar = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight          = false
    activeTimers     = {}
    trackedAuras     = {}
    miasmaCount      = 0
    soakCount        = 0
    breathCount      = 0
    fearCryCooldown  = false
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    M:ProgressBarHide(3)
    M:ProgressBarHide(4)
    UnregisterCLEU()
end

-- ─── Événements ──────────────────────────────────────────────────────────────
-- ─── Slash commande de test ───────────────────────────────────────────────────
SLASH_LHCHIMAERTEST1 = "/lhchimaertest"
SlashCmdList["LHCHIMAERTEST"] = function(arg)
    local me = UnitName("player")
    if arg == "upheaval" then
        soakCount = soakCount + 1
        local isGroupA   = (soakCount % 2 == 1)
        local groupLabel = isGroupA and "GROUPE A (1&3)" or "GROUPE B (2&4)"
        ShowAlert("[UPHEAVAL]  " .. groupLabel .. "  — SOAK !", "soak", ALNDUST_UPHEAVAL_ID)
        M:ShowPrivateText("TON TOUR DE SOAK  — " .. groupLabel, ALNDUST_UPHEAVAL_ID)
    elseif arg == "miasma" then
        miasmaCount = miasmaCount + 1
        local rot = GetMiasmaRotation()
        local idx = ((miasmaCount - 1) % #rot) + 1
        ShowDispel("DISPELL  |cffffff00" .. me .. "|r  !", CONSUMING_MIASMA_ID)
    elseif arg == "madness" then
        ShowPrivate("RIFT MADNESS — UN JOUEUR VIENT TE COUVRIR !", RIFT_MADNESS_ID)
    elseif arg == "rending" then
        ShowPrivate("RENDING TEAR SUR TOI — ATTEND LE TAUNT !", RENDING_TEAR_ID)
        ShowPrivate("RENDING TEAR — TAUNT " .. me .. " !", RENDING_TEAR_ID)
    elseif arg == "fearsome" then
        OnFearsomeCryCast()
    elseif arg == "consume" then
        OnConsumeCast()
    elseif arg == "devastation" then
        OnCorruptedDevCast()
    elseif arg == "phlegm" then
        ShowAlert("CAUSTIC PHLEGM — DOT RAID !", "global", CAUSTIC_PHLEGM_ID)
    elseif arg == "dissonance" then
        ShowPrivate("DISSONANCE — CHANGE DE REALM !", DISSONANCE_ID)
    end
end

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
            RegisterCLEU()
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

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not inFight then return end
        local _, subevent, _, _, srcName, _, _, _, destName, _, _, spellId = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_AURA_APPLIED" then
            if    spellId == CONSUMING_MIASMA_ID then OnMiasmaApplied(destName)
            elseif spellId == RIFT_MADNESS_ID    then OnRiftMadnessApplied(destName)
            elseif spellId == ALNDUST_UPHEAVAL_ID then OnUpheavalApplied(destName)
            elseif spellId == RENDING_TEAR_ID    then OnRendingTearApplied(destName)
            end

        elseif subevent == "SPELL_CAST_START" then
            if    spellId == FEARSOME_CRY_ID  then OnFearsomeCryCast()
            elseif spellId == CONSUME_ID       then OnConsumeCast()
            elseif spellId == CORRUPTED_DEV_ID then OnCorruptedDevCast()
            elseif spellId == RAVENOUS_DIVE_ID then OnRavenousDiveCast()
            end
        end
    end
end)
