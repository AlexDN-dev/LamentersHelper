local addonName, M = ...

-- ─── L'ura — Midnight Falls ───────────────────────────────────────────────────
-- Jeu de mémoire des runes : 5 symboles (Héroïque) ou 3 (Normal).
--
-- Encodage par NOMBRE DE YELLS (inspiré de BunnyWithLura / Vaelhys) :
--   1 yell = Rune 1 (Cercle)    2 yells = Rune 2 (Croix)
--   3 yells = Rune 3 (Diamond)  4 yells = Rune 4 (T)
--   5 yells = Rune 5 (Triangle) 6 yells = CLEAR  7 yells = UNDO
--
-- La personne désignée appuie sur les macros LH_Rune1..5.
-- Tout le raid voit le diagramme se remplir en temps réel.

local LURA_ENCOUNTER_ID = 3183
local TEX_PATH          = "Interface\\AddOns\\LamentersHelper\\media\\icons\\"
local VANISH_GRACE      = 10

-- ─── Runes ───────────────────────────────────────────────────────────────────
-- Ordre : Cercle / Croix / Diamond / T / Triangle (même que BunnyWithLura)
local RUNE_TEXTURES = {
    [1] = TEX_PATH .. "rune_circle",
    [2] = TEX_PATH .. "rune_cross",
    [3] = TEX_PATH .. "rune_diamond",
    [4] = TEX_PATH .. "rune_T",
    [5] = TEX_PATH .. "rune_triangle",
}

local RUNE_NAMES = { "Cercle", "Croix", "Diamond", "T", "Triangle" }

-- Positions en anneau (angles fixes, comme BunnyWithLura)
local RING_RADIUS = 62
local SLOT_ANGLES = { 36, 108, 180, 252, 324 }

-- Fenêtres de jeu — reset automatique à la fin de chaque phase
-- Source : PugaHelper / BunnyWithLura (timings confirmés)
local WINDOWS = {
    { reset = 32  },
    { reset = 102 },
    { reset = 172 },
}

-- ─── État ────────────────────────────────────────────────────────────────────
local sequence      = {}
local lastCombatEnd = 0
local phaseTimers   = {}

-- ─── Diagramme ───────────────────────────────────────────────────────────────
local diagFrame  = nil
local compassDots = {}
local DOT_SIZE    = 36

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
    for i = 1, 5 do
        local dot = compassDots[i]
        if not dot then break end
        if i <= maxSym and sequence[i] then
            dot.icon:SetTexture(RUNE_TEXTURES[sequence[i]])
            dot.icon:Show()
            dot.num:SetText("|cffFFFF00" .. i .. "|r")
            dot.bg:SetColorTexture(0.08, 0.03, 0.15, 0.7)
        else
            dot.icon:Hide()
            dot.num:SetText("|cff555555" .. i .. "|r")
            dot.bg:SetColorTexture(0.05, 0.02, 0.10, 0.4)
        end
    end
end

