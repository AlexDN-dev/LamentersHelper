local addonName, M = ...

-- Spell IDs — Fallen-King Salhadaar, The Voidspire (Midnight 12.0)
-- Source : WarcraftLogs Mythic kill 28/03/2026 (Report #kisasmukana, 6:03)
local ENCOUNTER_ID = 3179

local SPELL = {
    -- Casts du boss (SPELL_CAST_START) — fréquence gérable (~1 CPM chacun)
    TWISTING_OBSCURITY      = 1250686,  -- AoE raid debuff (6 casts, 59% uptime raid)
    SHATTERING_TWILIGHT     = 1253032,  -- 6 casts
    FRACTURED_PROJECTION    = 1254081,  -- Invoque l'add Fractured Image (6 casts)
    DESPOTIC_COMMAND_CAST   = 1260823,  -- Cible un joueur avec debuff (6 casts)
    VOID_CONVERGENCE        = 1243453,  -- Mécanique ponctuelle (6 casts)
    ENTROPIC_UNRAVELING     = 1246175,  -- Mécanique de phase (3 casts, rare)
    UMBRAL_BEAMS            = 1260030,  -- AoE final (2 casts, fin de phase)

    -- Debuffs sur joueurs (SPELL_AURA_APPLIED / SPELL_AURA_APPLIED_DOSE)
    DESTABILIZING_STRIKES   = 1271579,  -- Debuff tank, 127 applications (91% uptime)
    DESPOTIC_COMMAND_DEBUFF = 1248697,  -- Debuff ciblé sur un joueur (24 applications)
    DARK_RADIATION          = 1250991,  -- DoT AoE raid (240 applications — trop fréquent pour alerter)
}

-- Seuils de stacks pour Destabilizing Strikes avant de crier au swap
local DESTAB_ALERT_THRESHOLD = 5

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

    local _, subevent, _, _, _, _, _, destGUID, destName, _, _, spellID, _, _, _, amount =
        CombatLogGetCurrentEventInfo()

    -- === CASTS DU BOSS ===
    if subevent == "SPELL_CAST_START" then

        if spellID == SPELL.TWISTING_OBSCURITY then
            ShowAlert("TWISTING OBSCURITY — SOINS RAID !")

        elseif spellID == SPELL.SHATTERING_TWILIGHT then
            ShowAlert("SHATTERING TWILIGHT — ATTENTION !")

        elseif spellID == SPELL.FRACTURED_PROJECTION then
            ShowAlert("FRACTURED IMAGE INVOQUÉ — FOCUS L'ADD !")

        elseif spellID == SPELL.DESPOTIC_COMMAND_CAST then
            ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !")

        elseif spellID == SPELL.VOID_CONVERGENCE then
            ShowAlert("VOID CONVERGENCE !")

        elseif spellID == SPELL.ENTROPIC_UNRAVELING then
            ShowAlert("ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !")

        elseif spellID == SPELL.UMBRAL_BEAMS then
            ShowAlert("UMBRAL BEAMS — DÉPLACEZ-VOUS !")
        end

    -- === DEBUFFS SUR JOUEURS ===
    elseif subevent == "SPELL_AURA_APPLIED" then

        -- Despotic Command : alerte personnelle au joueur ciblé
        if spellID == SPELL.DESPOTIC_COMMAND_DEBUFF then
            if destGUID == UnitGUID("player") then
                M:ShowPrivateText("DESPOTIC COMMAND — BOUGEZ !")
                if M.PlayAssetSound then
                    M:PlayAssetSound("assets\\check_dispell.ogg")
                end
                C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
                    M:HidePrivateText()
                end)
            end
        end

        -- Destabilizing Strikes : premier stack sur un tank
        if spellID == SPELL.DESTABILIZING_STRIKES then
            ShowAlert("DESTABILIZING STRIKES ×1 — " .. GetShortName(destName))
        end

    elseif subevent == "SPELL_AURA_APPLIED_DOSE" then

        -- Destabilizing Strikes : alerte aux seuils de stacks
        if spellID == SPELL.DESTABILIZING_STRIKES then
            local stacks = amount or 0
            if stacks % DESTAB_ALERT_THRESHOLD == 0 then
                ShowAlert("DESTABILIZING STRIKES ×" .. stacks .. " — " .. GetShortName(destName) .. " — SWAP TANK !")
            end
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
            M:HidePrivateText()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        inFight = false

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLogEvent()
    end
end)

SLASH_LHSALHADAARTEST1 = "/lhsaltest"

SlashCmdList["LHSALHADAARTEST"] = function()
    ShowAlert("TWISTING OBSCURITY — SOINS RAID !")
    M:ShowPrivateText("DESPOTIC COMMAND — BOUGEZ !")
    if M.PlayAssetSound then
        M:PlayAssetSound("assets\\check_dispell.ogg")
    end
end
