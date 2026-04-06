local addonName, M = ...
local RL_NOTE_PLAYER = "Thiri\195\163ll"
local FONT_FLAGS = "OUTLINE"
local MIN_VISIBLE_DURATION = 0.75

-- Boss en cours d'édition dans le panneau d'options (clé ou "default")
M.anchorEditingBoss = "default"

-- Couleur du texte selon le type d'alerte
local ALERT_COLORS = {
    interrupt = {1,    0.27, 0.27},
    soak      = {1,    0.9,  0.1 },
    phase     = {0.3,  0.85, 1   },
    private   = {1,    0.65, 0.2 },
    global    = {1,    1,    1   },
    dispel    = {1,    0.1,  1   },
}

local POP_SCALE = {
    dispel = 1.5,
}

local POP_DURATION   = 0.15
local FLASH_DURATION = 0.4
local FLASH_ALPHA    = 0.35

-- ─── Helpers position ────────────────────────────────────────────────────────

-- Position pour le gameplay (boss actif en combat)
local function GetActivePos(key)
    local bossKey = M.activeBossKey
    if bossKey
       and M.config.bossAnchorOverrides
       and M.config.bossAnchorOverrides[bossKey]
       and M.config.bossAnchorOverrides[bossKey][key] ~= nil then
        return M.config.bossAnchorOverrides[bossKey][key]
    end
    return M.config[key] or 0
end

-- Position pour l'édition (boss sélectionné dans le dropdown)
local function GetEditingPos(key)
    local bossKey = M.anchorEditingBoss
    if bossKey and bossKey ~= "default"
       and M.config.bossAnchorOverrides
       and M.config.bossAnchorOverrides[bossKey]
       and M.config.bossAnchorOverrides[bossKey][key] ~= nil then
        return M.config.bossAnchorOverrides[bossKey][key]
    end
    return M.config[key] or 0
end

-- ─── Animations ──────────────────────────────────────────────────────────────

local function PlayPop(frame, maxScale)
    maxScale = maxScale or 1.2
    if frame.popTimer then frame.popTimer:Cancel(); frame.popTimer = nil end
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

local function PlayFlash(flashTex, r, g, b)
    if flashTex.flashTimer then flashTex.flashTimer:Cancel(); flashTex.flashTimer = nil end
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

-- ─── Mise à jour des frames ───────────────────────────────────────────────────

-- Repositionne l'ancre (preview) selon le boss en cours d'ÉDITION
local function UpdateAnchorPos(channel)
    if not channel.previewFrame then return end
    local x = GetEditingPos(channel.posXKey)
    local y = GetEditingPos(channel.posYKey)
    channel.previewFrame:ClearAllPoints()
    channel.previewFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    -- Mise à jour du label de coordonnées dans l'ancre
    if channel.coordsText then
        channel.coordsText:SetText(string.format("X: %d   Y: %d", x, y))
    end
    -- Mise à jour du label boss dans l'ancre
    if channel.bossLabel then
        local bossKey = M.anchorEditingBoss
        channel.bossLabel:SetText((bossKey and bossKey ~= "default") and bossKey or "")
    end
end

-- Repositionne le display frame selon le boss ACTIF en combat
local function UpdateDisplayPos(channel)
    if not channel.displayFrame then return end
    local x = GetActivePos(channel.posXKey)
    local y = GetActivePos(channel.posYKey)
    channel.displayFrame:ClearAllPoints()
    channel.displayFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function UpdateChannelSize(channel)
    local size = M.config[channel.sizeKey]
    if channel.previewText  then channel.previewText:SetFont("Fonts\\FRIZQT__.TTF",  size, FONT_FLAGS) end
    if channel.displayText  then channel.displayText:SetFont("Fonts\\FRIZQT__.TTF",  size, FONT_FLAGS) end
end

local function HideChannel(channel)
    if not channel.displayFrame or not channel.displayText then return end
    if channel.displayFrame.timer then channel.displayFrame.timer:Cancel(); channel.displayFrame.timer = nil end
    if channel.displayFrame.popTimer then channel.displayFrame.popTimer:Cancel(); channel.displayFrame.popTimer = nil end
    channel.displayFrame:SetScale(1.0)
    if channel.flashTex then
        if channel.flashTex.flashTimer then channel.flashTex.flashTimer:Cancel(); channel.flashTex.flashTimer = nil end
        channel.flashTex:SetColorTexture(0, 0, 0, 0)
    end
    channel.displayText:SetText("")
    channel.displayFrame:SetAlpha(1)
    channel.displayFrame:Hide()
