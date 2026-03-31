local addonName, M = ...

-- Spell IDs — Lightblinded Vanguard, The Voidspire (Midnight 12.0)
-- Source : Wowhead (live 12.0.5) + beta 12.0.1 — mars 2026
-- ⚠️ ENCOUNTER_ID : introuvable en ligne, à corriger via debugEncounter = true au prochain pull
local ENCOUNTER_ID = 3180

local SPELL = {
    -- === Commander Venel Lightblood (Rétribution) ===
    EXECUTION_SENTENCE      = 1248983,  -- Cercles de soak sur des joueurs — ne pas superposer (SPELL_CAST_START + AURA)
    SACRED_TOLL             = 1246749,  -- Nuke raid inévitable — CD de soin (SPELL_CAST_START)
    AURA_OF_WRATH           = 1248449,  -- 100 énergie : +100% dégâts Holy des alliés 40y (SPELL_CAST_START)

    -- === General Amias Bellamy (Protection) ===
    DIVINE_TOLL             = 1248644,  -- Volées de boucliers qui silence — éviter (SPELL_CAST_START)
    AURA_OF_DEVOTION        = 1246162,  -- 100 énergie : -75% dégâts subis des boss 40y (SPELL_CAST_START)

    -- === War Chaplain Senn (Holy) ===
    SACRED_SHIELD           = 1248674,  -- Senn immune aux interrupts + Blinding Light imminent (SPELL_CAST_START)
    BLINDING_LIGHT          = 1258514,  -- Dégâts raid + désorientation 5s si non interrompu (SPELL_CAST_START)
    SEARING_RADIANCE        = 1255738,  -- Dégâts raid continus 15s (SPELL_CAST_START)
    AURA_OF_PEACE           = 1250812,  -- 100 énergie : pacifie ceux qui attaquent les alliés protégés (SPELL_CAST_START)
    ELEKK_CHARGE            = 1249130,  -- Charge de Senn sur un joueur aléatoire — esquiver (SPELL_CAST_SUCCESS)

    -- === Debuffs sur joueurs (SPELL_AURA_APPLIED) ===
    EXECUTION_SENTENCE_DEBUFF = 1248983, -- Joueur ciblé par le cercle — alerte privée
    TYRS_WRATH              = 1248710,  -- Absorb de soin sur les 3 joueurs les plus proches de Senn — rotationnez
    RETRIBUTION             = 1246174,  -- Buff dégâts ramping sur les boss survivants à la mort d'un boss
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

    -- === CASTS DES BOSS (avec cast time) ===
    if subevent == "SPELL_CAST_START" then

        -- Commander Venel
        if spellID == SPELL.EXECUTION_SENTENCE then
            ShowAlert("EXECUTION SENTENCE — SOAK LES CERCLES !")

        elseif spellID == SPELL.SACRED_TOLL then
            ShowAlert("SACRED TOLL — CD DE SOIN !")

        elseif spellID == SPELL.AURA_OF_WRATH then
            ShowAlert("AURA OF WRATH — VENEL SUR LE BORD !")

        -- General Bellamy
        elseif spellID == SPELL.DIVINE_TOLL then
            ShowAlert("DIVINE TOLL — ÉVITEZ LES BOUCLIERS !")

        elseif spellID == SPELL.AURA_OF_DEVOTION then
            ShowAlert("AURA OF DEVOTION — BELLAMY SUR LE BORD !")

        -- Chaplain Senn
        elseif spellID == SPELL.SACRED_SHIELD then
            ShowAlert("SACRED SHIELD — BURST LE BOUCLIER !")

        elseif spellID == SPELL.BLINDING_LIGHT then
            ShowAlert("BLINDING LIGHT — INTERROMPRE !")

        elseif spellID == SPELL.SEARING_RADIANCE then
            ShowAlert("SEARING RADIANCE — SOINS RAID !")

        elseif spellID == SPELL.AURA_OF_PEACE then
            ShowAlert("AURA OF PEACE — SENN SUR LE BORD !")
        end

    -- === CASTS INSTANTANÉS ===
    elseif subevent == "SPELL_CAST_SUCCESS" then

        if spellID == SPELL.ELEKK_CHARGE then
            ShowAlert("ELEKK CHARGE — ESQUIVEZ !")
        end

    -- === DEBUFFS SUR JOUEURS ===
    elseif subevent == "SPELL_AURA_APPLIED" then

        -- Execution Sentence : alerte privée au joueur ciblé
        if spellID == SPELL.EXECUTION_SENTENCE_DEBUFF then
            if destGUID == UnitGUID("player") then
                M:ShowPrivateText("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !")
                C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
                    M:HidePrivateText()
                end)
            end

        -- Tyr's Wrath : absorb sur les 3 joueurs les plus proches
        elseif spellID == SPELL.TYRS_WRATH then
            ShowAlert("TYR'S WRATH — ROTATIONNEZ LA POSITION !")

        -- Retribution : quand un boss meurt, les autres rampent
        elseif spellID == SPELL.RETRIBUTION then
            ShowAlert("RETRIBUTION — ÉQUILIBREZ LES PV !")
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

SLASH_LHVANGUARDTEST1 = "/lhvanguardtest"

SlashCmdList["LHVANGUARDTEST"] = function()
    ShowAlert("BLINDING LIGHT — INTERROMPRE !")
    M:ShowPrivateText("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !")
end
