local addonName, M = ...

-- Chimaerus the Undreamt God — The Voidspire (Midnight 12.0) — Mythique
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
local ENCOUNTER_ID = 3178   -- à confirmer en jeu via debugEncounter

-- ─── Spell IDs ────────────────────────────────────────────────────────────────
local ALNDUST_UPHEAVAL_ID  = 1262289  -- Soak cercle ciblant le tank → envoie les soakers en Rift
local RIFT_MADNESS_ID      = 1264756  -- Mythic : debuff sur 2 joueurs Rift (dont 1 healer)
local CONSUMING_MIASMA_ID  = 1257087  -- Debuff dispellable → explosion AoE qui détruit les flaques
local RENDING_TEAR_ID      = 1272726  -- Tankbuster frontal + knockback → swap tank
local CAUSTIC_PHLEGM_ID    = 1246621  -- DoT nature raid-wide 12s
local RIFT_EMERGENCE_ID    = 1258610  -- Spawn adds dans le Rift
local CONSUME_ID           = 1245396  -- Canal 10s à 100 énergie — mange les adds restants
local CORRUPTED_DEV_ID     = 1245486  -- Phase 2 : ligne + avancée boss
local RAVENOUS_DIVE_ID     = 1245406  -- Phase 2 : saut au sol → retour phase 1
local FEARSOME_CRY_ID      = 1249017  -- Add : AoE fear → interruption requise
local DISSONANCE_ID        = 1267201  -- Mythic : pulsion dégâts si realms mélangés

-- ─── Rotation de dispel Consuming Miasma ─────────────────────────────────────
local miasmaCount = 0

local function GetMiasmaRotation()
    return (M.config and M.config.chimerusMiasmaRotation) or
           { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" }
end

-- ─── Groupes de soak Alndust Upheaval ────────────────────────────────────────
-- Groupe A (groupes 1&3) et Groupe B (groupes 2&4) alternent à chaque soak
local soakCount = 0

local function GetSoakGroupA()
    return (M.config and M.config.chimaeraSoakGroupA) or {}
end

local function GetSoakGroupB()
    return (M.config and M.config.chimaeraSoakGroupB) or {}
end

local function InTable(t, val)
    for _, v in ipairs(t) do
        if v == val then return true end
    end
    return false
end

-- ─── Swap pairs Rift Madness ──────────────────────────────────────────────────
-- Un debuff tombe toujours sur un healer → son partenaire Reality doit le couvrir
local function GetRiftMadnessPairs()
    return (M.config and M.config.chimaeraMadnessPairs) or {}
    -- Format : { {healer="Smiths", partner="Thiriäll"}, ... }
end

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight         = false
local activeTimers    = {}
local trackedAuras    = {}
local cleuRegistered  = false

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

    ShowAlert("|cff80ff80[MIASMA]|r  " .. destName .. "  — DISPELL !", "dispel", CONSUMING_MIASMA_ID)

    if myName == assigned then
        ShowDispel("DISPELL  |cffffff00" .. destName .. "|r  !", CONSUMING_MIASMA_ID)
    end

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Chimaerus|r Miasma #%d → %s → assigné %s [%d/%d]",
            miasmaCount, destName, assigned, idx, #rot))
    end
end

-- ─── Rift Madness : alerte swap pair ─────────────────────────────────────────
local function OnRiftMadnessApplied(destName)
    local myName = UnitName("player")

    -- Alerte globale
    ShowAlert("|cffff8000[RIFT MADNESS]|r  " .. destName .. "  — COUVREZ !", "phase", RIFT_MADNESS_ID)

    -- Alerte privée pour la cible
    if myName == destName then
        ShowPrivate("RIFT MADNESS SUR TOI — TON PARTENAIRE ARRIVE !", RIFT_MADNESS_ID)
        return
    end

    -- Alerte privée pour le partenaire
    local pairs = GetRiftMadnessPairs()
    for _, pair in ipairs(pairs) do
        local isTarget  = (pair.healer == destName or pair.partner == destName)
        local isPartner = (pair.healer == myName   or pair.partner == myName)
        if isTarget and isPartner then
            ShowPrivate("TON PARTENAIRE A RIFT MADNESS — COUVRE " .. destName .. " !", RIFT_MADNESS_ID)
            return
        end
    end
end

-- ─── Alndust Upheaval : soak par groupe alterné ───────────────────────────────
local function OnUpheavalApplied(destName)
    soakCount = soakCount + 1
    local myName = UnitName("player")
    local groupA = GetSoakGroupA()
    local groupB = GetSoakGroupB()

    -- Groupe actif ce tour
    local activeGroup, groupLabel
    if soakCount % 2 == 1 then
        activeGroup = groupA
        groupLabel  = "GROUPE A (1&3)"
    else
        activeGroup = groupB
        groupLabel  = "GROUPE B (2&4)"
    end

    ShowAlert("|cffffff00[UPHEAVAL]|r  " .. groupLabel .. "  — SOAK !", "soak", ALNDUST_UPHEAVAL_ID)

    if InTable(activeGroup, myName) then
        ShowPrivate("SOAK  |cffffff00" .. groupLabel .. "|r  — TON TOUR !", ALNDUST_UPHEAVAL_ID)
    end

    if M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Chimaerus|r Upheaval #%d → %s actif (moi=%s, dans groupe=%s)",
            soakCount, groupLabel, myName, tostring(InTable(activeGroup, myName))))
    end
