local addonName, M = ...

-- Imperator Averzian — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est une "Secret Value" taintée en Midnight — impossible à comparer.
-- On identifie les sorts par eventInfo.duration (non tainté), comme BigWigs.
-- Durées sources : BigWigs_TheVoidspire/Averzian.lua
local ENCOUNTER_ID = 3176

local inFight = false
local trackedAuras = {}
local activeTimers = {}  -- eventID → callback, pour STATE_CHANGED
local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType)
    M:ShowText(msg)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
    C_Timer.After(M.config and M.config.textDuration or 4, function() M:HideText() end)
end

local function ShowPrivate(msg)
    M:ShowPrivateText(msg)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
    C_Timer.After(M.config and M.config.privateTextDuration or 5, function() M:HidePrivateText() end)
end

-- Durée → callback (fires quand l'ability cast, state = Finished)
-- Valeurs non-Mythic (source BigWigs TimersOther) + Mythic entre parenthèses
local function BuildTimerCallback(d)
    if d == 84 or d == 12 or d == 94 or d == 14 then
        -- Shadow's Advance (84/12 non-mythic, 94/14 mythic)
        return function() ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase") end
    elseif d == 48 or d == 18 or d == 60 then
        -- Oblivion's Wrath (48/18 non-mythic, 60/18 mythic)
        return function() ShowAlert("OBLIVION'S WRATH — BOUGEZ !") end
    elseif d == 20 or d == 32 then
        -- Umbral Collapse (20 non-mythic, 32 mythic)
        return function() ShowAlert("UMBRAL COLLAPSE — SOAK !", "soak") end
    elseif d == 125 or d == 160 then
        -- Void Fall (125 non-mythic, 160 mythic)
        return function() ShowAlert("VOID FALL — ÉVITEZ LES ZONES !") end
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
        print(string.format("|cff00ff00LH Debug|r IMPERATOR TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == 2 then  -- Finished = ability fires now
        local cb = activeTimers[eventID]
        if cb then cb() end
    end
    if state == 2 or state == 3 then  -- cleanup (Finished or Canceled)
        activeTimers[eventID] = nil
    end
end

local function OnUnitAura(unit)
    if unit ~= "player" then return end
    -- Auras boss taintées en Midnight (spellId secret) — player seulement
    local umbral = C_UnitAuras.GetPlayerAuraBySpellID(1249265)  -- Umbral Collapse private aura
    if umbral and not trackedAuras.umbral then
        trackedAuras.umbral = true
        ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
    elseif not umbral then
        trackedAuras.umbral = nil
    end
end

local function ResetState()
    inFight = false
    trackedAuras = {}
    activeTimers = {}
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
    end
end)

SLASH_LHIMPERTEST1 = "/lhimpertest"
SlashCmdList["LHIMPERTEST"] = function()
    ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase")
    ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
end
