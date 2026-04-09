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
-- Shadowclaw Slam — pas de spellID direct via timeline (dur=16/136/240)
local SLAM_SPELL         = 1241844  -- réutilise SMASHED pour l'icône (même sort)
-- Fixation Ectocloque → joueur (SPELL_AURA_APPLIED depuis l'add)
-- 0 = catch-all (tout debuff depuis un Ectocloque) → à préciser via debugEncounter
local FIXATED_SPELL_ID   = 0        -- À CONFIRMER en jeu

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight          = false
local slamCount        = 0       -- Nombre de Shadowclaw Slams (pour tracking des murs)
local addKillCount     = 0       -- Kills d'Ectocloques dans la vague courante
local blistered        = false
local smashedStacks    = 0
local voidBreathActive = false
local activeTimers     = {}
local fixatedPlayers   = {}      -- { [playerName] = true } — joueurs fixés par un Ectocloque
local classCache       = {}      -- { [playerName] = "CLASSNAME" } — cache classe pour couleurs

local frame = CreateFrame("Frame")

-- ─── Affichage ────────────────────────────────────────────────────────────────
local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

-- ─── Classe et couleur des joueurs (pour la note RL) ─────────────────────────
-- Construit le cache nom→classe une seule fois, puis réutilise.
local function BuildClassCache()
    local n = GetNumGroupMembers()
    for i = 1, n do
        local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
        if name and fileName and fileName ~= "" then
            classCache[name] = fileName   -- ex: "WARRIOR", "PALADIN", "DRUID"…
        end
    end
    -- S'ajouter soi-même (solo / hors raid)
    local me = UnitName("player")
    if me and not classCache[me] then
        local _, cls = UnitClass("player")
        if cls then classCache[me] = cls end
    end
end

local function ClassColoredName(name)
    local class = classCache[name]
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) .. name .. "|r"
    end
    return "|cffffffff" .. name .. "|r"
end

