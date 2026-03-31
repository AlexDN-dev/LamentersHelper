local addonName, M = ...

-- Spell IDs — Crown of the Cosmos (Alleria Windrunner), The Voidspire (Midnight 12.0)
-- Source : Wowhead (live 12.0.5) — mars 2026
local ENCOUNTER_ID = 3181

local SPELL = {
    -- === PHASE 1 — Undying Sentinels ===
    SILVERSTRIKE_ARROW      = 1233602,  -- Debuff sur le joueur ciblé — vise un Sentinel (AURA)
    GRASP_OF_EMPTINESS      = 1232470,  -- Ancre des joueurs aux obélisques — orienter avant expiration (AURA)
    NULL_CORONA             = 1233865,  -- Grosse absorb sur un joueur — soigner, dispel seulement si critique (AURA)
    VOID_EXPULSION          = 1264531,  -- Cible les Ranged — bait les flaques en bord (CAST_START) — P1 & P2
    INTERRUPTING_TREMOR     = 1243743,  -- Demair : interrompt tous les sorts dans 40y (CAST_START)

    -- === INTERMISSIONS (1 & 2) ===
    SILVERSTRIKE_BARRAGE    = 1243982,  -- Même que Silverstrike Arrow + 300% dmg flèches 8s (CAST_START)
    SINGULARITY_ERUPTION    = 1235622,  -- Flaques à esquiver (CAST_START)

    -- === PHASE 2 — Alleria + Rift Simulacrum ===
    CALL_OF_THE_VOID        = 1237875,  -- Spawn 2 Undying Voidspawns — interrompre Void Barrage (CAST_START)
    VOID_BARRAGE            = 1260000,  -- Cast des Voidspawns — interrompre ! 100 énergie = plus interruptible (CAST_START)
    COSMIC_BARRIER          = 1246918,  -- Absorb sur le Simulacrum — burst (AURA)
    RANGERS_CAPTAINS_MARK   = 1237614,  -- Version P2 de Silverstrike Arrow — rebondit entre joueurs (AURA)
    VOIDSTALKER_STING       = 1237040,  -- DoT 25s sur un joueur aléatoire (AURA)

    -- === PHASE 3 ===
    ASPECT_OF_THE_END       = 1239080,  -- Attache 1 Tank, 1 Mêlée, 1 Ranged — ordre de rupture : Ranged > Mêlée > Tank (AURA)
    DEVOURING_COSMOS        = 1238843,  -- Couvre une slice — prendre les plumes Dark Rush (CAST_START)
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

local function ShowPrivate(msg)
    M:ShowPrivateText(msg)
    if M.PlayAssetSound then
        M:PlayAssetSound("assets\\check_dispell.ogg")
    end
    C_Timer.After(M.config and M.config.privateTextDuration or 5, function()
        M:HidePrivateText()
    end)
end

local function OnCombatLogEvent()
    if not inFight then return end

    local _, subevent, _, _, _, _, _, destGUID, destName, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    -- === CASTS (avec cast time) ===
    if subevent == "SPELL_CAST_START" then

        if spellID == SPELL.VOID_EXPULSION then
            ShowAlert("VOID EXPULSION — RANGED BAITEZ !")

        elseif spellID == SPELL.INTERRUPTING_TREMOR then
            ShowAlert("INTERRUPTING TREMOR — STOP LES SORTS !")

        elseif spellID == SPELL.SILVERSTRIKE_BARRAGE then
            ShowAlert("SILVERSTRIKE BARRAGE — PRENEZ UNE FLÈCHE PUIS ÉVITEZ !")

        elseif spellID == SPELL.SINGULARITY_ERUPTION then
            ShowAlert("SINGULARITY ERUPTION — ÉVITEZ LES FLAQUES !")

        elseif spellID == SPELL.CALL_OF_THE_VOID then
            ShowAlert("CALL OF THE VOID — ADDS SPAWN !")

        elseif spellID == SPELL.VOID_BARRAGE then
            ShowAlert("VOID BARRAGE — INTERROMPRE !")

        elseif spellID == SPELL.DEVOURING_COSMOS then
            ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !")
        end

    -- === DEBUFFS / BUFFS ===
    elseif subevent == "SPELL_AURA_APPLIED" then

        -- Silverstrike Arrow : privé au joueur marqué
        if spellID == SPELL.SILVERSTRIKE_ARROW then
            if destGUID == UnitGUID("player") then
                ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
            end

        -- Grasp of Emptiness : privé aux joueurs ancrés
        elseif spellID == SPELL.GRASP_OF_EMPTINESS then
            if destGUID == UnitGUID("player") then
                ShowPrivate("GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !")
            end

        -- Null Corona : privé au joueur ciblé
        elseif spellID == SPELL.NULL_CORONA then
            if destGUID == UnitGUID("player") then
                ShowPrivate("NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !")
            end

        -- Cosmic Barrier : global — burst l'add
        elseif spellID == SPELL.COSMIC_BARRIER then
            ShowAlert("COSMIC BARRIER — BURST LE SIMULACRUM !")

        -- Ranger Captain's Mark : privé au joueur marqué
        elseif spellID == SPELL.RANGERS_CAPTAINS_MARK then
            if destGUID == UnitGUID("player") then
                ShowPrivate("RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !")
            end

        -- Voidstalker Sting : privé au joueur ciblé
        elseif spellID == SPELL.VOIDSTALKER_STING then
            if destGUID == UnitGUID("player") then
                ShowPrivate("VOIDSTALKER STING — DOT SUR TOI (25s) !")
            end

        -- Aspect of the End : global + privé aux 3 joueurs liés
        elseif spellID == SPELL.ASPECT_OF_THE_END then
            ShowAlert("ASPECT OF THE END — RANGED > MÊLÉE > TANK !")
            if destGUID == UnitGUID("player") then
                ShowPrivate("ASPECT OF THE END — RESTEZ EN PLACE !")
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

SLASH_LHCROWNTEST1 = "/lhcrowntest"

SlashCmdList["LHCROWNTEST"] = function()
    ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !")
    ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
end
