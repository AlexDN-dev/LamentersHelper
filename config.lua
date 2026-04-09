local addonName, M = ...

-- ─── Deep-copy (évite que les tables partagent la même référence) ─────────────
local function DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[k] = DeepCopy(v) end
    return copy
end

-- ─── Valeurs par défaut ───────────────────────────────────────────────────────
local defaults = {
    -- Affichage — texte global
    textSize         = 28,
    posX             = 0,
    posY             = 0,
    textDuration     = 4,

    -- Affichage — texte privé
    privateTextSize     = 22,
    privatePosX         = 0,
    privatePosY         = -90,
    privateTextDuration = 5,

    -- Affichage — note RL
    rlNoteTextSize = 18,
    rlNotePosX     = 320,
    rlNotePosY     = 120,

    -- Affichage — options visuelles
    showSpellIcons = false,   -- icônes de sort discrètes à côté du texte
    flashEnabled   = true,    -- rectangle coloré qui s'illumine sur les alertes

    -- Barres de progression
    barGroupPosX = 0,
    barGroupPosY = 0,
    barWidth     = 320,
    barHeight    = 28,

    -- Grille Imperator
    alwaysShowGrid   = false,
    gridBossName     = "Imperator Averzian",
    gridEncounterID  = 3176,
    gridPosX         = 400,
    gridPosY         = 0,

    -- Crown
    crownBossName    = "Couronne du cosmos",
    crownEncounterID = 3181,

    -- Système
    debugEncounter = false,
    soundEnabled   = true,

    -- Rôle global (tous les boss)
    playerRole         = "AUTO",   -- AUTO / TANK / HEALER / MELEE / RANGE

    -- Vorasius
    vorasiusMythicMode = true,     -- 3 explosions par mur + flaques

    -- Imperator — Rotation de dispel (Void Marked)
    imperatorDispelRotation = { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" },

    -- Chimaerus — Configuration Mythique
    chimerusMiasmaRotation = { "Lill\195\164ka", "Smiths", "Wadabloom", "C\195\164bron" },
    chimaeraSoakGroupA     = {},   -- Noms joueurs groupes 1&3
    chimaeraSoakGroupB     = {},   -- Noms joueurs groupes 2&4
    chimaeraMadnessPairs   = {},   -- { {healer="X", partner="Y"}, ... }

    -- L'ura — Jeu de mémoire
    luraDiagX      = 0,
    luraDiagY      = 150,
    luraHeroicMode = true,

    -- Belo'ren — Aura Vide/Lumière (change à chaque essai)
    -- AUTO = détection via UNIT_AURA | "VOID" | "LIGHT" = override manuel
    belorenPlayerAura   = "AUTO",

    -- Belo'ren — Icône d'aura persistante (affichée tout le fight)
    belorenAuraIconX    = 0,
    belorenAuraIconY    = -200,
    belorenAuraIconSize = 80,

    -- Positions par boss — { bossKey = { posXKey = val, posYKey = val, ... } }
    -- Si absent pour un boss, fallback sur les positions globales (posX/posY etc.)
    bossAnchorOverrides    = {},
}

M.config = {}

-- ─── Init & Save ──────────────────────────────────────────────────────────────
local function EnsureDatabase()
    if type(LamentersHelperDB) ~= "table" then
        LamentersHelperDB = {}
    end
    -- Migration vorasiusRole → playerRole (v1.x → v2.0)
    if LamentersHelperDB.vorasiusRole ~= nil and LamentersHelperDB.playerRole == nil then
        LamentersHelperDB.playerRole = LamentersHelperDB.vorasiusRole
        LamentersHelperDB.vorasiusRole = nil
    end
    -- Initialise les clés manquantes (deep-copy des tables)
    for key, value in pairs(defaults) do
        if LamentersHelperDB[key] == nil then
            LamentersHelperDB[key] = DeepCopy(value)
        end
    end
    -- Profils
    if type(LamentersHelperDB.profiles) ~= "table" then
        LamentersHelperDB.profiles = {}
    end
end

function M:InitializeConfig()
    -- Copie des valeurs par défaut dans M.config (deep-copy)
    for key, value in pairs(defaults) do
        M.config[key] = DeepCopy(value)
    end

    EnsureDatabase()

    -- Charge depuis la DB (deep-copy pour éviter les références partagées)
    for key in pairs(defaults) do
        if LamentersHelperDB[key] ~= nil then
            M.config[key] = DeepCopy(LamentersHelperDB[key])
        end
    end
end

function M:SaveConfig()
    EnsureDatabase()
    for key in pairs(defaults) do
        LamentersHelperDB[key] = DeepCopy(M.config[key])
    end
end

-- ─── Profils ──────────────────────────────────────────────────────────────────
function M:SaveProfile(name)
    if not name or name == "" then return false end
    EnsureDatabase()
    local snapshot = {}
    for key in pairs(defaults) do
        snapshot[key] = DeepCopy(M.config[key])
    end
    LamentersHelperDB.profiles[name] = snapshot
    return true
end

function M:LoadProfile(name)
    if not LamentersHelperDB or not LamentersHelperDB.profiles then return false end
    local profile = LamentersHelperDB.profiles[name]
    if not profile then return false end
    for key, value in pairs(profile) do
        M.config[key] = DeepCopy(value)
        LamentersHelperDB[key] = DeepCopy(value)
    end
    return true
end

function M:DeleteProfile(name)
    if LamentersHelperDB and LamentersHelperDB.profiles then
        LamentersHelperDB.profiles[name] = nil
    end
end

function M:GetProfiles()
    if not LamentersHelperDB or type(LamentersHelperDB.profiles) ~= "table" then
        return {}
    end
    local list = {}
    for name in pairs(LamentersHelperDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end
