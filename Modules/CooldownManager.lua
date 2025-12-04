local _, BCDM = ...
local CooldownViewerToDB = BCDM.CooldownViewerToDB
local CooldownManagerViewers = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
}

local IconPerCooldownViewer = {
    ["EssentialCooldownViewer"] = 0,
    ["UtilityCooldownViewer"] = 0,
    ["BuffIconCooldownViewer"] = 0,
}

local function StripTextures(textureToStrip)
    if not textureToStrip then return end
    if textureToStrip.GetMaskTexture then
        local i = 1
        local textureMask = textureToStrip:GetMaskTexture(i)
        while textureMask do
            textureToStrip:RemoveMaskTexture(textureMask)
            i = i + 1
            textureMask = textureToStrip:GetMaskTexture(i)
        end
    end
    local textureParent = textureToStrip:GetParent()
    if textureParent then
        for _, textureRegion in ipairs({ textureParent:GetRegions() }) do
            if textureRegion:IsObjectType("Texture") and textureRegion ~= textureToStrip and textureRegion:IsShown() then
                textureRegion:SetTexture(nil)
                textureRegion:Hide()
            end
        end
    end
end

local function SizeIconsInCooldownViewer(viewerName, iconSize)
    if not viewerName or not iconSize then return end
    local viewer = _G[viewerName]
    if not viewer then return end
    local icons = {viewer:GetChildren()}
    if viewerName == "BuffIconCooldownViewer" then
        for i, icon in ipairs(icons) do
            if not icon.layoutIndex and not icon:GetID() then
                icon._creationOrder = icon._creationOrder or i
            end
        end
    end
    table.sort(icons, function(a, b) local la = a.layoutIndex or a:GetID() or a._creationOrder or 0 local lb = b.layoutIndex or b:GetID() or b._creationOrder or 0 return la < lb end)
    for _, icon in ipairs(icons) do
        if icon then
            icon:SetSize(iconSize, iconSize)
        end
    end
end

local function AdjustChargeCount(cooldownViewer)
    local CooldownManagerDB = BCDM.db.global
    local GeneralDB = CooldownManagerDB.General
    local CooldownViewerDB = CooldownManagerDB[CooldownViewerToDB[cooldownViewer]]
    for _, child in ipairs({ _G[cooldownViewer]:GetChildren() }) do
        if child and child.ChargeCount and child.ChargeCount.Current then
            local current = child.ChargeCount.Current
            current:SetFont(STANDARD_TEXT_FONT, CooldownViewerDB.Count.FontSize, GeneralDB.FontFlag)
            current:ClearAllPoints()
            current:SetPoint(CooldownViewerDB.Count.Anchors[1], child, CooldownViewerDB.Count.Anchors[2], CooldownViewerDB.Count.Anchors[3], CooldownViewerDB.Count.Anchors[4])
            current:SetTextColor(CooldownViewerDB.Count.Colour[1], CooldownViewerDB.Count.Colour[2], CooldownViewerDB.Count.Colour[3], 1)
        end
    end
    for _, child in ipairs({ _G[cooldownViewer]:GetChildren() }) do
        if child and child.Applications then
            local max = child.Applications.Applications
            max:SetFont(STANDARD_TEXT_FONT, CooldownViewerDB.Count.FontSize, GeneralDB.FontFlag)
            max:ClearAllPoints()
            max:SetPoint(CooldownViewerDB.Count.Anchors[1], child, CooldownViewerDB.Count.Anchors[2], CooldownViewerDB.Count.Anchors[3], CooldownViewerDB.Count.Anchors[4])
            max:SetTextColor(CooldownViewerDB.Count.Colour[1], CooldownViewerDB.Count.Colour[2], CooldownViewerDB.Count.Colour[3], 1)
        end
    end
end

local function SizeAllIcons()
    for cooldownViewer, _ in pairs(IconPerCooldownViewer) do
        local CooldownManagerDB = BCDM.db.global
        local CooldownViewerDB = CooldownManagerDB[CooldownViewerToDB[cooldownViewer]]
        local iconSize = (CooldownViewerDB.IconSize)
        SizeIconsInCooldownViewer(cooldownViewer, iconSize)
    end
end

local function SkinCooldownManager()
    local CooldownManagerDB = BCDM.db.global
    local EssentialDB = CooldownManagerDB.Essential
    local UtilityDB = CooldownManagerDB.Utility
    local BuffsDB = CooldownManagerDB.Buffs
    C_CVar.SetCVar("cooldownViewerEnabled", 1)
    SizeIconsInCooldownViewer("EssentialCooldownViewer", EssentialDB.IconSize)
    SizeIconsInCooldownViewer("UtilityCooldownViewer", UtilityDB.IconSize)
    SizeIconsInCooldownViewer("BuffIconCooldownViewer", BuffsDB.IconSize)
    for _, cooldownViewer in ipairs(CooldownManagerViewers) do
        for _, viewerChild in ipairs({_G[cooldownViewer]:GetChildren()}) do
            if viewerChild and not viewerChild.isSkinned then
                -- Skin Icon, Strip Textures
                if viewerChild.Icon then
                    StripTextures(viewerChild.Icon)
                    viewerChild.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                    viewerChild.isSkinned = true
                end
                -- Skin Cooldown
                if viewerChild.Cooldown then
                    viewerChild.Cooldown:ClearAllPoints()
                    viewerChild.Cooldown:SetPoint("TOPLEFT", viewerChild, "TOPLEFT", 0, 0)
                    viewerChild.Cooldown:SetPoint("BOTTOMRIGHT", viewerChild, "BOTTOMRIGHT", 0, 0)
                    viewerChild.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
                    viewerChild.Cooldown:SetDrawEdge(false)
                    viewerChild.Cooldown:SetDrawSwipe(true)
                    viewerChild.Cooldown:SetSwipeTexture("Interface\\Buttons\\WHITE8X8")
                end
                if viewerChild.CooldownFlash then
                    viewerChild.CooldownFlash:SetAlpha(0)
                end
                -- Add Border
                BCDM:AddPixelBorder(viewerChild)
            end
        end
    end
    AdjustChargeCount("EssentialCooldownViewer")
    AdjustChargeCount("UtilityCooldownViewer")
    AdjustChargeCount("BuffIconCooldownViewer")
