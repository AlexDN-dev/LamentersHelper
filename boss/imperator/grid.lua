local addonName, M = ...

local PLAYER_NAME = UnitName("player")
local ROLE = "viewer"

if PLAYER_NAME == "Thiri\195\163ll" then
    ROLE = "rl"
elseif PLAYER_NAME == "Bananamonke" or PLAYER_NAME == "Asterawyn" then
    ROLE = "viewer"
end

C_ChatInfo.RegisterAddonMessagePrefix("LH_GRID")

local selected = {}
local blocked = {}
local locked = false
local resetTimer = nil
local selectedCount = 0
local CreatesLine
local activeEncounterID = nil
local ResetGrid

local function GetCenterOffsets(frame)
    local centerX, centerY = frame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()

    if not centerX or not centerY or not parentCenterX or not parentCenterY then
        return M.config.gridPosX or 400, M.config.gridPosY or 0
    end

    return math.floor(centerX - parentCenterX + 0.5), math.floor(centerY - parentCenterY + 0.5)
end

local function GetPriority(index)
    if index == 1 or index == 3 or index == 7 or index == 9 then return 2 end
    if index == 5 then return 1 end
    return 3
end

local function SortIndices(list)
    table.sort(list, function(a, b)
        return a < b
    end)
end

local function CopyBlockedState()
    local copy = {}

    for k, v in pairs(blocked) do
        copy[k] = v
    end

    return copy
end

local function ChooseBestSkip(list)
    local bestChoice
    local bestCreatesLine = true
    local bestScore = -1

    SortIndices(list)

    for _, candidate in ipairs(list) do
        local test = CopyBlockedState()
        local createsLine
        local score = GetPriority(candidate)

        test[candidate] = true
        createsLine = CreatesLine(test)

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

local winPatterns = {
    {1,2,3},{4,5,6},{7,8,9},
    {1,4,7},{2,5,8},{3,6,9},
    {1,5,9},{3,5,7},
}

CreatesLine = function(testBlocked)
    for _, p in ipairs(winPatterns) do
        if testBlocked[p[1]] and testBlocked[p[2]] and testBlocked[p[3]] then
            return true
        end
    end
    return false
end

local icons = {
    1,2,3,
    4,5,6,
    7,8,1
}

local function GetIconTexture(index)
    local left = ((index - 1) % 4) * 64
    local right = (((index - 1) % 4) + 1) * 64
    local top = math.floor((index - 1) / 4) * 64
    local bottom = (math.floor((index - 1) / 4) + 1) * 64

    return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcons:24:24:0:0:256:256:"
        .. left .. ":" .. right .. ":" .. top .. ":" .. bottom .. "|t"
end

local function GetTrackedEncounterID()
    if M.config and M.config.gridEncounterID then
        return M.config.gridEncounterID
    end

    return 3176
end

local function PrintEncounterDebug(encounterID, encounterName, phase)
    if not M.config or not M.config.debugEncounter then
        return
    end

    print(string.format("|cff00ff00LH Debug|r %s: %s (ID: %s)", phase, tostring(encounterName), tostring(encounterID)))
end

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

gridFrame:SetBackdropColor(0,0,0,0.8)

gridFrame:SetScript("OnDragStart", gridFrame.StartMoving)
gridFrame:SetScript("OnDragStop", function(self)
    local x
    local y

    self:StopMovingOrSizing()
    x, y = GetCenterOffsets(self)

    LamentersHelperDB.gridPosX = x
    LamentersHelperDB.gridPosY = y
    M.config.gridPosX = x
    M.config.gridPosY = y

    if M.SaveConfig then
        M:SaveConfig()
    end
end)

