local addonName, M = ...

-- Belo'ren, Enfant d'Al'ar — The Voidspire (Midnight 12.0) — Héroïque/Mythique
-- SYSTÈME D'AURAS : chaque joueur reçoit VIDE ou LUMIÈRE (change à chaque essai).
-- L'aura détermine : qui soak les plongées, qui ramasse les orbes,
-- qui interrompt les adds, qui soak les cônes tanks.
-- IMPORTANT : eventInfo.spellID tainté en Midnight → identification Timeline par durée.
-- CLEU utilisé pour : auras joueurs, casts boss/adds, marqueurs de soak.
local ENCOUNTER_ID = 3182   -- à confirmer via debugEncounter si incorrect

-- ─── Spell IDs ────────────────────────────────────────────────────────────────

-- Aura Convergence Vide/Lumière
-- NOTE : En jeu il peut y avoir 2 IDs distincts (un par couleur).
-- → Activer debugEncounter, identifier les 2 IDs et les séparer ici.
local VOID_CONVERGENCE_ID    = 1242515   -- Convergence du Vide / de Lumière (base connue)
local LIGHT_CONVERGENCE_ID   = 1242515   -- (à splitter si 2e ID différent)

-- Soaks — Plongée Vide / Lumière
-- NOTE : MythicTrap liste un seul ID ; 2 IDs probables en jeu (un par couleur).
local DIVE_ID                = 1241292   -- Plongée du Vide / de Lumière (à splitter si nécessaire)

-- Tanks — Édit du Gardien
local GUARDIAN_EDICT_ID      = 1260763   -- Série de cônes frontaux colorés → tank matching couleur

-- Orbes — Échos Rayonnants
local RADIANT_ECHOES_ID      = 1242981   -- Orbes des deux couleurs → ramasser la sienne (évite boss)

-- Piquants Infusés (Héroïque/Mythique)
local INFUSED_QUILLS_ID      = 1242260   -- Marqué couleur OPPOSÉE → joueur couleur MATCHING soak

-- Adds — Éruption Vide / Lumière
-- NOTE : Probablement 2 IDs distincts en jeu (add Void vs add Light).
local ERUPTION_ID            = 1243854   -- Add qui cast → interrompre par joueur couleur MATCHING

-- Renaissance — Œuf 15s
local REBIRTH_ID             = 1263412   -- Add meurt → œuf (15s pour kill sinon respawn)

-- Boss — Transitions
local DEATH_DROP_ID          = 1246709   -- Boss tombe au centre → ÉLOIGNEZ-VOUS (→ Phase 2)

-- DoTs / Passifs
local BURNING_HEART_ID       = 1283067   -- Dégâts raid pulsants (↑↑ pendant Renaissance)
local ETERNAL_BURNS_ID       = 1244344   -- Bouclier absorb + DoT tank → soigner l'absorb

-- Phase 2 — Œuf
local INCUBATION_FLAMES_ID   = 1242792   -- Zones colorées Phase 2 — aller dans SA zone
local ASHEN_BENEDICTION_ID   = 1262573   -- Burst Feu + stack réduction soins (→ tuer œuf vite)

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight             = false
local activeTimers        = {}
local trackedAuras        = {}
local cleuRegistered      = false
local myAura              = nil        -- "VOID" | "LIGHT" | nil  (auto-détecté ou config)
local currentPhase        = 1         -- 1 = boss actif, 2 = œuf
local ashenStacks         = 0
local auraReminderTicker  = nil
local eruptionCooldown    = false
local rebirthCooldown     = false
local deathDropCooldown   = false

local frame = CreateFrame("Frame")

