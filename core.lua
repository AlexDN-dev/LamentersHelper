local addonName, M = ...

M.frame = CreateFrame("Frame")

M.frame:SetScript("OnEvent", function(self, event, ...)
    if M[event] then
        M[event](M, ...)
    end
end)

M.frame:RegisterEvent("PLAYER_LOGIN")
M.frame:RegisterEvent("PLAYER_LOGOUT")

function M:PLAYER_LOGIN()
    if self.InitializeConfig then
        self:InitializeConfig()
    end

    if self.CreatePreviewText then
        self:CreatePreviewText()
    end

    print("|cff00ff00LamentersHelper loaded!|r")
end

function M:PLAYER_LOGOUT()
    if self.SaveConfig then
        self:SaveConfig()
    end
end

function M:PlayAssetSound(relativePath)
    if not relativePath or relativePath == "" then
        return false
    end

    local normalized = string.gsub(relativePath, "/", "\\")
    local windowsPath = "Interface\\AddOns\\" .. addonName .. "\\" .. normalized
    local gamePath = string.gsub(windowsPath, "\\", "/")
    local ok

    ok = PlaySoundFile(windowsPath, "Master")
    if ok then
        return true
    end

    ok = PlaySoundFile(gamePath, "Master")
    if ok then
        return true
    end

    ok = PlaySoundFile(windowsPath, "SFX")
    if ok then
        return true
    end

    ok = PlaySoundFile(gamePath, "SFX")
    if ok then
        return true
    end

    print("|cffff5555LamentersHelper: impossible de jouer le son|r " .. tostring(relativePath))
    return false
end

SLASH_LAMENTERSHELPER1 = "/lh"

SlashCmdList["LAMENTERSHELPER"] = function(msg)
    if M.panel:IsShown() then
        M.panel:Hide()
    else
        M.panel:Show()

        if M.ShowSection then
            M.ShowSection("options")
        end
    end
end

C_ChatInfo.RegisterAddonMessagePrefix("LH_CHECK")

function M:SendAddonCheck()
    C_ChatInfo.SendAddonMessage("LH_CHECK", "ping", "RAID")
end

function M:CHAT_MSG_ADDON(prefix, msg, channel, sender)
    if prefix == "LH_CHECK" then
        print(sender .. " has LamentersHelper")
    end
end

M.frame:RegisterEvent("CHAT_MSG_ADDON")

SLASH_LHCHECK1 = "/lhcheck"

SlashCmdList["LHCHECK"] = function()
    M:SendAddonCheck()
end
