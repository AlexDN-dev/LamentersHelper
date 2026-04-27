local addonName, M = ...

-- Vaelgor & Ezzorak — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Détection principale via CLEU (SPELL_CAST_START) pour Dread Breath et Void Howl :
--   plus précis que les timers car fire au moment exact du cast, indépendamment de la phase.
-- CLEU spellIDs ne sont PAS taintés en Midnight — comparaison directe sûre.
local ENCOUNTER_ID = 3178

-- ─── Spell IDs (CLEU — non taintés) ──────────────────────────────────────────
local SPELL_DREAD_BREATH    = 1244221  -- Souffle Redoutable (Vaelgor) → fear AoE
local SPELL_VOID_HOWL       = 1244917  -- Hurlement du Vide (Ezzorak) → spread 2.5s cast
local SPELL_RADIANT_BARRIER = 1248847  -- Barrière Radieuse → début intermission
local SPELL_NULLBEAM        = 1262623  -- Rayon du Néant → tank soak
local SPELL_GLOOM           = 1245391  -- Déprime → soak rotation
local SPELL_VAELWING        = 1265131  -- Aile du Vide → adds sur joueurs
-- Auras joueur (UNIT_AURA — GetPlayerAuraBySpellID, non tainté)
local SPELL_NULLZONE        = 1244672  -- Zone du Néant → debuff joueur ciblé
local SPELL_DIMINISH        = 1270852  -- Diminution → ne plus soak Gloom

-- Durée cast de Dread Breath (en secondes) — à confirmer via debugEncounter
-- BigWigs ne liste pas le cast time directement ; 3s est une estimation.
local DREAD_BREATH_CAST     = 3.0
-- Durée intermission Radiant Barrier (BigWigs : ~120s Mythic)
local INTERMISSION_DURATION = 120

-- ─── État ─────────────────────────────────────────────────────────────────────
local inFight        = false
local trackedAuras   = {}
local activeTimers   = {}
local breathCooldown = false  -- anti-spam si double event
local howlCooldown   = false

local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

-- ─── Handlers CLEU ───────────────────────────────────────────────────────────

-- Dread Breath : Vaelgor caste → tout le monde doit se retourner / absorber le fear
-- Barre courte = cast time restant (comme Echo "BREATH 2.4")
local function OnDreadBreath()
    if breathCooldown then return end
    breathCooldown = true
    C_Timer.After(DREAD_BREATH_CAST + 1, function() breathCooldown = false end)
    ShowAlert("FEAR — SOUFFLE REDOUTABLE !", "interrupt", SPELL_DREAD_BREATH)
    M:ProgressBarCountdown(2, DREAD_BREATH_CAST, "FEAR — SOUFFLE REDOUTABLE", "interrupt", SPELL_DREAD_BREATH)
end

-- Void Howl : Ezzorak caste → SPREAD (2.5s pour s'écarter de ses voisins)
local function OnVoidHowl()
    if howlCooldown then return end
    howlCooldown = true
    C_Timer.After(2.5 + 1, function() howlCooldown = false end)
    ShowAlert("SPREAD — HURLEMENT DU VIDE !", "soak", SPELL_VOID_HOWL)
    M:ProgressBarCountdown(3, 2.5, "SPREAD — ÉCARTEZ-VOUS", "soak", SPELL_VOID_HOWL)
end

-- Radiant Barrier : début intermission → barre de durée complète
local function OnIntermission()
    ShowAlert("INTERMISSION — STACK DANS LE BARRIER !", "phase", SPELL_RADIANT_BARRIER)
    M:ProgressBarCountdown(4, INTERMISSION_DURATION, "INTERMISSION — BARRIER", "phase", SPELL_RADIANT_BARRIER)
end

-- ─── Timeline (mécaniques sans cast détectable) ───────────────────────────────
-- Nullbeam, Gloom et Vaelwing restent sur timeline car pas de cast CLEU fiable.
local function BuildTimerCallback(d)
    if d == 30 or d == 18 or d == 45 then
        return function() ShowAlert("NULLBEAM — TANK SOAK !", "soak", SPELL_NULLBEAM) end
    elseif d == 10 or d == 48 or d == 25 then
        return function() ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak", SPELL_GLOOM) end
    elseif d == 6 or d == 19 or d == 21 then
        return function() ShowAlert("VAELWING — ÉCARTEZ-VOUS !", "global", SPELL_VAELWING) end
    end
    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local d = math.floor(eventInfo.duration + 0.5)
    local cb = BuildTimerCallback(d)
    if cb then
        activeTimers[eventInfo.id] = cb
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r DRAKES TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
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

-- ─── UNIT_AURA : debuffs joueur ───────────────────────────────────────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local nullzone = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_NULLZONE)
    if nullzone and not trackedAuras.nullzone then
        trackedAuras.nullzone = true
        ShowPrivate("NULLZONE — BOUGEZ !", SPELL_NULLZONE)
        local dur = (nullzone.expirationTime and nullzone.expirationTime > 0)
                    and (nullzone.expirationTime - GetTime())
                    or (nullzone.duration or 10)
        M:ProgressBarCountdown(1, dur, "NULLZONE", "soak", SPELL_NULLZONE)
    elseif not nullzone then
        trackedAuras.nullzone = nil
        M:ProgressBarHide(1)
    end

    local diminish = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_DIMINISH)
    if diminish and not trackedAuras.diminish then
        trackedAuras.diminish = true
        ShowPrivate("DIMINISH — NE SOAKEZ PLUS GLOOM !", SPELL_DIMINISH)
    elseif not diminish then
        trackedAuras.diminish = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight      = false
    trackedAuras = {}
    activeTimers = {}
    breathCooldown = false
    howlCooldown   = false
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    M:ProgressBarHide(3)
    M:ProgressBarHide(4)
end

-- ─── Événements ───────────────────────────────────────────────────────────────
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
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
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
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
        local _, subevent, _, _, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_CAST_START" then
            if spellId == SPELL_DREAD_BREATH then
                OnDreadBreath()
            elseif spellId == SPELL_VOID_HOWL then
                OnVoidHowl()
            end

        elseif subevent == "SPELL_AURA_APPLIED" then
            -- Radiant Barrier peut être un AURA_APPLIED (shield) plutôt qu'un CAST
            if spellId == SPELL_RADIANT_BARRIER then
                OnIntermission()
            end

        elseif subevent == "SPELL_CAST_SUCCESS" then
            -- Fallback si Radiant Barrier fire sur CAST_SUCCESS au lieu de AURA_APPLIED
            if spellId == SPELL_RADIANT_BARRIER and not trackedAuras.intermission then
                trackedAuras.intermission = true
                OnIntermission()
            end
        end
    end
end)

SLASH_LHDRAKESTEST1 = "/lhdrakestest"
SlashCmdList["LHDRAKESTEST"] = function(arg)
    if arg == "breath" then
        OnDreadBreath()
    elseif arg == "spread" then
        OnVoidHowl()
    elseif arg == "inter" then
        OnIntermission()
    elseif arg == "gloom" then
        ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak", SPELL_GLOOM)
    elseif arg == "nullzone" then
        ShowPrivate("NULLZONE — BOUGEZ !", SPELL_NULLZONE)
    else
        print("|cff00ff00LH Drakes|r /lhdrakestest breath|spread|inter|gloom|nullzone")
    end
end
