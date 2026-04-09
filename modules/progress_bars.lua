local addonName, M = ...

-- Barres type boss mod : icone + nom d'abilite a gauche, timer a droite.

M._progressBarSlots = M._progressBarSlots or {}

local BAR_W_DEFAULT = 320
local BAR_H_DEFAULT = 28

local function GetBarSize()
    return (M.config and M.config.barWidth  or BAR_W_DEFAULT),
           (M.config and M.config.barHeight or BAR_H_DEFAULT)
end
local ICON_SIZE     = 22
local ICON_PAD      = 4
local FONT          = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE     = 13
local SOLID_TEX     = "Interface\\Buttons\\WHITE8X8"

local ALERT_COLORS = {
    interrupt = { 1,    0.27, 0.27 },
    soak      = { 1,    0.9,  0.1  },
    phase     = { 0.3,  0.85, 1    },
    private   = { 1,    0.65, 0.2  },
    global    = { 1,    1,    1    },
    dispel    = { 1,    0.1,  1    },
}
local DEFAULT_BAR_COLOR = { 0.95, 0.82, 0.18 }

local function GetBarColor(alertType)
    local c = alertType and ALERT_COLORS[alertType]
    if c then return c[1], c[2], c[3] end
    return DEFAULT_BAR_COLOR[1], DEFAULT_BAR_COLOR[2], DEFAULT_BAR_COLOR[3]
end

local function SetBarTextStyle(fs)
    fs:SetFont(FONT, FONT_SIZE, "OUTLINE")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

local function ApplyBarFillColor(sb, alertType)
    local r, g, b = GetBarColor(alertType)
    sb:SetStatusBarColor(r, g, b, 0.85)
end

local SLOT_REL_Y = { 140, 104, 68, 32 }

local function GetSlotPosition(slotIndex)
    local cfgX = (M.config and M.config.barGroupPosX) or 0
    local cfgY = (M.config and M.config.barGroupPosY) or 0
    return cfgX, cfgY + (SLOT_REL_Y[slotIndex] or 0)
end

local function UpdateCountdownTexts(f, timeLeft)
    local title = f._countdownTitle or ""
    f.barTitle:SetText(title)
    if timeLeft and timeLeft > 0 then
        f.barTime:SetText(string.format("%.1f", timeLeft))
    else
        f.barTime:SetText("")
    end
end

-- Applique l'icone et reposisionne le titre en consequence.
local function SetBarIcon(f, spellID)
    if spellID and spellID > 0 then
        local iconID = C_Spell.GetSpellTexture(spellID)
        if iconID then
            f.iconTex:SetTexture(iconID)
            f.iconTex:Show()
            f.barTitle:ClearAllPoints()
            f.barTitle:SetPoint("LEFT",  f.statusBar, "LEFT",  3 + ICON_SIZE + ICON_PAD, 0)
            f.barTitle:SetPoint("RIGHT", f.statusBar, "CENTER", -4, 0)
            return
        end
    end
    f.iconTex:Hide()
    f.barTitle:ClearAllPoints()
    f.barTitle:SetPoint("LEFT",  f.statusBar, "LEFT",  8, 0)
    f.barTitle:SetPoint("RIGHT", f.statusBar, "CENTER", -4, 0)
end

