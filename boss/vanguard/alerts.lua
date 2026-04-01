local addonName, M = ...

-- Spell IDs — Lightblinded Vanguard, The Voidspire (Midnight 12.0)
-- ⚠️ ENCOUNTER_ID : à vérifier via debugEncounter = true au prochain pull
local ENCOUNTER_ID = 3180

local SPELL = {
    EXECUTION_SENTENCE        = 1248983,
    SACRED_TOLL               = 1246749,
    AURA_OF_WRATH             = 1248449,
    DIVINE_TOLL               = 1248644,
    AURA_OF_DEVOTION          = 1246162,
    SACRED_SHIELD             = 1248674,
    BLINDING_LIGHT            = 1258514,
    SEARING_RADIANCE          = 1255738,
    AURA_OF_PEACE             = 1250812,
    ELEKK_CHARGE              = 1249130,
    TYRS_WRATH                = 1248710,
    EXECUTION_SENTENCE_DEBUFF = 1248983,
    RETRIBUTION               = 1246174,
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

local function OnTimelineAdded(eventIndex)
    local spellID = C_EncounterTimeline.GetEventInfo(eventIndex)
    if not spellID then return end

    -- Commander Venel
    if spellID == SPELL.EXECUTION_SENTENCE then
        ShowAlert("EXECUTION SENTENCE — SOAK LES CERCLES !", "soak")
    elseif spellID == SPELL.SACRED_TOLL then
        ShowAlert("SACRED TOLL — CD DE SOIN !")
    elseif spellID == SPELL.AURA_OF_WRATH then
        ShowAlert("AURA OF WRATH — VENEL SUR LE BORD !", "phase")
    -- General Bellamy
    elseif spellID == SPELL.DIVINE_TOLL then
        ShowAlert("DIVINE TOLL — ÉVITEZ LES BOUCLIERS !")
    elseif spellID == SPELL.AURA_OF_DEVOTION then
        ShowAlert("AURA OF DEVOTION — BELLAMY SUR LE BORD !", "phase")
    -- Chaplain Senn
    elseif spellID == SPELL.SACRED_SHIELD then
        ShowAlert("SACRED SHIELD — BURST LE BOUCLIER !", "interrupt")
    elseif spellID == SPELL.BLINDING_LIGHT then
        ShowAlert("BLINDING LIGHT — INTERROMPRE !", "interrupt")
    elseif spellID == SPELL.SEARING_RADIANCE then
        ShowAlert("SEARING RADIANCE — SOINS RAID !")
    elseif spellID == SPELL.AURA_OF_PEACE then
        ShowAlert("AURA OF PEACE — SENN SUR LE BORD !", "phase")
    elseif spellID == SPELL.TYRS_WRATH then
        ShowAlert("TYR'S WRATH — ROTATIONNEZ LA POSITION !")
    end
end

local function OnTimelineStateChanged(eventIndex, newState)
    if newState ~= Enum.EncounterEventState.Finished then return end
    local spellID = C_EncounterTimeline.GetEventInfo(eventIndex)
    if not spellID then return end

    if spellID == SPELL.ELEKK_CHARGE then
        ShowAlert("ELEKK CHARGE — ESQUIVEZ !")
    end
end

local function OnPrivateAuraApplied(auraInstanceID, spellID)
    if spellID == SPELL.EXECUTION_SENTENCE_DEBUFF then
        ShowPrivate("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !")
    end
end

local function OnUnitAura(unit)
    local retri = C_UnitAuras.GetAuraDataBySpellID(unit, SPELL.RETRIBUTION, "HELPFUL")
    local key = unit .. "_retri"
    if retri and not trackedAuras[key] then
        trackedAuras[key] = true
        ShowAlert("RETRIBUTION — ÉQUILIBREZ LES PV !", "phase")
    elseif not retri then
        trackedAuras[key] = nil
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
frame:RegisterEvent("PRIVATE_AURA_APPLIED")
frame:RegisterUnitEvent("UNIT_AURA", "boss1", "boss2", "boss3")

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
    elseif event == "PRIVATE_AURA_APPLIED" then
        if not inFight then return end
        OnPrivateAuraApplied(...)
    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)
    end
end)

SLASH_LHVANGUARDTEST1 = "/lhvanguardtest"
SlashCmdList["LHVANGUARDTEST"] = function()
    ShowAlert("BLINDING LIGHT — INTERROMPRE !", "interrupt")
    ShowPrivate("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !")
end
