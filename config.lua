local addonName, M = ...

local defaults = {
    textSize = 20,
    posX = 0,
    posY = 0,
    textDuration = 4,
    privateTextSize = 16,
    privatePosX = 0,
    privatePosY = -90,
    privateTextDuration = 5,
    rlNoteTextSize = 18,
    rlNotePosX = 320,
    rlNotePosY = 120,
    alwaysShowGrid = false,
    gridBossName = "Imperator Averzian",
    gridEncounterID = 3176,
    gridPosX = 400,
    gridPosY = 0,
    debugEncounter = false,
}

M.config = {}

local function CopyDefaultsIntoConfig()
    for key, value in pairs(defaults) do
        M.config[key] = value
    end
end

local function EnsureDatabase()
    if type(LamentersHelperDB) ~= "table" then
        LamentersHelperDB = {}
    end

    for key, value in pairs(defaults) do
        if LamentersHelperDB[key] == nil then
            LamentersHelperDB[key] = value
        end
    end
end

function M:InitializeConfig()
    CopyDefaultsIntoConfig()
    EnsureDatabase()

    for key in pairs(defaults) do
        self.config[key] = LamentersHelperDB[key]
    end
end

function M:SaveConfig()
    EnsureDatabase()

    for key in pairs(defaults) do
        LamentersHelperDB[key] = self.config[key]
    end
end
