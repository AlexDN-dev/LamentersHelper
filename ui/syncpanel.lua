local addonName, M = ...

function M:CreateSyncPanel()
    local CURRENT_VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version"))
                          or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
                          or "0.1"

    local frame = CreateFrame("Frame", nil, M.content)
    frame:SetAllPoints()

    -- ─── En-tête ─────────────────────────────────────────────────────────────
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 24, -28)
    title:SetText("Verification de l'addon")
    title:SetTextColor(1, 1, 1)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.78, 0.07, 0.07, 0.40)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -67)

    local versionLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    versionLabel:SetPoint("TOPLEFT", 24, -82)
    versionLabel:SetText("|cff888888 Votre version :|r  |cffdddddd" .. CURRENT_VERSION .. "|r")

    -- ─── Bouton ───────────────────────────────────────────────────────────────
    local checkBtn = M.MakeBtn(frame, "Lancer la verification", 190, 28)
    checkBtn:SetPoint("TOPLEFT", 24, -112)

    local statusMsg = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusMsg:SetPoint("LEFT", checkBtn, "RIGHT", 12, 0)
    statusMsg:SetText("")

    -- ─── Compteur ─────────────────────────────────────────────────────────────
    local counter = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    counter:SetPoint("TOPLEFT", 24, -150)
    counter:SetText("")

    -- ─── ScrollFrame ──────────────────────────────────────────────────────────
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     24,  -172)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(scrollFrame:GetWidth() or 560)
    scrollFrame:SetScrollChild(content)

    -- ─── Lignes de résultats ──────────────────────────────────────────────────
    local rows = {}
    local ROW_HEIGHT = 20

    for i = 1, 40 do
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        fs:SetText("")
        fs:Hide()
        rows[i] = fs
    end

    -- ─── Rafraîchissement ─────────────────────────────────────────────────────
    local function Refresh()
        for _, r in ipairs(rows) do
            r:SetText("")
            r:Hide()
        end

        local results = M.syncResults or {}
        local sorted  = {}
        for name, data in pairs(results) do
            table.insert(sorted, { name = name, data = data })
        end

        if #sorted == 0 then
            counter:SetText("|cffaaaaaa Cliquez sur 'Lancer la verification' pour commencer.|r")
            content:SetHeight(20)
            return
        end

        local order = { ok = 1, outdated = 2, missing = 3 }
        table.sort(sorted, function(a, b)
            local oa = order[a.data.status] or 4
            local ob = order[b.data.status] or 4
            if oa ~= ob then return oa < ob end
            return a.name < b.name
        end)

        local okCount = 0
        for _, e in ipairs(sorted) do
            if e.data.status == "ok" then okCount = okCount + 1 end
        end
        counter:SetText(string.format(
            "|cffaaaaaa%d / %d membres ont l'addon a jour|r",
            okCount, #sorted
        ))

        for i, entry in ipairs(sorted) do
            if rows[i] then
                local icon, color, suffix
                if entry.data.status == "ok" then
                    icon   = "[v]"
                    color  = "|cff00ff00"
                    suffix = "  v" .. (entry.data.version or "?")
                elseif entry.data.status == "outdated" then
                    icon   = "[!]"
                    color  = "|cffff8800"
                    suffix = "  v" .. (entry.data.version or "?") .. "  (obsolete)"
                else
                    icon   = "[x]"
                    color  = "|cffff4444"
                    suffix = "  addon non installe"
                end
                rows[i]:SetText(color .. icon .. "|r  " .. entry.name .. "|cffaaaaaa" .. suffix .. "|r")
                rows[i]:Show()
            end
        end

        content:SetHeight(math.max(#sorted * ROW_HEIGHT, 20))
    end

    M.OnSyncUpdate = Refresh

    -- ─── Clic bouton ─────────────────────────────────────────────────────────
    checkBtn:SetScript("OnClick", function()
        local ok, err = M:StartVersionCheck()
        if not ok then
            if err == "not_privileged" then
                statusMsg:SetText("|cffff4444Reserve au Raid Leader et aux assistants|r")
            elseif err == "not_in_group" then
                statusMsg:SetText("|cffff4444Vous n'etes pas dans un groupe|r")
            end
        else
            statusMsg:SetText("|cffaaaaaa Verification en cours (10s)...|r")
            C_Timer.After(10, function() statusMsg:SetText("") end)
        end
    end)

    frame:SetScript("OnShow", Refresh)

    return frame
end
