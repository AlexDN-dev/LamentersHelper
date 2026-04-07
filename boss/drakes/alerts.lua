local addonName, M = ...

-- Vaelgor & Ezzorak — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/VaelgorAndEzzorak.lua (Mythic, stage 1 pull)
-- ⚠ Les durées varient beaucoup par stage — activer debugEncounter pour cartographier les autres stages
local ENCOUNTER_ID = 3178

local inFight = false
local trackedAuras = {}
local activeTimers = {}
local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

-- SpellIDs connus pour les icônes
local SPELL_NULLZONE = 1244672
local SPELL_DIMINISH = 1270852

-- Durées confirmées BigWigs (Mythic, stage 1 initial pull) :
--   30           → Nullbeam
--   35           → Void Howl
--   10           → Gloom (stage 1) ; 48 (stage 2) ; 25 (stage 3)
--   8            → Midnight Flames (début intermission)
-- Stage 2/3 : durées différentes, activer debugEncounter pour les découvrir
local function BuildTimerCallback(d)
    if d == 30 then
        return function() ShowAlert("NULLBEAM — TANK SOAK !", "soak", SPELL_NULLZONE) end
    elseif d == 35 then
        return function() ShowAlert("VOID HOWL — GROUPEZ-VOUS !") end
    elseif d == 10 or d == 48 or d == 25 then
        return function() ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak") end
    elseif d == 8 then
        return function() ShowAlert("INTERMISSION — STACK DANS LE BARRIER !", "phase") end
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

local function OnUnitAura(unit)
    if unit ~= "player" then return end
    -- Auras boss taintées en Midnight (spellId secret) — player seulement
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

local function ResetState()
    inFight = false
    trackedAuras = {}
    activeTimers = {}
    M:ProgressBarHide(1)
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

SLASH_LHDRAKESTEST1 = "/lhdrakestest"
SlashCmdList["LHDRAKESTEST"] = function()
    ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak")
    ShowPrivate("NULLZONE — BOUGEZ !")
end
