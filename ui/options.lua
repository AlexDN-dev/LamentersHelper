local addonName, M = ...

local R, G, B = 0.78, 0.07, 0.07    -- rouge guilde

local RL_NOTE_PLAYER = "Thiri\195\163ll"

-- ─── Helpers UI ──────────────────────────────────────────────────────────────

local function IsPrivileged()
    return UnitIsGroupLeader("player") or UnitIsRaidOfficer("player") or not IsInGroup()
end

local function SectionHeader(parent, text, offsetY)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 0, offsetY)
    title:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(R, G, B, 0.40)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  title, "BOTTOMLEFT",  0, -6)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT",   0, offsetY - 29)
    return title
end

local function MakeSlider(parent, name, label, minV, maxV, configKey, posPoint, posRelFrame, posRelPoint, offX, offY, onChange)
    local s = CreateFrame("Slider", "LHSlider_" .. name, parent, "OptionsSliderTemplate")
    s:SetSize(200, 20)
    s:SetPoint(posPoint, posRelFrame, posRelPoint, offX, offY)
    s:SetMinMaxValues(minV, maxV)
    s:SetValue(M.config[configKey] or minV)
    s:SetValueStep(1)
    _G[s:GetName() .. "Low"]:SetText(tostring(minV))
    _G[s:GetName() .. "High"]:SetText(tostring(maxV))
    _G[s:GetName() .. "Text"]:SetText(label)
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value)
        M.config[configKey] = value
        if M.SaveConfig then M:SaveConfig() end
        if onChange then onChange(value) end
    end)
    return s
end

