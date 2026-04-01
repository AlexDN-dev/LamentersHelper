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
    -- private aura IDs (from BigWigs TheVoidspire/Crown.lua)
    SILVERSTRIKE_ARROW      = 1233602,
    GRASP_OF_EMPTINESS      = 1232470,
    NULL_CORONA             = 1233865,
    RANGERS_CAPTAINS_MARK   = 1237623, -- BigWigs: 1237623 (LH had 1237614)
    VOIDSTALKER_STING       = 1237038, -- BigWigs: 1237038 (LH had 1237040)
    ASPECT_OF_END_PRIV      = 1239111, -- BigWigs: 1239111 (LH had 1239080)
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
        ShowAlert("ASPECT OF THE END — MÊLÉE > RANGED > TANK !", "phase")
    elseif spellID == SPELL.DEVOURING_COSMOS then
        ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase")
    end
end

local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local function checkPrivate(spellID, key, msg)
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura and not trackedAuras[key] then
            trackedAuras[key] = true
            ShowPrivate(msg)
        elseif not aura then
            trackedAuras[key] = nil
        end
    end

    checkPrivate(SPELL.SILVERSTRIKE_ARROW,    "arrow",   "SILVERSTRIKE ARROW — VISE UN SENTINEL !")
    checkPrivate(SPELL.GRASP_OF_EMPTINESS,    "grasp",   "GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !")
    checkPrivate(SPELL.NULL_CORONA,           "corona",  "NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !")
    checkPrivate(SPELL.RANGERS_CAPTAINS_MARK, "mark",    "RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !")
    checkPrivate(SPELL.VOIDSTALKER_STING,     "sting",   "VOIDSTALKER STING — DOT SUR TOI (25s) !")
    checkPrivate(SPELL.ASPECT_OF_END_PRIV,    "aspect",  "ASPECT OF THE END — RESTEZ EN PLACE !")
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

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
    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)
    end
end)

SLASH_LHCROWNTEST1 = "/lhcrowntest"
SlashCmdList["LHCROWNTEST"] = function()
    ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase")
    ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
end
