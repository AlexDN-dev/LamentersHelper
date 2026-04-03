local addonName, M = ...

-- Vorasius — The Voidspire (Midnight 12.0) — Mythique
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Les spellIDs CLEU (passés comme args, non lus via unit API) sont utilisables normalement.
local ENCOUNTER_ID = 3177

-- ─── Spell IDs ────────────────────────────────────────────────────────────────
-- CLEU (détection par cast)
local VOID_BREATH_ID     = 1256855  -- Souffle du Vide (rayon balayant, 15s)
-- Auras joueur (UNIT_AURA — non-taintées sur "player")
local BLISTERBURST_AURA  = 1259186  -- Explosion Cuisante : +100% dégâts reçus, 30s
local SMASHED_AURA       = 1241844  -- Heurtoir : vulnérabilité physique tank (cumulable)
-- NOTE : l'aura de ciblage (fixate) et le ralentissement des Ectocloques
--        n'ont pas encore de spell ID confirmé. Activez debugEncounter pour les trouver.

-- ─── Specs mêlée par classe (index de spécialisation WoW) ─────────────────────
local MELEE_SPECS = {
    WARRIOR     = {[1]=true, [2]=true},           -- Armes, Fureur (3=Protection=tank)
    PALADIN     = {[3]=true},                      -- Vindicte
    HUNTER      = {[3]=true},                      -- Survie (1=BM, 2=MM = distance)
    ROGUE       = {[1]=true, [2]=true, [3]=true},  -- Assassinat, Hors-la-loi, Subtilité
    DEATHKNIGHT = {[2]=true, [3]=true},            -- Givre, Impie (1=Sang=tank)
    SHAMAN      = {[2]=true},                      -- Amélioration (1=Élé, 3=Resto)
    MONK        = {[3]=true},                      -- Marcheur du vent (1=Tank, 2=Heal)
    DRUID       = {[2]=true},                      -- Farouche (1=Équi, 3=Garden, 4=Resto)
    DEMONHUNTER = {[1]=true},                      -- Dévastation (2=Vengeance=tank)
    -- WARRIOR 2=Fureur inclus (souvent en mêlée mais peut être éloigné en Mythique — configurable)
}

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight          = false
local slamCount        = 0       -- Nombre de Shadowclaw Slams (pour tracking des murs)
local addKillCount     = 0       -- Kills d'Ectocloques dans la vague courante
local blistered        = false
local smashedStacks    = 0
local voidBreathActive = false
local activeTimers     = {}

local frame = CreateFrame("Frame")

-- ─── Détection du rôle joueur ──────────────────────────────────────────────────
-- Priorité : config manuelle > rôle de groupe > spec auto
local function GetVorasiusRole()
    local override = M.config and M.config.vorasiusRole
    if override and override ~= "AUTO" then return override end

    local role = UnitGroupRolesAssigned("player")
    if role == "TANK"   then return "TANK"   end
    if role == "HEALER" then return "HEALER" end

    local specIndex = GetSpecialization()
    if not specIndex then return "RANGE" end
    local _, classFile = UnitClass("player")
    if MELEE_SPECS[classFile] and MELEE_SPECS[classFile][specIndex] then
        return "MELEE"
    end
    return "RANGE"
end

-- Exposé pour le panel d'options
M.GetVorasiusRole = GetVorasiusRole

-- ─── Affichage ────────────────────────────────────────────────────────────────
local function ShowAlert(msg, soundType)
    M:ShowText(msg, soundType)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
    C_Timer.After(M.config and M.config.textDuration or 4, function() M:HideText() end)
end

local function ShowPrivate(msg)
    M:ShowPrivateText(msg)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
    C_Timer.After(M.config and M.config.privateTextDuration or 5, function() M:HidePrivateText() end)
end