-- ─── Détection et label de l'aura ─────────────────────────────────────────────
local function GetMyAura()
    -- La config prend toujours la priorité (changeable dans /lh → Belo'ren)
    local cfg = M.config and M.config.belorenPlayerAura
    if cfg and cfg ~= "AUTO" then return cfg end
    -- Sinon : valeur auto-détectée via UNIT_AURA ou slash command
    return myAura
end

local function AuraLabel(aura)
    if aura == "VOID"  then return "|cffb05be8VIDE|r"    end
    if aura == "LIGHT" then return "|cffffcc00LUMIÈRE|r"  end
    return "|cffff8080???|r"
end

local function OppAura(aura)
    if aura == "VOID"  then return "LIGHT" end
    if aura == "LIGHT" then return "VOID"  end
    return nil
end

-- ─── Helpers alertes ─────────────────────────────────────────────────────────
local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

local function ShowDispel(msg, spellID)
    M:ShowDispelText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("dispel") end
end

-- ─── CLEU lazy-register ───────────────────────────────────────────────────────
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

-- ─── Rappel d'aura (toutes les 60s) ──────────────────────────────────────────
-- Rappelle régulièrement au joueur sa couleur pour éviter les erreurs de mécanique.
local function ShowAuraReminder()
    local aura = GetMyAura()
    if not aura then
        ShowPrivate("|cffff8080⚠ AURA INCONNUE|r — vérifie tes buffs ou  /lhbeloren void|light", nil)
        return
    end
    ShowPrivate("TON AURA : " .. AuraLabel(aura), VOID_CONVERGENCE_ID)
end

local function StartAuraReminder()
    if auraReminderTicker then
        auraReminderTicker:Cancel()
        auraReminderTicker = nil
    end
    -- Premier rappel dès 5s (laisse le temps de se positionner)
    C_Timer.After(5, function()
        if inFight then ShowAuraReminder() end
    end)
    -- Puis rappel toutes les 60s
    auraReminderTicker = C_Timer.NewTicker(60, function()
        if inFight then ShowAuraReminder() end
    end)
end

-- ─── Plongée Vide / Lumière : soak cercle ────────────────────────────────────
-- Un joueur est marqué par un cercle → les joueurs de SA couleur viennent soak.
-- Knockback + flaque permanente en bordure → le marqué se place en bord.
local function OnDiveApplied(destName, spellId)
    local myName = UnitName("player")
    local myA    = GetMyAura()

    -- Tenter de déterminer la couleur via le nom du sort (robuste si 2 IDs distincts)
    local spellName = C_Spell.GetSpellName(spellId) or ""
    local nameLow   = spellName:lower()
    local isVoid    = nameLow:find("vide") or nameLow:find("void")
    local diveAura  = isVoid and "VOID" or "LIGHT"
    local diveLabel = AuraLabel(diveAura)

    -- Alerte globale : tout le monde voit le marqué et la couleur concernée
    ShowAlert(
        "PLONGÉE " .. diveLabel .. "  |cffffff00" .. destName .. "|r  — " .. diveLabel .. " SOAKEZ !",
        "soak", spellId
    )

    if myName == destName then
        -- Le joueur marqué : se placer en bordure et attendre
        ShowPrivate("TU ES MARQUÉ " .. diveLabel .. "  — PLACE-TOI EN BORDURE !", spellId)
    elseif myA == diveAura then
        -- Les joueurs de la bonne couleur : venir soak
        ShowPrivate(
            "SOAK PLONGÉE " .. diveLabel .. " → |cffffff00" .. destName .. "|r  !",
            spellId
        )
    end
end

-- ─── Piquants Infusés (Héroïque/Mythique) : soak couleur opposée ──────────────
-- Le joueur cible reçoit un piquant de sa couleur OPPOSÉE.
-- → Un joueur de la couleur du piquant doit venir soak.
local function OnInfusedQuillsApplied(destName, spellId)
    local myName = UnitName("player")
    local myA    = GetMyAura()

    -- Déterminer la couleur du piquant via nom du sort
    local spellName  = C_Spell.GetSpellName(spellId) or ""
    local nameLow    = spellName:lower()
    local isVoid     = nameLow:find("vide") or nameLow:find("void")
    local quillAura  = isVoid and "VOID" or "LIGHT"
    local quillLabel = AuraLabel(quillAura)

    ShowAlert(
        "PIQUANT " .. quillLabel .. "  |cffffff00" .. destName .. "|r  — " .. quillLabel .. " SOAK !",
        "soak", spellId
    )

    if myName == destName then
        -- Le joueur marqué : un joueur de couleur OPPOSÉE (= couleur du piquant) arrive
        ShowPrivate(
            "PIQUANT SUR TOI — " .. quillLabel .. " TE COUVRE !",
            spellId
        )
    elseif myA == quillAura then
        -- Le soaker de la bonne couleur
        ShowPrivate(
            "SOAK PIQUANT " .. quillLabel .. " → |cffffff00" .. destName .. "|r  !",
            spellId
        )
    end
end

-- ─── Édit du Gardien : cônes frontaux tank ────────────────────────────────────
-- Série de cônes colorés sur les tanks → chaque tank soak son cône de SA couleur.
-- Si couleur opposée touchée ou personne → le boss enrage.
local function OnGuardianEdictCast()
    local role = M:GetRole()
    local myA  = GetMyAura()

    -- Depuis le nerf : Édit du Gardien donne +20% dmg au boss — tout le raid doit le savoir
    ShowAlert("ÉDIT DU GARDIEN — TANKS  |cffff8080CÔNE COLORÉ|r  |cffff4444BOSS +20% DMG|r  !", "phase", GUARDIAN_EDICT_ID)

    if role == "TANK" then
        ShowPrivate(
            "ÉDIT — TON CÔNE " .. AuraLabel(myA) .. "  — POSITIONNE-TOI  |cffff4444(+20% DMG BOSS)|r !",
            GUARDIAN_EDICT_ID
        )
    end
end

-- ─── Échos Rayonnants : orbes à ramasser ──────────────────────────────────────
-- Orbes des deux couleurs traversent la salle → ramasser UNIQUEMENT sa couleur.
-- Sur Mythique : les orbes explosent au contact du boss.
local function OnRadiantEchoes()
    local myA = GetMyAura()
    ShowAlert(
        "ORBES — RAMASSEZ VOS COULEURS  |cffa0ffa0(évitez le boss !)|r",
        "global", RADIANT_ECHOES_ID
    )
    ShowPrivate("RAMASSE LES ORBES " .. AuraLabel(myA) .. " !", RADIANT_ECHOES_ID)
end

-- ─── Éruption Vide / Lumière : add → interrompre couleur matching ─────────────
-- L'add caste → SEULEMENT les joueurs de la couleur CORRESPONDANTE peuvent interrompre.
local function OnEruptionCast(spellId)
    if eruptionCooldown then return end
    eruptionCooldown = true
    C_Timer.After(2, function() eruptionCooldown = false end)

    local myA       = GetMyAura()
    local spellName = C_Spell.GetSpellName(spellId) or ""
    local nameLow   = spellName:lower()
    local isVoid    = nameLow:find("vide") or nameLow:find("void")
    local addAura   = isVoid and "VOID" or "LIGHT"
    local addLabel  = AuraLabel(addAura)

    ShowAlert(
        "ADD ÉRUPTION " .. addLabel .. "  — INTERRUPT " .. addLabel .. " !",
        "interrupt", spellId
    )

    if myA == addAura then
        ShowPrivate("INTERROMPS L'ADD " .. addLabel .. " !", spellId)
    end
end

-- ─── Renaissance : add meurt → œuf (15s) ─────────────────────────────────────
-- Quand un add meurt, il devient un œuf. 15s pour le tuer sinon il respawn.
-- Pendant cette phase : Cœur Brûlant fait plus de dégâts au raid.
local function OnRebirth()
    if rebirthCooldown then return end
    rebirthCooldown = true
    C_Timer.After(5, function() rebirthCooldown = false end)

    -- Dégâts de Renaissance fortement réduits sur Mythique (nerf) — timer 15s inchangé
    ShowAlert(
        "RENAISSANCE — TUEZ L'ŒUF  |cffffff0015s|r  !",
        "phase", REBIRTH_ID
    )
    M:ProgressBarCountdown(2, 15, "RENAISSANCE", "soak", REBIRTH_ID)

    -- Rappel à T+10s (5s restantes)
    C_Timer.After(10, function()
        if inFight then
            ShowAlert(
                "RENAISSANCE — |cffffff005s RESTANTES|r — KILL L'ŒUF !",
                "phase", REBIRTH_ID
            )
        end
    end)
end

-- ─── Chute Mortelle : boss tombe au centre → éloignement ──────────────────────
-- Le boss s'écrase au centre de la salle → plus on est loin, moins on prend.
-- Déclenche la transition vers la Phase 2 (Œuf).
local function OnDeathDrop()
    if deathDropCooldown then return end
    deathDropCooldown = true
    C_Timer.After(10, function() deathDropCooldown = false end)

    ShowAlert(
        "CHUTE MORTELLE — ÉLOIGNEZ-VOUS DU CENTRE !",
        "phase", DEATH_DROP_ID
    )
end

-- ─── Brûlures Éternelles : bouclier absorb + DoT tank ────────────────────────
-- Un shield d'absorption apparaît sur le tank + DoT.
-- Il faut soigner à travers le bouclier pour le faire disparaître.
local function OnEternalBurnsApplied(destName)
    local myName = UnitName("player")
    local role   = M:GetRole()

    if myName == destName then
        ShowPrivate("BRÛLURES ÉTERNELLES — SOIGNE TON BOUCLIER !", ETERNAL_BURNS_ID)
    elseif role == "HEALER" then
        ShowPrivate(
            "BRÛLURES ÉTERNELLES → |cffffff00" .. destName .. "|r — SOIGNE L'ABSORB !",
            ETERNAL_BURNS_ID
        )
    end
end

-- ─── Incubation des Flammes : Phase 2 → zones colorées ───────────────────────
-- La salle se divise en zones colorées (Vide / Lumière).
-- Chaque joueur rejoint la zone de SA couleur pour 30s de DPS sur l'œuf.
local function OnIncubationFlames()
    currentPhase = 2
    ashenStacks  = 0
    local myA    = GetMyAura()

    ShowAlert(
        "PHASE 2 — REJOIGNEZ VOS ZONES  |cffa0ffa0DPS L'ŒUF !|r",
        "phase", INCUBATION_FLAMES_ID
    )
    M:ShowPrivateText("VA DANS LA ZONE " .. AuraLabel(myA) .. " !", INCUBATION_FLAMES_ID)
    M:ProgressBarCountdown(1, 30, "INCUBATION DES FLAMMES", "phase", INCUBATION_FLAMES_ID)

    -- Rappel d'aura 3s après la transition (beaucoup de mouvement)
    C_Timer.After(3, function()
        if inFight then ShowAuraReminder() end
    end)
end

-- ─── Bénédiction Cendre : burst Feu + stacks réduction soins ─────────────────
-- Explosion de feu en Phase 2. Les stacks s'accumulent à chaque Phase 2 :
-- plus de stacks = soins de plus en plus réduits → tuer l'œuf rapidement !
local function OnAshenBenedictionCast()
    ashenStacks = ashenStacks + 1
    local warn  = ""
    if ashenStacks >= 3 then
        warn = "  |cffff4444⚠ STACK " .. ashenStacks .. " — SOINS RÉDUITS|r"
    end
    ShowAlert(
        "BÉNÉDICTION CENDRE" .. warn .. "  — BURST MAX !",
        "phase", ASHEN_BENEDICTION_ID
    )
end

-- ─── UNIT_AURA : auto-détection de l'aura Vide / Lumière ─────────────────────
-- Réévaluée à CHAQUE tick : le boss peut changer l'aura en cours de combat.
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    -- Détecter l'aura active (par nom du sort, résistant au split d'IDs)
    local detected = nil

    local auraInfo = C_UnitAuras.GetPlayerAuraBySpellID(VOID_CONVERGENCE_ID)
    if auraInfo then
        local nameLow = (auraInfo.name or ""):lower()
        if nameLow:find("vide") or nameLow:find("void") then
            detected = "VOID"
        elseif nameLow:find("lumi") or nameLow:find("light") then
            detected = "LIGHT"
        end
    end

    -- Si on a un 2e ID distinct pour la lumière, vérifier aussi
    if not detected and LIGHT_CONVERGENCE_ID ~= VOID_CONVERGENCE_ID then
        local lightInfo = C_UnitAuras.GetPlayerAuraBySpellID(LIGHT_CONVERGENCE_ID)
        if lightInfo then
            detected = "LIGHT"
        end
    end

    -- Mise à jour uniquement si l'aura a changé (détection initiale ou changement en combat)
    if detected and detected ~= myAura then
        local prev = myAura
        myAura            = detected
        trackedAuras.aura = true
        if prev then
            -- Changement d'aura en cours de combat (boss switch Vide ↔ Lumière)
            ShowPrivate(
                "⚠ AURA CHANGÉE : " .. AuraLabel(prev) .. "  →  " .. AuraLabel(detected),
                VOID_CONVERGENCE_ID
            )
        else
            -- Première détection en début de combat
            ShowPrivate("AURA DÉTECTÉE : " .. AuraLabel(myAura), VOID_CONVERGENCE_ID)
        end
    elseif not detected and not inFight then
        -- Hors combat : on peut reset (wipe, entre les essais)
        trackedAuras.aura = nil
    end
    -- Si detected == nil en combat : aura absente temporairement (reapplication) → on garde myAura

    -- Brûlures Éternelles (tank absorb + DoT)
    local eternBurns = C_UnitAuras.GetPlayerAuraBySpellID(ETERNAL_BURNS_ID)
    if eternBurns and not trackedAuras.eternBurns then
        trackedAuras.eternBurns = true
        ShowPrivate("BRÛLURES ÉTERNELLES — SOIGNE TON BOUCLIER !", ETERNAL_BURNS_ID)
    elseif not eternBurns then
        trackedAuras.eternBurns = nil
    end