local function MakeCheck(parent, label, configKey, posPoint, posRelFrame, posRelPoint, offX, offY, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint(posPoint, posRelFrame, posRelPoint, offX, offY)
    cb:SetChecked(M.config[configKey])
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    lbl:SetText(label)
    lbl:SetTextColor(0.82, 0.82, 0.85)
    -- Recolore le checkmark en rouge guilde
    local ct = cb:GetCheckedTexture()
    if ct then ct:SetVertexColor(R, G, B) end
    cb:SetScript("OnClick", function(self)
        M.config[configKey] = self:GetChecked() and true or false
        if M.SaveConfig then M:SaveConfig() end
        if onChange then onChange(M.config[configKey]) end
    end)
    return cb
end

-- ─── Onglet : Affichage ───────────────────────────────────────────────────────

local function BuildAffichageTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()

    SectionHeader(f, "Position des textes", -8)

    local toggleBtn = M.MakeBtn(f, "Afficher les ancres", 200, 28)
    toggleBtn:SetPoint("TOPLEFT", 0, -42)

    local anchorsVisible = false
    local sliders = {}

    local s1 = MakeSlider(f, "GlobalSize", "Texte global", 10, 60, "textSize",
        "TOPLEFT", toggleBtn, "BOTTOMLEFT", 12, -42,
        function(v)
            if M.previewText    then M.previewText:SetFont("Fonts\\FRIZQT__.TTF", v) end
            if M.displayText    then M.displayText:SetFont("Fonts\\FRIZQT__.TTF", v) end
        end)

    local s2 = MakeSlider(f, "PrivateSize", "Texte privé", 10, 40, "privateTextSize",
        "LEFT", s1, "RIGHT", 60, 0,
        function(v)
            if M.privatePreviewText then M.privatePreviewText:SetFont("Fonts\\FRIZQT__.TTF", v) end
            if M.privateDisplayText then M.privateDisplayText:SetFont("Fonts\\FRIZQT__.TTF", v) end
        end)

    local s3
    if UnitName("player") == RL_NOTE_PLAYER then
        s3 = MakeSlider(f, "RLNoteSize", "Note RL", 10, 32, "rlNoteTextSize",
            "TOPLEFT", s1, "BOTTOMLEFT", 0, -52,
            function(v)
                if M.rlNotePreviewText then M.rlNotePreviewText:SetFont("Fonts\\FRIZQT__.TTF", v) end
                if M.rlNoteDisplayText  then M.rlNoteDisplayText:SetFont("Fonts\\FRIZQT__.TTF", v) end
            end)
    end

    sliders = { s1, s2, s3 }
    for _, s in ipairs(sliders) do if s then s:Hide() end end

    toggleBtn:SetScript("OnClick", function()
        anchorsVisible = not anchorsVisible
        M.anchorMode = anchorsVisible

        if M.previewFrame        then if anchorsVisible then M.previewFrame:Show()        else M.previewFrame:Hide()        end end
        if M.privatePreviewFrame then if anchorsVisible then M.privatePreviewFrame:Show() else M.privatePreviewFrame:Hide() end end
        if M.rlNotePreviewFrame  then if anchorsVisible then M.rlNotePreviewFrame:Show()  else M.rlNotePreviewFrame:Hide()  end end
        if M.RefreshGridVisibility then M:RefreshGridVisibility() end

        for _, s in ipairs(sliders) do
            if s then if anchorsVisible then s:Show() else s:Hide() end end
        end
        toggleBtn:SetText(anchorsVisible and "Cacher les ancres" or "Afficher les ancres")
    end)

    local baseY = s3 and -176 or -124

    SectionHeader(f, "Visuel", baseY)

    local iconsCheck = MakeCheck(f, "Afficher les ic\195\180nes de sort  (discret, sur le texte d'alerte)",
        "showSpellIcons", "TOPLEFT", f, "TOPLEFT", 0, baseY - 34)

    SectionHeader(f, "Développement", baseY - 76)

    local debugCheck = MakeCheck(f, "Afficher l'encounterID dans le chat (debug)",
        "debugEncounter", "TOPLEFT", f, "TOPLEFT", 0, baseY - 110)

    f:SetScript("OnShow", function()
        s1:SetValue(M.config.textSize or 28)
        s2:SetValue(M.config.privateTextSize or 22)
        if s3 then s3:SetValue(M.config.rlNoteTextSize or 18) end
        iconsCheck:SetChecked(M.config.showSpellIcons)
        debugCheck:SetChecked(M.config.debugEncounter)
        anchorsVisible = false
        toggleBtn:SetText("Afficher les ancres")
        for _, s in ipairs(sliders) do if s then s:Hide() end end
    end)

    return f
end

-- ─── Onglet : Sons ────────────────────────────────────────────────────────────

local function BuildSonsTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()

    SectionHeader(f, "Sons", -8)

    local soundCheck = MakeCheck(f, "Sons activés", "soundEnabled",
        "TOPLEFT", f, "TOPLEFT", 0, -44)

    SectionHeader(f, "Tester les sons", -90)

    local SOUND_TESTS = {
        { label = "Global",    type = "global"    },
        { label = "Phase",     type = "phase"     },
        { label = "Interrupt", type = "interrupt" },
        { label = "Soak",      type = "soak"      },
        { label = "Privé",     type = "private"   },
        { label = "Dispel",    type = "dispel"    },
    }

    local prev
    for i, t in ipairs(SOUND_TESTS) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local btn = M.MakeBtn(f, t.label, 130, 28)
        if col == 0 then
            btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -126 - row * 36)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", 8, 0)
        end
        btn:SetScript("OnClick", function()
            if M.PlayAlertSound then M:PlayAlertSound(t.type) end
        end)
        prev = btn
    end

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    note:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -210)
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetText("Sons issus de SharedMedia_Causese (vocaux) — fallback SOUNDKIT si addon absent.")

    f:SetScript("OnShow", function()
        soundCheck:SetChecked(M.config.soundEnabled)
    end)

    return f
end

-- ─── Onglet : Profils ─────────────────────────────────────────────────────────

