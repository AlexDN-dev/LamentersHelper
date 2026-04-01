local addonName, M = ...

-- Spell IDs — Vaelgor & Ezzorak, The Voidspire (Midnight 12.0)
-- ⚠️ ENCOUNTER_ID : estimation 3178, à vérifier via debugEncounter = true au prochain pull
local ENCOUNTER_ID = 3178

local SPELL = {
    NULLBEAM                = 1262688,
    NULLZONE                = 1244672,
    VOID_HOWL               = 1245302,
    GLOOM                   = 1245391,
    NULLZONE_IMPLOSION      = 1252157,
    MIDNIGHT_FLAMES         = 1250071,
    DREAD_BREATH            = 1255595,
    DIMINISH                = 1270852,
    TWILIGHT_BOND           = 1270189,
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

    if spellID == SPELL.NULLBEAM then
        ShowAlert("NULLBEAM — TANK SOAK !", "soak")
    elseif spellID == SPELL.NULLZONE then
        ShowAlert("NULLZONE — ROMPEZ LES LIENS !", "soak")
    elseif spellID == SPELL.VOID_HOWL then
        ShowAlert("VOID HOWL — GROUPEZ-VOUS !")
    elseif spellID == SPELL.GLOOM then
        ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak")
    elseif spellID == SPELL.NULLZONE_IMPLOSION then
        ShowAlert("NULLZONE IMPLOSION — SOINS RAID !")
    elseif spellID == SPELL.MIDNIGHT_FLAMES then
        ShowAlert("INTERMISSION — STACK DANS LE BARRIER !", "phase")
    end
end

local function OnPrivateAuraApplied(auraInstanceID, spellID)
    if spellID == SPELL.DREAD_BREATH then
        ShowPrivate("DREAD BREATH — SORTEZ SUR LE CÔTÉ !")
    elseif spellID == SPELL.DIMINISH then
        ShowPrivate("DIMINISH — NE SOAKEZ PLUS GLOOM !")
    end
end

local function OnUnitAura(unit)
    local bond = C_UnitAuras.GetAuraDataBySpellID(unit, SPELL.TWILIGHT_BOND, "HELPFUL")
    local key = unit .. "_bond"
    if bond and not trackedAuras[key] then
        trackedAuras[key] = true
        ShowAlert("TWILIGHT BOND — ÉQUILIBREZ LES PV !", "phase")
    elseif not bond then
        trackedAuras[key] = nil
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("PRIVATE_AURA_APPLIED")
frame:RegisterUnitEvent("UNIT_AURA", "boss1", "boss2")

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
    elseif event == "PRIVATE_AURA_APPLIED" then
        if not inFight then return end
        OnPrivateAuraApplied(...)
    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)
    end
end)

SLASH_LHDRAKESTEST1 = "/lhdrakestest"
SlashCmdList["LHDRAKESTEST"] = function()
    ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !", "soak")
    ShowPrivate("DREAD BREATH — SORTEZ SUR LE CÔTÉ !")
end
