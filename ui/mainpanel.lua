local addonName, M = ...

-- ─── Palette guilde ──────────────────────────────────────────────────────────
local R, G, B = 0.78, 0.07, 0.07          -- rouge Lamenters

-- ─── Frame principal ─────────────────────────────────────────────────────────
local panel = CreateFrame("Frame", "LamentersHelperPanel", UIParent)
panel:SetSize(820, 560)
panel:SetPoint("CENTER")
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetClampedToScreen(true)
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)

-- Fond sombre
local _bg = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
_bg:SetAllPoints()
_bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)

-- Bordure extérieure
do
    local function Edge(p1, p2, horiz)
        local t = panel:CreateTexture(nil, "BORDER")
        if horiz then t:SetHeight(1) else t:SetWidth(1) end
        t:SetPoint(p1); t:SetPoint(p2)
        t:SetColorTexture(0.20, 0.20, 0.25, 0.7)
    end
    Edge("TOPLEFT",    "TOPRIGHT",    true)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    Edge("TOPLEFT",    "BOTTOMLEFT",  false)
    Edge("TOPRIGHT",   "BOTTOMRIGHT", false)
end

-- Barre accent rouge (3px, tout en haut)
do
    local bar = panel:CreateTexture(nil, "ARTWORK", nil, 2)
    bar:SetHeight(3)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetColorTexture(R, G, B, 1)
end

-- Zone header (fond légèrement distinct)
do
    local hdr = panel:CreateTexture(nil, "BACKGROUND")
    hdr:SetHeight(40)
    hdr:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -3)
    hdr:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -3)
    hdr:SetColorTexture(0.04, 0.04, 0.06, 1)
end

-- Ligne de séparation header / contenu (rouge subtil)
do
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -43)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -43)
    sep:SetColorTexture(R, G, B, 0.35)
end

-- Titre
local titleFs = panel:CreateFontString(nil, "OVERLAY")
titleFs:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
titleFs:SetPoint("TOP", panel, "TOP", 0, -17)
titleFs:SetText("|cffcc1414LAMENTERS|r HELPER")

-- Version
do
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata(addonName, "Version")) or "?"
    local verFs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verFs:SetPoint("TOP", titleFs, "BOTTOM", 0, -1)
    verFs:SetTextColor(0.28, 0.28, 0.32)
    verFs:SetText("v" .. ver)
end

-- Bouton fermer (×)
do
    local closeBtn = CreateFrame("Button", nil, panel)
    closeBtn:SetSize(32, 32)
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -8)

    local hl = closeBtn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(R, G, B, 0.15)

    local txt = closeBtn:CreateFontString(nil, "OVERLAY")
    txt:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    txt:SetAllPoints(); txt:SetJustifyH("CENTER"); txt:SetJustifyV("MIDDLE")
    txt:SetText("×"); txt:SetTextColor(0.35, 0.35, 0.40)

    closeBtn:SetScript("OnEnter", function() txt:SetTextColor(R, G, B) end)
    closeBtn:SetScript("OnLeave", function() txt:SetTextColor(0.35, 0.35, 0.40) end)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)
end

panel:Hide()

-- ─── Menu latéral ─────────────────────────────────────────────────────────────
local menu = CreateFrame("Frame", nil, panel)
menu:SetWidth(180)
menu:SetPoint("TOPLEFT",    panel, "TOPLEFT",    0, -44)
menu:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0,   0)

do
    local mbg = menu:CreateTexture(nil, "BACKGROUND", nil, -1)
    mbg:SetAllPoints()
    mbg:SetColorTexture(0.04, 0.04, 0.06, 1)

    -- Séparateur vertical droit du menu
    local vdiv = panel:CreateTexture(nil, "ARTWORK")
    vdiv:SetWidth(1)
    vdiv:SetPoint("TOPLEFT",    menu, "TOPRIGHT",    0, 0)
    vdiv:SetPoint("BOTTOMLEFT", menu, "BOTTOMRIGHT", 0, 0)
    vdiv:SetColorTexture(0.13, 0.13, 0.17, 1)
end

-- ScrollFrame intérieur pour le menu nav (résistant aux débordements)
local menuScrollFrame = CreateFrame("ScrollFrame", "LHNavScroll", menu)
menuScrollFrame:SetPoint("TOPLEFT",     menu, "TOPLEFT",     0, 0)
menuScrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 0, 0)
menuScrollFrame:EnableMouseWheel(true)

local menuContent = CreateFrame("Frame", nil, menuScrollFrame)
menuContent:SetWidth(180)
menuContent:SetHeight(600)   -- ajusté après la création de tous les boutons
menuScrollFrame:SetScrollChild(menuContent)

menuScrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current  = self:GetVerticalScroll()
    local maxScroll = math.max(0, menuContent:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, current - delta * 30)))
end)

-- ─── Zone de contenu ──────────────────────────────────────────────────────────
local content = CreateFrame("Frame", nil, panel)
content:SetPoint("TOPLEFT",     menu,  "TOPRIGHT",    16,  0)
content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 8)

-- ─── Navigation ───────────────────────────────────────────────────────────────
local allNavBtns   = {}
local activeNavBtn = nil
local navY         = -8

local function SetNavActive(btn)
    if activeNavBtn then
        activeNavBtn.indicator:Hide()
        activeNavBtn.label:SetTextColor(0.88, 0.88, 0.90)
        activeNavBtn.bgTex:SetColorTexture(0, 0, 0, 0)
    end
    activeNavBtn = btn
    btn.indicator:Show()
    btn.label:SetTextColor(1, 1, 1)
    btn.bgTex:SetColorTexture(R, G, B, 0.10)
