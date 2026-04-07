local addonName, M = ...

-- Lightblinded Vanguard — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/Vanguard.lua (Heroic initial + Mythic)
-- ⚠ Encounter très complexe (rotation ~159s, ~8 abilities) — debug pour les durées inconnues
local ENCOUNTER_ID = 3180

local inFight = false
local trackedAuras = {}
local activeTimers = {}
local frame = CreateFrame("Frame")

local function ShowAlert(msg, soundType, spellID)
    M:ShowText(msg, soundType, spellID)
    if M.PlayAlertSound then M:PlayAlertSound(soundType or "global") end
end

local function ShowPrivate(msg, spellID)
    M:ShowPrivateText(msg, spellID)
    if M.PlayAlertSound then M:PlayAlertSound("private") end
end

-- SpellIDs connus pour les icônes
local SPELL_EXEC   = 1248985
local SPELL_BLIND  = 1258514

-- Durées BigWigs Vanguard — Héroïque (TimersHeroic) + Mythique (TimersMythic) :
--   10       → Sacred Toll (Héroïque pull ; Mythique: 20)
--   15       → Avenger's Shield (Héroïque) — alerte tank, pas de message raid
--   17       → Sacred Shield (toutes difficultés)
--   18       → Divine Storm (Héroïque ; Mythique: 15/123)
--   23       → Sacred Toll (Normal pull)
--   26       → Judgement Blue (Héroïque/Normal) / Aura of Devotion (Mythique)
--   29       → Divine Toll (Mythique)
--   30       → Judgement Red (Héroïque/Normal pull)
--   35       → Aura of Devotion (Héroïque/Normal pull)
--   38       → Divine Toll (Héroïque ; Mythique: 26/29/22)
--   47       → Searing Radiance (Héroïque ; Mythique: 7/59)
--   66/12    → Avenger's Shield (Mythique) — pas d'alerte raid
--   79/83    → Aura of Wrath (79=Mythique, 83=Héroïque)
--   82/86    → Execution Sentence (82=Mythique, 86=Héroïque)
--   131/132  → Aura of Peace (131=Héroïque, 132=Mythique)
--   135      → Tyr's Wrath (Mythique uniquement, non tracké)
-- Blinding Light : private aura 1258514 — détecté dans OnUnitAura
-- Elekk Charge : buff sur les NPCs (BigWigs: "lol"), non trackable
-- dur=15 = Avenger's Shield (Héroïque) — tank ability, pas d'alerte raid
-- dur=45 = repeating timer post-pull, non cartographié par BigWigs non plus
local function BuildTimerCallback(d)
    if d == 15 then
        return nil  -- Avenger's Shield (Héroïque) = tank ability, pas d'alerte
    elseif d == 10 or d == 23 or d == 20 then
        return function() ShowAlert("SACRED TOLL — CD DE SOIN !") end
    elseif d == 17 then
        return function() ShowAlert("SACRED SHIELD — BURST LE BOUCLIER !", "interrupt") end
    elseif d == 18 then
        return function() ShowAlert("DIVINE STORM — ÉVITEZ LES TORNADES !") end
    elseif d == 30 or d == 82 or d == 86 then
        -- 30=Judgement Red(Héroïque/Normal pull), 82=Mythique, 86=Héroïque
        return function() ShowAlert("EXECUTION SENTENCE — SOAK LES CERCLES !", "soak", SPELL_EXEC) end
    elseif d == 35 then
        return function() ShowAlert("AURA OF DEVOTION — BELLAMY SUR LE BORD !", "phase") end
    elseif d == 38 or d == 26 or d == 29 or d == 22 then
        return function() ShowAlert("DIVINE TOLL — ÉVITEZ LES BOUCLIERS !") end
    elseif d == 47 or d == 7 or d == 59 then
        return function() ShowAlert("SEARING RADIANCE — SOINS RAID !") end
    elseif d == 79 or d == 83 then
        return function() ShowAlert("AURA OF WRATH — VENEL SUR LE BORD !", "phase") end
    elseif d == 131 or d == 132 then
        return function() ShowAlert("AURA OF PEACE — SENN SUR LE BORD !", "phase") end
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

local function OnUnitAura(unit)
    if unit ~= "player" then return end
    -- Auras boss taintées en Midnight (spellId secret) — player seulement
    local exec = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_EXEC)
              or C_UnitAuras.GetPlayerAuraBySpellID(1248994)
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
    local blind = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_BLIND)
    if blind and not trackedAuras.blind then
        trackedAuras.blind = true
        ShowPrivate("BLINDING LIGHT — INTERROMPRE !", SPELL_BLIND)
    elseif not blind then
        trackedAuras.blind = nil
    end
end

local function ResetState()
    inFight = false
    trackedAuras = {}
    activeTimers = {}
    M:ProgressBarHide(1)
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

SLASH_LHVANGUARDTEST1 = "/lhvanguardtest"
SlashCmdList["LHVANGUARDTEST"] = function()
    ShowAlert("DIVINE STORM — ÉVITEZ LES TORNADES !")
    ShowAlert("AURA OF PEACE — SENN SUR LE BORD !", "phase")
    ShowPrivate("EXECUTION SENTENCE — NE SUPERPOSEZ PAS !")
    ShowPrivate("BLINDING LIGHT — INTERROMPRE !")
end
