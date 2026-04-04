local addonName, M = ...
local RL_NOTE_PLAYER = "Thiri\195\163ll"
local FONT_FLAGS = "OUTLINE"
local MIN_VISIBLE_DURATION = 0.75

-- Couleur du texte selon le type d'alerte
-- SetTextColor colore le texte sans couleur explicite ; les |cff...| dans le msg ont priorité
local ALERT_COLORS = {
    interrupt = {1,    0.27, 0.27},  -- rouge vif
    soak      = {1,    0.9,  0.1 },  -- jaune doré
    phase     = {0.3,  0.85, 1   },  -- cyan
    private   = {1,    0.65, 0.2 },  -- orange chaud (alertes personnelles)
    global    = {1,    1,    1   },  -- blanc (défaut)
    dispel    = {1,    0.1,  1   },  -- magenta vif (alerte dispel urgente)
}

-- Intensité du pop selon le type d'alerte (scale max)
local POP_SCALE = {
    dispel = 1.5,   -- plus agressif pour les dispels
}

local POP_DURATION   = 0.15   -- secondes : retour à échelle 1.0 après le "punch"
local FLASH_DURATION = 0.4    -- secondes : disparition du fond coloré
local FLASH_ALPHA    = 0.35   -- opacité maximale du fond coloré

-- Pop : scale → 1.0 en POP_DURATION secondes (~60fps ticker)
-- maxScale : 1.2 par défaut, 1.5 pour les alertes dispel
local function PlayPop(frame, maxScale)
    maxScale = maxScale or 1.2
    if frame.popTimer then
        frame.popTimer:Cancel()
        frame.popTimer = nil
    end
    frame:SetScale(maxScale)
    local t0 = GetTime()
    local delta = maxScale - 1.0
    frame.popTimer = C_Timer.NewTicker(0.016, function()
        local p = math.min((GetTime() - t0) / POP_DURATION, 1)
        frame:SetScale(maxScale - delta * p)
        if p >= 1 then
            frame:SetScale(1.0)
            if frame.popTimer then frame.popTimer:Cancel(); frame.popTimer = nil end
        end
    end)
end

-- Flash : fond coloré alpha FLASH_ALPHA → 0 en FLASH_DURATION secondes
local function PlayFlash(flashTex, r, g, b)
    if flashTex.flashTimer then
        flashTex.flashTimer:Cancel()
        flashTex.flashTimer = nil
    end
    flashTex:SetColorTexture(r, g, b, FLASH_ALPHA)
    local t0 = GetTime()
    flashTex.flashTimer = C_Timer.NewTicker(0.016, function()
        local p = math.min((GetTime() - t0) / FLASH_DURATION, 1)
        flashTex:SetColorTexture(r, g, b, FLASH_ALPHA * (1 - p))
        if p >= 1 then
            flashTex:SetColorTexture(r, g, b, 0)
            if flashTex.flashTimer then flashTex.flashTimer:Cancel(); flashTex.flashTimer = nil end
        end
    end)
end

local function GetCenterOffsets(frame, fallbackX, fallbackY)
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()

    if not centerX or not centerY or not parentCenterX or not parentCenterY then
        return fallbackX or 0, fallbackY or 0
    end

    return math.floor(centerX - parentCenterX + 0.5), math.floor(centerY - parentCenterY + 0.5)
end

local function UpdateChannelPosition(channel)
    if channel.previewFrame then
        channel.previewFrame:ClearAllPoints()
        channel.previewFrame:SetPoint("CENTER", UIParent, "CENTER", M.config[channel.posXKey], M.config[channel.posYKey])
    end

    if channel.displayFrame then
        channel.displayFrame:ClearAllPoints()
        channel.displayFrame:SetPoint("CENTER", UIParent, "CENTER", M.config[channel.posXKey], M.config[channel.posYKey])
    end
end

local function UpdateChannelSize(channel)
    local size = M.config[channel.sizeKey]

    if channel.previewText then
        channel.previewText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
        channel.previewText:SetTextColor(1, 1, 1, 1)
    end

    if channel.displayText then
        channel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
        channel.displayText:SetTextColor(1, 1, 1, 1)
    end
end

