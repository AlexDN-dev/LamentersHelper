local addonName, M = ...

-- Fallen-King Salhadaar — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/Salhadaar.lua (TimersOther = non-Mythic)
local ENCOUNTER_ID = 3179

local inFight = false
local destabStacks = 0
local despoticActive = false
local umbralBeamsActive = false
local activeTimers = {}  -- eventID → callback
local ambig45Count = 0   -- compteur pour les 3 abilities à ~45s (cyclent en ordre)
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
local SPELL_DESPOTIC   = 1248697
local SPELL_UMBRAL_B   = 1260030
local SPELL_DESTAB     = 1271577
-- À confirmer via debugEncounter (icônes des barres globales)
local SPELL_FRACTURED  = 1249025  -- Shadow Fracture (le cast de l'add Fractured Image)
local SPELL_ENTROPIC   = 1253891  -- Entropic Unraveling

-- Durées confirmées BigWigs Salhadaar (TimersOther) :
--   11           → Void Convergence (pull)
--   15           → Twisting Obscurity (pull)
--   27           → Despotic Command (pull ; Mythic = 22)
--   18           → Fractured Projection (pull ; Mythic = 27)
--   42           → Shattering Twilight (pull ; Mythic = 44)
--   100          → Entropic Unraveling
--   ~46.5        → Void Convergence (répétition)
--   ~46.0        → Despotic Command (répétition)
--   ~45          → ambiguë : TW → FP → ST en rotation
local function BuildTimerCallback(d, dExact)
    if d == 11 then
        return function() ShowAlert("VOID CONVERGENCE !") end
    elseif d == 15 then
        return function() ShowAlert("TWISTING OBSCURITY — SOINS RAID !") end
    elseif d == 27 or d == 22 then
        return function() ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !", "soak", SPELL_DESPOTIC) end
    elseif d == 18 then
        -- Shadow Fracture : cast time 12s Mythique → barre interrupt 12s pour tout le raid
        return function()
            ShowAlert("FRACTURED IMAGE — KICK !", "interrupt", SPELL_FRACTURED)
            M:ProgressBarCountdown(3, 12, "FRACTURED IMAGE — KICK", "interrupt", SPELL_FRACTURED)
        end
    elseif d == 42 or d == 44 then
        return function() ShowAlert("SHATTERING TWILIGHT — ATTENTION !") end
    elseif d == 100 then
        -- Entropic Unraveling = le "spin" de 100s → barre phase pour tout le raid
        return function()
            ShowAlert("ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !", "phase", SPELL_ENTROPIC)
            M:ProgressBarCountdown(4, 100, "SPIN — ENTROPIC UNRAVELING", "phase", SPELL_ENTROPIC)
        end
    end

    -- ~46.5 vs ~46 : distinguer par la demi-seconde
    local dHalf = math.floor(dExact * 2 + 0.5) / 2  -- arrondi au 0.5 près
    if dHalf == 46.5 then
        return function() ShowAlert("VOID CONVERGENCE !") end
    elseif dHalf == 46.0 then
        return function() ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !", "soak", SPELL_DESPOTIC) end
    elseif d == 45 then
        -- Rotation TW → FP → ST
        ambig45Count = ambig45Count + 1
        local cycle = ambig45Count % 3
        if cycle == 1 then
            return function() ShowAlert("TWISTING OBSCURITY — SOINS RAID !") end
        elseif cycle == 2 then
            return function() ShowAlert("FRACTURED IMAGE INVOQUÉ — FOCUS L'ADD !") end
        else
            return function() ShowAlert("SHATTERING TWILIGHT — ATTENTION !") end
        end
    end
    return nil
end

local function OnTimelineAdded(eventInfo)
    if not eventInfo or eventInfo.source ~= 0 then return end
    local dExact = eventInfo.duration
    local d = math.floor(dExact + 0.5)
    local cb = BuildTimerCallback(d, dExact)
    if cb then
        activeTimers[eventInfo.id] = cb
    elseif M.config and M.config.debugEncounter then
        print(string.format("|cff00ff00LH Debug|r SALHADAAR TIMELINE dur=%.1f id=%d", dExact, eventInfo.id))
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

local DESTAB_ALERT_THRESHOLD = 5

local function OnUnitAura(unit)
    if unit ~= "player" then return end

    local despotic = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_DESPOTIC)
    if despotic and not despoticActive then
        despoticActive = true
        ShowPrivate("DESPOTIC COMMAND — BOUGEZ !", SPELL_DESPOTIC)
        local dur = (despotic.expirationTime and despotic.expirationTime > 0)
                    and (despotic.expirationTime - GetTime())
                    or (despotic.duration or 8)
        M:ProgressBarCountdown(1, dur, "DESPOTIC COMMAND", "soak", SPELL_DESPOTIC)
    elseif not despotic then
        despoticActive = false
        M:ProgressBarHide(1)
    end

    local umbral = C_UnitAuras.GetPlayerAuraBySpellID(SPELL_UMBRAL_B)
    if umbral and not umbralBeamsActive then
        umbralBeamsActive = true
        ShowPrivate("UMBRAL BEAMS — BOUGEZ !", SPELL_UMBRAL_B)
        local dur = (umbral.expirationTime and umbral.expirationTime > 0)
                    and (umbral.expirationTime - GetTime())
                    or (umbral.duration or 8)
        M:ProgressBarCountdown(2, dur, "UMBRAL BEAMS", "phase", SPELL_UMBRAL_B)
    elseif not umbral then
        umbralBeamsActive = false
        M:ProgressBarHide(2)
    end

    local aura = M.FindAura("player", SPELL_DESTAB, "HARMFUL")
    if aura then
        local stacks = aura.applications or 1
        if stacks ~= destabStacks then
            destabStacks = stacks
            if stacks == 1 then
                ShowPrivate("DESTABILIZING STRIKES ×1", SPELL_DESTAB)
            elseif stacks % DESTAB_ALERT_THRESHOLD == 0 then
                ShowPrivate("DESTABILIZING STRIKES ×" .. stacks .. " — SWAP TANK !", SPELL_DESTAB)
            end
        end
    else
        destabStacks = 0
    end
end

local function ResetState()
    inFight = false
    destabStacks = 0
    despoticActive = false
    umbralBeamsActive = false
    activeTimers = {}
    ambig45Count = 0
    M:ProgressBarHide(1)
    M:ProgressBarHide(2)
    M:ProgressBarHide(3)
    M:ProgressBarHide(4)
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

SLASH_LHSALHADAARTEST1 = "/lhsaltest"
SlashCmdList["LHSALHADAARTEST"] = function()
    ShowAlert("TWISTING OBSCURITY — SOINS RAID !")
    ShowPrivate("DESPOTIC COMMAND — BOUGEZ !")
end
