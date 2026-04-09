local addonName, M = ...

-- Lightblinded Vanguard — The Voidspire (Midnight 12.0)
-- Détection principale via CLEU (SPELL_CAST_START) pour les mécaniques clés :
--   Searing Radiance, Sacred Toll, Sacred Shield, Blinding Light
-- Timeline conservée pour : Aura of X, Divine Toll, Execution Sentence (global), Divine Storm
-- CLEU spellIDs ne sont PAS taintés en Midnight — comparaison directe sûre.
local ENCOUNTER_ID = 3180

-- ─── Spell IDs (CLEU — non taintés) ──────────────────────────────────────────
local SPELL_SEARING_RAD  = 1255738  -- Rayonnance Ardente (Senn) → SPREAD 2s
local SPELL_SACRED_TOLL  = 1246749  -- Péage Sacré (Venel) → RAID DAMAGE 2s
local SPELL_SACRED_SHIELD= 1248674  -- Bouclier Sacré (Senn) → shield à burst + kick
local SPELL_BLINDING     = 1258514  -- Lumière Aveuglante (Senn) → interrupt 7s
local SPELL_DIVINE_TOLL  = 1248644  -- Divine Toll (Bellamy) → éviter boucliers
local SPELL_DIVINE_STORM = 1246765  -- Tempête Divine → tornades
local SPELL_ELEKK        = 1249130  -- Elekk Charge → esquiver
-- Auras joueur (UNIT_AURA — GetPlayerAuraBySpellID)
local SPELL_EXEC         = 1248985  -- Execution Sentence (privé joueur ciblé)
local SPELL_EXEC_ALT     = 1248994  -- variante
-- Timers de phase (timeline)
local SPELL_AURA_WRATH   = 1248449  -- Aura of Wrath → Venel sur le bord
local SPELL_AURA_DEV     = 1246162  -- Aura of Devotion → Bellamy sur le bord
local SPELL_AURA_PEACE   = 1248451  -- Aura of Peace → Senn sur le bord

-- Durée du cast de Blinding Light (BigWigs : ~7s à confirmer via debug)
local BLINDING_CAST      = 7.0
-- Durée du bouclier Sacred Shield (BigWigs timeline : dur=17)
local SACRED_SHIELD_DUR  = 17.0
-- Deadline pour burst le shield (secondes restantes) — marker rouge à cette position
-- Valeur estimée : 7s restantes = après ce point c'est trop tard
local SACRED_SHIELD_DEADLINE = 7.0

-- ─── État ─────────────────────────────────────────────────────────────────────
local inFight         = false
local trackedAuras    = {}
local activeTimers    = {}
local cleuRegistered  = false
local shieldActive    = false
local spreadCooldown  = false
local tollCooldown    = false
local blindCooldown   = false

local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
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

-- ─── Handlers CLEU ───────────────────────────────────────────────────────────