local function HideChannel(channel)
    if not channel.displayFrame or not channel.displayText then
        return
    end

    if channel.displayFrame.timer then
        channel.displayFrame.timer:Cancel()
        channel.displayFrame.timer = nil
    end

    -- Annulation des animations en cours
    if channel.displayFrame.popTimer then
        channel.displayFrame.popTimer:Cancel()
        channel.displayFrame.popTimer = nil
    end
    channel.displayFrame:SetScale(1.0)

    if channel.flashTex then
        if channel.flashTex.flashTimer then
            channel.flashTex.flashTimer:Cancel()
            channel.flashTex.flashTimer = nil
        end
        channel.flashTex:SetColorTexture(0, 0, 0, 0)
    end

    channel.displayText:SetText("")
    channel.displayFrame:SetAlpha(1)
    channel.displayFrame:Hide()
end

local function ShowChannel(channel, msg, soundType)
    if not channel.displayFrame or not channel.displayText then
        return
    end

    UpdateChannelPosition(channel)
    UpdateChannelSize(channel)

    local c = ALERT_COLORS[soundType] or ALERT_COLORS["global"]
    channel.displayText:SetTextColor(c[1], c[2], c[3], 1)
    channel.displayText:SetText(msg)
    channel.displayFrame:SetAlpha(0)
    channel.displayFrame:Show()
    UIFrameFadeIn(channel.displayFrame, 0.05, 0, 1)

    -- Pop + Flash (uniquement pour les alertes avec durée, pas la RL note persistante)
    if channel.durationKey then
        PlayPop(channel.displayFrame, POP_SCALE[soundType])
        if channel.flashTex and soundType and soundType ~= "global" then
            PlayFlash(channel.flashTex, c[1], c[2], c[3])
        end
    end

    if channel.displayFrame.timer then
        channel.displayFrame.timer:Cancel()
        channel.displayFrame.timer = nil
    end

    if channel.durationKey then
        local duration = tonumber(M.config[channel.durationKey]) or channel.defaultDuration or 3

        if duration < MIN_VISIBLE_DURATION then
            duration = math.max(channel.defaultDuration or MIN_VISIBLE_DURATION, MIN_VISIBLE_DURATION)
        end

        channel.displayFrame.timer = C_Timer.NewTimer(duration, function()
            channel.displayFrame.timer = nil
            HideChannel(channel)
        end)
    end
end

local function CreateTextChannel(channel)
    if channel.previewFrame and channel.displayFrame then
        UpdateChannelPosition(channel)
        UpdateChannelSize(channel)
        return
    end

    local anchor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    anchor:SetSize(channel.width, channel.height)
    anchor:SetPoint("CENTER", UIParent, "CENTER", M.config[channel.posXKey], M.config[channel.posYKey])
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    anchor:SetBackdrop({
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 16,
    })
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")

    anchor:SetScript("OnDragStart", anchor.StartMoving)
    anchor:SetScript("OnDragStop", function(self)
        local x
        local y

        self:StopMovingOrSizing()
        x, y = GetCenterOffsets(self, M.config[channel.posXKey], M.config[channel.posYKey])

        M.config[channel.posXKey] = x
        M.config[channel.posYKey] = y

        if M.SaveConfig then
            M:SaveConfig()
        end

        UpdateChannelPosition(channel)
    end)

    anchor:Hide()

    local previewText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    previewText:SetPoint("TOPLEFT", 12, -12)
    previewText:SetPoint("BOTTOMRIGHT", -12, 12)
    previewText:SetJustifyH(channel.justifyH or "CENTER")
    previewText:SetJustifyV(channel.justifyV or "MIDDLE")
    previewText:SetText(channel.previewLabel)
    previewText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey], FONT_FLAGS)
    previewText:SetTextColor(1, 1, 1, 1)
    previewText:SetShadowOffset(1, -1)
    previewText:SetShadowColor(0, 0, 0, 0.85)

    local display = CreateFrame("Frame", nil, UIParent)
    display:SetSize(channel.width, channel.height)
    display:SetPoint("CENTER", UIParent, "CENTER", M.config[channel.posXKey], M.config[channel.posYKey])
    display:SetFrameStrata("HIGH")
    display:EnableMouse(false)

    local displayText = display:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    displayText:SetPoint("TOPLEFT", 12, -12)
    displayText:SetPoint("BOTTOMRIGHT", -12, 12)
    displayText:SetJustifyH(channel.justifyH or "CENTER")
    displayText:SetJustifyV(channel.justifyV or "MIDDLE")
    displayText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey], FONT_FLAGS)
    displayText:SetTextColor(1, 1, 1, 1)
    displayText:SetShadowOffset(1, -1)
    displayText:SetShadowColor(0, 0, 0, 0.85)

    -- Fond coloré flash (alertes avec durée uniquement, pas la RL note persistante)
    if channel.durationKey then
        local flashTex = display:CreateTexture(nil, "BACKGROUND")
        flashTex:SetAllPoints()
        flashTex:SetColorTexture(0, 0, 0, 0)
        channel.flashTex = flashTex
    end

    display:Hide()

    channel.previewFrame = anchor
    channel.previewText = previewText
    channel.displayFrame = display
    channel.displayText = displayText
