local addonName, M = ...

-- ─── L'ura — Midnight Falls ───────────────────────────────────────────────────
-- Jeu de mémoire des runes : 5 symboles (Héroïque) ou 3 (Normal).
-- Une personne désignée appuie sur les macros → le diagramme se met à jour
-- en temps réel pour tout le raid (détection via combos YELL / RW / PING).
-- Logique identique à PugaHelper (Vaelhys), intégrée dans LamentersHelper.

local LURA_ENCOUNTER_ID = 3183
local VANISH_GRACE      = 10   -- secondes avant arrêt complet après sortie combat

-- ─── Symboles ────────────────────────────────────────────────────────────────
-- Icônes WoW natives — pas de fichiers media requis.
local SYMBOLS = {
    TRI = { icon = "Interface\\Icons\\INV_Mask_07",                  r=0.4, g=1.0, b=0.5  },
    DIA = { icon = "Interface\\Icons\\INV_Mask_10",                  r=0.48,g=0.20,b=0.96 },
    CIR = { icon = "Interface\\Icons\\INV_Mask_08",                  r=1.0, g=0.64,b=0.01 },
    X   = { icon = "Interface\\Icons\\INV_Mask_09",                  r=1.0, g=0.3, b=0.3  },
    TEE = { icon = "Interface\\Icons\\INV_Helm_Mask_MetalBand_A_01", r=0.98,g=0.98,b=0.99 },
}

local SLOT_POS_HEROIC = {
    {x=55,y=44}, {x=55,y=-22}, {x=0,y=-60}, {x=-55,y=-22}, {x=-55,y=44},
}
local SLOT_POS_NORMAL = {
    {x=55,y=-22}, {x=0,y=-60}, {x=-55,y=-22},
}

-- ─── Fenêtres de jeu (secondes depuis PLAYER_REGEN_DISABLED) ─────────────────
-- 3 jeux de mémoire par combat. Source : PugaHelper / Vaelhys.
local WINDOWS = {
    { open=6,   close=24,  reset=32,  sound=36  },
    { open=76,  close=94,  reset=102, sound=106 },
    { open=146, close=164, reset=172, sound=176 },
}

-- ─── État ────────────────────────────────────────────────────────────────────
local inputsOpen    = false
local sequence      = {}
local combatTimers  = {}
local lastCombatEnd = 0

-- ─── Diagramme (frame en jeu) ────────────────────────────────────────────────
local SLOT_SIZE    = 40
local MAX_SLOTS    = 5
local diagFrame    = nil
local displaySlots = {}

local function IsHeroic()
    return (M.config and M.config.luraHeroicMode) ~= false
end

local function GetDiagPos()
    return (M.config and M.config.luraDiagX or 0),
           (M.config and M.config.luraDiagY or 150)
end

local function UpdateDiagram()
    if not diagFrame then return end
    local maxSym = IsHeroic() and 5 or 3
    for i = 1, MAX_SLOTS do
        local slot = displaySlots[i]
        if not slot then break end
        local sym = sequence[i]
        if i <= maxSym and sym and SYMBOLS[sym] then
            local s = SYMBOLS[sym]
            slot.icon:SetTexture(s.icon)
            slot.icon:SetAlpha(1)
            slot.num:SetText(tostring(i))
            slot.num:SetAlpha(1)
            slot.bg:SetColorTexture(s.r*0.2, s.g*0.2, s.b*0.2, 1)
            slot.border:SetColorTexture(s.r*0.9, s.g*0.9, s.b*0.9, 1)
        else
            slot.icon:SetAlpha(0)
            slot.num:SetAlpha(0)
            slot.bg:SetColorTexture(0.1, 0.1, 0.15, 1)
            slot.border:SetColorTexture(0.3, 0.3, 0.4, 1)
        end
    end
end

local function ApplyMode()
    local positions = IsHeroic() and SLOT_POS_HEROIC or SLOT_POS_NORMAL
    local maxSym    = IsHeroic() and 5 or 3
    wipe(sequence)
    if not diagFrame then return end
    for i = 1, MAX_SLOTS do
        local slot = displaySlots[i]
        if slot then
            if i <= maxSym then
                local pos = positions[i]
                slot.frame:ClearAllPoints()
                slot.frame:SetPoint("CENTER", diagFrame, "CENTER", pos.x, pos.y)
                slot.frame:Show()
            else
                slot.frame:Hide()
            end
        end
    end
    UpdateDiagram()
end

