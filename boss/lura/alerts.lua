local addonName, M = ...

-- ─── L'ura — Midnight Falls ───────────────────────────────────────────────────
-- Jeu de mémoire des runes.
--
-- CALLER (RL/assist désigné) :
--   Clique sur les 5 boutons de rune dans l'ordre → Send → séquence partagée.
--
-- VIEWER (tout le raid) :
--   Diagramme circulaire qui s'affiche automatiquement dès réception.
--   Se cache automatiquement à la fin de chaque phase.
--
-- Communication via addon message (LH_LURA) — fonctionne en combat.

local LURA_ENCOUNTER_ID = 3183
local PREFIX            = "LH_LURA"
local VANISH_GRACE      = 10

local TEX = "Interface\\AddOns\\LamentersHelper\\media\\lura\\"
local RUNES = {
    TRI = { tex = TEX .. "TRIANGLE.blp", label = "Triangle", r=0.3, g=0.9, b=0.3  },
    DIA = { tex = TEX .. "DIAMOND.blp",  label = "Diamond",  r=0.6, g=0.3, b=1.0  },
    CIR = { tex = TEX .. "CIRCLE.blp",   label = "Cercle",   r=1.0, g=0.6, b=0.0  },
    X   = { tex = TEX .. "X.blp",        label = "Croix",    r=1.0, g=0.3, b=0.3  },
    TEE = { tex = TEX .. "T.blp",        label = "T",        r=0.9, g=0.9, b=0.9  },
}
-- Ordre fixe des boutons caller
local RUNE_ORDER = { "TRI", "DIA", "CIR", "X", "TEE" }

-- Positions en cercle pour le viewer (5 slots)
local VIEWER_ANGLES = { 30, 330, 270, 210, 150 }
local VIEWER_RADIUS = 70
local VIEWER_NUM_RADIUS = 92

-- Fenêtres de reset automatique (fin de chaque phase)
local PHASE_RESETS = { 32, 102, 172 }

-- ─── État ────────────────────────────────────────────────────────────────────
local sequence      = {}  -- { "TRI", "CIR", ... }
local phaseTimers   = {}
local callerFrame   = nil
local viewerFrame   = nil
local viewerIcons   = {}
local callerBtns    = {}  -- { [id] = btn }

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

-- ─── Helpers ─────────────────────────────────────────────────────────────────
local function CanSend()
    return not IsInRaid() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function Serialize(seq)
    return table.concat(seq, ",")
end

local function Deserialize(str)
    local t = {}
    for tok in str:gmatch("([^,]+)") do table.insert(t, tok) end
    return t
end

-- ─── Viewer ──────────────────────────────────────────────────────────────────
local function UpdateViewer()
    if not viewerFrame then return end
    for _, obj in ipairs(viewerIcons) do obj:Hide() end
    wipe(viewerIcons)

    if #sequence == 0 then
        viewerFrame:Hide()
        return
    end

    for i, id in ipairs(sequence) do
        local rune = RUNES[id]
        if not rune then break end
        local pos  = VIEWER_ANGLES[i]
        if not pos then break end
        local rad = math.rad(pos)
        local x   = VIEWER_RADIUS * math.cos(rad)
        local y   = VIEWER_RADIUS * math.sin(rad)

        local tex = viewerFrame:CreateTexture(nil, "ARTWORK")
        tex:SetSize(40, 40)
        tex:SetPoint("CENTER", viewerFrame, "CENTER", x, y)
        tex:SetTexture(rune.tex)
        table.insert(viewerIcons, tex)

        local nx = VIEWER_NUM_RADIUS * math.cos(rad)
        local ny = VIEWER_NUM_RADIUS * math.sin(rad)
        local num = viewerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        num:SetPoint("CENTER", viewerFrame, "CENTER", nx, ny)
        num:SetTextColor(1, 0.84, 0, 1)
        num:SetText(tostring(i))
        table.insert(viewerIcons, num)
    end

    viewerFrame:Show()
end

