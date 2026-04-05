local addonName, M = ...

-- ─── Détection du rôle joueur (global) ────────────────────────────────────────
-- Priorité : config manuelle (playerRole) > rôle de groupe > spec auto
-- Réglable dans /lh → Options → Affichage
local MELEE_SPECS = {
    WARRIOR     = {[1]=true, [2]=true},           -- Armes, Fureur (3=Protection=tank)
    PALADIN     = {[3]=true},                      -- Vindicte
    HUNTER      = {[3]=true},                      -- Survie (1=BM, 2=MM=distance)
    ROGUE       = {[1]=true, [2]=true, [3]=true},  -- Assassinat, Hors-la-loi, Subtilité
    DEATHKNIGHT = {[2]=true, [3]=true},            -- Givre, Impie (1=Sang=tank)
    SHAMAN      = {[2]=true},                      -- Amélioration (1=Élé, 3=Resto)
    MONK        = {[3]=true},                      -- Marcheur du vent (1=Tank, 2=Heal)
    DRUID       = {[2]=true},                      -- Farouche (1=Équi, 3=Garden, 4=Resto)
    DEMONHUNTER = {[1]=true},                      -- Dévastation (2=Vengeance=tank)
}

function M:GetRole()
    local override = M.config and M.config.playerRole
    if override and override ~= "AUTO" then return override end

    local role = UnitGroupRolesAssigned("player")
    if role == "TANK"   then return "TANK"   end
    if role == "HEALER" then return "HEALER" end

    local specIndex = GetSpecialization()
    if not specIndex then return "RANGE" end
    local _, classFile = UnitClass("player")
    if MELEE_SPECS[classFile] and MELEE_SPECS[classFile][specIndex] then
        return "MELEE"
    end
    return "RANGE"
end

-- ─── Alerte générique (backward compat) ───────────────────────────────────────
function M:TriggerAlert(msg)
    self:ShowText(msg)
    if self.PlayAlertSound then
        self:PlayAlertSound("global")
    end
    C_Timer.After(2, function()
        M:HideText()
    end)
end
