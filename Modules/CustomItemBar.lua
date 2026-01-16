local _, BCDM = ...

local function ApplyCooldownText(cooldown)
    if not cooldown then return end
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CooldownTextDB = CooldownManagerDB.CooldownManager.General.CooldownText
    if not cooldown.CustomBarCooldownText then
        for _, region in ipairs({ cooldown:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                cooldown.CustomBarCooldownText = region
                break
            end
        end
    end
    local region = cooldown.CustomBarCooldownText
    if not region then return end
    if CooldownTextDB.ScaleByIconSize then
        local iconWidth = cooldown:GetWidth()
        local scaleFactor = iconWidth / 36
        region:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize * scaleFactor, GeneralDB.FontFlag)
    else
        region:SetFont(BCDM.Media.Font, CooldownTextDB.FontSize, GeneralDB.FontFlag)
    end
    region:SetTextColor(unpack(CooldownTextDB.Colour))
    if GeneralDB.Fonts.Shadow.Enabled then
        region:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
        region:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
    else
        region:SetShadowColor(0, 0, 0, 0)
        region:SetShadowOffset(0, 0)
    end
    return region
end

local function FetchItemData(itemId)
    local itemCount = C_Item.GetItemCount(itemId)
    if itemId == 224464 or itemId == 5512 then itemCount = C_Item.GetItemCount(itemId, false, true) end
    local startTime, durationTime = C_Item.GetItemCooldown(itemId)
    return itemCount, startTime, durationTime
end

local function CreateCustomIcon(itemId)
    local CooldownManagerDB = BCDM.db.profile
    local GeneralDB = CooldownManagerDB.General
    local CustomDB = CooldownManagerDB.CooldownManager.Item
    if not itemId then return end
    if not C_Item.GetItemInfo(itemId) then return end

    local customIcon = CreateFrame("Button", "BCDM_Custom_" .. itemId, UIParent, "BackdropTemplate")
    customIcon:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BCDM.db.profile.CooldownManager.General.BorderSize, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    customIcon:SetBackdropBorderColor(0, 0, 0, 1)
    customIcon:SetSize(CustomDB.IconSize, CustomDB.IconSize)
    customIcon:SetPoint(CustomDB.Layout[1], _G[CustomDB.Layout[2]], CustomDB.Layout[3], CustomDB.Layout[4], CustomDB.Layout[5])
    customIcon:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    customIcon:RegisterEvent("PLAYER_ENTERING_WORLD")
    customIcon:RegisterEvent("ITEM_COUNT_CHANGED")

    local HighLevelContainer = CreateFrame("Frame", nil, customIcon)
    HighLevelContainer:SetAllPoints(customIcon)
    HighLevelContainer:SetFrameLevel(customIcon:GetFrameLevel() + 999)

    customIcon.Charges = HighLevelContainer:CreateFontString(nil, "OVERLAY")
    customIcon.Charges:SetFont(BCDM.Media.Font, CustomDB.Text.FontSize, GeneralDB.Fonts.FontFlag)
    customIcon.Charges:SetPoint(CustomDB.Text.Layout[1], customIcon, CustomDB.Text.Layout[2], CustomDB.Text.Layout[3], CustomDB.Text.Layout[4])
    customIcon.Charges:SetTextColor(CustomDB.Text.Colour[1], CustomDB.Text.Colour[2], CustomDB.Text.Colour[3], 1)
    customIcon.Charges:SetText(tostring(select(1, FetchItemData(itemId)) or ""))
    if GeneralDB.Fonts.Shadow.Enabled then
        customIcon.Charges:SetShadowColor(GeneralDB.Fonts.Shadow.Colour[1], GeneralDB.Fonts.Shadow.Colour[2], GeneralDB.Fonts.Shadow.Colour[3], GeneralDB.Fonts.Shadow.Colour[4])
        customIcon.Charges:SetShadowOffset(GeneralDB.Fonts.Shadow.OffsetX, GeneralDB.Fonts.Shadow.OffsetY)
    else
        customIcon.Charges:SetShadowColor(0, 0, 0, 0)
        customIcon.Charges:SetShadowOffset(0, 0)
    end

    customIcon.Cooldown = CreateFrame("Cooldown", nil, customIcon, "CooldownFrameTemplate")
    customIcon.Cooldown:SetAllPoints(customIcon)
    customIcon.Cooldown:SetDrawEdge(false)
    customIcon.Cooldown:SetDrawSwipe(true)
    customIcon.Cooldown:SetSwipeColor(0, 0, 0, 0.8)
    customIcon.Cooldown:SetHideCountdownNumbers(false)
    customIcon.Cooldown:SetReverse(false)

    customIcon:HookScript("OnEvent", function(self, event, ...)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "PLAYER_ENTERING_WORLD" or event == "ITEM_COUNT_CHANGED" then
            local itemCount, startTime, durationTime = FetchItemData(itemId)
            if itemCount then
                customIcon.Charges:SetText(tostring(itemCount))
                customIcon.Cooldown:SetCooldown(startTime, durationTime)
                if itemCount <= 0 then
                    customIcon.Icon:SetDesaturated(true)
                    customIcon.Charges:SetText("")
                else
                    customIcon.Icon:SetDesaturated(false)
                    customIcon.Charges:SetText(tostring(itemCount))
                end
            end
        end
    end)

    customIcon.Icon = customIcon:CreateTexture(nil, "BACKGROUND")
    customIcon.Icon:SetPoint("TOPLEFT", customIcon, "TOPLEFT", 1, -1)
    customIcon.Icon:SetPoint("BOTTOMRIGHT", customIcon, "BOTTOMRIGHT", -1, 1)
    local iconZoom = BCDM.db.profile.CooldownManager.General.IconZoom * 0.5
    customIcon.Icon:SetTexCoord(iconZoom, 1 - iconZoom, iconZoom, 1 - iconZoom)
    customIcon.Icon:SetTexture(select(10, C_Item.GetItemInfo(itemId)))

    return customIcon
end

local function CreateCustomIcons(iconTable)
    local Items = BCDM.db.profile.CooldownManager.Item.Items

    local isWarlock = select(2, UnitClass("player")) == "WARLOCK"
    local pactOfGluttony = C_SpellBook.IsSpellKnown(386689)

    local healthstoneToSkip = nil
    if isWarlock then
        if pactOfGluttony then
            healthstoneToSkip = 5512
        else
            healthstoneToSkip = 224464
        end
    end

    wipe(iconTable)

    if Items then
        local items = {}
        for itemId, data in pairs(Items) do
            if data.isActive and itemId ~= healthstoneToSkip then
                table.insert(items, {id = itemId, index = data.layoutIndex})
            end
        end

        table.sort(items, function(a, b) return a.index < b.index end)

        for _, item in ipairs(items) do
            local customItem = CreateCustomIcon(item.id)
            if customItem then
                table.insert(iconTable, customItem)
            end
        end
    end
end

local function LayoutCustomItemBar()
    local CooldownManagerDB = BCDM.db.profile
    local CustomDB = CooldownManagerDB.CooldownManager.Item
    local customItemBarIcons = {}

    local growthDirection = CustomDB.GrowthDirection or "RIGHT"

    local anchorFlipMap = {
        ["LEFT"] = "RIGHT",
        ["RIGHT"] = "LEFT",
        ["TOPLEFT"] = "TOPRIGHT",
        ["TOPRIGHT"] = "TOPLEFT",
        ["BOTTOMLEFT"] = "BOTTOMRIGHT",
        ["BOTTOMRIGHT"] = "BOTTOMLEFT",
        ["TOP"] = "TOP",
        ["BOTTOM"] = "BOTTOM",
        ["CENTER"] = "CENTER"
    }

    local containerAnchorFrom = CustomDB.Layout[1]
    if growthDirection == "LEFT" then containerAnchorFrom = anchorFlipMap[CustomDB.Layout[1]] or CustomDB.Layout[1] end

    if not BCDM.CustomItemBarContainer then
        BCDM.CustomItemBarContainer = CreateFrame("Frame", "BCDM_CustomItemBar", UIParent, "BackdropTemplate")
        BCDM.CustomItemBarContainer:SetSize(1, 1)
        BCDM.CustomItemBarContainer:SetFrameStrata("LOW")
    end

    BCDM.CustomItemBarContainer:ClearAllPoints()
    BCDM.CustomItemBarContainer:SetPoint(containerAnchorFrom, _G[CustomDB.Layout[2]], CustomDB.Layout[3], CustomDB.Layout[4], CustomDB.Layout[5])

    for _, child in ipairs({BCDM.CustomItemBarContainer:GetChildren()}) do child:UnregisterAllEvents() child:Hide() child:SetParent(nil) end

    CreateCustomIcons(customItemBarIcons)

    local iconSize = CustomDB.IconSize
    local iconSpacing = CustomDB.Spacing

    for i, itemIcon in ipairs(customItemBarIcons) do
        itemIcon:SetParent(BCDM.CustomItemBarContainer)
        itemIcon:SetSize(iconSize, iconSize)
        itemIcon:ClearAllPoints()

        if growthDirection == "RIGHT" then
            if i == 1 then
                itemIcon:SetPoint("LEFT", BCDM.CustomItemBarContainer, "LEFT", 0, 0)
            else
                itemIcon:SetPoint("LEFT", customItemBarIcons[i - 1], "RIGHT", iconSpacing, 0)
            end
        elseif growthDirection == "LEFT" then
            if i == 1 then
                itemIcon:SetPoint("RIGHT", BCDM.CustomItemBarContainer, "RIGHT", 0, 0)
            else
                itemIcon:SetPoint("RIGHT", customItemBarIcons[i - 1], "LEFT", -iconSpacing, 0)
            end
        elseif growthDirection == "UP" then
            if i == 1 then
                itemIcon:SetPoint("BOTTOM", BCDM.CustomItemBarContainer, "BOTTOM", 0, 0)
            else
                itemIcon:SetPoint("BOTTOM", customItemBarIcons[i - 1], "TOP", 0, iconSpacing)
            end
        elseif growthDirection == "DOWN" then
            if i == 1 then
                itemIcon:SetPoint("TOP", BCDM.CustomItemBarContainer, "TOP", 0, 0)
            else
                itemIcon:SetPoint("TOP", customItemBarIcons[i - 1], "BOTTOM", 0, -iconSpacing)
            end
        end
        ApplyCooldownText(itemIcon.Cooldown)
        itemIcon:Show()
    end

    if #customItemBarIcons > 0 then
        local totalWidth, totalHeight = 0, 0
        if growthDirection == "RIGHT" or growthDirection == "LEFT" then
            totalWidth = (#customItemBarIcons * iconSize) + ((#customItemBarIcons - 1) * iconSpacing)
            totalHeight = iconSize
        elseif growthDirection == "UP" or growthDirection == "DOWN" then
            totalWidth = iconSize
            totalHeight = (#customItemBarIcons * iconSize) + ((#customItemBarIcons - 1) * iconSpacing)
        end
        BCDM.CustomItemBarContainer:SetWidth(totalWidth)
        BCDM.CustomItemBarContainer:SetHeight(totalHeight)
    else
        BCDM.CustomItemBarContainer:SetWidth(1)
        BCDM.CustomItemBarContainer:SetHeight(1)
    end

    BCDM.CustomItemBarContainer:Show()
end

function BCDM:SetupCustomItemBar()
    LayoutCustomItemBar()
end

function BCDM:UpdateCustomItemBar()
    local CooldownManagerDB = BCDM.db.profile
    local CustomDB = CooldownManagerDB.CooldownManager.Item
    if BCDM.CustomItemBarContainer then
        BCDM.CustomItemBarContainer:ClearAllPoints()
        BCDM.CustomItemBarContainer:SetPoint(CustomDB.Layout[1], _G[CustomDB.Layout[2]], CustomDB.Layout[3], CustomDB.Layout[4], CustomDB.Layout[5])
    end
    LayoutCustomItemBar()
end

function BCDM:AdjustItemLayoutIndex(direction, itemId)
    local CooldownManagerDB = BCDM.db.profile
    local CustomDB = CooldownManagerDB.CooldownManager.Item
    local Items = CustomDB.Items

    if not Items then return end

    local currentIndex = Items[itemId].layoutIndex
    local newIndex = currentIndex + direction

    local totalItems = 0

    for _ in pairs(Items) do totalItems = totalItems + 1 end
    if newIndex < 1 or newIndex > totalItems then return end

    for _, data in pairs(Items) do
        if data.layoutIndex == newIndex then
            data.layoutIndex = currentIndex
            break
        end
    end

    Items[itemId].layoutIndex = newIndex

    BCDM:UpdateCustomItemBar()
end

function BCDM:AdjustItemList(itemId, adjustingHow)
    local CooldownManagerDB = BCDM.db.profile
    local CustomDB = CooldownManagerDB.CooldownManager.Item
    local Items = CustomDB.Items

    if not Items then Items = {} end

    if adjustingHow == "add" then
        local maxIndex = 0
        for _, data in pairs(Items) do
            if data.layoutIndex > maxIndex then
                maxIndex = data.layoutIndex
            end
        end
        Items[itemId] = { isActive = true, layoutIndex = maxIndex + 1 }
    elseif adjustingHow == "remove" then
        Items[itemId] = nil
    end

    BCDM:UpdateCustomItemBar()
end

function BCDM:FetchTrinketSlots()
    -- Loop through CharacterFrame
    -- Get ItemID for Trinket Slots (13 & 14)
    -- Return the ItemID and check if it's usable
    local isItemUsable = C_Item.IsUsableItem(itemInfo)
end