local function BuildDiagramFrame()
    if diagFrame then return end
    local dx, dy = GetDiagPos()

    local f = CreateFrame("Frame", "LHLuraDiagram", UIParent)
    f:SetSize(210, 210)
    f:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Fond circulaire via mask (même approche que PugaHelper)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("CENTER", 0, 0)
    bg:SetSize(220, 220)
    bg:SetColorTexture(0.314, 0.306, 0.306, 0.92)
    local bgMask = f:CreateMaskTexture()
    bgMask:SetAllPoints(bg)
    bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bg:AddMaskTexture(bgMask)

    -- Image L'ura au centre (media PugaHelper si installé, sinon rien)
    local bossImg = f:CreateTexture(nil, "ARTWORK")
    bossImg:SetSize(80, 80)
    bossImg:SetPoint("CENTER", 0, 8)
    bossImg:SetTexture("Interface\\AddOns\\PugaHelper\\media\\Lura.png")
    local bossMask = f:CreateMaskTexture()
    bossMask:SetAllPoints(bossImg)
    bossMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bossImg:AddMaskTexture(bossMask)

    -- 5 slots (positions héroïques par défaut, ApplyMode ajuste)
    for i = 1, MAX_SLOTS do
        local pos = SLOT_POS_HEROIC[i]
        local sf = CreateFrame("Frame", nil, f)
        sf:SetSize(SLOT_SIZE, SLOT_SIZE)
        sf:SetPoint("CENTER", f, "CENTER", pos.x, pos.y)

        local border = sf:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0.3, 0.3, 0.4, 1)

        local innerBg = sf:CreateTexture(nil, "ARTWORK")
        innerBg:SetPoint("TOPLEFT",      1, -1)
        innerBg:SetPoint("BOTTOMRIGHT", -1,  1)
        innerBg:SetColorTexture(0.1, 0.1, 0.15, 1)

        local iconTex = sf:CreateTexture(nil, "OVERLAY")
        iconTex:SetSize(SLOT_SIZE - 8, SLOT_SIZE - 8)
        iconTex:SetPoint("CENTER", 0, 5)
        iconTex:SetAlpha(0)

        local numFs = sf:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        numFs:SetPoint("CENTER", 0, -13)
        numFs:SetTextColor(1, 1, 1)
        numFs:SetAlpha(0)

        displaySlots[i] = { frame=sf, icon=iconTex, num=numFs, bg=innerBg, border=border }
    end

    -- Drag (bloqué en combat)
    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if M.config then
            local cx, cy = self:GetCenter()
            local px, py = UIParent:GetCenter()
            M.config.luraDiagX = math.floor(cx - px + 0.5)
            M.config.luraDiagY = math.floor(cy - py + 0.5)
            if M.SaveConfig then M:SaveConfig() end
        end
    end)

    f:Hide()
    diagFrame = f
end

-- ─── API publique ─────────────────────────────────────────────────────────────

function M:RepositionLuraDiagram()
    if not diagFrame then return end
    local x, y = GetDiagPos()
    diagFrame:ClearAllPoints()
    diagFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

function M:ToggleLuraDiagram()
    if not diagFrame then BuildDiagramFrame(); ApplyMode() end
    if diagFrame:IsShown() then
        diagFrame:Hide()
    else
        diagFrame:Show()
        UpdateDiagram()
    end
end

function M:SetLuraHeroicMode(heroic)
    if M.config then
        M.config.luraHeroicMode = heroic
        if M.SaveConfig then M:SaveConfig() end
    end
    ApplyMode()
end

-- ─── Timers de combat ────────────────────────────────────────────────────────

local function CancelAllTimers()
    for _, t in ipairs(combatTimers) do
        if t then pcall(function() t:Cancel() end) end
    end
    wipe(combatTimers)
end

local function HideAndReset()
    inputsOpen = false
    wipe(sequence)
    UpdateDiagram()
    if diagFrame then pcall(function() diagFrame:Hide() end) end
end

local function OpenWindow()
    inputsOpen = true
    if diagFrame then pcall(function() diagFrame:Show() end) end
    UpdateDiagram()
end

local function LockInputs()
    inputsOpen = false
end

local function PlayDodgeAlert()
    if M.ShowText     then M:ShowText("ESQUIVEZ LES LAMES !", "phase") end
    if M.PlayAlertSound then M:PlayAlertSound("phase") end
end