end

local globalChannel = {
    width = 950,
    height = 160,
    posXKey = "posX",
    posYKey = "posY",
    sizeKey = "textSize",
    durationKey = "textDuration",
    defaultDuration = 4,
    previewLabel = "GLOBAL TEXT",
}

local privateChannel = {
    width = 750,
    height = 120,
    posXKey = "privatePosX",
    posYKey = "privatePosY",
    sizeKey = "privateTextSize",
    durationKey = "privateTextDuration",
    defaultDuration = 5,
    previewLabel = "PRIVATE TEXT",
}

local rlNoteChannel = {
    width = 520,
    height = 240,
    posXKey = "rlNotePosX",
    posYKey = "rlNotePosY",
    sizeKey = "rlNoteTextSize",
    durationKey = nil,
    persistent = true,
    previewLabel = "RL NOTE",
    justifyH = "LEFT",
    justifyV = "TOP",
}

local function IsRLNoteOwner()
    return UnitName("player") == RL_NOTE_PLAYER
end

function M:CreatePreviewText()
    CreateTextChannel(globalChannel)
    CreateTextChannel(privateChannel)
    if IsRLNoteOwner() then
        CreateTextChannel(rlNoteChannel)
    end

    self.previewFrame = globalChannel.previewFrame
    self.previewText = globalChannel.previewText
    self.displayFrame = globalChannel.displayFrame
    self.displayText = globalChannel.displayText

    self.privatePreviewFrame = privateChannel.previewFrame
    self.privatePreviewText = privateChannel.previewText
    self.privateDisplayFrame = privateChannel.displayFrame
    self.privateDisplayText = privateChannel.displayText

    self.rlNotePreviewFrame = rlNoteChannel.previewFrame
    self.rlNotePreviewText = rlNoteChannel.previewText
    self.rlNoteDisplayFrame = rlNoteChannel.displayFrame
    self.rlNoteDisplayText = rlNoteChannel.displayText
end

function M:ShowText(msg, soundType)
    if not self.displayFrame or not self.displayText then
        self:CreatePreviewText()
    end

    ShowChannel(globalChannel, msg, soundType)
end

function M:HideText()
    HideChannel(globalChannel)
end

function M:ShowPrivateText(msg)
    if not self.privateDisplayFrame or not self.privateDisplayText then
        self:CreatePreviewText()
    end

    ShowChannel(privateChannel, msg, "private")
end

function M:HidePrivateText()
    HideChannel(privateChannel)
end

-- Alerte dispel : même canal que private mais THICKOUTLINE + magenta + pop agressif
function M:ShowDispelText(msg)
    if not self.privateDisplayFrame or not self.privateDisplayText then
        self:CreatePreviewText()
    end

    -- Bascule temporairement la police en THICKOUTLINE pour l'effet "gras"
    local size = M.config and M.config[privateChannel.sizeKey] or 28
    privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")

    ShowChannel(privateChannel, msg, "dispel")

    -- Restaure OUTLINE après la durée de l'alerte
    local duration = (M.config and M.config[privateChannel.durationKey]) or privateChannel.defaultDuration or 5
    C_Timer.After(duration + 0.1, function()
        privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
    end)
end

function M:HideDispelText()
    HideChannel(privateChannel)
    -- Restaure la police normale immédiatement
    local size = M.config and M.config[privateChannel.sizeKey] or 28
    privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
end

function M:ToggleTextAnchors()
    if not self.previewFrame or not self.privatePreviewFrame then
        return
    end

    local shouldShow = not self.previewFrame:IsShown()

    if shouldShow then
        self.previewFrame:Show()
        self.privatePreviewFrame:Show()
        if IsRLNoteOwner() and self.rlNotePreviewFrame then
            self.rlNotePreviewFrame:Show()
        end
    else
        self.previewFrame:Hide()
        self.privatePreviewFrame:Hide()
        if self.rlNotePreviewFrame then
            self.rlNotePreviewFrame:Hide()
        end
    end
end

function M:ShowRLNote(msg)
    if not IsRLNoteOwner() then
        return
    end

    if not self.rlNoteDisplayFrame or not self.rlNoteDisplayText then
        self:CreatePreviewText()
    end

    ShowChannel(rlNoteChannel, msg)
end

function M:HideRLNote()
    HideChannel(rlNoteChannel)
end