end

local function NudgeViewer(viewerName, xOffset, yOffset)
    local viewer = _G[viewerName]
    if not viewer then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = viewer:GetPoint(1)
    viewer:ClearAllPoints()
    viewer:SetPoint(point, relativeTo, relativePoint, xOfs + xOffset, yOfs + yOffset)
end

local function PositionCooldownViewers()
    local EssentialCooldownViewer = _G["EssentialCooldownViewer"]
    local UtilityCooldownViewer = _G["UtilityCooldownViewer"]
    local BuffIconCooldownViewer = _G["BuffIconCooldownViewer"]
    local CooldownManagerDB = BCDM.db.global
    local EssentialDB = CooldownManagerDB.Essential
    local UtilityDB = CooldownManagerDB.Utility
    local BuffsDB = CooldownManagerDB.Buffs
    if EssentialCooldownViewer then
        EssentialCooldownViewer:ClearAllPoints()
        local anchorParent = EssentialDB.Anchors[2] or "UIParent"
        EssentialCooldownViewer:SetPoint(EssentialDB.Anchors[1], _G[anchorParent], EssentialDB.Anchors[3], EssentialDB.Anchors[4], EssentialDB.Anchors[5])
        NudgeViewer("EssentialCooldownViewer", -0.1, 0)
    end
    if UtilityCooldownViewer then
        UtilityCooldownViewer:ClearAllPoints()
        local anchorParent = UtilityDB.Anchors[2] or "UIParent"
        UtilityCooldownViewer:SetPoint(UtilityDB.Anchors[1], _G[anchorParent], UtilityDB.Anchors[3], UtilityDB.Anchors[4], UtilityDB.Anchors[5])
        NudgeViewer("UtilityCooldownViewer", 0, 0)
    end
    if BuffIconCooldownViewer then
        BuffIconCooldownViewer:ClearAllPoints()
        local anchorParent = BuffsDB.Anchors[2] or "UIParent"
        BuffIconCooldownViewer:SetPoint(BuffsDB.Anchors[1], _G[anchorParent], BuffsDB.Anchors[3], BuffsDB.Anchors[4], BuffsDB.Anchors[5])
        NudgeViewer("BuffIconCooldownViewer", 0, 0)
    end
end

local function FetchCooldownTextRegion(cooldown)
    if not cooldown then return end
    if cooldown.FUIText then
        return cooldown.FUIText
    end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region:GetObjectType() == "FontString" then
            cooldown.FUIText = region
            return region
        end
    end
end

local function ApplyCooldownText(cooldownViewer)
    local CooldownManagerDB = BCDM.db.global
    local GeneralDB = CooldownManagerDB.General
    local CooldownTextDB = GeneralDB.CooldownText
    local Viewer = _G[cooldownViewer]
    if not Viewer then return end
    for _, icon in ipairs({ Viewer:GetChildren() }) do
        if icon and icon.Cooldown then
            local textRegion = FetchCooldownTextRegion(icon.Cooldown)
            if textRegion then
                textRegion:SetFont(STANDARD_TEXT_FONT, CooldownTextDB.FontSize, GeneralDB.FontFlag)
                textRegion:SetTextColor(CooldownTextDB.Colour[1], CooldownTextDB.Colour[2], CooldownTextDB.Colour[3], 1)
                textRegion:ClearAllPoints()
                textRegion:SetPoint(CooldownTextDB.Anchors[1], icon, CooldownTextDB.Anchors[2], CooldownTextDB.Anchors[3], CooldownTextDB.Anchors[4])
            end
        end
    end
end

function BCDM:SetupCooldownManager()
    PositionCooldownViewers()
    for cooldownViewer, _ in pairs(IconPerCooldownViewer) do ApplyCooldownText(cooldownViewer) end
    hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function() PositionCooldownViewers() SizeAllIcons() end)
    hooksecurefunc(EditModeManagerFrame, "ExitEditMode", function() PositionCooldownViewers() SizeAllIcons() end)
    for _, cooldownViewer in ipairs(CooldownManagerViewers) do
        hooksecurefunc(_G[cooldownViewer], "RefreshLayout", function() SkinCooldownManager() PositionCooldownViewers() SizeAllIcons() end)
    end
end

function BCDM:UpdateCooldownViewer(cooldownViewer)
    SizeIconsInCooldownViewer(cooldownViewer, BCDM.db.global[CooldownViewerToDB[cooldownViewer]].IconSize)
    AdjustChargeCount(cooldownViewer)
    if _G[cooldownViewer] and _G[cooldownViewer].Layout then
        _G[cooldownViewer]:Layout()
    end
    PositionCooldownViewers()
end

function BCDM:RefreshAllViewers()
    BCDM:UpdateCooldownViewer("EssentialCooldownViewer")
    BCDM:UpdateCooldownViewer("UtilityCooldownViewer")
    BCDM:UpdateCooldownViewer("BuffIconCooldownViewer")
end