end

local function MakeNavSection(label)
    local fs = menuContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", menuContent, "TOPLEFT", 12, navY)
    fs:SetText(label)
    fs:SetTextColor(0.85, 0.20, 0.20, 1)
    navY = navY - 20
end

local function NavSeparator()
    local t = menuContent:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  menuContent, "TOPLEFT",  10, navY + 4)
    t:SetPoint("TOPRIGHT", menuContent, "TOPRIGHT", -10, navY + 4)
    t:SetColorTexture(0.13, 0.13, 0.17, 1)
    navY = navY - 14
end

local function MakeNavBtn(label, onClick)
    local btn = CreateFrame("Button", nil, menuContent)
    btn:SetSize(180, 30)
    btn:SetPoint("TOPLEFT", menuContent, "TOPLEFT", 0, navY)
    navY = navY - 31

    local bgTex = btn:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(); bgTex:SetColorTexture(0, 0, 0, 0)
    btn.bgTex = bgTex

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints(); hlTex:SetColorTexture(R, G, B, 0.07)

    local indicator = btn:CreateTexture(nil, "ARTWORK")
    indicator:SetWidth(3)
    indicator:SetPoint("TOPLEFT",    btn, "TOPLEFT",    0, 0)
    indicator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    indicator:SetColorTexture(R, G, B, 1)
    indicator:Hide()
    btn.indicator = indicator

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", btn, "LEFT", 14, 0)
    lbl:SetText(label)
    lbl:SetTextColor(0.88, 0.88, 0.90)
    btn.label = lbl

    btn:SetScript("OnClick", function()
        SetNavActive(btn)
        onClick()
    end)

    table.insert(allNavBtns, btn)
    return btn
end

-- ─── Panels enregistrés ───────────────────────────────────────────────────────
local PANELS = {
    options     = { frameKey = "optionsFrame",     createFn = "CreateOptions"         },
    imperator   = { frameKey = "imperatorFrame",   createFn = "CreateImperatorPanel"  },
    vorasius    = { frameKey = "vorasiusFrame",    createFn = "CreateVorasiusPanel"   },
    couronne    = { frameKey = "crownFrame",       createFn = "CreateCrownPanel"      },
    chimaerus   = { frameKey = "chimaerUsFrame",   createFn = "CreateChimaerUsPanel"  },
    beloren     = { frameKey = "belorenFrame",     createFn = "CreateBelorenPanel"    },
    glas_minuit = { frameKey = "glasMinuitFrame",  createFn = "CreateGlasMinuitPanel" },
    sync        = { frameKey = "syncFrame",        createFn = "CreateSyncPanel"       },
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
    M[p.frameKey]:Hide()
    M[p.frameKey]:Show()
end

-- ─── Boutons de navigation boss ────────────────────────────────────────────────
local bossButtons = {
    { key = "imperator",       label = "Imperator"          },
    { key = "vorasius",        label = "Vorasius"            },
    { key = "salhadaar",       label = "Salhadaar"           },
    { key = "vaelgor_ezzorak", label = "Vaelgor et Ezzorak"  },
    { key = "avant_garde",     label = "Avant-garde"         },
    { key = "couronne",        label = "Couronne"            },
    { key = "chimaerus",       label = "Chimaerus"           },
    { key = "beloren",         label = "Belo'ren"            },
    { key = "glas_minuit",     label = "Glas de minuit"      },
}

MakeNavSection("BOSS")
for _, boss in ipairs(bossButtons) do
    MakeNavBtn(boss.label, function() ShowSection(boss.key) end)
end

NavSeparator()
MakeNavSection("OUTILS")
MakeNavBtn("Verif Addon", function() ShowSection("sync")    end)
MakeNavBtn("Options",     function() ShowSection("options") end)

-- Ajuste la hauteur du contenu au nombre réel de boutons créés
menuContent:SetHeight(-navY + 20)

-- ─── Bouton stylisé (partagé avec options/sync) ──────────────────────────────
function M.MakeBtn(parent, label, w, h)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w or 120, h or 26)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.11, 0.11, 0.14, 1)
    btn._bg = bg

    -- Bordure fine rouge sombre
    local function Edge(p1, p2, horiz)
        local t = btn:CreateTexture(nil, "BORDER")
        if horiz then t:SetHeight(1) else t:SetWidth(1) end
        t:SetPoint(p1); t:SetPoint(p2)
        t:SetColorTexture(0.38, 0.05, 0.05, 0.90)
    end
    Edge("TOPLEFT","TOPRIGHT",true);  Edge("BOTTOMLEFT","BOTTOMRIGHT",true)
    Edge("TOPLEFT","BOTTOMLEFT",false); Edge("TOPRIGHT","BOTTOMRIGHT",false)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(R, G, B, 0.15)

    local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt:SetAllPoints(); txt:SetJustifyH("CENTER"); txt:SetJustifyV("MIDDLE")
    txt:SetText(label or ""); txt:SetTextColor(0.90, 0.90, 0.92)
    btn._txt = txt

    -- Compat SetText/GetText
    btn.SetText = function(self, t) self._txt:SetText(t) end
    btn.GetText = function(self)    return self._txt:GetText() end

    btn:SetScript("OnMouseDown", function() bg:SetColorTexture(0.07, 0.07, 0.09, 1) end)
    btn:SetScript("OnMouseUp",   function() bg:SetColorTexture(0.11, 0.11, 0.14, 1) end)

    return btn
end

-- ─── Exports ──────────────────────────────────────────────────────────────────
M.content     = content
M.panel       = panel
M.ShowSection = ShowSection
