local addonName, M = ...

-- Spell IDs — Imperator Averzian, The Voidspire (Midnight 12.0)
-- Source : Wowhead (live 12.0.5) — mars 2026
local ENCOUNTER_ID = 3176

local SPELL = {
    -- Casts du boss (SPELL_CAST_START — cast de 3s)
    SHADOWS_ADVANCE         = 1251361,  -- Phase plateau — spawne 3 Abyssal Voidshapers
    OBLIVIONS_WRATH         = 1260718,  -- Piques directionnelles autour du boss

    -- Casts du boss (SPELL_CAST_SUCCESS — instant)
    VOID_FALL               = 1258883,  -- Knockback + tourbillons au sol

    -- Casts des adds
    VOID_RUPTURE            = 1262036,  -- Cast du Voidshaper — capture une case si non interrompu/soak
    PITCH_BULWARK           = 1255702,  -- Cast du Stalwart / Annihilator — absorb shield sur les alliés

    -- Debuffs sur les joueurs (SPELL_AURA_APPLIED)
    UMBRAL_COLLAPSE         = 1249262,  -- Soak assigné à un joueur aléatoire
    IMPERATORS_GLORY        = 1253918,  -- Buff du boss s'il se trouve près d'une case capturée (75% dmg, 99% dmg réduit)
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

        if spellID == SPELL.SHADOWS_ADVANCE then
            ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !")

        elseif spellID == SPELL.OBLIVIONS_WRATH then
            ShowAlert("OBLIVION'S WRATH — BOUGEZ !")

        -- === CASTS DES ADDS ===
        elseif spellID == SPELL.VOID_RUPTURE then
            ShowAlert("VOID RUPTURE — SOAK / INTERROMPRE !")

        elseif spellID == SPELL.PITCH_BULWARK then
            ShowAlert("PITCH BULWARK — INTERROMPRE !")
        end

    -- === CASTS DU BOSS (instant) ===
    elseif subevent == "SPELL_CAST_SUCCESS" then

        if spellID == SPELL.VOID_FALL then
            ShowAlert("VOID FALL — ÉVITEZ LES ZONES !")
        end

    -- === DEBUFFS SUR JOUEURS ===
    elseif subevent == "SPELL_AURA_APPLIED" then

        if spellID == SPELL.UMBRAL_COLLAPSE then
            ShowAlert("UMBRAL COLLAPSE — SOAK !")
            if destGUID == UnitGUID("player") then
                M:ShowPrivateText("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
                C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
                    M:HidePrivateText()
                end)
            end

        elseif spellID == SPELL.IMPERATORS_GLORY then
            ShowAlert("IMPERATOR'S GLORY — ÉLOIGNEZ LE BOSS !")
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

SLASH_LHIMPERTEST1 = "/lhimpertest"

SlashCmdList["LHIMPERTEST"] = function()
    ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !")
    M:ShowPrivateText("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
end
