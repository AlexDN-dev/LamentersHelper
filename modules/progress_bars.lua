local addonName, M = ...

-- Barres type boss mod : texture en dégradé, texte dans la barre (titre à gauche, secondes à droite).

M._progressBarSlots = M._progressBarSlots or {}

local BAR_W, BAR_H = 280, 22
local FONT = "Fonts\\FRIZQT__.TTF"

-- Texture remplissage : dégradé vertical (style proche BigWigs / PaperDoll)
local STATUS_TEX = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar"

-- Couleurs par type d'alerte — identiques à text.lua pour la cohérence visuelle
local ALERT_COLORS = {
    interrupt = { 1,    0.27, 0.27 },
    soak      = { 1,    0.9,  0.1  },
    phase     = { 0.3,  0.85, 1    },
    private   = { 1,    0.65, 0.2  },
    global    = { 1,    1,    1    },
    dispel    = { 1,    0.1,  1    },
}
local DEFAULT_BAR_COLOR = { 0.95, 0.82, 0.18 }  -- or/jaune si type non reconnu

local function GetBarColor(alertType)
    local c = alertType and ALERT_COLORS[alertType]
    if c then return c[1], c[2], c[3] end
    return DEFAULT_BAR_COLOR[1], DEFAULT_BAR_COLOR[2], DEFAULT_BAR_COLOR[3]
end

local function SetBarTextStyle(fs)
    fs:SetFont(FONT, 11, "")
    fs:SetTextColor(1, 0.98, 0.85)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
end

local function ApplyBarFillColor(sb, alertType)
    local r, g, b = GetBarColor(alertType)
    sb:SetStatusBarColor(r, g, b, 1)
end

--- slotIndex 1..4 : décalage Y relatif par rapport à l'ancre du groupe
local SLOT_REL_Y = { 140, 90, 40, -10 }

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

local function GetOrCreateBar(slotIndex)
    local bar = M._progressBarSlots[slotIndex]
    if bar then
        return bar
    end

    local anchorX, anchorY = GetSlotPosition(slotIndex)

    local f = CreateFrame("Frame", "LHProgressBar" .. slotIndex, UIParent, "BackdropTemplate")
    f:SetSize(BAR_W, BAR_H + 10)
    f:SetPoint("CENTER", UIParent, "CENTER", anchorX, anchorY)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    f:SetBackdropColor(0.02, 0.02, 0.02, 0.92)

    local sb = CreateFrame("StatusBar", nil, f)
    sb:SetPoint("TOPLEFT", 5, -5)
    sb:SetPoint("BOTTOMRIGHT", -5, 5)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(1)
    sb:SetStatusBarTexture(STATUS_TEX)
    local tex = sb:GetStatusBarTexture()
    if tex then
        tex:SetHorizTile(false)
        tex:SetVertTile(false)
    end
    ApplyBarFillColor(sb)

    local bg = sb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.08, 0.95)

    local barTitle = sb:CreateFontString(nil, "OVERLAY", nil)
    barTitle:SetPoint("LEFT", sb, "LEFT", 6, 0)
    barTitle:SetJustifyH("LEFT")
    SetBarTextStyle(barTitle)

    local barTime = sb:CreateFontString(nil, "OVERLAY", nil)
    barTime:SetPoint("RIGHT", sb, "RIGHT", -6, 0)
    barTime:SetJustifyH("RIGHT")
    SetBarTextStyle(barTime)

    f.barTitle = barTitle
    f.barTime = barTime
    f.statusBar = sb
    f.slotIndex = slotIndex
    f:Hide()

    M._progressBarSlots[slotIndex] = f
    return f
end

function M:ProgressBarSet(slotIndex, min, max, value, titleText, alertType)
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = nil
    f.barTitle:SetText(titleText or "")
    f.barTime:SetText(value ~= nil and string.format("%.1f", value) or "")
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(min, max)
    f.statusBar:SetValue(value)
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

--- titleText = libellé fixe à gauche (ex. "underworld") ; les secondes s’affichent à droite et se mettent à jour.
function M:ProgressBarCountdown(slotIndex, durationSeconds, titleText, alertType)
    if not durationSeconds or durationSeconds <= 0 then
        self:ProgressBarHide(slotIndex)
        return
    end
    local f = GetOrCreateBar(slotIndex)
    f._countdownTitle = titleText or ""
    ApplyBarFillColor(f.statusBar, alertType)
    f.statusBar:SetMinMaxValues(0, durationSeconds)
    f.statusBar:SetValue(durationSeconds)
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
