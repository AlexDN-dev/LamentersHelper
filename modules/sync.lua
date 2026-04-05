local addonName, M = ...

-- ─── Protocole ────────────────────────────────────────────────────────────────
-- Prefix : "LMHELPER" (≤16 chars, enregistré sur PLAYER_LOGIN)
-- VER_REQ          → RL/assist demande la version à tout le raid
-- VER_RPL:<version> → chaque membre répond avec sa version
-- ──────────────────────────────────────────────────────────────────────────────

local PREFIX          = "LMHELPER"
local CHECK_TIMEOUT   = 10   -- secondes avant de marquer les non-répondants
local CURRENT_VERSION = nil  -- initialisé dans InitSync (GetAddOnMetadata pas dispo avant PLAYER_LOGIN)

M.syncResults = {}  -- [name] = { version = "x.x", status = "ok"|"outdated"|"missing" }

-- ─── Comparaison de versions ──────────────────────────────────────────────────
local function VersionToInt(v)
    if not v then return 0 end
    local a, b, c = v:match("^(%d+)%.?(%d*)%.?(%d*)$")
    return (tonumber(a) or 0) * 10000
         + (tonumber(b) or 0) * 100
         + (tonumber(c) or 0)
end

-- ─── Initialisation ───────────────────────────────────────────────────────────
function M:InitSync()
    CURRENT_VERSION = (C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version"))
                   or GetAddOnMetadata and GetAddOnMetadata(addonName, "Version")
                   or "0.1"
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    self.frame:RegisterEvent("CHAT_MSG_ADDON")
end

-- ─── Réception des messages ───────────────────────────────────────────────────
function M:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if prefix ~= PREFIX then return end

    -- Nettoie le nom (supprime "-ServerName")
    local name = sender:match("^([^%-]+)") or sender

    if message == "VER_REQ" then
        -- Un RL/assist demande → on répond avec notre version
        if IsInGroup() then
            local replyChannel = IsInRaid() and "RAID" or "PARTY"
            C_ChatInfo.SendAddonMessage(PREFIX, "VER_RPL:" .. CURRENT_VERSION, replyChannel)
        end

    elseif message:sub(1, 8) == "VER_RPL:" then
        -- Quelqu'un répond avec sa version
        local version = message:sub(9)
        local status  = (VersionToInt(version) >= VersionToInt(CURRENT_VERSION)) and "ok" or "outdated"
        M.syncResults[name] = { version = version, status = status }
        if M.OnSyncUpdate then M:OnSyncUpdate() end
    end
end

-- ─── Lancement du check (RL / assist seulement) ───────────────────────────────
function M:StartVersionCheck()
    if not (UnitIsGroupLeader("player") or UnitIsRaidOfficer("player") or not IsInGroup()) then
        return false, "not_privileged"
    end

    -- Réinitialise les résultats
    M.syncResults = {}

    -- Ajoute soi-même directement
    M.syncResults[UnitName("player")] = { version = CURRENT_VERSION, status = "ok" }

    if IsInGroup() then
        -- Pré-remplit tous les membres comme "manquants"
        local groupType = IsInRaid() and "raid" or "party"
        local count     = GetNumGroupMembers()
        for i = 1, count do
            local unit = groupType .. i
            local name = UnitName(unit)
            if name and name ~= UnitName("player") then
                M.syncResults[name] = { version = nil, status = "missing" }
            end
        end

        -- Envoie la demande au groupe
        local channel = IsInRaid() and "RAID" or "PARTY"
        C_ChatInfo.SendAddonMessage(PREFIX, "VER_REQ", channel)

        -- Après le timeout → dernier refresh pour afficher les non-répondants
        C_Timer.After(CHECK_TIMEOUT, function()
            if M.OnSyncUpdate then M:OnSyncUpdate() end
        end)
    end

    -- Notifie l'UI immédiatement
    if M.OnSyncUpdate then M:OnSyncUpdate() end

    return true
end
