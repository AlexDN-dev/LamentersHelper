local addonName, M = ...

-- Spell IDs — Imperator Averzian, The Voidspire (Midnight 12.0)
local ENCOUNTER_ID = 3176

local SPELL = {
    SHADOWS_ADVANCE         = 1251361,
    OBLIVIONS_WRATH         = 1260718,
    VOID_RUPTURE            = 1262036,
    PITCH_BULWARK           = 1255702,
    UMBRAL_COLLAPSE         = 1249262,
    UMBRAL_COLLAPSE_PRIVATE = 1249265, -- private aura spell ID (from BigWigs)
    VOID_FALL               = 1258883,
    IMPERATORS_GLORY        = 1253918,
}

local inFight = false
local trackedAuras = {}
local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType)
    M:ShowText(msg)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
    C_Timer.After(M.config and M.config.textDuration or 4, function()
        M:HideText()
    end)
end

local function ShowPrivate(msg)
    M:ShowPrivateText(msg)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
    C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
        M:HidePrivateText()
    end)
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo then return end
    local spellID = eventInfo.spellID
    if not spellID then return end

    if spellID == SPELL.SHADOWS_ADVANCE then
        ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase")
    elseif spellID == SPELL.OBLIVIONS_WRATH then
        ShowAlert("OBLIVION'S WRATH — BOUGEZ !")
    elseif spellID == SPELL.VOID_RUPTURE then
        ShowAlert("VOID RUPTURE — SOAK / INTERROMPRE !", "interrupt")
    elseif spellID == SPELL.PITCH_BULWARK then
        ShowAlert("PITCH BULWARK — INTERROMPRE !", "interrupt")
    elseif spellID == SPELL.UMBRAL_COLLAPSE then
        ShowAlert("UMBRAL COLLAPSE — SOAK !", "soak")
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state ~= 2 then return end -- 2 = Finished
    local info = C_EncounterTimeline.GetEventInfo(eventID)
    if not info then return end
    local spellID = info.spellID
    if not spellID then return end

    if spellID == SPELL.VOID_FALL then
        ShowAlert("VOID FALL — ÉVITEZ LES ZONES !")
    end
end

local function OnUnitAura(unit)
    if unit == "player" then
        local umbral = C_UnitAuras.GetPlayerAuraBySpellID(SPELL.UMBRAL_COLLAPSE_PRIVATE)
        if umbral and not trackedAuras.umbral then
            trackedAuras.umbral = true
            ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
        elseif not umbral then
            trackedAuras.umbral = nil
        end
        return
    end

    local glory = C_UnitAuras.GetAuraDataBySpellID(unit, SPELL.IMPERATORS_GLORY, "HELPFUL")
    if glory and not trackedAuras.glory then
        trackedAuras.glory = true
        ShowAlert("IMPERATOR'S GLORY — LIBÉREZ LA CASE !", "phase")
    elseif not glory then
        trackedAuras.glory = nil
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
frame:RegisterUnitEvent("UNIT_AURA", "boss1", "player")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r START: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = true
            trackedAuras = {}
        end
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = false
            trackedAuras = {}
            M:HideText()
            M:HidePrivateText()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false
        trackedAuras = {}
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
