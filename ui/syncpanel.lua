local addonName, M = ...

function M:CreateSyncPanel()
    local CURRENT_VERSION = GetAddOnMetadata(addonName, "Version") or "0.1"

    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    -- ─── En-tête ─────────────────────────────────────────────────────────────
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 24, -28)
    title:SetText("Vérification de l'addon")

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.12)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -67)

    local versionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionLabel:SetPoint("TOPLEFT", 24, -82)
    versionLabel:SetText("|cffaaaaaa Version de votre addon :|r  |cffffff00" .. CURRENT_VERSION .. "|r")

    -- ─── Bouton de vérification ───────────────────────────────────────────────
    local checkBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    checkBtn:SetSize(200, 30)
    checkBtn:SetPoint("TOPLEFT", 24, -112)
    checkBtn:SetText("Lancer la verification")

    local statusMsg = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusMsg:SetPoint("LEFT", checkBtn, "RIGHT", 12, 0)
    statusMsg:SetText("")

    -- ─── Compteur ────────────────────────────────────────────────────────────
    local counter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    counter:SetPoint("TOPLEFT", 24, -152)
    counter:SetText("")

    -- ─── Zone de résultats (scroll) ───────────────────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 24, -176)
    scrollFrame:SetPoint("BOTTOMRIGHT", -40, 16)

    local resultContent = CreateFrame("Frame", nil, scrollFrame)
    resultContent:SetSize(520, 20)
    scrollFrame:SetScrollChild(resultContent)

    local emptyLabel = resultContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyLabel:SetPoint("TOPLEFT", 0, 0)
    emptyLabel:SetTextColor(0.5, 0.5, 0.5)
    emptyLabel:SetText("Cliquez sur 'Lancer la verification' pour commencer.")

    local rows = {}

    -- ─── Rafraîchissement de l'UI ─────────────────────────────────────────────
    local function Refresh()
        for _, r in ipairs(rows) do r:Hide() end

        local results = M.syncResults or {}
        local sorted  = {}
        for name, data in pairs(results) do
            table.insert(sorted, { name = name, data = data })
        end

        if #sorted == 0 then
            emptyLabel:Show()
            counter:SetText("")
            return
        end
        emptyLabel:Hide()

        -- Tri : ok → outdated → missing, puis par nom
        local order = { ok = 1, outdated = 2, missing = 3 }
        table.sort(sorted, function(a, b)
            local oa = order[a.data.status] or 4
            local ob = order[b.data.status] or 4
            if oa ~= ob then return oa < ob end
            return a.name < b.name
        end)

        -- Compteur ok/total
        local okCount = 0
        for _, e in ipairs(sorted) do
            if e.data.status == "ok" then okCount = okCount + 1 end
        end
        counter:SetText(string.format("|cffaaaaaa%d / %d membres ont l'addon a jour|r", okCount, #sorted))

        -- Lignes
        for i, entry in ipairs(sorted) do
            if not rows[i] then
                rows[i] = resultContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            end
            rows[i]:ClearAllPoints()
            rows[i]:SetPoint("TOPLEFT", 0, -(i - 1) * 22)

            local icon, color, suffix
            if entry.data.status == "ok" then
                icon   = "v"
                color  = "|cff00ff00"
                suffix = "  v" .. (entry.data.version or "?")
            elseif entry.data.status == "outdated" then
                icon   = "!"
                color  = "|cffffff00"
                suffix = "  v" .. (entry.data.version or "?") .. "  (obsolete)"
            else
                icon   = "x"
                color  = "|cffff4444"
                suffix = "  addon non installe"
            end

            rows[i]:SetText(color .. "[" .. icon .. "]|r  " .. entry.name .. "|cffaaaaaa" .. suffix .. "|r")
            rows[i]:Show()
        end

        resultContent:SetHeight(math.max(#sorted * 22, 20))
    end

    M.OnSyncUpdate = Refresh

    -- ─── Clic sur le bouton ───────────────────────────────────────────────────
    checkBtn:SetScript("OnClick", function()
        local ok, err = M:StartVersionCheck()
        if not ok then
            if err == "not_privileged" then
                statusMsg:SetText("|cffff4444Reservé au Raid Leader et aux assistants|r")
            elseif err == "not_in_group" then
                statusMsg:SetText("|cffff4444Vous n'etes pas dans un groupe|r")
            end
        else
            statusMsg:SetText("|cffaaaaaa Verification en cours (10s)...|r")
            C_Timer.After(10, function()
                statusMsg:SetText("")
            end)
        end
    end)

    -- ─── Refresh à l'ouverture ────────────────────────────────────────────────
    frame:SetScript("OnShow", Refresh)

    return frame
end
