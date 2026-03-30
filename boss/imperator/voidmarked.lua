local addonName, M = ...

local RL_NOTE_PLAYER = "Thiri\195\163ll"
local PREFIX = "LH_VM"
local VOID_MARK_AURAS = {
    "Void Marked",
    "Marque du Vide",
}

local frame = CreateFrame("Frame")
local lastBroadcast = ""
local lastPrivateText = ""

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local function GetShortName(name)
    if not name then
        return ""
    end

    return string.match(name, "^[^-]+") or name
end

local function NamesMatch(left, right)
    return GetShortName(left) == GetShortName(right)
end

local function IsController()
    return UnitName("player") == RL_NOTE_PLAYER
end

local function IsTrackedAuraOnUnit(unit)
    local auraName

    for _, name in ipairs(VOID_MARK_AURAS) do
        auraName = AuraUtil.FindAuraByName(name, unit, "HARMFUL")
        if auraName then
            return true
        end
    end

    return false
end

local function CollectMarkedPlayers()
    local marked = {}
    local unit
    local playerName

    if not IsInRaid() then
        return marked
    end

    for index = 1, GetNumGroupMembers() do
        unit = "raid" .. index
        if UnitExists(unit) and IsTrackedAuraOnUnit(unit) then
            playerName = GetUnitName(unit, true)
            table.insert(marked, playerName)
        end
    end

    table.sort(marked, function(a, b)
        return GetShortName(a) < GetShortName(b)
    end)

    return marked
end

local function CollectHealers()
    local healers = {}
    local unit
    local playerName

    if not IsInRaid() then
        return healers
    end

    for index = 1, GetNumGroupMembers() do
        unit = "raid" .. index
        if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "HEALER" then
            playerName = GetUnitName(unit, true)
            table.insert(healers, playerName)
        end
    end

    table.sort(healers, function(a, b)
        return GetShortName(a) < GetShortName(b)
    end)

    return healers
end

local function GetPlayerClassToken(playerName)
    local unit
    local classToken

    if not IsInRaid() then
        return nil
    end

    for index = 1, GetNumGroupMembers() do
        unit = "raid" .. index
        if UnitExists(unit) and NamesMatch(GetUnitName(unit, true), playerName) then
            _, classToken = UnitClass(unit)
            return classToken
        end
    end

    return nil
end

local function GetClassColoredName(playerName)
    local classToken = GetPlayerClassToken(playerName)
    local color

    if not classToken then
        return GetShortName(playerName)
    end

    color = RAID_CLASS_COLORS[classToken]
    if not color then
        return GetShortName(playerName)
    end

    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(color.r * 255 + 0.5),
        math.floor(color.g * 255 + 0.5),
        math.floor(color.b * 255 + 0.5),
        GetShortName(playerName)
    )
end

local function BuildAssignments(markedPlayers, healers)
    local assignments = {}
    local healCount = #healers
    local healerName

    if healCount == 0 then
        healerName = GetUnitName("player", true)
        healers = { healerName }
        healCount = 1
    end

    for index, playerName in ipairs(markedPlayers) do
        assignments[index] = {
            player = playerName,
            healer = healers[((index - 1) % healCount) + 1],
            soak = math.ceil(index / 2),
        }
    end

    return assignments
end

local function BuildRLNote(assignments)
    local lines = {}
    local currentSoak = 0

    for _, entry in ipairs(assignments) do
        if entry.soak ~= currentSoak then
            currentSoak = entry.soak
            table.insert(lines, "SOAK " .. currentSoak .. " :")
        end

        table.insert(lines, GetShortName(entry.player) .. " -> " .. GetShortName(entry.healer))
    end

    return table.concat(lines, "\n")
end

local function BuildHealerText(assignments, healerName)
    local lines = {}

    for _, entry in ipairs(assignments) do
        if NamesMatch(entry.healer, healerName) then
            table.insert(lines, "DISPEL " .. GetClassColoredName(entry.player))
        end
    end

    return table.concat(lines, "\n")
end

local function SerializeAssignments(assignments)
    local parts = {}

    for _, entry in ipairs(assignments) do
        table.insert(parts, table.concat({
            entry.soak,
            GetShortName(entry.player),
            GetShortName(entry.healer),
        }, ":"))
    end

    return table.concat(parts, ";")
end

local function DeserializeAssignments(payload)
    local assignments = {}
    local soak
    local playerName
    local healerName

    if payload == "" then
        return assignments
    end

    for entry in string.gmatch(payload, "[^;]+") do
        soak, playerName, healerName = strsplit(":", entry)
        table.insert(assignments, {
            soak = tonumber(soak),
            player = playerName,
            healer = healerName,
        })
    end

    return assignments
end

local function BroadcastAssignments(assignments)
    local payload = SerializeAssignments(assignments)

    if payload == lastBroadcast then
        return
    end

    lastBroadcast = payload
    C_ChatInfo.SendAddonMessage(PREFIX, payload, "RAID")
end

local function ApplyAssignments(assignments)
    local myName = GetUnitName("player", true)
    local privateText = BuildHealerText(assignments, myName)
    local textChanged = privateText ~= lastPrivateText

    if privateText ~= "" then
        M:ShowPrivateText(privateText)

        if textChanged and M.PlayAssetSound then
            M:PlayAssetSound("assets\\check_dispell.ogg")
        end
    else
        M:HidePrivateText()
    end

    lastPrivateText = privateText

    if IsController() then
        if #assignments > 0 then
            M:ShowRLNote(BuildRLNote(assignments))
        else
            M:HideRLNote()
        end
    end
end

local function UpdateVoidMarkedAssignments()
    local markedPlayers
    local healers
    local assignments

    if not IsController() then
        return
    end

    if not IsInRaid() then
        ApplyAssignments({})
        lastBroadcast = ""
        return
    end

    markedPlayers = CollectMarkedPlayers()
    healers = CollectHealers()
    assignments = BuildAssignments(markedPlayers, healers)

    ApplyAssignments(assignments)
    BroadcastAssignments(assignments)
end

local function HandleAddonMessage(payload)
    local assignments = DeserializeAssignments(payload)

    ApplyAssignments(assignments)
end

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, payload = ...
        if prefix == PREFIX then
            HandleAddonMessage(payload)
        end
        return
    end

    if event == "UNIT_AURA" then
        local unit = ...
        if not unit or not string.match(unit, "^raid%d+$") then
            return
        end
    end

    UpdateVoidMarkedAssignments()
end)

SLASH_LHVOIDTEST1 = "/lhvoidtest"

SlashCmdList["LHVOIDTEST"] = function()
    local myName = GetShortName(GetUnitName("player", true))

    M:ShowPrivateText("DISPEL " .. GetClassColoredName(myName))

    if M.PlayAssetSound then
        M:PlayAssetSound("assets\\check_dispell.ogg")
    end

    if IsController() then
        M:ShowRLNote(table.concat({
            "SOAK 1 :",
            myName .. " -> " .. myName,
            "Testheal -> " .. myName,
            "SOAK 2 :",
            "Testmage -> Healalpha",
            "Testlock -> Healbeta",
            "SOAK 3 :",
            "Testhunt -> Healgamma",
            "Testrogue -> Healdelta",
        }, "\n"))
    end
end