local function BuildViewerFrame()
    if viewerFrame then return end
    local dx = M.config and M.config.luraDiagX or 0
    local dy = M.config and M.config.luraDiagY or 150

    local f = CreateFrame("Frame", "LHLuraViewer", UIParent)
    f:SetSize(200, 200)
    f:SetPoint("CENTER", UIParent, "CENTER", dx, dy)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")

    -- Fond circulaire
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", -6, 6)
    bg:SetPoint("BOTTOMRIGHT", 6, -6)
    bg:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    bg:SetVertexColor(0.10, 0.05, 0.18, 0.88)

    -- "BOSS" au centre
    local bossLbl = f:CreateFontString(nil, "OVERLAY")
    bossLbl:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    bossLbl:SetPoint("CENTER", 0, 0)
    bossLbl:SetTextColor(0.78, 0.07, 0.07, 1)
    bossLbl:SetText("BOSS")

    -- Icône tank au dessus
    local tankTex = f:CreateTexture(nil, "OVERLAY")
    tankTex:SetSize(22, 22)
    tankTex:SetPoint("CENTER", 0, 52)
    tankTex:SetTexture("Interface\\Icons\\INV_Shield_04")

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
    viewerFrame = f
end

-- ─── Caller panel ─────────────────────────────────────────────────────────────
local function RefreshCallerButtons()
    for _, id in ipairs(RUNE_ORDER) do
        local btn = callerBtns[id]
        if btn then
            local inSeq = false
            for i, sid in ipairs(sequence) do
                if sid == id then inSeq = true; btn._order = i; break end
            end
            if inSeq then
                btn:SetAlpha(0.35)
                btn._numLabel:SetText(tostring(btn._order))
                btn._numLabel:Show()
            else
                btn:SetAlpha(1)
                btn._numLabel:SetText("")
                btn._numLabel:Hide()
            end
        end
    end
end

local function BuildCallerFrame()
    if callerFrame then return end

    local BTN  = 56
    local PAD  = 8
    local W    = 5 * BTN + 4 * PAD + 2 * PAD
    local H    = BTN + 48 + 2 * PAD

    local f = CreateFrame("Frame", "LHLuraCaller", UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -280)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0.10, 0.05, 0.18, 0.95)
    f:SetBackdropBorderColor(0.35, 0.15, 0.55, 0.8)
    f:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Titre
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetTextColor(0.60, 0.93, 1.0, 1)
    title:SetText("L'ura — Mémoire des Runes")

    -- 5 boutons rune
    for i, id in ipairs(RUNE_ORDER) do
        local rune = RUNES[id]
        local btn  = CreateFrame("Button", nil, f, "BackdropTemplate")
        btn:SetSize(BTN, BTN)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + (i-1)*(BTN+PAD), -20)
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.05, 0.01, 0.10, 0.9)
        btn:SetBackdropBorderColor(rune.r*0.6, rune.g*0.6, rune.b*0.6, 0.8)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetSize(BTN-6, BTN-6)
        tex:SetPoint("CENTER")
        tex:SetTexture(rune.tex)

        -- Numéro de position
        local numLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        numLbl:SetPoint("CENTER")
        numLbl:SetTextColor(1, 0.84, 0, 1)
        numLbl:Hide()
        btn._numLabel = numLbl
        btn._id = id

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(rune.r, rune.g, rune.b, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(rune.r*0.6, rune.g*0.6, rune.b*0.6, 0.8)
        end)
        btn:SetScript("OnClick", function(self)
            local rid = self._id
            -- Toggle : si déjà dans la séquence → retire
            for j, sid in ipairs(sequence) do
                if sid == rid then
                    table.remove(sequence, j)
                    RefreshCallerButtons()
                    UpdateViewer()
                    return
                end
            end
            -- Ajoute
            local maxSym = (M.config and M.config.luraHeroicMode ~= false) and 5 or 3
            if #sequence < maxSym then
                table.insert(sequence, rid)
                RefreshCallerButtons()
                UpdateViewer()
            end
        end)

        callerBtns[id] = btn
    end

    -- Send button
    local sendBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    sendBtn:SetSize((W - 3*PAD) / 2, 32)
    sendBtn:SetPoint("BOTTOMLEFT", PAD, PAD)
    sendBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    sendBtn:SetBackdropColor(0.10, 0.28, 0.10, 1)
    sendBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)
    local sendLbl = sendBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sendLbl:SetPoint("CENTER"); sendLbl:SetText("Envoyer")
    sendLbl:SetTextColor(0.6, 1.0, 0.6, 1)
    sendBtn:SetScript("OnClick", function()
        if #sequence == 0 then return end
        if not CanSend() then
            print("|cffcc1414LH|r Tu dois être RL ou assistant pour envoyer.")
            return
        end
        local msg = Serialize(sequence)
        local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
        if channel then
            C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
        end
        -- Feedback visuel
        sendBtn:SetBackdropColor(0.2, 0.6, 0.2, 1)
        C_Timer.After(0.6, function()
            sendBtn:SetBackdropColor(0.10, 0.28, 0.10, 1)
        end)
        UpdateViewer()
    end)

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    clearBtn:SetSize((W - 3*PAD) / 2, 32)
    clearBtn:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    clearBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    clearBtn:SetBackdropColor(0.28, 0.06, 0.06, 1)
    clearBtn:SetBackdropBorderColor(0.7, 0.2, 0.2, 0.8)
    local clearLbl = clearBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clearLbl:SetPoint("CENTER"); clearLbl:SetText("Clear")
    clearLbl:SetTextColor(1.0, 0.5, 0.5, 1)
    clearBtn:SetScript("OnClick", function()
        wipe(sequence)
        RefreshCallerButtons()
        UpdateViewer()
        if CanSend() then
            local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
            if channel then
                C_ChatInfo.SendAddonMessage(PREFIX, "CLEAR", channel)
            end
        end
    end)

    f:Hide()
    callerFrame = f