local function BuildProfilsTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()

    SectionHeader(f, "Sauvegarder un profil", -8)

    local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    nameBox:SetSize(220, 24)
    nameBox:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -44)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(40)

    local namePlaceholder = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    namePlaceholder:SetPoint("LEFT", nameBox, "LEFT", 8, 0)
    namePlaceholder:SetTextColor(0.5, 0.5, 0.5)
    namePlaceholder:SetText("Nom du profil...")

    nameBox:SetScript("OnTextChanged", function(self)
        namePlaceholder:SetShown(self:GetText() == "")
    end)
    nameBox:SetScript("OnEditFocusGained", function() namePlaceholder:Hide() end)
    nameBox:SetScript("OnEditFocusLost",   function(self)
        namePlaceholder:SetShown(self:GetText() == "")
    end)

    local saveBtn = M.MakeBtn(f, "Sauvegarder", 100, 26)
    saveBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    local feedback = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    feedback:SetPoint("LEFT", saveBtn, "RIGHT", 10, 0)
    feedback:SetText("")

    SectionHeader(f, "Profils sauvegardés", -82)

    -- Liste des profils (max 10 affichés)
    local profileRows = {}
    for i = 1, 10 do
        local row = {}
        local yOff = -118 - (i - 1) * 30

        row.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("TOPLEFT", f, "TOPLEFT", 4, yOff)
        row.label:SetWidth(240)

        row.loadBtn = M.MakeBtn(f, "Charger", 70, 22)
        row.loadBtn:SetPoint("LEFT", f, "TOPLEFT", 260, yOff + 1)

        row.delBtn = M.MakeBtn(f, "Suppr", 70, 22)
        row.delBtn:SetPoint("LEFT", row.loadBtn, "RIGHT", 6, 0)
        row.delBtn._txt:SetTextColor(1, 0.28, 0.28)

        row.frame = f   -- back-ref pour rafraîchir
        row.label:Hide()
        row.loadBtn:Hide()
        row.delBtn:Hide()

        profileRows[i] = row
    end

    local emptyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -118)
    emptyLabel:SetTextColor(0.5, 0.5, 0.5)
    emptyLabel:SetText("Aucun profil sauvegardé.")

    local function RefreshProfileList()
        local profiles = M:GetProfiles()
        emptyLabel:SetShown(#profiles == 0)
        for i, row in ipairs(profileRows) do
            local name = profiles[i]
            if name then
                row.label:SetText(name)
                row.label:SetTextColor(0.88, 0.88, 0.90)
                row.label:Show()
                row.loadBtn:Show()
                row.delBtn:Show()
                row.loadBtn:SetScript("OnClick", function()
                    if M:LoadProfile(name) then
                        feedback:SetText("|cff00ff00Profil '" .. name .. "' chargé !|r")
                        C_Timer.After(3, function() feedback:SetText("") end)
                    end
                end)
                row.delBtn:SetScript("OnClick", function()
                    M:DeleteProfile(name)
                    RefreshProfileList()
                end)
            else
                row.label:Hide()
                row.loadBtn:Hide()
                row.delBtn:Hide()
            end
        end
    end

    saveBtn:SetScript("OnClick", function()
        local name = nameBox:GetText():match("^%s*(.-)%s*$")
        if name == "" then
            feedback:SetText("|cffff4444Entrez un nom de profil.|r")
            C_Timer.After(2, function() feedback:SetText("") end)
            return
        end
        if M:SaveProfile(name) then
            feedback:SetText("|cff00ff00Sauvegardé !|r")
            nameBox:SetText("")
            namePlaceholder:Show()
            C_Timer.After(2, function() feedback:SetText("") end)
            RefreshProfileList()
        end
    end)

    f:SetScript("OnShow", RefreshProfileList)

    return f
end

-- ─── Onglet : Rôle ───────────────────────────────────────────────────────────

local function BuildRoleTab(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()

    SectionHeader(f, "Rôle global", -8)

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
    desc:SetText("Forcer le rôle  (AUTO = détection auto par spec / rôle de groupe) :")
    desc:SetTextColor(0.72, 0.72, 0.76)

    local ROLES       = { "AUTO", "TANK", "HEALER", "MELEE", "RANGE" }
    local ROLE_LABELS = { AUTO="AUTO", TANK="Tank", HEALER="Healer", MELEE="Mêlée", RANGE="Distance" }
    local roleButtons = {}
    local prevBtn

    local function RefreshRoleButtons()
        local current = M.config.playerRole or "AUTO"
        for _, btn in ipairs(roleButtons) do
            if btn.roleKey == current then
                btn._bg:SetColorTexture(R, G, B, 0.65)
                btn._txt:SetTextColor(1, 1, 1)
            else
                btn._bg:SetColorTexture(0.11, 0.11, 0.14, 1)
                btn._txt:SetTextColor(0.65, 0.65, 0.68)
            end
        end
    end

    for i, roleKey in ipairs(ROLES) do
        local btn = M.MakeBtn(f, ROLE_LABELS[roleKey], 96, 28)
        btn.roleKey = roleKey
        if i == 1 then btn:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -70)
        else btn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0) end
        btn:SetScript("OnClick", function()
            M.config.playerRole = roleKey
            if M.SaveConfig then M:SaveConfig() end
            RefreshRoleButtons()
        end)
        roleButtons[i] = btn
        prevBtn = btn
    end

    -- Explication des rôles
    SectionHeader(f, "Comportement par rôle", -118)

    local roleInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    roleInfo:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -156)
    roleInfo:SetWidth(560)
    roleInfo:SetJustifyH("LEFT")
    roleInfo:SetSpacing(4)
    roleInfo:SetTextColor(0.68, 0.68, 0.72)
    roleInfo:SetText(
        "|cffcc2222AUTO|r  — Détecté depuis la spécialisation et le rôle de groupe\n" ..
        "|cffcc2222TANK|r  — Alertes de swap, soaks de boss\n" ..
        "|cffcc2222HEALER|r  — Alertes de dispel, soins d'urgence\n" ..
        "|cffcc2222MÊLÉE|r  — Alertes de positionnement mêlée (ex: mur gauche sur Vorasius)\n" ..
        "|cffcc2222DISTANCE|r  — Alertes de positionnement distance (ex: mur droit sur Vorasius)"
    )

    f:SetScript("OnShow", RefreshRoleButtons)

    return f