end

-- ─── Timeline : Échos Rayonnants ─────────────────────────────────────────────
-- Les orbes sont un event récurrent → durée à confirmer via debugEncounter.
local function BuildTimerCallback(d)
    -- Échos Rayonnants — durée à confirmer en jeu via debugEncounter
    if d == 45 or d == 46 or d == 47 then
        return function() OnRadiantEchoes() end
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
        print(string.format("|cff00ff00LH Debug|r BELOREN TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    if state == 2 then
        local cb = activeTimers[eventID]
        if cb then cb() end
    end
    if state == 2 or state == 3 then
        activeTimers[eventID] = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight           = false
    activeTimers      = {}
    trackedAuras      = {}
    myAura            = nil
    currentPhase      = 1
    ashenStacks       = 0
    eruptionCooldown  = false
    rebirthCooldown   = false
    deathDropCooldown = false
    if auraReminderTicker then
        auraReminderTicker:Cancel()
        auraReminderTicker = nil
    end
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    UnregisterCLEU()
end

-- ─── Commandes de test ────────────────────────────────────────────────────────
-- /lhbeloren void|light     → Définir son aura manuellement
-- /lhbeloren aura           → Afficher son aura actuelle
-- /lhbeloren [mécanique]    → Simuler une alerte
SLASH_LHBELORENTEST1 = "/lhbeloren"
SlashCmdList["LHBELORENTEST"] = function(arg)
    local me = UnitName("player")
    arg = arg and arg:lower() or ""

    if arg == "void" then
        myAura = "VOID"
        ShowPrivate("AURA DÉFINIE : " .. AuraLabel("VOID"), VOID_CONVERGENCE_ID)

    elseif arg == "light" then
        myAura = "LIGHT"
        ShowPrivate("AURA DÉFINIE : " .. AuraLabel("LIGHT"), LIGHT_CONVERGENCE_ID)

    elseif arg == "aura" then
        ShowAuraReminder()

    elseif arg == "dive" then
        OnDiveApplied(me, DIVE_ID)

    elseif arg == "quill" then
        OnInfusedQuillsApplied(me, INFUSED_QUILLS_ID)

    elseif arg == "edict" then
        OnGuardianEdictCast()

    elseif arg == "orbs" then
        OnRadiantEchoes()

    elseif arg == "eruption" then
        OnEruptionCast(ERUPTION_ID)

    elseif arg == "rebirth" then
        OnRebirth()

    elseif arg == "deathdrop" then
        OnDeathDrop()

    elseif arg == "eternal" then
        OnEternalBurnsApplied(me)

    elseif arg == "phase2" then
        OnIncubationFlames()

    elseif arg == "ashen" then
        OnAshenBenedictionCast()

    else
        print("|cff00ff00LH Belo'ren|r /lhbeloren :")
        print("  |cffffff00void|light|r  — Définir ton aura manuellement")
        print("  |cffffff00aura|r        — Afficher ton aura actuelle")
        print("  |cffffff00dive|r        — Plongée Vide/Lumière (soak)")
        print("  |cffffff00quill|r       — Piquant Infusé (Héroïque)")
        print("  |cffffff00edict|r       — Édit du Gardien (cône tank)")
        print("  |cffffff00orbs|r        — Échos Rayonnants (orbes)")
        print("  |cffffff00eruption|r    — Add Éruption (interrupt)")
        print("  |cffffff00rebirth|r     — Renaissance (œuf 15s)")
        print("  |cffffff00deathdrop|r   — Chute Mortelle (transition P2)")
        print("  |cffffff00eternal|r     — Brûlures Éternelles (tank)")
        print("  |cffffff00phase2|r      — Incubation des Flammes (Phase 2)")
        print("  |cffffff00ashen|r       — Bénédiction Cendre (burst + stack)")
    end
end

-- ─── Événements ──────────────────────────────────────────────────────────────
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
            StartAuraReminder()
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END id=%s", tostring(encounterID)))
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

    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not inFight then return end
        local _, subevent, _, _, srcName, _, _, _, destName, _, _, spellId = CombatLogGetCurrentEventInfo()

        -- ── SPELL_AURA_APPLIED ────────────────────────────────────────────────
        if subevent == "SPELL_AURA_APPLIED" then

            if spellId == DIVE_ID then
                -- NOTE : Si 2 IDs distincts (Void/Light), ajouter ici :
                --   elseif spellId == DIVE_LIGHT_ID then OnDiveApplied(destName, spellId)
                OnDiveApplied(destName, spellId)

            elseif spellId == INFUSED_QUILLS_ID then
                OnInfusedQuillsApplied(destName, spellId)

            elseif spellId == ETERNAL_BURNS_ID then
                OnEternalBurnsApplied(destName)

            elseif spellId == REBIRTH_ID then
                OnRebirth()

            end

        -- ── SPELL_CAST_START ──────────────────────────────────────────────────
        elseif subevent == "SPELL_CAST_START" then

            if spellId == GUARDIAN_EDICT_ID then
                OnGuardianEdictCast()

            elseif spellId == ERUPTION_ID then
                -- NOTE : Si 2 IDs distincts (add Void vs add Light), ajouter ici :
                --   elseif spellId == ERUPTION_LIGHT_ID then OnEruptionCast(spellId)
                OnEruptionCast(spellId)

            elseif spellId == DEATH_DROP_ID then
                OnDeathDrop()

            elseif spellId == INCUBATION_FLAMES_ID then
                OnIncubationFlames()

            elseif spellId == ASHEN_BENEDICTION_ID then
                OnAshenBenedictionCast()

            end
        end
    end
end)