local function BuildDiagramFrame()
    if diagFrame then return end
    local dx, dy = GetDiagPos()

    local f = CreateFrame("Frame", "LHLuraDiagram", UIParent, "BackdropTemplate")
    f:SetSize(190, 200)
    f:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile   = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 3,
    })
    f:SetBackdropColor(0.32, 0.32, 0.32, 1)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Boss au centre (rouge)
    local bossIcon = f:CreateTexture(nil, "ARTWORK")
    bossIcon:SetTexture("Interface\\BUTTONS\\WHITE8X8")
    bossIcon:SetVertexColor(0.78, 0.07, 0.07, 1)
    bossIcon:SetSize(50, 50)
    bossIcon:SetPoint("CENTER", f, "CENTER", 0, -8)
    local bossMask = f:CreateMaskTexture()
    bossMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOEDGE", "CLAMPTOEDGE", "TRILINEAR")
    bossMask:SetAllPoints(bossIcon)
    bossIcon:AddMaskTexture(bossMask)

    -- Label "L'ura" au centre
    local bossLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLabel:SetPoint("CENTER", bossIcon, "CENTER", 0, 0)
    bossLabel:SetText("L'ura")
    bossLabel:SetTextColor(1, 1, 1)

    -- 5 slots en anneau
    for i = 1, 5 do
        local dot = CreateFrame("Frame", nil, f)
        dot:SetSize(DOT_SIZE, DOT_SIZE)

        local bg = dot:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.02, 0.10, 0.4)
        dot.bg = bg

        local icon = dot:CreateTexture(nil, "ARTWORK")
        icon:SetSize(DOT_SIZE - 2, DOT_SIZE - 2)
        icon:SetPoint("CENTER")
        icon:Hide()
        dot.icon = icon

        local num = dot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        num:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", -1, 1)
        num:SetText("|cff555555" .. i .. "|r")
        dot.num = num

        local rad = math.rad(SLOT_ANGLES[i])
        local x = math.sin(rad) * RING_RADIUS
        local y = math.cos(rad) * RING_RADIUS
        dot:SetPoint("CENTER", f, "CENTER", x, y - 8)

        compassDots[i] = dot
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
    -- Clic droit pour cacher
    f:SetScript("OnMouseUp", function(self, btn)
        if btn == "RightButton" then self:Hide() end
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
    if not diagFrame then BuildDiagramFrame() end
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
    wipe(sequence)
    UpdateDiagram()
end

-- ─── Décodage par nombre de yells ────────────────────────────────────────────
-- 1-5 yells → rune 1-5 | 6 yells → CLEAR | 7 yells → UNDO
local yellCount  = 0
local yellTimer  = nil
local YELL_WINDOW = 0.3

local function AddRune(runeIdx)
    local maxSym = IsHeroic() and 5 or 3
    if #sequence >= maxSym then return end
    table.insert(sequence, runeIdx)
    if diagFrame then diagFrame:Show() end
    UpdateDiagram()
end

local function ClearSequence()
    wipe(sequence)
    UpdateDiagram()
    if diagFrame then diagFrame:Hide() end
end

local function UndoLast()
    if #sequence > 0 then
        table.remove(sequence)
        UpdateDiagram()
    end
end

local function ResetYellCounter()
    yellCount = 0
    if yellTimer then yellTimer:Cancel(); yellTimer = nil end
end

local function OnYellDecoded(count)
    if count >= 1 and count <= 5 then
        AddRune(count)
    elseif count == 6 then
        ClearSequence()
    elseif count == 7 then
        UndoLast()
    end
end

-- ─── Création des macros ──────────────────────────────────────────────────────
-- Chaque macro envoie N yells pour encoder la rune N.
local MACROS = {}
for i = 1, 5 do
    local lines = {}
    for y = 1, i do
        table.insert(lines, "/yell " .. y)
    end
    MACROS[i] = {
        name = "LH_Rune" .. i,
        icon = "rune_" .. ({ "circle","cross","diamond","T","triangle" })[i],
        text = table.concat(lines, "\n"),
    }
end
local MACRO_CLEAR = { name="LH_LuraClear", icon="INV_Misc_QuestionMark", text="" }
local MACRO_UNDO  = { name="LH_LuraUndo",  icon="INV_Misc_QuestionMark", text="" }
do
    local lines = {}
    for y=1,6 do table.insert(lines, "/yell "..y) end
    MACRO_CLEAR.text = table.concat(lines, "\n")
end
do
    local lines = {}
    for y=1,7 do table.insert(lines, "/yell "..y) end
    MACRO_UNDO.text = table.concat(lines, "\n")
end

function M:CreateLuraMacros()
    local allMacros = { MACROS[1],MACROS[2],MACROS[3],MACROS[4],MACROS[5],MACRO_CLEAR,MACRO_UNDO }
    for _, m in ipairs(allMacros) do
        local idx = GetMacroIndexByName(m.name)
        if idx == 0 then
            CreateMacro(m.name, m.icon, m.text, nil)
        else
            EditMacro(idx, m.name, m.icon, m.text)
        end
    end
    print("|cffcc1414LamentersHelper|r Macros L'ura créées — glisse LH_Rune1 à LH_Rune5 + LH_LuraClear + LH_LuraUndo sur ta barre !")
end

-- ─── Événements ──────────────────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("CHAT_MSG_YELL")
evtFrame:RegisterEvent("ENCOUNTER_START")
evtFrame:RegisterEvent("ENCOUNTER_END")
evtFrame:RegisterEvent("PLAYER_LOGIN")

evtFrame:SetScript("OnEvent", function(_, event, encounterID)
    if event == "CHAT_MSG_YELL" then
        yellCount = yellCount + 1
        if yellTimer then yellTimer:Cancel() end
        yellTimer = C_Timer.NewTimer(YELL_WINDOW, function()
            local count = yellCount
            ResetYellCounter()
            OnYellDecoded(count)
        end)

    elseif event == "ENCOUNTER_START" then
        if encounterID == LURA_ENCOUNTER_ID then
            wipe(sequence)
            UpdateDiagram()
            -- Reset automatique à la fin de chaque phase
            for _, t in ipairs(phaseTimers) do pcall(function() t:Cancel() end) end
            wipe(phaseTimers)
            for _, w in ipairs(WINDOWS) do
                table.insert(phaseTimers, C_Timer.NewTimer(w.reset, function()
                    ClearSequence()
                end))
            end
        end

    elseif event == "ENCOUNTER_END" then
        if encounterID == LURA_ENCOUNTER_ID then
            for _, t in ipairs(phaseTimers) do pcall(function() t:Cancel() end) end
            wipe(phaseTimers)
            lastCombatEnd = GetTime()
            C_Timer.NewTimer(VANISH_GRACE, function()
                ClearSequence()
            end)
        end

    elseif event == "PLAYER_LOGIN" then
        BuildDiagramFrame()
    end
end)