end

-- ─── Options globales (onglets) ───────────────────────────────────────────────

function M:CreateOptions()
    if self.CreatePreviewText then self:CreatePreviewText() end

    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints(M.content)

    -- Barre d'onglets
    local TAB_DEFS = {
        { key = "Affichage", build = BuildAffichageTab },
        { key = "Sons",      build = BuildSonsTab      },
        { key = "Rôle",      build = BuildRoleTab      },
        { key = "Profils",   build = BuildProfilsTab   },
    }

    local tabBtns   = {}
    local tabFrames = {}
    local prevBtn

    local function SwitchTab(key)
        for _, tb in ipairs(tabBtns) do
            if tb.tabKey == key then
                tb.btxt:SetTextColor(1, 1, 1)
                tb.bbar:SetColorTexture(R, G, B, 1)
                tb.bbg:SetColorTexture(0.11, 0.11, 0.14, 1)
            else
                tb.btxt:SetTextColor(0.48, 0.48, 0.54)
                tb.bbar:SetColorTexture(R, G, B, 0)
                tb.bbg:SetColorTexture(0.08, 0.08, 0.10, 1)
            end
        end
        for k, tf in pairs(tabFrames) do
            if k == key then tf:Show() else tf:Hide() end
        end
    end

    for i, def in ipairs(TAB_DEFS) do
        local btn = CreateFrame("Button", nil, frame)
        btn:SetSize(120, 28)
        btn.tabKey = def.key
        if i == 1 then
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -8)
        else
            btn:SetPoint("LEFT", prevBtn, "RIGHT", 4, 0)
        end

        local bbg = btn:CreateTexture(nil, "BACKGROUND")
        bbg:SetAllPoints(); bbg:SetColorTexture(0.08, 0.08, 0.10, 1)
        btn.bbg = bbg

        local bhl = btn:CreateTexture(nil, "HIGHLIGHT")
        bhl:SetAllPoints(); bhl:SetColorTexture(R, G, B, 0.10)

        local bbar = btn:CreateTexture(nil, "ARTWORK")
        bbar:SetHeight(2)
        bbar:SetPoint("BOTTOMLEFT"); bbar:SetPoint("BOTTOMRIGHT")
        bbar:SetColorTexture(R, G, B, 0)
        btn.bbar = bbar

        local btxt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btxt:SetAllPoints(); btxt:SetJustifyH("CENTER"); btxt:SetJustifyV("MIDDLE")
        btxt:SetText(def.key); btxt:SetTextColor(0.48, 0.48, 0.54)
        btn.btxt = btxt

        btn:SetScript("OnClick", function() SwitchTab(def.key) end)
        tabBtns[i] = btn
        prevBtn = btn

        -- Sous-frame pour le contenu de cet onglet
        local sf = CreateFrame("Frame", nil, frame)
        sf:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, -48)
        sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,   0)
        def.build(sf)              -- construit le contenu à l'intérieur de sf
        tabFrames[def.key] = sf   -- on stocke sf, pas le frame interne
        sf:Hide()
    end

    -- Divider sous les onglets
    local div = frame:CreateTexture(nil, "ARTWORK")
    div:SetColorTexture(1, 1, 1, 0.1)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -42)
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -42)

    frame:SetScript("OnShow", function() SwitchTab("Affichage") end)

    return frame
