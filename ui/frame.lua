local addonName, M = ...

local frame = CreateFrame("Frame", "LamentersHelperFrame", UIParent)
frame:SetSize(300, 100)
frame:SetPoint("CENTER")

frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

M.mainFrame = frame