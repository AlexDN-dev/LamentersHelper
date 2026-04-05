local addonName, M = ...

-- Imperator Averzian — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est une "Secret Value" taintée en Midnight — impossible à comparer.
-- On identifie les sorts par eventInfo.duration (non tainté), comme BigWigs.
-- Durées sources : BigWigs_TheVoidspire/Averzian.lua
local ENCOUNTER_ID = 3176

-- ─── Void Marked — Rotation de dispel ────────────────────────────────────────
-- Debuff spellID 1280023, 2 cibles par vague, 2 vagues par cycle (~80s)
-- Vague A → Vague B ~8s après → prochain cycle ~80s plus tard
-- Tous les dispels healer ont 8s de CD → rotation par application individuelle
-- La rotation est configurable dans /lh → Imperator (RL/assist)
local VOID_MARKED_ID = 1280023
local voidMarkCount  = 0   -- reset à chaque ENCOUNTER_START

local function GetDispelRotation()
    return (M.config and M.config.imperatorDispelRotation) or
           { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" }
end

-- ─── État du combat ──────────────────────────────────────────────────────────
local inFight      = false
local trackedAuras = {}
local activeTimers = {}
local cleuRegistered = false

local frame = CreateFrame("Frame")

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

-- ─── CLEU (enregistré uniquement pendant l'encounter pour éviter ADDON_ACTION_FORBIDDEN) ──
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

-- ─── Void Marked : assignation du healer ─────────────────────────────────────
local function OnVoidMarked(destName)
    voidMarkCount = voidMarkCount + 1
    local rot      = GetDispelRotation()
    local idx      = ((voidMarkCount - 1) % #rot) + 1
    local assigned = rot[idx]
    local myName   = UnitName("player")

    -- Alerte globale : tout le monde voit qui est marqué
    ShowAlert("|cffc080ff[VOID MARKED]|r  " .. destName, nil, VOID_MARKED_ID)

    -- Alerte dispel uniquement pour le healer assigné (son double + texte gras magenta)
    if myName == assigned then
        ShowDispel("DISPELL  |cffffff00" .. destName .. "|r  !", VOID_MARKED_ID)
    end

    if M.config and M.config.debugEncounter then
        local rot = GetDispelRotation()
        print(string.format("|cff00ff00LH Imperator|r VoidMark #%d → %s assigné à %s [%d/%d] (moi=%s)",
            voidMarkCount, destName, assigned, idx, #rot, myName))
    end
end

-- ─── Timeline callbacks (durée → abilité) ────────────────────────────────────
local function BuildTimerCallback(d)
    if d == 84 or d == 12 or d == 94 or d == 14 then
        return function() ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase") end
    elseif d == 48 or d == 18 or d == 60 then
        return function() ShowAlert("OBLIVION'S WRATH — BOUGEZ !") end
    elseif d == 20 or d == 32 then
        return function() ShowAlert("UMBRAL COLLAPSE — SOAK !", "soak") end
    elseif d == 125 or d == 160 then
        return function() ShowAlert("VOID FALL — ÉVITEZ LES ZONES !") end
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
        print(string.format("|cff00ff00LH Debug|r IMPERATOR TIMELINE dur=%.1f id=%d", eventInfo.duration, eventInfo.id))
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

-- ─── UNIT_AURA : auras privées du joueur ─────────────────────────────────────
local function OnUnitAura(unit)
    if unit ~= "player" then return end
    local umbral = C_UnitAuras.GetPlayerAuraBySpellID(1249265)  -- Umbral Collapse
    if umbral and not trackedAuras.umbral then
        trackedAuras.umbral = true
        ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !", 1249265)
    elseif not umbral then
        trackedAuras.umbral = nil
    end
end

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight       = false
    trackedAuras  = {}
    activeTimers  = {}
    voidMarkCount = 0
    UnregisterCLEU()
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
        local _, subevent, _, _, _, _, _, _, destName, _, _, spellId = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_AURA_APPLIED" and spellId == VOID_MARKED_ID then
            OnVoidMarked(destName)
        end
    end
end)

-- ─── Commandes de test ───────────────────────────────────────────────────────
SLASH_LHIMPERTEST1 = "/lhimpertest"
SlashCmdList["LHIMPERTEST"] = function(args)
    local cmd = args and args:lower() or ""
    if cmd == "void" then
        -- Simule 4 applications successives pour tester la rotation
        for i = 1, 4 do
            C_Timer.After(i * 0.3, function()
                local fakeNames = { "Lilläka", "Smiths", "Wadabloom", "Cäbron" }
                OnVoidMarked(fakeNames[i])
            end)
        end
    elseif cmd == "umbral" then
        ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
    elseif cmd == "phase" then
        ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase")
    elseif cmd == "reset" then
        voidMarkCount = 0
        print("|cff00ff00LH Imperator|r Compteur Void Marked remis à 0.")
    else
        ShowAlert("SHADOW'S ADVANCE — PHASE PLATEAU !", "phase")
        ShowPrivate("UMBRAL COLLAPSE — ALLEZ AU MARQUEUR !")
        print("|cff00ff00LH Imperator|r /lhimpertest [void|umbral|phase|reset]")
    end
end
