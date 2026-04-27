local addonName, M = ...

-- Fallen-King Salhadaar — The Voidspire (Midnight 12.0)
-- IMPORTANT: eventInfo.spellID est tainté en Midnight. Identification par eventInfo.duration.
-- Durées sources : BigWigs_TheVoidspire/Salhadaar.lua (TimersOther = non-Mythic)
-- CLEU utilisé pour : Shadow Fracture (add cast), Entropic Unraveling (boss cast)
local ENCOUNTER_ID = 3179

-- ─── Spell IDs (CLEU — non taintés) ──────────────────────────────────────────
local SPELL_FRACTURED  = 1254081  -- Fractured Projection (cast de l'add Fractured Image)
local SPELL_ENTROPIC   = 1246175  -- Entropic Unraveling (spin boss)
local SPELL_CONVERGENCE= 1247738  -- Void Convergence (orbes)
local SPELL_TWISTING   = 1250686  -- Twisting Obscurity (dégâts raid)
local SPELL_SHATTERING = 1250803  -- Shattering Twilight (pics)
local SPELL_DESPOTIC   = 1248697  -- Despotic Command (aura joueur + icône)
local SPELL_UMBRAL_B   = 1260030  -- Umbral Beams (aura joueur)
local SPELL_DESTAB     = 1271577  -- Destabilizing Strikes (stacks tank)

-- ─── Indicateur de portée kick sur les Fractured Images ──────────────────────
local FRACTURED_IMAGE_NAME    = "Fractured Image"
local FRACTURED_IMAGE_NAME_FR = "Image Fractur\195\169e"

-- Sort d'interrupt par classe (spell ID baseline, non-tainté)
local CLASS_INTERRUPT = {
    WARRIOR     = 6552,    -- Pummel           5 yd
    PALADIN     = 96231,   -- Rebuke           5 yd
    HUNTER      = 147362,  -- Counter Shot    40 yd
    ROGUE       = 1766,    -- Kick             5 yd
    SHAMAN      = 57994,   -- Wind Shear      30 yd
    MAGE        = 2139,    -- Counterspell    40 yd
    MONK        = 116705,  -- Spear Hand       5 yd
    DRUID       = 106839,  -- Skull Bash       5 yd
    DEMONHUNTER = 183752,  -- Disrupt          5 yd (Havoc/Vengeance) / 15 yd (Dévorer)
    DEATHKNIGHT = 47528,   -- Mind Freeze     15 yd
    EVOKER      = 351338,  -- Quell           25 yd
}

local playerClass      = select(2, UnitClass("player"))
local interruptSpellID = CLASS_INTERRUPT[playerClass]

-- Table des overlays actifs : { [unitToken] = frame }
local kickOverlays = {}

local function IsFracturedImage(unit)
    local name = UnitName(unit)
    return name == FRACTURED_IMAGE_NAME or name == FRACTURED_IMAGE_NAME_FR
end

local function CreateKickOverlay(unit)
    if kickOverlays[unit] then return end
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if not np then return end

    local f = CreateFrame("Frame", nil, np)
    f:SetSize(52, 22)
    f:SetPoint("BOTTOM", np, "TOP", 0, 8)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(np:GetFrameLevel() + 10)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.75)

    local lbl = f:CreateFontString(nil, "OVERLAY")
    lbl:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    lbl:SetAllPoints()
    lbl:SetJustifyH("CENTER")
    lbl:SetJustifyV("MIDDLE")
    f._lbl = lbl
    f._unit = unit
    f._t = 0

    f:SetScript("OnUpdate", function(self, elapsed)
        self._t = self._t + elapsed
        if self._t < 0.1 then return end
        self._t = 0

        if not interruptSpellID then
            self._lbl:SetText("|cffaaaaaa  —  |r")
            return
        end

        local inRange = C_Spell.IsSpellInRange(interruptSpellID, self._unit)
        if inRange == true then
            self._lbl:SetText("|cff00ee44KICK|r")
        elseif inRange == false then
            self._lbl:SetText("|cffff2222LOIN|r")
        else
            self._lbl:SetText("")
        end
    end)

    f:Show()
    kickOverlays[unit] = f
end

local function RemoveKickOverlay(unit)
    local f = kickOverlays[unit]
    if f then
        f:SetScript("OnUpdate", nil)
        f:Hide()
        kickOverlays[unit] = nil
    end
end

