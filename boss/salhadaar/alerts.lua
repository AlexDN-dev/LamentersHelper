local addonName, M = ...

-- Spell IDs — Fallen-King Salhadaar, The Voidspire (Midnight 12.0)
-- Source : WarcraftLogs Mythic kill 28/03/2026 (Report #kisasmukana, 6:03)
local ENCOUNTER_ID = 3179

local SPELL = {
    TWISTING_OBSCURITY      = 1250686,
    SHATTERING_TWILIGHT     = 1253032,
    FRACTURED_PROJECTION    = 1254081,
    DESPOTIC_COMMAND_CAST   = 1260823,
    VOID_CONVERGENCE        = 1243453,
    ENTROPIC_UNRAVELING     = 1246175,
    UMBRAL_BEAMS            = 1260030,
    DESPOTIC_COMMAND_DEBUFF = 1248697,
    DESTABILIZING_STRIKES   = 1271579,
}

local DESTAB_ALERT_THRESHOLD = 5

local inFight = false
local destabStacks = 0
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

    if spellID == SPELL.TWISTING_OBSCURITY then
        ShowAlert("TWISTING OBSCURITY — SOINS RAID !")
    elseif spellID == SPELL.SHATTERING_TWILIGHT then
        ShowAlert("SHATTERING TWILIGHT — ATTENTION !")
    elseif spellID == SPELL.FRACTURED_PROJECTION then
        ShowAlert("FRACTURED IMAGE INVOQUÉ — FOCUS L'ADD !")
    elseif spellID == SPELL.DESPOTIC_COMMAND_CAST then
        ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !", "soak")
    elseif spellID == SPELL.VOID_CONVERGENCE then
        ShowAlert("VOID CONVERGENCE !")
    elseif spellID == SPELL.ENTROPIC_UNRAVELING then
        ShowAlert("ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !", "phase")
    elseif spellID == SPELL.UMBRAL_BEAMS then
        ShowAlert("UMBRAL BEAMS — DÉPLACEZ-VOUS !", "phase")
    end
end

local function OnPrivateAuraApplied(auraInstanceID, spellID)
    if spellID == SPELL.DESPOTIC_COMMAND_DEBUFF then
        ShowPrivate("DESPOTIC COMMAND — BOUGEZ !")
    end
end

local function OnUnitAura(unit)
    if unit ~= "player" then return end
    local aura = C_UnitAuras.GetAuraDataBySpellID("player", SPELL.DESTABILIZING_STRIKES, "HARMFUL")
    if aura then
        local stacks = aura.applications or 1
        if stacks ~= destabStacks then
            destabStacks = stacks
            if stacks == 1 then
                ShowPrivate("DESTABILIZING STRIKES ×1")
            elseif stacks % DESTAB_ALERT_THRESHOLD == 0 then
                ShowPrivate("DESTABILIZING STRIKES ×" .. stacks .. " — SWAP TANK !")
            end
        end
    else
        destabStacks = 0
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("PRIVATE_AURA_APPLIED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r START: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = true
            destabStacks = 0
        end
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = false
            destabStacks = 0
            M:HideText()
            M:HidePrivateText()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false
        destabStacks = 0
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

SLASH_LHSALHADAARTEST1 = "/lhsaltest"
SlashCmdList["LHSALHADAARTEST"] = function()
    ShowAlert("TWISTING OBSCURITY — SOINS RAID !")
    ShowPrivate("DESPOTIC COMMAND — BOUGEZ !")
end