end

-- ─── API publique ─────────────────────────────────────────────────────────────

function M:ToggleLuraCallerPanel()
    if not callerFrame then BuildCallerFrame() end
    if callerFrame:IsShown() then callerFrame:Hide()
    else callerFrame:Show() end
end

function M:ToggleLuraDiagram()
    if not viewerFrame then BuildViewerFrame() end
    if viewerFrame:IsShown() then viewerFrame:Hide()
    else viewerFrame:Show(); UpdateViewer() end
end

function M:SetLuraHeroicMode(heroic)
    if M.config then
        M.config.luraHeroicMode = heroic
        if M.SaveConfig then M:SaveConfig() end
    end
    wipe(sequence)
    if callerFrame then RefreshCallerButtons() end
    UpdateViewer()
end

function M:RepositionLuraDiagram()
    if not viewerFrame then return end
    local x = M.config and M.config.luraDiagX or 0
    local y = M.config and M.config.luraDiagY or 150
    viewerFrame:ClearAllPoints()
    viewerFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

-- ─── Timers de phase (reset automatique) ─────────────────────────────────────
local function CancelPhaseTimers()
    for _, t in ipairs(phaseTimers) do pcall(function() t:Cancel() end) end
    wipe(phaseTimers)
end

local function StartPhaseTimers()
    CancelPhaseTimers()
    for _, secs in ipairs(PHASE_RESETS) do
        table.insert(phaseTimers, C_Timer.NewTimer(secs, function()
            wipe(sequence)
            if callerFrame then RefreshCallerButtons() end
            UpdateViewer()
        end))
    end
end

-- ─── Événements ──────────────────────────────────────────────────────────────
local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ENCOUNTER_START")
evtFrame:RegisterEvent("ENCOUNTER_END")
evtFrame:RegisterEvent("CHAT_MSG_ADDON")
evtFrame:RegisterEvent("PLAYER_LOGIN")

evtFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        BuildViewerFrame()
        BuildCallerFrame()

    elseif event == "ENCOUNTER_START" then
        local encounterID = ...
        if encounterID == LURA_ENCOUNTER_ID then
            wipe(sequence)
            if callerFrame then RefreshCallerButtons() end
            UpdateViewer()
            StartPhaseTimers()
        end

    elseif event == "ENCOUNTER_END" then
        local encounterID = ...
        if encounterID == LURA_ENCOUNTER_ID then
            CancelPhaseTimers()
            C_Timer.NewTimer(VANISH_GRACE, function()
                wipe(sequence)
                if callerFrame then RefreshCallerButtons() end
                UpdateViewer()
            end)
        end

    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message = ...
        if prefix ~= PREFIX then return end
        if message == "CLEAR" then
            wipe(sequence)
            if callerFrame then RefreshCallerButtons() end
            UpdateViewer()
            return
        end
        local seq = Deserialize(message)
        if #seq == 0 then return end
        wipe(sequence)
        for _, id in ipairs(seq) do
            if RUNES[id] then table.insert(sequence, id) end
        end
        if callerFrame then RefreshCallerButtons() end
        UpdateViewer()
    end
end)