local function GetOrCreateBar(slotIndex)
    local bar = M._progressBarSlots[slotIndex]
    if bar then return bar end

    local anchorX, anchorY = GetSlotPosition(slotIndex)

    -- Conteneur
    local w, h = GetBarSize()
    local f = CreateFrame("Frame", "LHProgressBar" .. slotIndex, UIParent)
    f:SetSize(w, h)
    f:SetPoint("CENTER", UIParent, "CENTER", anchorX, anchorY)
    f:SetFrameStrata("HIGH")

    -- Fond tres sombre
    local bgTex = f:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(0.04, 0.04, 0.06, 0.96)

    -- Bordure 1px
    local border = f:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT",     f, "TOPLEFT",     -1,  1)
    border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT",  1, -1)
    border:SetColorTexture(0, 0, 0, 1)

    -- StatusBar (fill)
    local sb = CreateFrame("StatusBar", nil, f)
    sb:SetAllPoints()
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(1)
    sb:SetStatusBarTexture(SOLID_TEX)
    ApplyBarFillColor(sb)

    -- Fond sombre derriere le fill
    local sbBg = sb:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints()
    sbBg:SetColorTexture(0.08, 0.08, 0.10, 1)

    -- Icone (gauche, dans sb pour passer au-dessus du fill)
    local iconTex = sb:CreateTexture(nil, "OVERLAY")
    iconTex:SetSize(ICON_SIZE, ICON_SIZE)
    iconTex:SetPoint("LEFT", sb, "LEFT", 3, 0)
    iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    iconTex:Hide()

    -- Titre (gauche, dans sb — reancre par SetBarIcon)
    local barTitle = sb:CreateFontString(nil, "OVERLAY")
    barTitle:SetPoint("LEFT",  sb, "LEFT",  8, 0)
    barTitle:SetPoint("RIGHT", sb, "CENTER", -4, 0)
    barTitle:SetJustifyH("LEFT")
    SetBarTextStyle(barTitle)

    -- Timer (droite, dans sb)
    local barTime = sb:CreateFontString(nil, "OVERLAY")
    barTime:SetPoint("RIGHT", sb, "RIGHT", -8, 0)
    barTime:SetJustifyH("RIGHT")
    SetBarTextStyle(barTime)

    -- Marker deadline (trait vertical rouge) — caché par défaut
    -- Positionné via SetDeadlineMarker(f, fraction) où fraction ∈ [0,1]
    local deadlineMarker = f:CreateTexture(nil, "OVERLAY")
    deadlineMarker:SetSize(3, h)
    deadlineMarker:SetColorTexture(1, 0.1, 0.1, 0.95)
    deadlineMarker:Hide()
    f._deadlineMarker = deadlineMarker

    f.iconTex   = iconTex
    f.barTitle  = barTitle
    f.barTime   = barTime
    f.statusBar = sb
    f.slotIndex = slotIndex
    f:Hide()

    M._progressBarSlots[slotIndex] = f
    return f
end

-- Place le marker deadline à `fraction` de la largeur (0=gauche, 1=droite).
-- Appeler avec fraction=nil pour le masquer.
local function SetDeadlineMarker(f, fraction)
    if not fraction then
        f._deadlineMarker:Hide()
        return
    end
    local w = f:GetWidth()
    local x = w * fraction
    f._deadlineMarker:ClearAllPoints()
    f._deadlineMarker:SetPoint("LEFT", f, "LEFT", x - 1, 0)
    f._deadlineMarker:Show()
end

function M:ProgressBarSet(slotIndex, min, max, value, titleText, alertType, spellID)
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = nil
    f.barTitle:SetText(titleText or "")
    f.barTime:SetText(value ~= nil and string.format("%.1f", value) or "")
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(min, max)
    f.statusBar:SetValue(value)
    SetBarIcon(f, spellID)
    f:Show()
end

function M:ProgressBarHide(slotIndex)
    local f = M._progressBarSlots[slotIndex]
    if f then
        if f.animTicker then
            f.animTicker:Cancel()
            f.animTicker = nil
        end
        f._countdownTitle = nil
        f:Hide()
    end
end

--- titleText = nom de l'abilite en majuscules (ex. "CONSUME") ; timer a droite.
--- spellID optionnel : affiche l'icone du sort a gauche du texte.
function M:ProgressBarCountdown(slotIndex, durationSeconds, titleText, alertType, spellID)
    if not durationSeconds or durationSeconds <= 0 then
        self:ProgressBarHide(slotIndex)
        return
    end
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = titleText or ""
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(0, durationSeconds)
    f.statusBar:SetValue(durationSeconds)
    SetBarIcon(f, spellID)
    UpdateCountdownTexts(f, durationSeconds)
    f:Show()

    if f.animTicker then
        f.animTicker:Cancel()
        f.animTicker = nil
    end

    local endT = GetTime() + durationSeconds
    f.animTicker = C_Timer.NewTicker(0.03, function()
        local left = endT - GetTime()
        if left <= 0 then
            f.statusBar:SetValue(0)
            UpdateCountdownTexts(f, 0)
            if f.animTicker then f.animTicker:Cancel(); f.animTicker = nil end
            f:Hide()
            return
        end
        f.statusBar:SetValue(left)
        UpdateCountdownTexts(f, left)
    end)
end

