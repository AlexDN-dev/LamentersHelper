local addonName, M = ...

-- Spell IDs — Vorasius, The Voidspire (Midnight 12.0)
-- Source : WarcraftLogs Mythic kill 29/03/2026 (Report njAfzM2k9ZJqrypw)
local ENCOUNTER_ID = 3177

local SPELL = {
    VOID_BREATH_CAST        = 1257629,
    SHADOWCLAW_SLAM_CAST    = 1272329,
    PRIMORDIAL_ROAR         = 1260052,
    PARASITE_EXPULSION      = 1254199,
    OVERPOWERING_PULSE      = 1244419,
    FOCUSED_AGGRESSION      = 1258967,
    BLISTERBURST            = 1259186,
    SMASHED                 = 1241844,
}

local SMASHED_ALERT_THRESHOLD = 3

local inFight = false
local smashedStacks = 0
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

    if spellID == SPELL.VOID_BREATH_CAST then
        ShowAlert("VOID BREATH — ÉVITEZ LE CÔNE !")
    elseif spellID == SPELL.SHADOWCLAW_SLAM_CAST then
        ShowAlert("SHADOWCLAW SLAM — ÉLOIGNEZ-VOUS !")
    elseif spellID == SPELL.PRIMORDIAL_ROAR then
        ShowAlert("PRIMORDIAL ROAR — TENEZ VOTRE POSITION !")
    elseif spellID == SPELL.PARASITE_EXPULSION then
        ShowAlert("BLISTERCREEPS — FOCUS LES ADDS !")
    elseif spellID == SPELL.OVERPOWERING_PULSE then
        ShowAlert("PULSE — APPROCHEZ LE BOSS !")
    elseif spellID == SPELL.FOCUSED_AGGRESSION then
        ShowAlert("⚠ ENRAGE — PUSH DPS MAXIMUM !", "phase")
    end
end

local function OnPrivateAuraApplied(auraInstanceID, spellID)
    if spellID == SPELL.BLISTERBURST then
        ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !")
    end
end

local function OnUnitAura(unit)
    if unit ~= "player" then return end
    local aura = C_UnitAuras.GetAuraDataBySpellID("player", SPELL.SMASHED, "HARMFUL")
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
            smashedStacks = 0
        end
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            inFight = false
            smashedStacks = 0
            M:HideText()
            M:HidePrivateText()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false
        smashedStacks = 0
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

SLASH_LHVORASIUSTEST1 = "/lhvoratest"
SlashCmdList["LHVORASIUSTEST"] = function()
    ShowAlert("VOID BREATH — ÉVITEZ LE CÔNE !")
end