-- ─── Note RL : liste des joueurs fixés par les Ectocloques ───────────────────
-- Visible uniquement par "Thiriäll" (guard dans M:ShowRLNote via IsRLNoteOwner).
local function UpdateFixateNote()
    local names = {}
    for name in pairs(fixatedPlayers) do
        names[#names + 1] = name
    end

    if #names == 0 then
        M:HideRLNote()
        return
    end

    table.sort(names)

    local colored = {}
    for _, name in ipairs(names) do
        colored[#colored + 1] = ClassColoredName(name)
    end

    -- Affichage en lignes de 3 (mur gauche / mur droit → 3 noms par ligne)
    local lines = { "|cffffff80FIXATED (" .. #names .. ")|r" }
    for i = 1, #colored, 3 do
        local row = {}
        for j = i, math.min(i + 2, #colored) do
            row[#row + 1] = colored[j]
        end
        lines[#lines + 1] = table.concat(row, "  ")
    end

    M:ShowRLNote(table.concat(lines, "\n"))
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
            ShowAlert("SHADOWCLAW SLAM — TANK ABSORBE !" .. wallMsg, "soak", SLAM_SPELL)
        end
    end

    -- Ectocloques / Blistercreeps — positionnement par rôle
    if d == 57 or d == 123 then
        return function()
            addKillCount = 0  -- Sécurité reset
            local role   = M:GetRole()
            local mythic = M.config and M.config.vorasiusMythicMode
            local kills  = mythic and "3 kills/mur" or "2 kills/mur"
            if role == "MELEE" then
                ShowAlert("ECTOCLOQUES — KITEZ VERS LA GAUCHE ! (" .. kills .. ")", "interrupt")
                M:ShowPrivateText("TOI \226\134\146 MUR GAUCHE  (tu es m\195\170l\195\169e)")
            elseif role == "RANGE" then
                ShowAlert("ECTOCLOQUES — KITEZ VERS LA DROITE ! (" .. kills .. ")", "interrupt")
                M:ShowPrivateText("TOI \226\134\146 MUR DROIT  (tu es distance)")
            elseif role == "HEALER" then
                ShowAlert("ECTOCLOQUES — DISSIPEZ LES RALENTISSEMENTS !", "interrupt")
                M:ShowPrivateText("HEALER : dispel le ralentissement des fixated")
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
    local _, event, _, _, sourceName, _, _, destGUID, destName, _, _, spellID =
        CombatLogGetCurrentEventInfo()

    -- Souffle du Vide (Void Breath) — détection du début de canalisation
    if event == "SPELL_CAST_START" or event == "SPELL_CHANNEL_START" then
        if spellID == VOID_BREATH_ID and not voidBreathActive then
            voidBreathActive = true
            ShowAlert("SOUFFLE DU VIDE — OBSERVEZ LE DÉPART DU RAYON !", "phase", VOID_BREATH_ID)
            M:ProgressBarCountdown(3, 16, "SOUFFLE DU VIDE", "phase", VOID_BREATH_ID)
            C_Timer.After(16, function()
                voidBreathActive = false
                M:ProgressBarHide(3)
            end)
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

    -- Fixation Ectocloque → joueur : mise à jour de la note RL
    -- sourceName = nom de l'Ectocloque, destName = joueur fixé
    if (event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REMOVED")
        and BLISTERCREEP_NAMES[sourceName] and destName then
        -- Filtre par spell ID si connu (FIXATED_SPELL_ID > 0), sinon catch-all
        local isFixation = (FIXATED_SPELL_ID == 0) or (spellID == FIXATED_SPELL_ID)
        if isFixation then
            if event == "SPELL_AURA_APPLIED" then
                fixatedPlayers[destName] = true
            else
                fixatedPlayers[destName] = nil
            end
            UpdateFixateNote()
        end
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r ECTO FIXATION %s → %s spellID=%d",
                event, tostring(destName), spellID or 0))
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
        ShowPrivate("BLISTERBURST — +100% DÉGÂTS REÇUS (30s) !", BLISTERBURST_AURA)
        local dur = (blister.expirationTime and blister.expirationTime > 0)
                    and (blister.expirationTime - GetTime())
                    or (blister.duration or 30)
        M:ProgressBarCountdown(1, dur, "BLISTERBURST", "soak", BLISTERBURST_AURA)
    elseif not blister and blistered then
        -- Guard : on ne cache que si la barre était active, pas à chaque UNIT_AURA
        blistered = false
        M:ProgressBarHide(1)
    end

    -- Smashed — vulnérabilité physique cumulable sur le tank
    local aura = M.FindAura("player", SMASHED_AURA, "HARMFUL")
    if aura then
        local stacks = aura.applications or 1
        if stacks ~= smashedStacks then
            smashedStacks = stacks
            if stacks == 1 then
                ShowPrivate("SMASHED ×1 — SWAP AU PROCHAIN SOAK !", SMASHED_AURA)
            elseif stacks >= SMASHED_SWAP_AT then
                ShowPrivate("SMASHED ×" .. stacks .. " — SWAP TANK MAINTENANT !", SMASHED_AURA)
            end
            local timeLeft = (aura.expirationTime and aura.expirationTime > 0)
                             and (aura.expirationTime - GetTime())
                             or (aura.duration or 20)
            M:ProgressBarCountdown(2, timeLeft, "SMASHED \215" .. stacks, "interrupt", SMASHED_AURA)
        end
    elseif smashedStacks > 0 then
        -- Guard : on ne cache que si des stacks étaient trackés
        smashedStacks = 0
        M:ProgressBarHide(2)
    end
end

-- ─── Register / Unregister CLEU ──────────────────────────────────────────────
local cleuRegistered = false

local function RegisterCLEU()
    if not cleuRegistered then
        C_Timer.After(0, function()
            frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            cleuRegistered = true
        end)
    end
end

local function UnregisterCLEU()
    if cleuRegistered then
        C_Timer.After(0, function()
            frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
            cleuRegistered = false
        end)
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
    fixatedPlayers   = {}
    classCache       = {}
    M:HideRLNote()
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    UnregisterCLEU()
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
            RegisterCLEU()
            BuildClassCache()   -- pré-remplit le cache nom→classe pour la note RL
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: ID=%s", tostring(encounterID)))
        end
        if encounterID == ENCOUNTER_ID then
            ResetState()
            M:HideText()
            M:HidePrivateText()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        ResetState()

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
    local role   = M:GetRole()
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
            M:ShowPrivateText("TOI \226\134\146 MUR GAUCHE  (tu es m\195\170l\195\169e)")
        elseif role == "RANGE" then
            ShowAlert("ECTOCLOQUES — KITEZ VERS LA DROITE ! (" .. kills .. ")", "interrupt")
            M:ShowPrivateText("TOI \226\134\146 MUR DROIT  (tu es distance)")
        elseif role == "HEALER" then
            ShowAlert("ECTOCLOQUES — DISSIPEZ LES RALENTISSEMENTS !", "interrupt")
            M:ShowPrivateText("HEALER : dispel le ralentissement des fixated")
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

    elseif arg == "fixate" then
        -- Simule la fixation de 6 joueurs (3 mêlée mur gauche + 3 distance mur droit)
        BuildClassCache()
        fixatedPlayers = {}
        local fakeNames = {
            "Smiths", "Lill\195\164ka", "Wadabloom",   -- mêlée → mur gauche
            "C\195\164bron", "Gnar", "Thiri\195\163ll", -- distance → mur droit
        }
        for _, name in ipairs(fakeNames) do
            fixatedPlayers[name] = true
        end
        UpdateFixateNote()

    elseif arg == "fixateclear" then
        fixatedPlayers = {}
        UpdateFixateNote()

    else
        print("|cff00ff00LH Vorasius|r  Rôle détecté : |cffffcc00" .. role .. "|r")
        print("  /lhvoratest [slam | beam | adds | wall | roar | blister | smashed | fixate | fixateclear]")
    end
end