--- Comme ProgressBarCountdown mais avec un marker rouge deadline.
--- deadlineSeconds = moment où le marker est positionné (ex: 10s sur une barre de 17s).
--- Le marker reste fixe ; la barre se vide vers lui.
function M:ProgressBarCountdownDeadline(slotIndex, durationSeconds, titleText, alertType, spellID, deadlineSeconds)
    if not durationSeconds or durationSeconds <= 0 then
        self:ProgressBarHide(slotIndex)
        return
    end
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = titleText or ""
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(0, durationSeconds)
    f.statusBar:SetValue(durationSeconds)
    SetBarIcon(f, spellID)
    UpdateCountdownTexts(f, durationSeconds)

    -- Positionne le marker : fraction = deadlineSeconds / durationSeconds (depuis la gauche)
    if deadlineSeconds and deadlineSeconds > 0 and deadlineSeconds < durationSeconds then
        SetDeadlineMarker(f, deadlineSeconds / durationSeconds)
    else
        SetDeadlineMarker(f, nil)
    end

    f:Show()

    if f.animTicker then f.animTicker:Cancel(); f.animTicker = nil end

    local endT = GetTime() + durationSeconds
    f.animTicker = C_Timer.NewTicker(0.03, function()
        local left = endT - GetTime()
        if left <= 0 then
            f.statusBar:SetValue(0)
            UpdateCountdownTexts(f, 0)
            SetDeadlineMarker(f, nil)
            if f.animTicker then f.animTicker:Cancel(); f.animTicker = nil end
            f:Hide()
            return
        end
        f.statusBar:SetValue(left)
        UpdateCountdownTexts(f, left)
    end)
end

--- Barre qui se REMPLIT de gauche à droite sur durationSeconds.
--- Le timer à droite affiche le temps restant (compte à rebours).
--- Se cache automatiquement quand la durée est écoulée.
function M:ProgressBarFill(slotIndex, durationSeconds, titleText, alertType, spellID)
    if not durationSeconds or durationSeconds <= 0 then
        self:ProgressBarHide(slotIndex)
        return
    end
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = titleText or ""
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(0, durationSeconds)
    f.statusBar:SetValue(0)
    SetBarIcon(f, spellID)
    SetDeadlineMarker(f, nil)
    UpdateCountdownTexts(f, durationSeconds)
    f:Show()

    if f.animTicker then f.animTicker:Cancel(); f.animTicker = nil end

    local startT = GetTime()
    f.animTicker = C_Timer.NewTicker(0.03, function()
        local elapsed = GetTime() - startT
        local left    = durationSeconds - elapsed
        if left <= 0 then
            f.statusBar:SetValue(durationSeconds)
            UpdateCountdownTexts(f, 0)
            if f.animTicker then f.animTicker:Cancel(); f.animTicker = nil end
            f:Hide()
            return
        end
        f.statusBar:SetValue(elapsed)
        UpdateCountdownTexts(f, left)
    end)
end

function M:ProgressBarTest(slotIndex, seconds, titleText)
    self:ProgressBarCountdown(slotIndex or 1, seconds or 12, titleText or "test")
end

function M:RepositionBars()
    for slotIndex, f in pairs(M._progressBarSlots) do
        local x, y = GetSlotPosition(slotIndex)
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end
end

function M:ResizeBars()
    local w, h = GetBarSize()
    for _, f in pairs(M._progressBarSlots) do
        f:SetSize(w, h)
    end
end

-- ─── Drag interactif (depuis le panneau d'options) ────────────────────────────
local _drag = { on = false, sx = 0, sy = 0, cx = 0, cy = 0, cb = nil }

function M:EnableBarDrag(onMove)
    _drag.cb = onMove
    _drag.on = false
    self:ProgressBarCountdown(1, 60, "D\195\169place les barres", "soak")
    self:ProgressBarCountdown(2, 58, "Fearsome Cry \226\128\148 INTERRUPT", "interrupt")
    self:ProgressBarCountdown(3, 56, "Phase Transition", "phase")
    self:ProgressBarCountdown(4, 54, "Void Breath", "global")

    local f = GetOrCreateBar(1)
    f:EnableMouse(true)
    f:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        _drag.on = true
        _drag.sx, _drag.sy = GetCursorPosition()
        _drag.cx = M.config.barGroupPosX or 0
        _drag.cy = M.config.barGroupPosY or 0
    end)
    f:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "LeftButton" then return end
        _drag.on = false
        if M.SaveConfig then M:SaveConfig() end
    end)
    f:SetScript("OnUpdate", function(_)
        if not _drag.on then return end
        local mx, my = GetCursorPosition()
        local sc = UIParent:GetEffectiveScale()
        M.config.barGroupPosX = math.floor(_drag.cx + (mx - _drag.sx) / sc)
        M.config.barGroupPosY = math.floor(_drag.cy + (my - _drag.sy) / sc)
        M:RepositionBars()
        if _drag.cb then _drag.cb() end
    end)
end

function M:DisableBarDrag()
    _drag.on = false
    _drag.cb = nil
    local f = M._progressBarSlots[1]
    if f then
        f:EnableMouse(false)
        f:SetScript("OnMouseDown", nil)
        f:SetScript("OnMouseUp", nil)
        f:SetScript("OnUpdate", nil)
    end
    for i = 1, 4 do self:ProgressBarHide(i) end
end