end

local function ShowChannel(channel, msg, soundType, spellID)
    if not channel.displayFrame or not channel.displayText then return end

    UpdateDisplayPos(channel)
    UpdateChannelSize(channel)

    local prefix = ""
    if M.config and M.config.showSpellIcons and spellID then
        local tex
        if C_Spell and C_Spell.GetSpellTexture then
            tex = C_Spell.GetSpellTexture(spellID)
        end
        if not tex and C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            tex = info and info.iconID
        end
        if tex then
            local sz = math.max(M.config[channel.sizeKey] or 24, 16)
            prefix = "|T" .. tex .. ":" .. sz .. ":" .. sz .. "|t  "
        end
    end

    local c = ALERT_COLORS[soundType] or ALERT_COLORS["global"]
    channel.displayText:SetTextColor(c[1], c[2], c[3], 1)
    channel.displayText:SetText(prefix .. msg)
    channel.displayFrame:SetAlpha(0)
    channel.displayFrame:Show()
    UIFrameFadeIn(channel.displayFrame, 0.05, 0, 1)

    if channel.durationKey then
        PlayPop(channel.displayFrame, POP_SCALE[soundType])
        if channel.flashTex and soundType and soundType ~= "global" then
            PlayFlash(channel.flashTex, c[1], c[2], c[3])
        end
    end

    if channel.displayFrame.timer then channel.displayFrame.timer:Cancel(); channel.displayFrame.timer = nil end

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

-- ─── Création de l'ancre (style ElvUI mover) ─────────────────────────────────

local function CreateTextChannel(channel)
    if channel.previewFrame and channel.displayFrame then
        UpdateAnchorPos(channel)
        UpdateChannelSize(channel)
        return
    end

    local initX = GetEditingPos(channel.posXKey)
    local initY = GetEditingPos(channel.posYKey)
    local r, g, b = unpack(channel.labelColor)

    -- ── Ancre (draggable, visible en mode édition) ───────────────────────────
    local anchor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    anchor:SetSize(channel.width, channel.height)
    anchor:SetPoint("CENTER", UIParent, "CENTER", initX, initY)
    anchor:SetFrameStrata("HIGH")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:EnableMouse(true)
    anchor:RegisterForDrag("LeftButton")

    -- Fond semi-transparent + bordure colorée (style ElvUI)
    anchor:SetBackdrop({
        bgFile   = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/ChatFrame/ChatFrameBackground",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    anchor:SetBackdropColor(0.04, 0.04, 0.08, 0.88)
    anchor:SetBackdropBorderColor(r, g, b, 0.75)

    -- Barre accent colorée à gauche
    local leftBar = anchor:CreateTexture(nil, "ARTWORK")
    leftBar:SetWidth(4)
    leftBar:SetPoint("TOPLEFT",    anchor, "TOPLEFT",    0, 0)
    leftBar:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
    leftBar:SetColorTexture(r, g, b, 1)

    -- Nom du canal (en haut à gauche)
    local nameLbl = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLbl:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, -9)
    nameLbl:SetText(channel.labelText)
    nameLbl:SetTextColor(r, g, b, 1)

    -- Boss édité (en haut à droite, affiché si != défaut)
    local bossLbl = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bossLbl:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -8, -9)
    bossLbl:SetJustifyH("RIGHT")
    bossLbl:SetTextColor(0.60, 0.60, 0.65)
    bossLbl:SetText("")
    channel.bossLabel = bossLbl

    -- Coordonnées (en bas à gauche)
    local coordsLbl = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    coordsLbl:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 12, 8)
    coordsLbl:SetTextColor(0.58, 0.58, 0.63)
    coordsLbl:SetText(string.format("X: %d   Y: %d", initX, initY))
    channel.coordsText = coordsLbl

    -- Texte de preview centré
    local previewText = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    previewText:SetPoint("TOPLEFT",     12, -30)
    previewText:SetPoint("BOTTOMRIGHT", -12, 24)
    previewText:SetJustifyH(channel.justifyH or "CENTER")
    previewText:SetJustifyV(channel.justifyV or "MIDDLE")
    previewText:SetText(channel.previewLabel)
    previewText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey], FONT_FLAGS)
    previewText:SetTextColor(r, g, b, 0.35)
    previewText:SetShadowOffset(1, -1)
    previewText:SetShadowColor(0, 0, 0, 0.85)

    anchor:SetScript("OnDragStart", anchor.StartMoving)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = GetCenterOffsets(self,
            GetEditingPos(channel.posXKey),
            GetEditingPos(channel.posYKey))

        -- Sauvegarde dans le bon contexte boss
        local editKey = M.anchorEditingBoss
        if editKey and editKey ~= "default" then
            if not M.config.bossAnchorOverrides then
                M.config.bossAnchorOverrides = {}
            end
            if not M.config.bossAnchorOverrides[editKey] then
                M.config.bossAnchorOverrides[editKey] = {}
            end
            M.config.bossAnchorOverrides[editKey][channel.posXKey] = x
            M.config.bossAnchorOverrides[editKey][channel.posYKey] = y
        else
            M.config[channel.posXKey] = x
            M.config[channel.posYKey] = y
        end

        if M.SaveConfig then M:SaveConfig() end

        -- Mettre à jour les coords affichées
        coordsLbl:SetText(string.format("X: %d   Y: %d", x, y))

        -- Repositionner le display frame (gameplay)
        UpdateDisplayPos(channel)
    end)

    anchor:Hide()

    -- ── Display frame (alertes en combat) ────────────────────────────────────
    local display = CreateFrame("Frame", nil, UIParent)
    display:SetSize(channel.width, channel.height)
    display:SetPoint("CENTER", UIParent, "CENTER", GetActivePos(channel.posXKey), GetActivePos(channel.posYKey))
    display:SetFrameStrata("HIGH")
    display:EnableMouse(false)

    local displayText = display:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    displayText:SetPoint("TOPLEFT",     12, -12)
    displayText:SetPoint("BOTTOMRIGHT", -12, 12)
    displayText:SetJustifyH(channel.justifyH or "CENTER")
    displayText:SetJustifyV(channel.justifyV or "MIDDLE")
    displayText:SetFont("Fonts\\FRIZQT__.TTF", M.config[channel.sizeKey], FONT_FLAGS)
    displayText:SetTextColor(1, 1, 1, 1)
    displayText:SetShadowOffset(1, -1)
    displayText:SetShadowColor(0, 0, 0, 0.85)

    if channel.durationKey then
        local flashTex = display:CreateTexture(nil, "BACKGROUND")
        flashTex:SetAllPoints()
        flashTex:SetColorTexture(0, 0, 0, 0)
        channel.flashTex = flashTex
    end

    display:Hide()

    channel.previewFrame = anchor
    channel.previewText  = previewText
    channel.displayFrame = display
    channel.displayText  = displayText