-- ─── Timeline callbacks ───────────────────────────────────────────────────────
-- Durées confirmées BigWigs Vorasius :
--   16, 136, 240  → Shadowclaw Slam (Heurtoir d'Ombregriffe)
--   57, 123       → Parasite Expulsion (Ectocloques / Blistercreeps)
--   6, 120        → Primordial Roar (Grondement Primordial)
local function BuildTimerCallback(d)

    -- Shadowclaw Slam — tank soak, murs du Vide
    if d == 16 or d == 136 or d == 240 then
        return function()
            slamCount     = slamCount + 1
            addKillCount  = 0  -- Nouvelle vague d'adds = reset compteur
            local wallMsg = ""
            if slamCount == 1 then
                wallMsg = " | MUR #1 — KITEZ LES ADDS !"
            elseif slamCount == 2 then
                wallMsg = " | MUR #2 — TANK SWAP !"
            end
            ShowAlert("SHADOWCLAW SLAM — TANK ABSORBE !" .. wallMsg, "soak")
        end
    end

    -- Ectocloques / Blistercreeps — positionnement par rôle
    if d == 57 or d == 123 then
        return function()
            addKillCount = 0  -- Sécurité reset
            local role   = GetVorasiusRole()
            local mythic = M.config and M.config.vorasiusMythicMode
            local kills  = mythic and "3 kills/mur" or "2 kills/mur"
            if role == "MELEE" then
                ShowAlert("ECTOCLOQUES — KITEZ VERS LA GAUCHE ! (" .. kills .. ")", "interrupt")
                ShowPrivate("TOI → MUR GAUCHE  (tu es mêlée)")
            elseif role == "RANGE" then
                ShowAlert("ECTOCLOQUES — KITEZ VERS LA DROITE ! (" .. kills .. ")", "interrupt")
                ShowPrivate("TOI → MUR DROIT  (tu es distance)")
            elseif role == "HEALER" then
                ShowAlert("ECTOCLOQUES — DISSIPEZ LES RALENTISSEMENTS !", "interrupt")
                ShowPrivate("HEALER : dispel le ralentissement des fixated")
            elseif role == "TANK" then
                ShowAlert("ECTOCLOQUES — GÉREZ LES ADDS ! (" .. kills .. ")", "interrupt")
            else
                ShowAlert("ECTOCLOQUES — FOCUS LES ADDS ! (" .. kills .. ")", "interrupt")
            end
        end
    end

    -- Primordial Roar — attraction + knockback
    if d == 6 or d == 120 then
        return function()
            ShowAlert("GRONDEMENT PRIMORDIAL — NE TOMBEZ PAS DE LA PLATEFORME !", "phase")
        end
    end

    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local d  = math.floor(eventInfo.duration + 0.5)
    local cb = BuildTimerCallback(d)
    if cb then
        activeTimers[eventInfo.id] = cb
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r VORASIUS TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == 2 then  -- Finished = capacité qui se déclenche
        local cb = activeTimers[eventID]
        if cb then cb() end
    end
    if state == 2 or state == 3 then
        activeTimers[eventID] = nil
    end
end

-- ─── CLEU ─────────────────────────────────────────────────────────────────────
-- Noms des Ectocloques (FR + EN) pour tracker les kills et alerter sur les murs
local BLISTERCREEP_NAMES = {
    ["Ectocloque"]   = true,
    ["Ectocloques"]  = true,
    ["Blistercreep"] = true,
    ["Blistercreeps"]= true,
}

local function OnCLEU()
    local _, event, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    -- Souffle du Vide (Void Breath) — détection du début de canalisation
    if event == "SPELL_CAST_START" or event == "SPELL_CHANNEL_START" then
        if spellID == VOID_BREATH_ID and not voidBreathActive then
            voidBreathActive = true
            ShowAlert("SOUFFLE DU VIDE — OBSERVEZ LE DÉPART DU RAYON !", "phase")
            C_Timer.After(16, function() voidBreathActive = false end)
        end
    end

    -- Kills d'Ectocloques — suivi de la destruction des murs
    if event == "UNIT_DIED" and BLISTERCREEP_NAMES[destName] then
        addKillCount = addKillCount + 1
        local mythic = M.config and M.config.vorasiusMythicMode
        local target = mythic and 3 or 2  -- kills nécessaires par mur
        if addKillCount % target == 0 and addKillCount > 0 then
            local wallNum = addKillCount / target
            ShowAlert("MUR #" .. wallNum .. " DÉTRUIT — ESPACE LIBÉRÉ !", "phase")
        end
    end

    -- Mode debug : log toutes les auras appliquées/retirées sur le joueur
    if M.config and M.config.debugEncounter then
        local myGUID = UnitGUID("player")
        if (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED") and destGUID == myGUID then
            print(string.format("|cff00ff00LH Debug|r AURA %s spellID=%s src=%s",
                event, tostring(spellID), tostring(sourceName)))
        end
    end
end

-- ─── UNIT_AURA : debuffs personnels ───────────────────────────────────────────
local SMASHED_SWAP_AT = 2  -- Swap obligatoire à partir de ce stack (règle guilde)

local function OnUnitAura(unit)
    if unit ~= "player" then return end

    -- Blisterburst — +100% dégâts reçus pendant 30s (si l'add est à côté de toi)
    local blister = C_UnitAuras.GetPlayerAuraBySpellID(BLISTERBURST_AURA)
    if blister and not blistered then
        blistered = true
        ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !")
    elseif not blister then
        blistered = false
    end

    -- Smashed — vulnérabilité physique cumulable sur le tank
    local aura = M.FindAura("player", SMASHED_AURA, "HARMFUL")
    if aura then
        local stacks = aura.applications or 1
        if stacks ~= smashedStacks then
            smashedStacks = stacks
            if stacks == 1 then
                ShowPrivate("SMASHED ×1 — SWAP AU PROCHAIN SOAK !")
            elseif stacks >= SMASHED_SWAP_AT then
                ShowPrivate("SMASHED ×" .. stacks .. " — SWAP TANK MAINTENANT !")
            end
        end
    else
        smashedStacks = 0
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight          = false
    slamCount        = 0
    addKillCount     = 0
    blistered        = false
    smashedStacks    = 0
    voidBreathActive = false
    activeTimers     = {}
    -- CLEU n'est enregistré que pendant le combat pour éviter ADDON_ACTION_FORBIDDEN
    -- et ne pas traiter inutilement des milliers d'events hors-combat
    frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
end

-- ─── Events ───────────────────────────────────────────────────────────────────
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
frame:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
frame:RegisterUnitEvent("UNIT_AURA", "player")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r START: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            ResetState()
            inFight = true
            -- CLEU enregistré uniquement pendant le combat Vorasius
            frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: ID=%s", tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            ResetState()  -- UnregisterEvent CLEU appelé ici via ResetState
            M:HideText()
            M:HidePrivateText()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetState()  -- UnregisterEvent CLEU appelé ici via ResetState

    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        if not inFight then return end
        OnTimelineAdded(...)

    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        if not inFight then return end
        OnTimelineStateChanged(...)

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not inFight then return end
        OnCLEU()

    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)
    end
end)

-- ─── Slash commande de test ───────────────────────────────────────────────────
SLASH_LHVORASIUSTEST1 = "/lhvoratest"
SlashCmdList["LHVORASIUSTEST"] = function(arg)
    local role   = GetVorasiusRole()
    local mythic = M.config and M.config.vorasiusMythicMode
    local kills  = mythic and "3 kills/mur" or "2 kills/mur"

    if arg == "slam" then
        slamCount = slamCount + 1
        local wallMsg = slamCount <= 2 and (" | MUR #" .. slamCount .. " — KITEZ LES ADDS !") or ""
        ShowAlert("SHADOWCLAW SLAM — TANK ABSORBE !" .. wallMsg, "soak")

    elseif arg == "beam" then
        ShowAlert("SOUFFLE DU VIDE — OBSERVEZ LE DÉPART DU RAYON !", "phase")

    elseif arg == "adds" then
        if role == "MELEE" then
            ShowAlert("ECTOCLOQUES — KITEZ VERS LA GAUCHE ! (" .. kills .. ")", "interrupt")
            ShowPrivate("TOI → MUR GAUCHE  (tu es mêlée)")
        elseif role == "RANGE" then
            ShowAlert("ECTOCLOQUES — KITEZ VERS LA DROITE ! (" .. kills .. ")", "interrupt")
            ShowPrivate("TOI → MUR DROIT  (tu es distance)")
        elseif role == "HEALER" then
            ShowAlert("ECTOCLOQUES — DISSIPEZ LES RALENTISSEMENTS !", "interrupt")
            ShowPrivate("HEALER : dispel le ralentissement des fixated")
        elseif role == "TANK" then
            ShowAlert("ECTOCLOQUES — GÉREZ LES ADDS ! (" .. kills .. ")", "interrupt")
        else
            ShowAlert("ECTOCLOQUES — FOCUS LES ADDS ! (" .. kills .. ")", "interrupt")
        end

    elseif arg == "wall" then
        ShowAlert("MUR #1 DÉTRUIT — ESPACE LIBÉRÉ !", "phase")

    elseif arg == "roar" then
        ShowAlert("GRONDEMENT PRIMORDIAL — NE TOMBEZ PAS DE LA PLATEFORME !", "phase")

    elseif arg == "blister" then
        ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !")

    elseif arg == "smashed" then
        ShowPrivate("SMASHED ×2 — SWAP TANK MAINTENANT !")

    else
        print("|cff00ff00LH Vorasius|r  Rôle détecté : |cffffcc00" .. role .. "|r")
        print("  /lhvoratest [slam | beam | adds | wall | roar | blister | smashed]")
    end
end
