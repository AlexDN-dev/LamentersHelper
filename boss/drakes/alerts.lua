local addonName, M = ...

-- Spell IDs — Vaelgor & Ezzorak, The Voidspire (Midnight 12.0)
-- Source : Wowhead (live 12.0.5) — mars 2026
-- ⚠️ ENCOUNTER_ID : estimation 3180, à vérifier via WarcraftLogs
local ENCOUNTER_ID = 3178

local SPELL = {
    -- Casts de Vaelgor (SPELL_CAST_START)
    NULLBEAM                = 1262688,  -- Beam frontal sur le tank — tank doit soak ~8 stacks
    DREAD_BREATH            = 1255595,  -- Cône frontal ciblant un joueur aléatoire (fear inclus)

    -- Casts d'Ezzorak (SPELL_CAST_START)
    VOID_HOWL               = 1245302,  -- Cercles sur tous les joueurs — groupez-vous pour les Voidorbs
    GLOOM                   = 1245391,  -- Orbe qui crée une flaque en bord de zone — 5 joueurs soakent

    -- Intermission (SPELL_CAST_START)
    MIDNIGHT_FLAMES         = 1250071,  -- Les deux boss s'envolent — stackez dans le Radiant Barrier

    -- Debuffs sur les joueurs (SPELL_AURA_APPLIED)
    NULLZONE                = 1244672,  -- Lien sur chaque joueur après Nullbeam — rompre sauf tank en dernier
    NULLZONE_IMPLOSION      = 1252157,  -- DoT raid quand le tank rompt son lien en dernier (6s)
    TWILIGHT_BOND           = 1270189,  -- Buff boss si écart de PV >10% ou moins de 15y entre eux
    DIMINISH                = 1270852,  -- Debuff 1min après soak Gloom — ne plus soak le prochain
}

local inFight = false
local frame = CreateFrame("Frame")

local function GetShortName(name)
    if not name then return "" end
    return string.match(name, "^[^-]+") or name
end

local function ShowAlert(msg)
    M:ShowText(msg)
    C_Timer.After(M.config and M.config.textDuration or 4, function()
        M:HideText()
    end)
end

local function OnCombatLogEvent()
    if not inFight then return end

    local _, subevent, _, _, _, _, _, destGUID, destName, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    -- === CASTS DU BOSS (avec cast time) ===
    if subevent == "SPELL_CAST_START" then

        if spellID == SPELL.NULLBEAM then
            ShowAlert("NULLBEAM — TANK SOAK !")

        elseif spellID == SPELL.VOID_HOWL then
            ShowAlert("VOID HOWL — GROUPEZ-VOUS !")

        elseif spellID == SPELL.GLOOM then
            ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !")

        elseif spellID == SPELL.MIDNIGHT_FLAMES then
            ShowAlert("INTERMISSION — STACK DANS LE BARRIER !")
        end

    -- === DEBUFFS SUR JOUEURS ===
    elseif subevent == "SPELL_AURA_APPLIED" then

        if spellID == SPELL.NULLZONE then
            ShowAlert("NULLZONE — ROMPEZ LES LIENS !")

        elseif spellID == SPELL.NULLZONE_IMPLOSION then
            ShowAlert("NULLZONE IMPLOSION — SOINS RAID !")

        elseif spellID == SPELL.TWILIGHT_BOND then
            ShowAlert("TWILIGHT BOND — ÉQUILIBREZ LES PV !")

        -- Dread Breath : alerte privée uniquement pour le joueur ciblé
        elseif spellID == SPELL.DREAD_BREATH then
            if destGUID == UnitGUID("player") then
                M:ShowPrivateText("DREAD BREATH — SORTEZ SUR LE CÔTÉ !")
                C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
                    M:HidePrivateText()
                end)
            end

        -- Diminish : alerte privée au joueur qui vient de soak Gloom
        elseif spellID == SPELL.DIMINISH then
            if destGUID == UnitGUID("player") then
                M:ShowPrivateText("DIMINISH — NE SOAKEZ PLUS GLOOM !")
                C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
                    M:HidePrivateText()
                end)
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

SLASH_LHDRAKESTEST1 = "/lhdrakestest"

SlashCmdList["LHDRAKESTEST"] = function()
    ShowAlert("GLOOM — ÉQUIPE SOAK EN POSITION !")
    M:ShowPrivateText("DREAD BREATH — SORTEZ SUR LE CÔTÉ !")
end
