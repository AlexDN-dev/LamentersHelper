local addonName, M = ...

-- Spell IDs — Crown of the Cosmos (Alleria Windrunner), The Voidspire (Midnight 12.0)
local ENCOUNTER_ID = 3181

local SPELL = {
    VOID_EXPULSION          = 1264531,
    INTERRUPTING_TREMOR     = 1243743,
    SILVERSTRIKE_BARRAGE    = 1243982,
    SINGULARITY_ERUPTION    = 1235622,
    CALL_OF_THE_VOID        = 1237875,
    VOID_BARRAGE            = 1260000,
    COSMIC_BARRIER          = 1246918,
    ASPECT_OF_THE_END       = 1239080,
    DEVOURING_COSMOS        = 1238843,
    SILVERSTRIKE_ARROW      = 1233602,
    GRASP_OF_EMPTINESS      = 1232470,
    NULL_CORONA             = 1233865,
    RANGERS_CAPTAINS_MARK   = 1237614,
    VOIDSTALKER_STING       = 1237040,
}

local inFight = false
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

local function OnTimelineAdded(eventIndex)
    local spellID = C_EncounterTimeline.GetEventInfo(eventIndex)
    if not spellID then return end

    if spellID == SPELL.VOID_EXPULSION then
        ShowAlert("VOID EXPULSION — RANGED BAITEZ !", "soak")
    elseif spellID == SPELL.INTERRUPTING_TREMOR then
        ShowAlert("INTERRUPTING TREMOR — STOP LES SORTS !", "interrupt")
    elseif spellID == SPELL.SILVERSTRIKE_BARRAGE then
        ShowAlert("SILVERSTRIKE BARRAGE — PRENEZ UNE FLÈCHE PUIS ÉVITEZ !", "phase")
    elseif spellID == SPELL.SINGULARITY_ERUPTION then
        ShowAlert("SINGULARITY ERUPTION — ÉVITEZ LES FLAQUES !")
    elseif spellID == SPELL.CALL_OF_THE_VOID then
        ShowAlert("CALL OF THE VOID — ADDS SPAWN !")
    elseif spellID == SPELL.VOID_BARRAGE then
        ShowAlert("VOID BARRAGE — INTERROMPRE !", "interrupt")
    elseif spellID == SPELL.COSMIC_BARRIER then
        ShowAlert("COSMIC BARRIER — BURST LE SIMULACRUM !", "soak")
    elseif spellID == SPELL.ASPECT_OF_THE_END then
        ShowAlert("ASPECT OF THE END — RANGED > MÊLÉE > TANK !", "phase")
    elseif spellID == SPELL.DEVOURING_COSMOS then
        ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase")
    end
end

local function OnPrivateAuraApplied(auraInstanceID, spellID)
    if spellID == SPELL.SILVERSTRIKE_ARROW then
        ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
    elseif spellID == SPELL.GRASP_OF_EMPTINESS then
        ShowPrivate("GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !")
    elseif spellID == SPELL.NULL_CORONA then
        ShowPrivate("NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !")
    elseif spellID == SPELL.RANGERS_CAPTAINS_MARK then
        ShowPrivate("RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !")
    elseif spellID == SPELL.VOIDSTALKER_STING then
        ShowPrivate("VOIDSTALKER STING — DOT SUR TOI (25s) !")
    elseif spellID == SPELL.ASPECT_OF_THE_END then
        ShowPrivate("ASPECT OF THE END — RESTEZ EN PLACE !")
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("PRIVATE_AURA_APPLIED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r START: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = true
        end
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = false
            M:HideText()
            M:HidePrivateText()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        if not inFight then return end
        OnTimelineAdded(...)
    elseif event == "PRIVATE_AURA_APPLIED" then
        if not inFight then return end
        OnPrivateAuraApplied(...)
    end
end)

SLASH_LHCROWNTEST1 = "/lhcrowntest"
SlashCmdList["LHCROWNTEST"] = function()
    ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase")
    ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
end
