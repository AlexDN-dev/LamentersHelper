local addonName, M = ...
local RL_NOTE_PLAYER = "Thiri\195\163ll"

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
        channel.previewText:SetFont("Fonts\\FRIZQT__.TTF", size)
        channel.previewText:SetTextColor(1, 1, 1, 1)
    end

    if channel.displayText then
        channel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size)
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

    channel.displayText:SetText("")
    channel.displayFrame:Hide()
end

local function ShowChannel(channel, msg)
    if not channel.displayFrame or not channel.displayText then
        return
    end

    UpdateChannelPosition(channel)
    UpdateChannelSize(channel)

    channel.displayFrame:Show()
    channel.displayText:SetText(msg)

    if channel.displayFrame.timer then
        channel.displayFrame.timer:Cancel()
        channel.displayFrame.timer = nil
    end

    if channel.durationKey then
        channel.displayFrame.timer = C_Timer.NewTimer(M.config[channel.durationKey], function()
            channel.displayText:SetText("")
            channel.displayFrame:Hide()
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
    previewText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey])
    previewText:SetTextColor(1, 1, 1, 1)

    local display = CreateFrame("Frame", nil, UIParent)
    display:SetSize(channel.width, channel.height)
    display:SetPoint("CENTER", UIParent, "CENTER", M.config[channel.posXKey], M.config[channel.posYKey])
    display:SetFrameStrata("HIGH")

    local displayText = display:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    displayText:SetPoint("TOPLEFT", 12, -12)
    displayText:SetPoint("BOTTOMRIGHT", -12, 12)
    displayText:SetJustifyH(channel.justifyH or "CENTER")
    displayText:SetJustifyV(channel.justifyV or "MIDDLE")
    displayText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey])
    displayText:SetTextColor(1, 1, 1, 1)

    display:Hide()

    channel.previewFrame = anchor
    channel.previewText = previewText
    channel.displayFrame = display
    channel.displayText = displayText
end

local globalChannel = {
    width = 300,
    height = 100,
    posXKey = "posX",
    posYKey = "posY",
    sizeKey = "textSize",
    durationKey = "textDuration",
    previewLabel = "GLOBAL TEXT",
}

local privateChannel = {
    width = 320,
    height = 80,
    posXKey = "privatePosX",
    posYKey = "privatePosY",
    sizeKey = "privateTextSize",
    durationKey = "privateTextDuration",
    previewLabel = "PRIVATE TEXT",
}

local rlNoteChannel = {
    width = 520,
    height = 240,
    posXKey = "rlNotePosX",
    posYKey = "rlNotePosY",
    sizeKey = "rlNoteTextSize",
    durationKey = nil,
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

function M:ShowText(msg)
    if not self.displayFrame or not self.displayText then
        self:CreatePreviewText()
    end

    ShowChannel(globalChannel, msg)
end

function M:HideText()
    HideChannel(globalChannel)
end

function M:ShowPrivateText(msg)
    if not self.privateDisplayFrame or not self.privateDisplayText then
        self:CreatePreviewText()
    end

    ShowChannel(privateChannel, msg)
end

function M:HidePrivateText()
    HideChannel(privateChannel)
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