end

-- ─── Panneau Imperator ────────────────────────────────────────────────────────

function M:CreateImperatorPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints(M.content)

    SectionHeader(frame, M.config.gridBossName or "Imperator Averzian", -28)

    -- Grille
    local alwaysShowCheck = MakeCheck(frame,
        "Toujours afficher la grille  (test hors combat)",
        "alwaysShowGrid", "TOPLEFT", frame, "TOPLEFT", 0, -72,
        function() if M.RefreshGridVisibility then M:RefreshGridVisibility() end end)

    -- ── Rotation de dispel ────────────────────────────────────────────────────
    SectionHeader(frame, "Rotation de dispel — Void Marked", -118)

    local isPriv = IsPrivileged()
    local lockNote = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -154)
    lockNote:SetTextColor(0.6, 0.6, 0.6)
    lockNote:SetText(isPriv and "" or "|cffff4444Réservé au Raid Leader et aux assistants.|r")

    local editBoxes = {}
    local saveRotBtn

    if isPriv then
        local rotation = M.config.imperatorDispelRotation or {}

        local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        info:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -154)
        info:SetTextColor(0.6, 0.6, 0.6)
        info:SetText("Chaque application de Void Marked est assignée dans l'ordre 1→2→3→4→1→...")

        for i = 1, 4 do
            local numLbl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            numLbl:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -176 - (i - 1) * 32)
            numLbl:SetText(tostring(i) .. ".")
            numLbl:SetTextColor(0.72, 0.72, 0.76)

            local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
            eb:SetSize(200, 24)
            eb:SetPoint("LEFT", numLbl, "RIGHT", 8, 0)
            eb:SetAutoFocus(false)
            eb:SetMaxLetters(40)
            eb:SetText(rotation[i] or "")
            editBoxes[i] = eb
        end

        saveRotBtn = M.MakeBtn(frame, "Sauvegarder", 130, 26)
        saveRotBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -312)

        local rotFeedback = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rotFeedback:SetPoint("LEFT", saveRotBtn, "RIGHT", 10, 0)
        rotFeedback:SetText("")

        saveRotBtn:SetScript("OnClick", function()
            local newRot = {}
            for i = 1, 4 do
                local name = editBoxes[i]:GetText():match("^%s*(.-)%s*$")
                newRot[i] = (name ~= "") and name or (M.config.imperatorDispelRotation[i] or "")
            end
            M.config.imperatorDispelRotation = newRot
            if M.SaveConfig then M:SaveConfig() end
            rotFeedback:SetText("|cff00ff00Sauvegardé !|r")
            C_Timer.After(2, function() rotFeedback:SetText("") end)
        end)

        local resetNote = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        resetNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -344)
        resetNote:SetTextColor(0.5, 0.5, 0.5)
        resetNote:SetText("Le compteur de rotation se remet à 0 à chaque nouveau pull.")
    end

    frame:SetScript("OnShow", function()
        alwaysShowCheck:SetChecked(M.config.alwaysShowGrid)
        if isPriv ~= IsPrivileged() then
            -- Rafraîchit si le statut RL/assist a changé
            lockNote:SetText(IsPrivileged() and "" or "|cffff4444Réservé au Raid Leader et aux assistants.|r")
        end
        if editBoxes[1] then
            local rot = M.config.imperatorDispelRotation or {}
            for i = 1, 4 do
                editBoxes[i]:SetText(rot[i] or "")
            end
        end
    end)

    return frame
end

-- ─── Panneau Vorasius ─────────────────────────────────────────────────────────

