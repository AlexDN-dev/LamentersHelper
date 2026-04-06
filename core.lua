local addonName, M = ...

-- GetPlayerAuraBySpellID retourne l'aura directement sans exposer le champ spellId tainté.
-- Comparer aura.spellId (Secret Value) via GetAuraDataByIndex cause un taint → bloqué par Blizzard.
-- Cette fonction ne fonctionne que sur "player".
function M.FindAura(unit, spellID, filter)
    if unit ~= "player" then return nil end
    if C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID) or nil
    end
    -- Fallback : pcall pour éviter le crash sur spellId tainté
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
        if not aura then break end
        local ok, match = pcall(function() return aura.spellId == spellID end)
        if ok and match then return aura end
        i = i + 1
    end
    return nil
end

M.frame = CreateFrame("Frame")

M.frame:SetScript("OnEvent", function(self, event, ...)
    if M[event] then
        M[event](M, ...)
    end
end)

M.frame:RegisterEvent("PLAYER_LOGIN")
M.frame:RegisterEvent("PLAYER_LOGOUT")
M.frame:RegisterEvent("ENCOUNTER_START")
M.frame:RegisterEvent("ENCOUNTER_END")

-- Mapping encounterID → clé boss (pour les positions d'ancres par boss)
local ENCOUNTER_BOSS_KEYS = {
    [3176] = "imperator",
    [3177] = "vorasius",
    [3178] = "chimaerus",
    [3179] = "salhadaar",
    [3180] = "vanguard",
    [3181] = "crown",
}

M.activeBossKey = nil

function M:ENCOUNTER_START(encounterID)
    M.activeBossKey = ENCOUNTER_BOSS_KEYS[encounterID]
end

function M:ENCOUNTER_END()
    M.activeBossKey = nil
end

function M:PLAYER_LOGIN()
    if self.InitializeConfig then
        self:InitializeConfig()
    end

    if self.CreatePreviewText then
        self:CreatePreviewText()
    end

    if self.InitSync then
        self:InitSync()
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

    return false
end

function M:UnitHasAuraBySpellID(unit, spellID, filter)
    -- Pour le joueur : GetPlayerAuraBySpellID évite d'accéder au champ spellId tainté
    if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        return C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end

    local index = 1
    local auraData

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        while true do
            auraData = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if not auraData then
                return false
            end

            local ok, match = pcall(function() return auraData.spellId == spellID end)
            if ok and match then
                return true
            end

            index = index + 1
        end
    end

    if AuraUtil and AuraUtil.FindAuraByName then
        local spellName
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            spellName = info and info.name
        elseif GetSpellInfo then
            spellName = GetSpellInfo(spellID)
        end
        if spellName then
            return AuraUtil.FindAuraByName(spellName, unit, filter) ~= nil
        end
    end

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
-- Enregistré ici aussi pour que le préfixe existe avant tout message entrant (réception fiable).
C_ChatInfo.RegisterAddonMessagePrefix("LH_GRID")

local checkActive = false

function M:SendAddonCheck()
    checkActive = true
    C_ChatInfo.SendAddonMessage("LH_CHECK", "ping", "RAID")
    C_Timer.After(10, function()
        checkActive = false
    end)
end

function M:CHAT_MSG_ADDON(prefix, msg, channel, sender)
    if prefix ~= "LH_CHECK" then
        return
    end

    local myName = UnitName("player")
    local senderShort = string.match(sender, "^[^-]+") or sender

    if msg == "ping" and senderShort ~= myName then
        C_ChatInfo.SendAddonMessage("LH_CHECK", "pong", "RAID")
    elseif msg == "pong" and checkActive then
        print(senderShort .. " has LamentersHelper")
    end
end

M.frame:RegisterEvent("CHAT_MSG_ADDON")

SLASH_LHCHECK1 = "/lhcheck"

SlashCmdList["LHCHECK"] = function()
    M:SendAddonCheck()
end

SLASH_LHSOUND1 = "/lhsound"

SlashCmdList["LHSOUND"] = function()
    if not M.PlayAlertSound then
        print("|cffff0000LH Sound: M:PlayAlertSound non défini !|r")
        return
    end
    print("|cff00ff00LH Sound: test global|r")
    M:PlayAlertSound("global")
    C_Timer.After(0.8, function()
        print("|cff00ff00LH Sound: test phase|r")
        M:PlayAlertSound("phase")
    end)
    C_Timer.After(1.6, function()
        print("|cff00ff00LH Sound: test interrupt|r")
        M:PlayAlertSound("interrupt")
    end)
    C_Timer.After(2.4, function()
        print("|cff00ff00LH Sound: test private|r")
        M:PlayAlertSound("private")
    end)
end
