local addonName, M = ...

-- Spell IDs — Vorasius, The Voidspire (Midnight 12.0)
-- Source : WarcraftLogs Mythic kill 29/03/2026 (Report njAfzM2k9ZJqrypw)
local ENCOUNTER_ID = 3177

local SPELL = {
    -- Casts du boss (détectés via SPELL_CAST_START dans le combat log)
    VOID_BREATH_CAST        = 1257629,  -- ⚠️ Wowhead listait 1256855, WCL confirme 1257629
    SHADOWCLAW_SLAM_CAST    = 1272329,  -- Cast initiateur (les dégâts ont l'ID 1272328)
    PRIMORDIAL_ROAR         = 1260052,  -- Pull + knockback AoE physique
    PARASITE_EXPULSION      = 1254199,  -- Spawne des Blistercreeps (adds)
    OVERPOWERING_PULSE      = 1244419,  -- Pulsation si personne à portée du boss
    FOCUSED_AGGRESSION      = 1258967,  -- Enrage du boss (~6 min)

    -- Debuffs sur les joueurs (détectés via SPELL_AURA_APPLIED)
    SMASHED                 = 1241844,  -- Debuff tank stackable (+150% dégâts physiques)
    BLISTERBURST            = 1259186,  -- Debuff +100% dégâts reçus (mort des adds, Mythic)
    DARK_ENERGY             = 1280101,  -- DoT Shadow pendant Void Breath
    PRIMORDIAL_POWER        = 1272950,  -- DoT AoE raid (s'accumule après chaque Roar)
}

local inFight = false
local frame = CreateFrame("Frame")

local function GetShortName(name)
    if not name then return "" end
    return string.match(name, "^[^-]+") or name
end

local function ShowAlert(msg)
    M:ShowText(msg)
    if M.PlayAssetSound then
        M:PlayAssetSound("assets\\soak.ogg")
    end
    C_Timer.After(M.config and M.config.textDuration or 4, function()
        M:HideText()
    end)
end

local function OnCombatLogEvent()
    if not inFight then return end

    local _, subevent, _, _, _, _, _, _, destName, _, _, spellID, _, _, _, amount =
        CombatLogGetCurrentEventInfo()

    if subevent == "SPELL_CAST_START" then

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
            ShowAlert("⚠ ENRAGE — PUSH DPS MAXIMUM !")
        end

    elseif subevent == "SPELL_AURA_APPLIED" then

        if spellID == SPELL.SMASHED then
            ShowAlert("SMASHED ×1 — " .. GetShortName(destName) .. " — SWAP TANK !")

        elseif spellID == SPELL.BLISTERBURST then
            ShowAlert("BLISTERBURST — +100% DÉGÂTS (30s) !")
        end

    elseif subevent == "SPELL_AURA_APPLIED_DOSE" then

        if spellID == SPELL.SMASHED then
            local stacks = amount or "?"
            ShowAlert("SMASHED ×" .. stacks .. " — " .. GetShortName(destName) .. " — SWAP TANK !")
        end
    end
end

frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

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
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    end
end)

SLASH_LHVORASIUSTEST1 = "/lhvoratest"

SlashCmdList["LHVORASIUSTEST"] = function()
    ShowAlert("VOID BREATH — ÉVITEZ LE CÔNE !")
end
