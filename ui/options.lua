local addonName, M = ...
local RL_NOTE_PLAYER = "Thiri\195\163ll"

local function CreateSectionHeader(parent, text, offsetY)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 24, offsetY)
    title:SetText(text)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.12)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -24, offsetY - 31)

    return title, divider
end

function M:CreateOptions()
    if self.CreatePreviewText then
        self:CreatePreviewText()
    end

    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    local preview = M.previewFrame
    local text = M.previewText
    local privatePreview = M.privatePreviewFrame
    local privateText = M.privatePreviewText
    local rlNotePreview = M.rlNotePreviewFrame
    local rlNoteText = M.rlNotePreviewText
    local anchorsVisible = false
    local isRLNoteOwner = UnitName("player") == RL_NOTE_PLAYER

    CreateSectionHeader(frame, "Global", -28)

    local toggleBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    toggleBtn:SetSize(180, 30)
    toggleBtn:SetPoint("TOPLEFT", 24, -88)
    toggleBtn:SetText("Afficher les ancres")

    local slider = CreateFrame("Slider", "LamentersHelperSlider", frame, "OptionsSliderTemplate")
    slider:SetSize(220, 20)
    slider:SetPoint("TOPLEFT", toggleBtn, "BOTTOMLEFT", 12, -42)
    slider:SetMinMaxValues(10, 60)
    slider:SetValue(M.config.textSize)
    slider:SetValueStep(1)

    _G[slider:GetName() .. "Low"]:SetText("10")
    _G[slider:GetName() .. "High"]:SetText("60")
    _G[slider:GetName() .. "Text"]:SetText("Taille du texte")

    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)

        if text then
            text:SetFont("Fonts\\FRIZQT__.TTF", value)
        end

        if M.displayText then
            M.displayText:SetFont("Fonts\\FRIZQT__.TTF", value)
        end

        M.config.textSize = value

        if M.SaveConfig then
            M:SaveConfig()
        end
    end)

    slider:Hide()

    local privateSlider = CreateFrame("Slider", "LamentersHelperPrivateSlider", frame, "OptionsSliderTemplate")
    privateSlider:SetSize(220, 20)
    privateSlider:SetPoint("LEFT", slider, "RIGHT", 80, 0)
    privateSlider:SetMinMaxValues(10, 40)
    privateSlider:SetValue(M.config.privateTextSize)
    privateSlider:SetValueStep(1)

    _G[privateSlider:GetName() .. "Low"]:SetText("10")
    _G[privateSlider:GetName() .. "High"]:SetText("40")
    _G[privateSlider:GetName() .. "Text"]:SetText("Taille du private texte")

    privateSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)

        if privateText then
            privateText:SetFont("Fonts\\FRIZQT__.TTF", value)
        end

        if M.privateDisplayText then
            M.privateDisplayText:SetFont("Fonts\\FRIZQT__.TTF", value)
        end

        M.config.privateTextSize = value

        if M.SaveConfig then
            M:SaveConfig()
        end
    end)

    privateSlider:Hide()

    local rlNoteSlider
    if isRLNoteOwner then
        rlNoteSlider = CreateFrame("Slider", "LamentersHelperRLNoteSlider", frame, "OptionsSliderTemplate")
        rlNoteSlider:SetSize(220, 20)
        rlNoteSlider:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 12, -92)
        rlNoteSlider:SetMinMaxValues(10, 32)
        rlNoteSlider:SetValue(M.config.rlNoteTextSize)
        rlNoteSlider:SetValueStep(1)

        _G[rlNoteSlider:GetName() .. "Low"]:SetText("10")
        _G[rlNoteSlider:GetName() .. "High"]:SetText("32")
        _G[rlNoteSlider:GetName() .. "Text"]:SetText("Taille de la note RL")

        rlNoteSlider:SetScript("OnValueChanged", function(self, value)
            value = math.floor(value)

            if rlNoteText then
                rlNoteText:SetFont("Fonts\\FRIZQT__.TTF", value)
            end

            if M.rlNoteDisplayText then
                M.rlNoteDisplayText:SetFont("Fonts\\FRIZQT__.TTF", value)
            end

            M.config.rlNoteTextSize = value

            if M.SaveConfig then
                M:SaveConfig()
            end
        end)

        rlNoteSlider:Hide()
    end

    local debugEncounterCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    if rlNoteSlider then
        debugEncounterCheck:SetPoint("TOPLEFT", rlNoteSlider, "BOTTOMLEFT", -12, -24)
    else
        debugEncounterCheck:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -12, -24)
    end
    debugEncounterCheck:SetChecked(M.config.debugEncounter)

    local debugEncounterLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    debugEncounterLabel:SetPoint("LEFT", debugEncounterCheck, "RIGHT", 4, 0)
    debugEncounterLabel:SetText("Afficher encounterID dans le chat")

    debugEncounterCheck:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked() and true or false

        M.config.debugEncounter = isChecked

        if M.SaveConfig then
            M:SaveConfig()
        end
    end)

    local soundEnabledCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    soundEnabledCheck:SetPoint("TOPLEFT", debugEncounterCheck, "BOTTOMLEFT", 0, -8)
    soundEnabledCheck:SetChecked(M.config.soundEnabled)

    local soundEnabledLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soundEnabledLabel:SetPoint("LEFT", soundEnabledCheck, "RIGHT", 4, 0)
    soundEnabledLabel:SetText("Sons activ\195\169s")

    soundEnabledCheck:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked() and true or false

        M.config.soundEnabled = isChecked

        if M.SaveConfig then
            M:SaveConfig()
        end
    end)

    toggleBtn:SetScript("OnClick", function()
        anchorsVisible = not anchorsVisible
        M.anchorMode = anchorsVisible

        if preview then
            if anchorsVisible then
                preview:Show()
                if privatePreview then
                    privatePreview:Show()
                end
                if rlNotePreview then
                    rlNotePreview:Show()
                end
            else
                preview:Hide()
                if privatePreview then
                    privatePreview:Hide()
                end
                if rlNotePreview then
                    rlNotePreview:Hide()
                end
            end
        end

        if M.RefreshGridVisibility then
            M:RefreshGridVisibility()
        end

        if anchorsVisible then
            slider:Show()
            privateSlider:Show()
            if rlNoteSlider then
                rlNoteSlider:Show()
            end
            toggleBtn:SetText("Cacher les ancres")
        else
            slider:Hide()
            privateSlider:Hide()
            if rlNoteSlider then
                rlNoteSlider:Hide()
            end
            toggleBtn:SetText("Afficher les ancres")
        end
    end)

    return frame