end

-- ─── Timeline callbacks ───────────────────────────────────────────────────────
-- Les durées réelles BigWigs sont à confirmer en jeu (debugEncounter)
-- On utilise CLEU pour les auras, et timeline pour les casts boss
local function BuildTimerCallback(d)
    -- Rending Tear (tankbuster) — durée typique ~2-3s cast
    if d == 2 or d == 3 then
        return function()
            local role = M:GetRole()
            if role == "TANK" then
                ShowPrivate("RENDING TEAR — FRONTALE + KNOCKBACK !", RENDING_TEAR_ID)
            else
                ShowAlert("RENDING TEAR — TANKBUSTER !", "interrupt", RENDING_TEAR_ID)
            end
        end
    -- Consume (canal 100 énergie) — durée 10s
    elseif d == 10 then
        return function() ShowAlert("CONSUME — TUEZ LES ADDS RESTANTS !", "phase", CONSUME_ID) end
    -- Caustic Phlegm (DoT raid) — durée 12s
    elseif d == 12 then
        return function() ShowAlert("CAUSTIC PHLEGM — DOT RAID !", "global", CAUSTIC_PHLEGM_ID) end
    -- Corrupted Devastation Phase 2 — durée à confirmer
    elseif d == 5 or d == 6 then
        return function() ShowAlert("CORRUPTED DEVASTATION — ÉVITEZ LA LIGNE !", "phase", CORRUPTED_DEV_ID) end
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

-- ─── UNIT_AURA : auras privées ───────────────────────────────────────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    -- Dissonance (Mythic) — tu es dans le mauvais realm
    local dissonance = C_UnitAuras.GetPlayerAuraBySpellID(DISSONANCE_ID)
    if dissonance and not trackedAuras.dissonance then
        trackedAuras.dissonance = true
        ShowPrivate("DISSONANCE — CHANGE DE REALM !", DISSONANCE_ID)
    elseif not dissonance then
        trackedAuras.dissonance = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight       = false
    activeTimers  = {}
    trackedAuras  = {}
    miasmaCount   = 0
    soakCount     = 0
    UnregisterCLEU()
end

-- ─── Événements ──────────────────────────────────────────────────────────────
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
        local _, subevent, _, _, _, _, _, _, destName, _, _, spellId = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_AURA_APPLIED" then
            if spellId == CONSUMING_MIASMA_ID then
                OnMiasmaApplied(destName)
            elseif spellId == RIFT_MADNESS_ID then
                OnRiftMadnessApplied(destName)
            elseif spellId == ALNDUST_UPHEAVAL_ID then
                OnUpheavalApplied(destName)
            end
        end
    end
end)