-- Searing Radiance : Senn caste → SPREAD (2s pour s'écarter)
local function OnSearingRadiance()
    if spreadCooldown then return end
    spreadCooldown = true
    C_Timer.After(2 + 1, function() spreadCooldown = false end)
    ShowAlert("SPREAD — RAYONNANCE ARDENTE !", "soak", SPELL_SEARING_RAD)
    M:ProgressBarCountdown(2, 2.0, "SPREAD — ÉCARTEZ-VOUS", "soak", SPELL_SEARING_RAD)
end

-- Sacred Toll : Venel caste → dégâts raid dans 2s
local function OnSacredToll()
    if tollCooldown then return end
    tollCooldown = true
    C_Timer.After(2 + 1, function() tollCooldown = false end)
    ShowAlert("SACRED TOLL — DÉGÂTS RAID !", "global", SPELL_SACRED_TOLL)
    M:ProgressBarCountdown(3, 2.0, "SACRED TOLL — DÉGÂTS RAID", "global", SPELL_SACRED_TOLL)
end

-- Blinding Light : Senn caste → interrompre dans 7s (cast long)
local function OnBlindingLight()
    if blindCooldown then return end
    blindCooldown = true
    C_Timer.After(BLINDING_CAST + 1, function() blindCooldown = false end)
    ShowAlert("BLINDING LIGHT — INTERROMPRE !", "interrupt", SPELL_BLINDING)
    M:ProgressBarCountdown(4, BLINDING_CAST, "BLINDING LIGHT — KICK", "interrupt", SPELL_BLINDING)
end

-- Sacred Shield : Senn cast → barre bleue 17s avec marker deadline rouge
-- Quand le shield est détruit (SPELL_CAST_SUCCESS sur Blinding Light ou
-- perte de l'aura shield), alerte kick.
local function OnSacredShield()
    if shieldActive then return end
    shieldActive = true
    ShowAlert("SACRED SHIELD — BURST LE BOUCLIER !", "interrupt", SPELL_SACRED_SHIELD)
    -- Barre bleue slot 4 avec marker rouge à SACRED_SHIELD_DEADLINE secondes restantes
    M:ProgressBarCountdownDeadline(4, SACRED_SHIELD_DUR, "SACRED SHIELD — BURST",
        "phase", SPELL_SACRED_SHIELD, SACRED_SHIELD_DEADLINE)
end

local function OnSacredShieldBroken()
    if not shieldActive then return end
    shieldActive = false
    M:ProgressBarHide(4)
    -- Kick dès que le shield tombe
    ShowAlert("SHIELD DÉTRUIT — KICK BLINDING LIGHT !", "interrupt", SPELL_BLINDING)
end

-- ─── Timeline (mécaniques sans cast CLEU fiable) ──────────────────────────────
local function BuildTimerCallback(d)
    if d == 10 or d == 23 or d == 20 then
        -- Sacred Toll : aussi sur timeline comme fallback
        return nil  -- géré par CLEU, pas de doublon
    elseif d == 18 or d == 15 then
        return function() ShowAlert("DIVINE STORM — ÉVITEZ LES TORNADES !") end
    elseif d == 30 or d == 82 or d == 86 then
        return function() ShowAlert("EXECUTION SENTENCE — SOAK LES CERCLES !", "soak", SPELL_EXEC) end
    elseif d == 35 then
        return function() ShowAlert("AURA OF DEVOTION — BELLAMY SUR LE BORD !", "phase", SPELL_AURA_DEV) end
    elseif d == 38 or d == 26 or d == 29 or d == 22 then
        return function() ShowAlert("DIVINE TOLL — ÉVITEZ LES BOUCLIERS !",  "global", SPELL_DIVINE_TOLL) end
    elseif d == 79 or d == 83 then
        return function() ShowAlert("AURA OF WRATH — VENEL SUR LE BORD !", "phase", SPELL_AURA_WRATH) end
    elseif d == 131 or d == 132 then
        return function() ShowAlert("AURA OF PEACE — SENN SUR LE BORD !", "phase", SPELL_AURA_PEACE) end
    end
    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local d = math.floor(eventInfo.duration + 0.5)
    local cb = BuildTimerCallback(d)
    if cb then
        activeTimers[eventInfo.id] = cb
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r VANGUARD TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
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

-- ─── UNIT_AURA : Execution Sentence (privé) + suivi Sacred Shield ────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local exec = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_EXEC)
              or C_UnitAuras.GetPlayerAuraBySpellID(SPELL_EXEC_ALT)
    if exec and not trackedAuras.exec then
        trackedAuras.exec = true
        ShowPrivate("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !", SPELL_EXEC)
        local dur = (exec.expirationTime and exec.expirationTime > 0)
                    and (exec.expirationTime - GetTime())
                    or (exec.duration or 15)
        M:ProgressBarCountdown(1, dur, "EXECUTION SENTENCE", "soak", SPELL_EXEC)
    elseif not exec then
        trackedAuras.exec = nil
        M:ProgressBarHide(1)
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight        = false
    trackedAuras   = {}
    activeTimers   = {}
    shieldActive   = false
    spreadCooldown = false
    tollCooldown   = false
    blindCooldown  = false
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    M:ProgressBarHide(3)
    M:ProgressBarHide(4)
    UnregisterCLEU()
end

-- ─── Événements ───────────────────────────────────────────────────────────────
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
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        if M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r END: %s (ID: %s)", tostring(encounterName), tostring(encounterID)))
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
        local _, subevent, _, _, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()

        if subevent == "SPELL_CAST_START" then
            if     spellId == SPELL_SEARING_RAD  then OnSearingRadiance()
            elseif spellId == SPELL_SACRED_TOLL  then OnSacredToll()
            elseif spellId == SPELL_BLINDING     then OnBlindingLight()
            elseif spellId == SPELL_SACRED_SHIELD then OnSacredShield()
            end

        elseif subevent == "SPELL_CAST_SUCCESS" then
            -- Sacred Shield peut aussi fire sur CAST_SUCCESS
            if spellId == SPELL_SACRED_SHIELD and not shieldActive then
                OnSacredShield()
            end

        elseif subevent == "SPELL_AURA_REMOVED" then
            -- Shield brisé = l'aura disparaît du boss → alerte kick
            if spellId == SPELL_SACRED_SHIELD then
                OnSacredShieldBroken()
            end
        end
    end
end)

SLASH_LHVANGUARDTEST1 = "/lhvanguardtest"
SlashCmdList["LHVANGUARDTEST"] = function(arg)
    if arg == "spread" then
        OnSearingRadiance()
    elseif arg == "toll" then
        OnSacredToll()
    elseif arg == "blind" then
        OnBlindingLight()
    elseif arg == "shield" then
        OnSacredShield()
    elseif arg == "broken" then
        OnSacredShieldBroken()
    elseif arg == "exec" then
        ShowAlert("EXECUTION SENTENCE — SOAK LES CERCLES !", "soak", SPELL_EXEC)
        ShowPrivate("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !", SPELL_EXEC)
    elseif arg == "peace" then
        ShowAlert("AURA OF PEACE — SENN SUR LE BORD !", "phase", SPELL_AURA_PEACE)
    else
        print("|cff00ff00LH Vanguard|r /lhvanguardtest spread|toll|blind|shield|broken|exec|peace")
    end
end
