local addonName, M = ...

local panel = CreateFrame("Frame", "LamentersHelperPanel", UIParent, "BackdropTemplate")
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -10)
title:SetText("Lamenters Helper")
local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

panel:SetSize(820, 560)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetClampedToScreen(true)

panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

panel:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})

panel:SetBackdropColor(0, 0, 0, 0.9)

panel:Hide()

local menu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
menu:SetSize(180, 500)
menu:SetPoint("LEFT", 12, 0)

menu:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background"
})
menu:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

local content = CreateFrame("Frame", nil, panel)
content:SetPoint("TOPLEFT",     menu, "TOPRIGHT",    12,  0)
content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 0)

local bossButtons = {
    { key = "imperator", label = "Imperator" },
    { key = "vorasius", label = "Vorasius" },
    { key = "salhadaar", label = "Salhadaar" },
    { key = "vaelgor_ezzorak", label = "Vaelgor et Ezzorak" },
    { key = "avant_garde", label = "Avant-garde" },
    { key = "couronne", label = "Couronne" },
    { key = "chimaerus", label = "Chimaerus" },
    { key = "beloren", label = "Belo'ren" },
    { key = "glas_minuit", label = "Glas de minuit" },
}

-- Table des panels enregistrés : key → { frameKey, createFn }
-- Ajouter une entrée ici suffit pour brancher un nouveau panel.
local PANELS = {
    options   = { frameKey = "optionsFrame",   createFn = "CreateOptions"       },
    imperator = { frameKey = "imperatorFrame", createFn = "CreateImperatorPanel" },
    vorasius  = { frameKey = "vorasiusFrame",  createFn = "CreateVorasiusPanel"  },
    couronne  = { frameKey = "crownFrame",     createFn = "CreateCrownPanel"     },
    sync      = { frameKey = "syncFrame",      createFn = "CreateSyncPanel"      },
}

local function HideAllPanels()
    for _, p in pairs(PANELS) do
        local f = M[p.frameKey]
        if f then f:Hide() end
    end
end

local function ShowSection(sectionName)
    HideAllPanels()
    local p = PANELS[sectionName]
    if not p then return end
    if not M[p.frameKey] then
        M[p.frameKey] = M[p.createFn](M)
    end
    -- Hide avant Show garantit la transition hidden→shown et force OnShow à se déclencher
    M[p.frameKey]:Hide()
    M[p.frameKey]:Show()
end

local previousButton

for index, boss in ipairs(bossButtons) do
    local button = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
    button:SetSize(140, 32)

    if index == 1 then
        button:SetPoint("TOP", 0, -20)
    else
        button:SetPoint("TOP", previousButton, "BOTTOM", 0, -10)
    end

    button:SetText(boss.label)
    button:SetScript("OnClick", function()
        ShowSection(boss.key)
    end)

    previousButton = button
end

local syncBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
syncBtn:SetSize(140, 32)
syncBtn:SetPoint("TOP", previousButton, "BOTTOM", 0, -18)
syncBtn:SetText("Verif Addon")
syncBtn:SetScript("OnClick", function()
    ShowSection("sync")
end)

local optionsBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
optionsBtn:SetSize(140, 32)
optionsBtn:SetPoint("TOP", syncBtn, "BOTTOM", 0, -10)
optionsBtn:SetText("Options")
optionsBtn:SetScript("OnClick", function()
    ShowSection("options")
end)

M.content = content
M.panel = panel
M.ShowSection = ShowSection
