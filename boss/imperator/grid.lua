local addonName, M = ...

local PLAYER_NAME = UnitName("player")
local ROLE = (PLAYER_NAME == "Thiri\195\163ll") and "rl" or "viewer"

C_ChatInfo.RegisterAddonMessagePrefix("LH_GRID")

local selected = {}
local blocked = {}
local locked = false
local resetTimer = nil
local selectedCount = 0
local activeEncounterID = nil
local CreatesLine, ResetGrid

-- Icônes raid marker par position (0 = case vide, pas d'icône)
-- WoW n'a que 8 marqueurs (1–8), la case du milieu est laissée vide intentionnellement
local icons = {
    1, 2, 3,
    4, 0, 6,
    7, 8, 1,
}

-- Textures précalculées au chargement (icônes 1–8, atlas 4x2 de 64px dans 256px)
local ICON_TEXTURES = {}
for i = 1, 8 do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    ICON_TEXTURES[i] = string.format(
        "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:24:24:0:0:256:256:%d:%d:%d:%d|t",
        col * 64, (col + 1) * 64, row * 64, (row + 1) * 64
    )
end

-- Retourne le label à afficher dans le message de soak pour une case donnée
local function GetSoakLabel(idx)
    if idx == 5 then
        return "CENTRE"
    end
    return ICON_TEXTURES[icons[idx]] or "?"
end

-- Construit le message "SOAK X ET Y" à partir des indices sélectionnés et du skip
local function BuildSoakMessage(list, red)
    local soakList = {}
    for _, idx in ipairs(list) do
        if idx ~= red then
            table.insert(soakList, idx)
        end
    end
    if #soakList < 2 then return nil end
    local text1 = "|cff00ff00" .. GetSoakLabel(soakList[1]) .. "|r"
    local text2 = "|cff00aaff" .. GetSoakLabel(soakList[2]) .. "|r"
    return "SOAK " .. text1 .. " ET " .. text2
end

local function GetShortName(name)
    return name and (string.match(name, "^[^%-]+") or name) or ""
end

local function GetCenterOffsets(frame)
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    if not centerX or not parentCenterX then
        return M.config.gridPosX or 400, M.config.gridPosY or 0
    end
    return math.floor(centerX - parentCenterX + 0.5), math.floor(centerY - parentCenterY + 0.5)
end

local function GetPriority(index)
    if index == 1 or index == 3 or index == 7 or index == 9 then return 2 end
    if index == 5 then return 1 end
    return 3
end

local function CopyBlockedState()
    local copy = {}
    for k, v in pairs(blocked) do copy[k] = v end
    return copy
end

local winPatterns = {
    {1,2,3}, {4,5,6}, {7,8,9},
    {1,4,7}, {2,5,8}, {3,6,9},
    {1,5,9}, {3,5,7},
}

CreatesLine = function(testBlocked)
    for _, p in ipairs(winPatterns) do
        if testBlocked[p[1]] and testBlocked[p[2]] and testBlocked[p[3]] then
            return true
        end
    end
    return false
end

local function ChooseBestSkip(list)
    local bestChoice
    local bestCreatesLine = true
    local bestScore = -1

    for _, candidate in ipairs(list) do
        local test = CopyBlockedState()
        local score = GetPriority(candidate)
        test[candidate] = true
        local createsLine = CreatesLine(test)

        if createsLine ~= bestCreatesLine then
            if not createsLine then
                bestChoice = candidate
                bestCreatesLine = false
                bestScore = score
            end
        elseif score > bestScore then
            bestChoice = candidate
            bestScore = score
        elseif score == bestScore and bestChoice and candidate < bestChoice then
            bestChoice = candidate
        end
    end

    return bestChoice or list[1]
end

local function GetTrackedEncounterID()
    return M.config and M.config.gridEncounterID or 3176
end

local function PrintEncounterDebug(encounterID, encounterName, phase)
    if not M.config or not M.config.debugEncounter then return end
    print(string.format("|cff00ff00LH Debug|r %s: %s (ID: %s)", phase, tostring(encounterName), tostring(encounterID)))
end

-- === UI ===

local gridFrame = CreateFrame("Frame", "LamentersHelperGrid", UIParent, "BackdropTemplate")
gridFrame:SetSize(300, 360)
gridFrame:SetPoint("CENTER", UIParent, "CENTER", M.config.gridPosX or 400, M.config.gridPosY or 0)
gridFrame:SetMovable(true)
gridFrame:EnableMouse(true)
gridFrame:RegisterForDrag("LeftButton")
gridFrame:SetClampedToScreen(true)
gridFrame:SetFrameStrata("HIGH")
gridFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    edgeSize = 16,
})
gridFrame:SetBackdropColor(0, 0, 0, 0.8)

gridFrame:SetScript("OnDragStart", gridFrame.StartMoving)
gridFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = GetCenterOffsets(self)
    LamentersHelperDB.gridPosX = x
    LamentersHelperDB.gridPosY = y
    M.config.gridPosX = x
    M.config.gridPosY = y
    if M.SaveConfig then M:SaveConfig() end
end)