function M:CreateVorasiusPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints(M.content)

    SectionHeader(frame, "Vorasius — Mythique", -28)

    local mythicCheck = MakeCheck(frame,
        "Mode Mythique  (3 explosions/mur + flaques au sol)",
        "vorasiusMythicMode", "TOPLEFT", frame, "TOPLEFT", 0, -72)

    -- Info strat
    local infoBox = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -118)
    infoBox:SetWidth(560)
    infoBox:SetJustifyH("LEFT")
    infoBox:SetSpacing(3)
    infoBox:SetTextColor(0.68, 0.68, 0.72)
    infoBox:SetText(
        "|cffcc2222Strat guilde|r\n" ..
        "  • MÊLÉE → Mur GAUCHE   |   DISTANCE → Mur DROIT\n" ..
        "  • Mythique : 3 kills d'Ectocloque par mur\n" ..
        "  • Swap tank après 2 soaks de Shadowclaw Slam\n" ..
        "  • Healers : dissipez le ralentissement des fixés\n" ..
        "  • Souffle du Vide : allez du côté opposé au rayon"
    )

    -- Boutons de test
    SectionHeader(frame, "Test des alertes", -230)

    local TEST_BTNS = {
        { arg = "slam",    label = "Shadowclaw Slam" },
        { arg = "beam",    label = "Souffle du Vide" },
        { arg = "adds",    label = "Ectocloques"     },
        { arg = "wall",    label = "Mur détruit"     },
        { arg = "roar",    label = "Grondement"      },
        { arg = "blister", label = "Blisterburst"    },
        { arg = "smashed", label = "Smashed"         },
    }

    local prevTest
    for i, t in ipairs(TEST_BTNS) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local btn = M.MakeBtn(frame, t.label, 124, 26)
        if col == 0 then btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -268 - row * 34)
        else btn:SetPoint("LEFT", prevTest, "RIGHT", 6, 0) end
        btn:SetScript("OnClick", function()
            if SlashCmdList and SlashCmdList["LHVORASIUSTEST"] then
                SlashCmdList["LHVORASIUSTEST"](t.arg)
            end
        end)
        prevTest = btn
    end

    frame:SetScript("OnShow", function()
        mythicCheck:SetChecked(M.config.vorasiusMythicMode)
    end)

    return frame
end

-- ─── Panneau Chimaerus ────────────────────────────────────────────────────────

