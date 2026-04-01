local addonName, M = ...

-- Vorasius — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/Vorasius.lua
local ENCOUNTER_ID = 3177

local inFight = false
local smashedStacks = 0
local blistered = false
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

-- Durées confirmées BigWigs Vorasius :
--   16, 136, 240 → Shadowclaw Slam
--   57, 123      → Parasite Expulsion
--   6, 120       → Primordial Roar
local function BuildTimerCallback(d)
    if d == 16 or d == 136 or d == 240 then
        return function() ShowAlert("SHADOWCLAW SLAM — ÉLOIGNEZ-VOUS !") end
    elseif d == 57 or d == 123 then
        return function() ShowAlert("BLISTERCREEPS — FOCUS LES ADDS !") end
    elseif d == 6 or d == 120 then
        return function() ShowAlert("PRIMORDIAL ROAR — TENEZ VOTRE POSITION !") end
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
        print(string.format("|cff00ff00LH Debug|r VORASIUS TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == 2 then  -- Finished = ability fires
        local cb = activeTimers[eventID]
        if cb then cb() end
    end
    if state == 2 or state == 3 then
        activeTimers[eventID] = nil
    end
end

local SMASHED_ALERT_THRESHOLD = 3

local function OnUnitAura(unit)
    if unit == "player" then
        local blister = C_UnitAuras.GetPlayerAuraBySpellID(1259186)  -- Blisterburst
        if blister and not blistered then
            blistered = true
            ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !")
        elseif not blister then
            blistered = false
        end

        local aura = M.FindAura("player", 1241844, "HARMFUL")  -- Smashed
        if aura then
            local stacks = aura.applications or 1
            if stacks ~= smashedStacks then
                smashedStacks = stacks
                if stacks == 1 or stacks % SMASHED_ALERT_THRESHOLD == 0 then
                    ShowPrivate("SMASHED ×" .. stacks .. " — SWAP TANK !")
                end
            end
        else
            smashedStacks = 0
        end
    end
end

local function ResetState()
    inFight = false
    smashedStacks = 0
    blistered = false
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

SLASH_LHVORASIUSTEST1 = "/lhvoratest"
SlashCmdList["LHVORASIUSTEST"] = function()
    ShowAlert("SHADOWCLAW SLAM — ÉLOIGNEZ-VOUS !")
    ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !")
end