local function StartCombatTimers()
    CancelAllTimers()
    wipe(sequence)
    inputsOpen = false
    UpdateDiagram()
    if diagFrame then pcall(function() diagFrame:Hide() end) end
    for _, w in ipairs(WINDOWS) do
        table.insert(combatTimers, C_Timer.NewTimer(w.open,  OpenWindow))
        table.insert(combatTimers, C_Timer.NewTimer(w.close, LockInputs))
        table.insert(combatTimers, C_Timer.NewTimer(w.reset, HideAndReset))
        table.insert(combatTimers, C_Timer.NewTimer(w.sound, PlayDodgeAlert))
    end
end

local function StopCombat()
    CancelAllTimers()
    HideAndReset()
end

-- ─── Détection des symboles (YELL / RW / PING) ───────────────────────────────
-- Combo dans une fenêtre de 0.5s → identifie le symbole.
-- Cooldown de 1s entre deux symboles pour éviter les doublons.

local eventBuffer     = {}
local lastSymbolTime  = 0
local bufferTimer     = nil
local COMBO_WINDOW    = 0.5
local SYMBOL_COOLDOWN = 1.0

local function AddSymbol(sym)
    if not inputsOpen then return end
    if not SYMBOLS[sym] then return end
    local maxSym = IsHeroic() and 5 or 3
    if #sequence >= maxSym then return end
    lastSymbolTime = GetTime()
    table.insert(sequence, sym)
    UpdateDiagram()
end

local function AnalyzeBuffer()
    local hasYell = eventBuffer["YELL"]
    local hasPing = eventBuffer["PING"]
    local hasRW   = eventBuffer["RW"]
    local sym
    if     hasYell and hasPing then sym = "TRI"
    elseif hasPing and hasRW   then sym = "DIA"
    elseif hasPing             then sym = "CIR"
    elseif hasRW               then sym = "X"
    elseif hasYell             then sym = "TEE"
    end
    wipe(eventBuffer)
    bufferTimer = nil
    if sym then AddSymbol(sym) end
end

local function OnEventReceived(evtType)
    local now = GetTime()
    if now - lastSymbolTime < SYMBOL_COOLDOWN then return end
    eventBuffer[evtType] = true
    if not bufferTimer then
        bufferTimer = C_Timer.NewTimer(COMBO_WINDOW, AnalyzeBuffer)
    end
end

-- ─── Création des macros ──────────────────────────────────────────────────────
local MACROS = {
    { name="LH_Triangle", icon="INV_Mask_07",                  text="/yell .\n/ping assist" },
    { name="LH_Diamond",  icon="INV_Mask_10",                  text="/rw .\n/ping assist"  },
    { name="LH_Circle",   icon="INV_Mask_08",                  text="/ping assist"          },
    { name="LH_Cross",    icon="INV_Mask_09",                  text="/rw ."                 },
    { name="LH_Tee",      icon="INV_Helm_Mask_MetalBand_A_01", text="/yell ."               },
}

function M:CreateLuraMacros()
    for _, m in ipairs(MACROS) do
        local idx = GetMacroIndexByName(m.name)
        if idx == 0 then
            CreateMacro(m.name, m.icon, m.text, nil)
        else
            EditMacro(idx, m.name, m.icon, m.text)
        end
    end
    print("|cffcc1414LamentersHelper|r Macros L'ura créées — glisse LH_Triangle / LH_Diamond / LH_Circle / LH_Cross / LH_Tee sur ta barre d'action !")
end

-- ─── Événements ──────────────────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("CHAT_MSG_YELL")
evtFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
evtFrame:RegisterEvent("CHAT_MSG_PING")
evtFrame:RegisterEvent("ENCOUNTER_START")
evtFrame:RegisterEvent("ENCOUNTER_END")
evtFrame:RegisterEvent("PLAYER_LOGIN")

evtFrame:SetScript("OnEvent", function(_, event, encounterID)
    if event == "CHAT_MSG_YELL" then
        OnEventReceived("YELL")
    elseif event == "CHAT_MSG_RAID_WARNING" then
        OnEventReceived("RW")
    elseif event == "CHAT_MSG_PING" then
        OnEventReceived("PING")
    elseif event == "ENCOUNTER_START" then
        if encounterID == LURA_ENCOUNTER_ID then
            StartCombatTimers()
        end
    elseif event == "ENCOUNTER_END" then
        if encounterID == LURA_ENCOUNTER_ID then
            lastCombatEnd = GetTime()
            C_Timer.NewTimer(VANISH_GRACE, function()
                StopCombat()
            end)
        end
    elseif event == "PLAYER_LOGIN" then
        BuildDiagramFrame()
        ApplyMode()
    end
end)