end

function M:CreateImperatorPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    CreateSectionHeader(frame, M.config.gridBossName or "Imperator Averzian", -28)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 24, -68)
    subtitle:SetText("Encounter ID: " .. tostring(M.config.gridEncounterID or 3176))

    local alwaysShowCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    alwaysShowCheck:SetPoint("TOPLEFT", 20, -110)
    alwaysShowCheck:SetChecked(M.config.alwaysShowGrid)

    local alwaysShowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alwaysShowLabel:SetPoint("LEFT", alwaysShowCheck, "RIGHT", 4, 0)
    alwaysShowLabel:SetText("Toujours afficher la grille (test)")

    alwaysShowCheck:SetScript("OnClick", function(self)
        local isChecked = self:GetChecked() and true or false

        M.config.alwaysShowGrid = isChecked

        if M.SaveConfig then
            M:SaveConfig()
        end

        if M.RefreshGridVisibility then
            M:RefreshGridVisibility()
        end
    end)

    local soundInfo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soundInfo:SetPoint("TOPLEFT", alwaysShowCheck, "BOTTOMLEFT", 0, -28)
    soundInfo:SetText("Sons : SOUNDKIT built-in WoW (LibSharedMedia si disponible)")

    return frame
end

function M:CreateVorasiusPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    CreateSectionHeader(frame, "Vorasius — Mythique", -28)

    -- ── Mode Mythique ──────────────────────────────────────────────────────────
    local mythicCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    mythicCheck:SetPoint("TOPLEFT", 20, -72)
    mythicCheck:SetChecked(M.config.vorasiusMythicMode)

    local mythicLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicLabel:SetPoint("LEFT", mythicCheck, "RIGHT", 4, 0)
    mythicLabel:SetText("Mode Mythique  (3 explosions/mur + flaques au sol)")

    mythicCheck:SetScript("OnClick", function(self)
        M.config.vorasiusMythicMode = self:GetChecked() and true or false
        if M.SaveConfig then M:SaveConfig() end
    end)

    -- ── Sélecteur de rôle ─────────────────────────────────────────────────────
    local roleTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    roleTitle:SetPoint("TOPLEFT", 24, -122)
    roleTitle:SetText("Forcer le rôle  (AUTO = détection automatique par spec / rôle de groupe) :")

    local ROLES = {"AUTO", "TANK", "HEALER", "MELEE", "RANGE"}
    local ROLE_LABELS = {
        AUTO   = "AUTO",
        TANK   = "Tank",
        HEALER = "Healer",
        MELEE  = "Mêlée",
        RANGE  = "Distance",
    }
    local roleButtons = {}
    local prevBtn

    local function RefreshRoleButtons()
        local current = M.config.vorasiusRole or "AUTO"
        for _, btn in ipairs(roleButtons) do
            if btn.roleKey == current then
                btn:SetAlpha(1.0)
                btn:LockHighlight()
            else
                btn:SetAlpha(0.55)
                btn:UnlockHighlight()
            end
        end
    end

    for i, roleKey in ipairs(ROLES) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(98, 28)
        btn.roleKey = roleKey
        if i == 1 then
            btn:SetPoint("TOPLEFT", 24, -152)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
        end
        btn:SetText(ROLE_LABELS[roleKey])
        btn:SetScript("OnClick", function()
            M.config.vorasiusRole = roleKey
            if M.SaveConfig then M:SaveConfig() end
            RefreshRoleButtons()
        end)
        roleButtons[i] = btn
        prevBtn = btn
    end

    -- ── Info stratégie ────────────────────────────────────────────────────────
    local infoBox = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoBox:SetPoint("TOPLEFT", 24, -202)
    infoBox:SetWidth(560)
    infoBox:SetJustifyH("LEFT")
    infoBox:SetSpacing(3)
    infoBox:SetText(
        "|cffffcc00Strat guilde|r\n" ..
        "  • MÊLÉE → Mur GAUCHE   |   DISTANCE → Mur DROIT\n" ..
        "  • Mythique : 3 kills d'Ectocloque pour détruire chaque mur\n" ..
        "  • Les Ectocloques laissent une flaque à leur mort (évitez le centre !)\n" ..
        "  • Swap tank après 2 soaks de Shadowclaw Slam (debuff ×2)\n" ..
        "  • Dissipez le ralentissement des joueurs fixés (healers)\n" ..
        "  • Souffle du Vide : regardez le départ du rayon et allez de l'autre côté"
    )

    -- ── Section test des alertes ──────────────────────────────────────────────
    CreateSectionHeader(frame, "Test des alertes", -318)

    local TEST_BTNS = {
        {arg = "slam",    label = "Shadowclaw Slam"},
        {arg = "beam",    label = "Souffle du Vide"},
        {arg = "adds",    label = "Ectocloques"},
        {arg = "wall",    label = "Mur détruit"},
        {arg = "roar",    label = "Grondement"},
        {arg = "blister", label = "Blisterburst"},
        {arg = "smashed", label = "Smashed"},
    }

    local prevTestBtn
    for i, t in ipairs(TEST_BTNS) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(126, 26)
        if col == 0 then
            btn:SetPoint("TOPLEFT", 24, -356 - row * 34)
        else
            btn:SetPoint("LEFT", prevTestBtn, "RIGHT", 6, 0)
        end
        btn:SetText(t.label)
        btn:SetScript("OnClick", function()
            if SlashCmdList and SlashCmdList["LHVORASIUSTEST"] then
                SlashCmdList["LHVORASIUSTEST"](t.arg)
            end
        end)
        prevTestBtn = btn
    end

    -- Refresh initial des boutons de rôle
    frame:SetScript("OnShow", function()
        mythicCheck:SetChecked(M.config.vorasiusMythicMode)
        RefreshRoleButtons()
    end)

    return frame
end

function M:CreateCrownPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    CreateSectionHeader(frame, M.config.crownBossName or "Couronne du cosmos", -28)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT", 24, -68)
    subtitle:SetText("Encounter ID: " .. tostring(M.config.crownEncounterID or 3181))

    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOPLEFT", 24, -118)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    info:SetText("Base du boss prete. On peut maintenant ajouter les mecaniques de Couronne du cosmos sur une structure dediee.")

    return frame
end
