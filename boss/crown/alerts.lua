local addonName, M = ...

-- Crown of the Cosmos (Alleria Windrunner) — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/Crown.lua (TimersOther = Héroïque/Normal)
-- Stage 1→2 : dur=25 (StageEvent), Stage 2→3 : dur=60/59 (Devouring Cosmos)
local ENCOUNTER_ID = 3181

local inFight = false
local trackedAuras = {}
local activeTimers = {}
local stage = 1       -- 1, 2, 3
local dur4Count = 0   -- stage 1 pull : dur=4 → Tremor(1) → DarkHand(2) → RavenousAbyss(3)
local frame = CreateFrame("Frame")

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

-- ============================================================
-- Durées BigWigs Crown — TimersOther (Héroïque / Normal)
-- ============================================================
-- Stage 1 pull (first ~5 timers) :
--   25     → StageEvent (fin pull, transition vers stage 2) — pas d'alerte
--   24     → Silverstrike Arrow
--   5      → Grasp of Emptiness
--   12     → Void Expulsion (Easy=60)
--   2/46.5 → Null Corona
--   4      → Interrupting Tremor (1er) → Dark Hand (2e) → Ravenous Abyss (3e)
-- Stage 1 répétition :
--   21/23  → Silverstrike Arrow
--   28/32/31.5 → Grasp of Emptiness
--   20     → Interrupting Tremor
--   19.5   → Ravenous Abyss
--   26     → Dark Hand
--   39     → Void Expulsion
-- Stage 2 (confirmé par debug du joueur) :
--   11/13  → Null Corona
--   19/21  → Ranger Captain's Mark
--   14/16  → Void Expulsion
--   22/24  → Cosmic Barrier ← unique !
--   6      → Rift Slash (1er) / Voidstalker Sting (suivants)
--   5      → Voidstalker Sting
--   10/12  → Call of the Void (1er)
--   8      → Voidstalker Sting
-- Stage 3 :
--   60/59  → Devouring Cosmos (déclenche transition stage 3) ← unique !
--   30/29  → Null Corona
--   39/21  → Aspect of the End ← BigWigs confirmé (21s ≠ Ranger's Mark car stage == 3)
--   9      → Aspect of the End (nouveau cast) ← BigWigs confirmé
--   8      → Aspect of the End (refresh du cast à 21s) ← BigWigs confirmé
-- ============================================================

local function BuildTimerCallback(d, dExact)
    if stage == 1 then
        if d == 25 then
            return nil  -- StageEvent géré dans OnTimelineAdded

        -- Pull timers Héroïque
        elseif d == 24 then
            return function() ShowAlert("SILVERSTRIKE ARROW — VISE UN SENTINEL !") end
        elseif d == 5 then
            return function() ShowAlert("GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !") end
        elseif d == 12 or d == 60 then
            return function() ShowAlert("VOID EXPULSION — RANGED BAITEZ !", "soak") end
        elseif d == 2 then
            return function() ShowAlert("NULL CORONA — SOIN À FOND !") end
        elseif dExact < 4.1 and d == 4 then
            dur4Count = dur4Count + 1
            if dur4Count == 1 then
                return function() ShowAlert("INTERRUPTING TREMOR — STOP LES SORTS !", "interrupt") end
            elseif dur4Count == 2 then
                return function() ShowAlert("DARK HAND — INTERROMPRE !", "interrupt") end
            elseif dur4Count == 3 then
                return function() ShowAlert("RAVENOUS ABYSS — SORTEZ DE LA ZONE !") end
            end

        -- Répétition stage 1
        elseif d == 21 or d == 23 then
            return function() ShowAlert("SILVERSTRIKE ARROW — VISE UN SENTINEL !") end
        elseif dExact >= 19.3 and dExact <= 19.7 then
            -- 19.5 = Ravenous Abyss répétitif — arrondirait à 20 sans ce check précis
            return function() ShowAlert("RAVENOUS ABYSS — SORTEZ DE LA ZONE !") end
        elseif d == 20 then
            return function() ShowAlert("INTERRUPTING TREMOR — STOP LES SORTS !", "interrupt") end
        elseif d == 26 then
            return function() ShowAlert("DARK HAND — INTERROMPRE !", "interrupt") end
        elseif d == 39 then
            return function() ShowAlert("VOID EXPULSION — RANGED BAITEZ !", "soak") end
        end

    elseif stage == 2 then
        if d == 11 or d == 13 then
            return function() ShowAlert("NULL CORONA — SOIN À FOND !") end
        elseif d == 19 or d == 21 then
            return function() ShowAlert("RANGER CAPTAIN'S MARK — DISPERSE !", "soak") end
        elseif d == 14 or d == 16 then
            return function() ShowAlert("VOID EXPULSION — RANGED BAITEZ !", "soak") end
        elseif d == 22 or d == 24 then
            return function() ShowAlert("COSMIC BARRIER — BURST LE SIMULACRUM !", "soak") end
        elseif d == 6 then
            return function() ShowAlert("RIFT SLASH — CHERCHEZ LE SIMULACRUM !") end
        elseif d == 10 or d == 12 then
            return function() ShowAlert("CALL OF THE VOID — ADDS SPAWN !") end
        end

    elseif stage == 3 then
        if d == 60 or d == 59 then
            return function() ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase") end
        elseif d == 30 or d == 29 then
            return function() ShowAlert("NULL CORONA — SOIN À FOND !") end
        elseif d == 39 or d == 21 then
            return function() ShowAlert("ASPECT OF THE END — RANGED > MÊLÉE > TANK !", "phase") end
        elseif d == 9 or d == 8 then
            return function() ShowAlert("ASPECT OF THE END — RANGED > MÊLÉE > TANK !", "phase") end
        end
    end

    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local dExact = eventInfo.duration
    local d = math.floor(dExact + 0.5)

    -- Transitions de stage (détection immédiate à EVENT_ADDED)
    if stage == 1 and d == 25 then
        stage = 2
        dur4Count = 0
        if M.config and M.config.debugEncounter then
            print("|cff00ff00LH Debug|r CROWN → Stage 2 (dur=25)")
        end
        return
    end
    if (stage == 1 or stage == 2) and (d == 60 or d == 59) then
        stage = 3
        if M.config and M.config.debugEncounter then
            print("|cff00ff00LH Debug|r CROWN → Stage 3 (dur=" .. d .. ")")
        end
    end

    local cb = BuildTimerCallback(d, dExact)
    if cb then
        activeTimers[eventInfo.id] = {cb = cb, d = d}
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r CROWN TIMELINE stage=%d dur=%.2f id=%d", stage, dExact, eventInfo.id))
    end
end

local function OnTimelineStateChanged(eventID)
    local state = C_EncounterTimeline.GetEventState(eventID)
    local entry = activeTimers[eventID]
    if entry then
        if state == 2 then
            entry.cb()
        elseif state == 3 and entry.d == 4 and stage == 1 then
            -- Event annulé pendant le pull : corrige le compteur pour éviter la désync
            dur4Count = dur4Count - 1
        end
    end
    if state == 2 or state == 3 then
        activeTimers[eventID] = nil
    end
end

local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local function checkPrivate(spellID, key, msg)
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if aura and not trackedAuras[key] then
            trackedAuras[key] = true
            ShowPrivate(msg)
        elseif not aura then
            trackedAuras[key] = nil
        end
    end

    checkPrivate(1233602, "arrow",   "SILVERSTRIKE ARROW — VISE UN SENTINEL !")
    checkPrivate(1232470, "grasp",   "GRASP OF EMPTINESS — ORIENTEZ L'OBÉLISQUE !")
    checkPrivate(1233865, "corona",  "NULL CORONA — SOIN À FOND / DISPEL SI CRITIQUE !")
    checkPrivate(1243753, "rabyss",  "RAVENOUS ABYSS — SORTEZ DE LA ZONE !")
    checkPrivate(1237623, "mark",    "RANGER CAPTAIN'S MARK — VISE UN VOIDSPAWN !")
    checkPrivate(1237038, "sting",   "VOIDSTALKER STING — DOT SUR TOI (25s) !")
    checkPrivate(1239111, "aspect",  "ASPECT OF THE END — RESTEZ EN PLACE !")
end

local function ResetState()
    inFight = false
    trackedAuras = {}
    activeTimers = {}
    stage = 1
    dur4Count = 0
end

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
    end
end)

SLASH_LHCROWNTEST1 = "/lhcrowntest"
SlashCmdList["LHCROWNTEST"] = function()
    ShowAlert("DEVOURING COSMOS — PRENEZ LES PLUMES !", "phase")
    ShowPrivate("SILVERSTRIKE ARROW — VISE UN SENTINEL !")
end