function M:RefreshGridVisibility()
    local shouldShow = self.anchorMode
        or (self.config and self.config.alwaysShowGrid)
        or (activeEncounterID and activeEncounterID == GetTrackedEncounterID())
    if shouldShow then
        gridFrame:Show()
    else
        gridFrame:Hide()
    end
end

local buttons = {}
local SIZE = 80
local GAP = 10

for row = 1, 3 do
    for col = 1, 3 do
        local index = (row - 1) * 3 + col

        local btn = CreateFrame("Button", nil, gridFrame, "BackdropTemplate")
        btn:SetSize(SIZE, SIZE)
        btn:SetBackdrop({bgFile = "Interface/Buttons/WHITE8x8"})
        btn:SetBackdropColor(0.5, 0.5, 0.5, 1)
        btn:SetPoint("CENTER", gridFrame, "CENTER", (col - 2) * (SIZE + GAP), (2 - row) * (SIZE + GAP))

        local iconIndex = icons[index]
        if iconIndex ~= 0 then
            local tex = btn:CreateTexture(nil, "OVERLAY")
            tex:SetSize(40, 40)
            tex:SetPoint("CENTER")
            tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
            tex:SetTexCoord(
                (iconIndex - 1) % 4 * 0.25,
                ((iconIndex - 1) % 4 + 1) * 0.25,
                math.floor((iconIndex - 1) / 4) * 0.25,
                (math.floor((iconIndex - 1) / 4) + 1) * 0.25
            )
        end

        btn:SetScript("OnClick", function()
            if ROLE ~= "rl" then return end
            if locked then return end
            if selected[index] then return end
            if blocked[index] then return end

            selected[index] = true
            selectedCount = selectedCount + 1
            btn:SetBackdropColor(0, 0.5, 1, 1)

            if selectedCount >= 3 then
                locked = true
                if resetTimer then resetTimer:Cancel() end

                local list = {}
                for i in pairs(selected) do table.insert(list, i) end
                table.sort(list)

                local bestChoice = ChooseBestSkip(list)

                for _, idx in ipairs(list) do
                    if idx == bestChoice then
                        buttons[idx]:SetBackdropColor(1, 0, 0, 1)
                        blocked[idx] = true
                    else
                        buttons[idx]:SetBackdropColor(0, 1, 0, 1)
                    end
                end

                local message = BuildSoakMessage(list, bestChoice)
                if message and M.ShowText then
                    M:ShowText(message)
                end

                if M.PlayAlertSound then
                    M:PlayAlertSound("soak")
                end

                C_ChatInfo.SendAddonMessage("LH_GRID", table.concat(list, ",") .. "|" .. bestChoice, "RAID")

                resetTimer = C_Timer.NewTimer(10, function()
                    for i, b in ipairs(buttons) do
                        if not blocked[i] then
                            b:SetBackdropColor(0.5, 0.5, 0.5, 1)
                        end
                    end
                    selected = {}
                    selectedCount = 0
                    locked = false
                end)
            end
        end)

        buttons[index] = btn
    end
end

ResetGrid = function()
    if resetTimer then resetTimer:Cancel() end
    selected = {}
    blocked = {}
    selectedCount = 0
    locked = false
    for _, b in ipairs(buttons) do
        b:SetBackdropColor(0.5, 0.5, 0.5, 1)
    end
end

local resetBtn = CreateFrame("Button", nil, gridFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(120, 30)
resetBtn:SetPoint("BOTTOM", 0, 15)
resetBtn:SetText("Reset")
resetBtn:SetScript("OnClick", ResetGrid)

-- === Événements (frame unique) ===

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("ENCOUNTER_START")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, msg, _, sender = ...
        if prefix ~= "LH_GRID" then return end
        if GetShortName(sender) == PLAYER_NAME then return end

        local sel, red = strsplit("|", msg)
        local list = {}
        for v in string.gmatch(sel, "[^,]+") do
            table.insert(list, tonumber(v))
        end
        red = tonumber(red)

        if not gridFrame:IsShown() and M.RefreshGridVisibility then
            M:RefreshGridVisibility()
        end

        for _, idx in ipairs(list) do
            if idx == red then
                buttons[idx]:SetBackdropColor(1, 0, 0, 1)
                blocked[idx] = true
            else
                buttons[idx]:SetBackdropColor(0, 1, 0, 1)
            end
        end

        local message = BuildSoakMessage(list, red)
        if message and M.ShowText then
            M:ShowText(message)
        end

    elseif event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        activeEncounterID = encounterID
        PrintEncounterDebug(encounterID, encounterName, "START")
        if M.RefreshGridVisibility then M:RefreshGridVisibility() end

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        activeEncounterID = nil
        PrintEncounterDebug(encounterID, encounterName, "END")
        ResetGrid()
        if M.RefreshGridVisibility then M:RefreshGridVisibility() end

    elseif event == "PLAYER_ENTERING_WORLD" then
        activeEncounterID = nil
        if M.RefreshGridVisibility then M:RefreshGridVisibility() end
    end
end)

if M.RefreshGridVisibility then
    M:RefreshGridVisibility()
else
    gridFrame:Hide()
end