end

-- ─── Descripteurs des canaux ─────────────────────────────────────────────────

local globalChannel = {
    width        = 950,
    height       = 160,
    posXKey      = "posX",
    posYKey      = "posY",
    sizeKey      = "textSize",
    durationKey  = "textDuration",
    defaultDuration = 4,
    previewLabel = "GLOBAL TEXT",
    labelText    = "TEXTE GLOBAL",
    labelColor   = {1, 1, 1},
    defaultPosX  = 0,
    defaultPosY  = 0,
}

local privateChannel = {
    width        = 750,
    height       = 120,
    posXKey      = "privatePosX",
    posYKey      = "privatePosY",
    sizeKey      = "privateTextSize",
    durationKey  = "privateTextDuration",
    defaultDuration = 5,
    previewLabel = "PRIVATE TEXT",
    labelText    = "TEXTE PRIVÉ",
    labelColor   = {1, 0.65, 0.2},
    defaultPosX  = 0,
    defaultPosY  = -90,
}

local rlNoteChannel = {
    width        = 520,
    height       = 240,
    posXKey      = "rlNotePosX",
    posYKey      = "rlNotePosY",
    sizeKey      = "rlNoteTextSize",
    durationKey  = nil,
    persistent   = true,
    previewLabel = "RL NOTE",
    labelText    = "NOTE RL",
    labelColor   = {0.3, 0.85, 1},
    justifyH     = "LEFT",
    justifyV     = "TOP",
    defaultPosX  = 320,
    defaultPosY  = 120,
}

-- Export des canaux pour options.lua
M.channels = {
    global  = globalChannel,
    private = privateChannel,
    rlNote  = rlNoteChannel,
}

-- ─── API publique ─────────────────────────────────────────────────────────────

local function IsRLNoteOwner()
    return UnitName("player") == RL_NOTE_PLAYER
end