function M:RefreshGridVisibility()
    local shouldShow = false

    if self.anchorMode then
        shouldShow = true
    elseif self.config and self.config.alwaysShowGrid then
        shouldShow = true
    elseif activeEncounterID and activeEncounterID == GetTrackedEncounterID() then
        shouldShow = true
    end

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
        btn:SetBackdropColor(0.5,0.5,0.5,1)

        local x = (col - 2) * (SIZE + GAP)
        local y = (2 - row) * (SIZE + GAP)
        btn:SetPoint("CENTER", gridFrame, "CENTER", x, y)

        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(40,40)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")

        local iconIndex = icons[index]
        icon:SetTexCoord(
            (iconIndex - 1) % 4 * 0.25,
            ((iconIndex - 1) % 4 + 1) * 0.25,
            math.floor((iconIndex - 1) / 4) * 0.25,
            (math.floor((iconIndex - 1) / 4) + 1) * 0.25
        )

        btn:SetScript("OnClick", function()
            if ROLE ~= "rl" then return end
            if locked then return end
            if selected[index] then return end
            if blocked[index] then return end

            selected[index] = true
            selectedCount = selectedCount + 1
            btn:SetBackdropColor(0,0.5,1,1)

            if selectedCount >= 3 then
                locked = true

                if resetTimer then resetTimer:Cancel() end

                local list = {}
                for i in pairs(selected) do table.insert(list, i) end
                SortIndices(list)

                local bestChoice = ChooseBestSkip(list)
                local soakList = {}

                for _, idx in ipairs(list) do
                    if idx == bestChoice then
                        buttons[idx]:SetBackdropColor(1,0,0,1)
                        blocked[idx] = true
                    else
                        buttons[idx]:SetBackdropColor(0,1,0,1)
                        table.insert(soakList, idx)
                    end
                end

                local icon1 = GetIconTexture(icons[soakList[1]])
                local icon2 = GetIconTexture(icons[soakList[2]])
                local text1 = "|cff00ff00" .. icon1 .. "|r"
                local text2 = "|cff00aaff" .. icon2 .. "|r"
                local message = "SOAK " .. text1 .. " AND " .. text2

                if M.ShowText then
                    M:ShowText(message)
                end

                if M.PlayAssetSound then
                    M:PlayAssetSound("assets\\soak.ogg")
                end

                local msg = table.concat(list, ",") .. "|" .. bestChoice
                C_ChatInfo.SendAddonMessage("LH_GRID", msg, "RAID")

                resetTimer = C_Timer.NewTimer(10, function()
                    for i, b in ipairs(buttons) do
                        if not blocked[i] then
                            b:SetBackdropColor(0.5,0.5,0.5,1)
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

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(_, _, prefix, msg, _, sender)
    if prefix ~= "LH_GRID" then return end
    if sender == PLAYER_NAME then return end

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
            buttons[idx]:SetBackdropColor(1,0,0,1)
            blocked[idx] = true
        else
            buttons[idx]:SetBackdropColor(0,1,0,1)
        end
    end
end)

local encounterFrame = CreateFrame("Frame")
encounterFrame:RegisterEvent("ENCOUNTER_START")
encounterFrame:RegisterEvent("ENCOUNTER_END")
encounterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

encounterFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, encounterName = ...
        activeEncounterID = encounterID
        PrintEncounterDebug(encounterID, encounterName, "START")
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName = ...
        activeEncounterID = nil
        PrintEncounterDebug(encounterID, encounterName, "END")
        ResetGrid()
    elseif event == "PLAYER_ENTERING_WORLD" then
        activeEncounterID = nil
    end

    if M.RefreshGridVisibility then
        M:RefreshGridVisibility()
    end
end)

ResetGrid = function()
    if resetTimer then resetTimer:Cancel() end

    selected = {}
    blocked = {}
    selectedCount = 0
    locked = false

    for _, b in ipairs(buttons) do
        b:SetBackdropColor(0.5,0.5,0.5,1)
    end
end

local resetBtn = CreateFrame("Button", nil, gridFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(120,30)
resetBtn:SetPoint("BOTTOM",0,15)
resetBtn:SetText("Reset")
resetBtn:SetScript("OnClick", ResetGrid)

if M.RefreshGridVisibility then
    M:RefreshGridVisibility()
else
    gridFrame:Hide()
end