function M:CreateChimaerUsPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints(M.content)

    local isPriv = IsPrivileged()

    SectionHeader(frame, "Chimaerus the Undreamt God — Mythique", -28)

    local lockNote = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockNote:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -64)
    lockNote:SetTextColor(0.6, 0.6, 0.6)
    lockNote:SetText(isPriv and "" or "|cffff4444Réservé au Raid Leader et aux assistants.|r")

    if not isPriv then return frame end

    -- ── ScrollFrame ───────────────────────────────────────────────────────────
    local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0,   -64)
    sf:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28,   8)

    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(580, 600)
    sf:SetScrollChild(c)

    local y = 0  -- curseur Y dans c

    -- ── Rotation de dispel Consuming Miasma ──────────────────────────────────
    SectionHeader(c, "Rotation de dispel — Consuming Miasma", y)
    y = y - 38

    local miasmaInfo = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    miasmaInfo:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    miasmaInfo:SetTextColor(0.6, 0.6, 0.6)
    miasmaInfo:SetText("Ordre de dispel du debuff Consuming Miasma (1→2→3→4→1→...)")
    y = y - 22

    local miasmaBoxes = {}
    for i = 1, 4 do
        local numLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        numLbl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
        numLbl:SetText(tostring(i) .. ".")
        numLbl:SetTextColor(0.72, 0.72, 0.76)

        local eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        eb:SetSize(200, 24)
        eb:SetPoint("LEFT", numLbl, "RIGHT", 8, 0)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(40)
        miasmaBoxes[i] = eb
        y = y - 32
    end

    local saveMiasmaBtn = M.MakeBtn(c, "Sauvegarder", 130, 26)
    saveMiasmaBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    local miasmaFeedback = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    miasmaFeedback:SetPoint("LEFT", saveMiasmaBtn, "RIGHT", 10, 0)
    miasmaFeedback:SetText("")
    y = y - 40

    saveMiasmaBtn:SetScript("OnClick", function()
        local newRot = {}
        for i = 1, 4 do
            local name = miasmaBoxes[i]:GetText():match("^%s*(.-)%s*$")
            newRot[i] = name ~= "" and name or ""
        end
        M.config.chimerusMiasmaRotation = newRot
        if M.SaveConfig then M:SaveConfig() end
        miasmaFeedback:SetText("|cff00ff00Sauvegardé !|r")
        C_Timer.After(2, function() miasmaFeedback:SetText("") end)
    end)

    -- ── Groupes de soak — auto-détection ─────────────────────────────────────
    SectionHeader(c, "Groupes de soak — Alndust Upheaval", y)
    y = y - 38

    local soakInfo = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    soakInfo:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    soakInfo:SetTextColor(0.6, 0.6, 0.6)
    soakInfo:SetText("Détection automatique depuis les groupes raid.\nGroupe A = groupes 1 & 3   |   Groupe B = groupes 2 & 4")
    y = y - 44

    local soakStatus = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    soakStatus:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    soakStatus:SetWidth(560)
    soakStatus:SetJustifyH("LEFT")
    soakStatus:SetSpacing(2)
    soakStatus:SetText("|cff888888Rejoignez un raid pour voir les groupes.|r")
    y = y - 52

    local refreshBtn = M.MakeBtn(c, "Actualiser", 130, 26)
    refreshBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    y = y - 44

    local function RefreshSoakGroups()
        local numMembers = GetNumGroupMembers()
        if numMembers == 0 then
            soakStatus:SetText("|cff888888Pas en raid.|r")
            return
        end
        local gA, gB = {}, {}
        for i = 1, numMembers do
            local name, _, group = GetRaidRosterInfo(i)
            if name then
                if group == 1 or group == 3 then gA[#gA+1] = name
                elseif group == 2 or group == 4 then gB[#gB+1] = name end
            end
        end
        local strA = #gA > 0 and table.concat(gA, ", ") or "—"
        local strB = #gB > 0 and table.concat(gB, ", ") or "—"
        soakStatus:SetText(
            "|cffcc2222Groupe A (1&3) :|r  " .. strA .. "\n" ..
            "|cffcc2222Groupe B (2&4) :|r  " .. strB
        )
    end

    refreshBtn:SetScript("OnClick", RefreshSoakGroups)

    -- ── Rift Madness — info ───────────────────────────────────────────────────
    SectionHeader(c, "Rift Madness", y)
    y = y - 38

    local madnessInfo = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    madnessInfo:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)
    madnessInfo:SetTextColor(0.6, 0.6, 0.6)
    madnessInfo:SetWidth(560)
    madnessInfo:SetJustifyH("LEFT")
    madnessInfo:SetText(
        "Détection automatique.\n" ..
        "La personne ciblée reçoit une alerte privée."
    )
    y = y - 44

    -- ── Test des alertes ─────────────────────────────────────────────────────
    SectionHeader(c, "Test des alertes", y)
    y = y - 38

    local TEST_BTNS = {
        { arg = "upheaval",  label = "Alndust Upheaval" },
        { arg = "miasma",    label = "Consuming Miasma" },
        { arg = "madness",   label = "Rift Madness"     },
        { arg = "rending",   label = "Rending Tear"     },
        { arg = "fearsome",  label = "Fearsome Cry"     },
        { arg = "consume",   label = "Consume"          },
        { arg = "devastation", label = "Corrupted Dev." },
        { arg = "phlegm",    label = "Caustic Phlegm"   },
        { arg = "dissonance",label = "Dissonance"       },
    }

    local prevTest
    for i, t in ipairs(TEST_BTNS) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local btn = M.MakeBtn(c, t.label, 168, 26)
        if col == 0 then
            btn:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y - row * 34)
        else
            btn:SetPoint("LEFT", prevTest, "RIGHT", 6, 0)
        end
        btn:SetScript("OnClick", function()
            if SlashCmdList and SlashCmdList["LHCHIMAERTEST"] then
                SlashCmdList["LHCHIMAERTEST"](t.arg)
            end
        end)
        prevTest = btn
    end
    local testRows = math.ceil(#TEST_BTNS / 3)
    y = y - testRows * 34 - 10

    -- Hauteur dynamique du scroll content
    c:SetHeight(math.abs(y) + 40)

    frame:SetScript("OnShow", function()
        local rot = M.config.chimerusMiasmaRotation or {}
        for i = 1, 4 do miasmaBoxes[i]:SetText(rot[i] or "") end
        RefreshSoakGroups()
    end)

    return frame
end

-- ─── Panneau Couronne ─────────────────────────────────────────────────────────

function M:CreateCrownPanel()
    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints(M.content)
    SectionHeader(frame, M.config.crownBossName or "Couronne du cosmos", -28)
    local info = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -72)
    info:SetWidth(520)
    info:SetJustifyH("LEFT")
    info:SetText("Les alertes de la Couronne du cosmos sont actives.\nConfiguration dédiée à venir.")
    return frame
end