function M:CreatePreviewText()
    CreateTextChannel(globalChannel)
    CreateTextChannel(privateChannel)
    if IsRLNoteOwner() then
        CreateTextChannel(rlNoteChannel)
    end

    -- Compatibilité accès direct (anciennes refs)
    self.previewFrame  = globalChannel.previewFrame
    self.previewText   = globalChannel.previewText
    self.displayFrame  = globalChannel.displayFrame
    self.displayText   = globalChannel.displayText

    self.privatePreviewFrame = privateChannel.previewFrame
    self.privatePreviewText  = privateChannel.previewText
    self.privateDisplayFrame = privateChannel.displayFrame
    self.privateDisplayText  = privateChannel.displayText

    self.rlNotePreviewFrame  = rlNoteChannel.previewFrame
    self.rlNotePreviewText   = rlNoteChannel.previewText
    self.rlNoteDisplayFrame  = rlNoteChannel.displayFrame
    self.rlNoteDisplayText   = rlNoteChannel.displayText
end

-- Repositionne toutes les ancres visibles sur le boss sélectionné (appelé par le dropdown)
function M:RefreshAnchorPositions()
    UpdateAnchorPos(globalChannel)
    UpdateAnchorPos(privateChannel)
    if IsRLNoteOwner() then UpdateAnchorPos(rlNoteChannel) end
end

-- Reset la position d'un canal pour un boss donné (ou le défaut global)
-- channelKey : "global" | "private" | "rlNote"
-- bossKey    : "default" ou clé boss
function M:ResetChannelPos(channelKey, bossKey)
    local ch = M.channels[channelKey]
    if not ch then return end

    if bossKey and bossKey ~= "default" then
        -- Supprime l'override pour ce boss
        if M.config.bossAnchorOverrides and M.config.bossAnchorOverrides[bossKey] then
            local ov = M.config.bossAnchorOverrides[bossKey]
            ov[ch.posXKey] = nil
            ov[ch.posYKey] = nil
        end
    else
        -- Remet aux valeurs par défaut globales
        M.config[ch.posXKey] = ch.defaultPosX
        M.config[ch.posYKey] = ch.defaultPosY
    end

    if M.SaveConfig then M:SaveConfig() end
    UpdateAnchorPos(ch)
    UpdateDisplayPos(ch)
end

function M:ShowText(msg, soundType, spellID)
    if not self.displayFrame or not self.displayText then self:CreatePreviewText() end
    ShowChannel(globalChannel, msg, soundType, spellID)
end

function M:HideText()
    HideChannel(globalChannel)
end

function M:ShowPrivateText(msg, spellID)
    if not self.privateDisplayFrame or not self.privateDisplayText then self:CreatePreviewText() end
    ShowChannel(privateChannel, msg, "private", spellID)
end

function M:HidePrivateText()
    HideChannel(privateChannel)
end

function M:ShowDispelText(msg, spellID)
    if not self.privateDisplayFrame or not self.privateDisplayText then self:CreatePreviewText() end
    local size = M.config and M.config[privateChannel.sizeKey] or 28
    privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, "THICKOUTLINE")
    ShowChannel(privateChannel, msg, "dispel", spellID)
    local duration = (M.config and M.config[privateChannel.durationKey]) or privateChannel.defaultDuration or 5
    C_Timer.After(duration + 0.1, function()
        privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
    end)
end

function M:HideDispelText()
    HideChannel(privateChannel)
    local size = M.config and M.config[privateChannel.sizeKey] or 28
    privateChannel.displayText:SetFont("Fonts\\FRIZQT__.TTF", size, FONT_FLAGS)
end

function M:ToggleTextAnchors()
    if not self.previewFrame or not self.privatePreviewFrame then return end
    local shouldShow = not self.previewFrame:IsShown()
    if shouldShow then
        self.previewFrame:Show()
        self.privatePreviewFrame:Show()
        if IsRLNoteOwner() and self.rlNotePreviewFrame then self.rlNotePreviewFrame:Show() end
    else
        self.previewFrame:Hide()
        self.privatePreviewFrame:Hide()
        if self.rlNotePreviewFrame then self.rlNotePreviewFrame:Hide() end
    end
end

function M:ShowRLNote(msg)
    if not IsRLNoteOwner() then return end
    if not self.rlNoteDisplayFrame or not self.rlNoteDisplayText then self:CreatePreviewText() end
    ShowChannel(rlNoteChannel, msg)
end

function M:HideRLNote()
    HideChannel(rlNoteChannel)
end