local function RemoveAllKickOverlays()
    for unit in pairs(kickOverlays) do
        RemoveKickOverlay(unit)
    end
end

-- ─── État du combat ───────────────────────────────────────────────────────────
local inFight           = false
local destabStacks      = 0
local despoticActive    = false
local umbralBeamsActive = false
local activeTimers      = {}
local ambig45Count      = 0   -- compteur pour les 2 abilities à ~45s (TW/ST ; FP sur CLEU)
local cleuRegistered    = false
local fractureCooldown  = false
local entropicCooldown  = false
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

local function OnVoidConvergence()
    ShowAlert("VOID CONVERGENCE !", "global", SPELL_CONVERGENCE)
end

local function OnTwistingObscurity()
    ShowAlert("TWISTING OBSCURITY — SOINS RAID !", "global", SPELL_TWISTING)
end

local function OnShatteringTwilight()
    ShowAlert("SHATTERING TWILIGHT — ATTENTION !", "soak", SPELL_SHATTERING)
end

local function OnDespoticCommand(destName)
    ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !", "soak", SPELL_DESPOTIC)
end

local function OnShadowFracture()
    if fractureCooldown then return end
    fractureCooldown = true
    C_Timer.After(14, function() fractureCooldown = false end)
    ShowAlert("FRACTURED IMAGE — KICK !", "interrupt", SPELL_FRACTURED)
    M:ProgressBarCountdown(3, 12, "FRACTURED IMAGE — KICK", "interrupt", SPELL_FRACTURED)
end

local function OnEntropicUnraveling()
    if entropicCooldown then return end
    entropicCooldown = true
    C_Timer.After(105, function() entropicCooldown = false end)
    ShowAlert("ENTROPIC UNRAVELING — MÉCANIQUE DE PHASE !", "phase", SPELL_ENTROPIC)
    M:ProgressBarCountdown(4, 100, "SPIN — ENTROPIC UNRAVELING", "phase", SPELL_ENTROPIC)
end

-- ─── UNIT_AURA : debuffs privés du joueur ────────────────────────────────────
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

-- ─── Reset ────────────────────────────────────────────────────────────────────
local function ResetState()
    inFight           = false
    destabStacks      = 0
    despoticActive    = false
    umbralBeamsActive = false
    fractureCooldown  = false
    entropicCooldown  = false
    RemoveAllKickOverlays()
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
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

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

    elseif event == "UNIT_AURA" then
        if not inFight then return end
        OnUnitAura(...)

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not inFight then return end
        local _, subevent, _, _, _, _, _, _, destName, _, _, spellId = CombatLogGetCurrentEventInfo()
        if subevent == "SPELL_CAST_START" then
            if     spellId == SPELL_FRACTURED   then OnShadowFracture()
            elseif spellId == SPELL_ENTROPIC    then OnEntropicUnraveling()
            elseif spellId == SPELL_CONVERGENCE then OnVoidConvergence()
            elseif spellId == SPELL_TWISTING    then OnTwistingObscurity()
            elseif spellId == SPELL_SHATTERING  then OnShatteringTwilight()
            end
        elseif subevent == "SPELL_AURA_APPLIED" then
            if spellId == SPELL_DESPOTIC then OnDespoticCommand(destName) end
        end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not inFight then return end
        local unit = ...
        if IsFracturedImage(unit) then
            CreateKickOverlay(unit)
        elseif M.config and M.config.debugEncounter then
            print(string.format("|cff00ff00LH Debug|r NAMEPLATE: '%s'", tostring(UnitName(unit))))
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = ...
        RemoveKickOverlay(unit)
    end
end)

SLASH_LHSALHADAARTEST1 = "/lhsaltest"
SlashCmdList["LHSALHADAARTEST"] = function(arg)
    if arg == "fracture" then
        OnShadowFracture()
    elseif arg == "entropic" then
        OnEntropicUnraveling()
    elseif arg == "despotic" then
        ShowAlert("DESPOTIC COMMAND — UN JOUEUR CIBLÉ !", "soak", SPELL_DESPOTIC)
        ShowPrivate("DESPOTIC COMMAND — BOUGEZ !", SPELL_DESPOTIC)
    else
        ShowAlert("TWISTING OBSCURITY — SOINS RAID !")
        ShowPrivate("DESPOTIC COMMAND — BOUGEZ !", SPELL_DESPOTIC)
        print("|cff00ff00LH Salhadaar|r /lhsaltest [fracture|entropic|despotic]")
    end
end
