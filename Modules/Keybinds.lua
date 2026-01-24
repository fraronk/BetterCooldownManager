-- Keybinds Module for BetterCooldownManager
-- Displays keybind text on cooldown icons

local _, BCDM = ...

local Keybinds = {}
BCDM.Keybinds = Keybinds

local LSM = BCDM.LSM

local BCDM_KEYBIND_DEBUG = false
local function PrintDebug(...)
    if BCDM_KEYBIND_DEBUG then
        print("[BCDM Keybinds]", ...)
    end
end

local isModuleEnabled = false
local areHooksInitialized = false

local NUM_ACTIONBAR_BUTTONS = 12
local MAX_ACTION_SLOTS = 180

-- Viewer name to settings key mapping
local viewersSettingKey = {
    EssentialCooldownViewer = "Essential",
    UtilityCooldownViewer = "Utility",
    BCDM_CustomCooldownViewer = "Custom",
    BCDM_AdditionalCustomCooldownViewer = "AdditionalCustom",
    BCDM_CustomItemBar = "Item",
    BCDM_TrinketBar = "Trinket",
    BCDM_CustomItemSpellBar = "ItemSpell",
}

local DEFAULT_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function GetFontPath(fontName)
    if not fontName or fontName == "" then
        return DEFAULT_FONT_PATH
    end

    if LSM then
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath then
            return fontPath
        end
    end
    return DEFAULT_FONT_PATH
end

-- Caches to avoid re-scanning all action slots/bindings on every icon update
local bindingKeyCache = {}
local bindingCacheValid = false

local slotMappingCache = {}
local slotMappingCacheKey = 0

local keybindCache = {}
local keybindCacheValid = false

local iconSpellCache = {}

local cachedStateData = {
    page = 1,
    bonusOffset = 0,
    form = 0,
    hasOverride = false,
    hasVehicle = false,
    hasTemp = false,
    hash = 0,
    valid = false,
}

local function IsKeybindEnabledForAnyViewer()
    if not BCDM.db or not BCDM.db.profile then
        return false
    end

    local keybindSettings = BCDM.db.profile.CooldownManager.Keybinds
    if not keybindSettings then
        return false
    end

    for _, viewerSettingName in pairs(viewersSettingKey) do
        local viewerSettings = keybindSettings[viewerSettingName]
        if viewerSettings and viewerSettings.Enabled then
            return true
        end
    end
    return false
end

local function GetKeybindSettings(viewerSettingName)
    local defaults = {
        Enabled = false,
        Anchor = "TOPRIGHT",
        FontSize = 12,
        OffsetX = -2,
        OffsetY = -2,
    }

    if not BCDM.db or not BCDM.db.profile then
        return defaults
    end

    local keybindSettings = BCDM.db.profile.CooldownManager.Keybinds
    if not keybindSettings or not keybindSettings[viewerSettingName] then
        return defaults
    end

    local viewerSettings = keybindSettings[viewerSettingName]
    return {
        Enabled = viewerSettings.Enabled or defaults.Enabled,
        Anchor = viewerSettings.Anchor or defaults.Anchor,
        FontSize = viewerSettings.FontSize or defaults.FontSize,
        OffsetX = viewerSettings.OffsetX or defaults.OffsetX,
        OffsetY = viewerSettings.OffsetY or defaults.OffsetY,
    }
end

local function UpdateCachedState()
    cachedStateData.page = GetActionBarPage and GetActionBarPage() or 1
    cachedStateData.bonusOffset = GetBonusBarOffset and GetBonusBarOffset() or 0
    cachedStateData.form = GetShapeshiftFormID and GetShapeshiftFormID() or 0
    cachedStateData.hasOverride = HasOverrideActionBar and HasOverrideActionBar() or false
    cachedStateData.hasVehicle = HasVehicleActionBar and HasVehicleActionBar() or false
    cachedStateData.hasTemp = HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() or false

    cachedStateData.hash = cachedStateData.page + (cachedStateData.bonusOffset * 100) + (cachedStateData.form * 10000)
    if cachedStateData.hasOverride then
        cachedStateData.hash = cachedStateData.hash + 1000000
    end
    if cachedStateData.hasVehicle then
        cachedStateData.hash = cachedStateData.hash + 2000000
    end
    if cachedStateData.hasTemp then
        cachedStateData.hash = cachedStateData.hash + 4000000
    end

    cachedStateData.valid = true
end

local function GetCachedStateHash()
    if not cachedStateData.valid then
        UpdateCachedState()
    end
    return cachedStateData.hash
end

local function RebuildBindingCache()
    wipe(bindingKeyCache)

    local patterns = {
        "ACTIONBUTTON",
        "MULTIACTIONBAR1BUTTON",
        "MULTIACTIONBAR2BUTTON",
        "MULTIACTIONBAR3BUTTON",
        "MULTIACTIONBAR4BUTTON",
        "MULTIACTIONBAR5BUTTON",
        "MULTIACTIONBAR6BUTTON",
        "MULTIACTIONBAR7BUTTON",
    }

    for _, pattern in ipairs(patterns) do
        for j = 1, NUM_ACTIONBAR_BUTTONS do
            local bindingKey = pattern .. j
            bindingKeyCache[bindingKey] = GetBindingKey(bindingKey) or ""
        end
    end

    -- Support for Bartender4
    for barNum = 1, 10 do
        for buttonNum = 1, 12 do
            local bindingKey = "CLICK BT4Button" .. ((barNum - 1) * 12 + buttonNum) .. ":LeftButton"
            local key = GetBindingKey(bindingKey)
            if key then
                bindingKeyCache["BT4Bar" .. barNum .. "Button" .. buttonNum] = key
            end
        end
    end

    bindingCacheValid = true
end

local function GetCachedBindingKey(bindingKey)
    if not bindingCacheValid then
        RebuildBindingCache()
    end
    return bindingKeyCache[bindingKey] or ""
end

local function CalculateActionSlot(buttonID, barType)
    if not cachedStateData.valid then
        UpdateCachedState()
    end
    local page = 1

    if barType == "main" then
        page = cachedStateData.page
        if cachedStateData.bonusOffset > 0 then
            page = 6 + cachedStateData.bonusOffset
        end
    elseif barType == "multibarbottomleft" then
        page = 6
    elseif barType == "multibarbottomright" then
        page = 5
    elseif barType == "multibarright" then
        page = 3
    elseif barType == "multibarleft" then
        page = 4
    elseif barType == "multibar5" then
        page = 13
    elseif barType == "multibar6" then
        page = 14
    elseif barType == "multibar7" then
        page = 15
    end

    if LE_EXPANSION_LEVEL_CURRENT >= 11 then
        if barType == "multibarbottomleft" then
            page = 5
        elseif barType == "multibarbottomright" then
            page = 6
        end
    end

    local safePage = math.max(1, page)
    local safeButtonID = math.max(1, math.min(buttonID, NUM_ACTIONBAR_BUTTONS))
    return safeButtonID + ((safePage - 1) * NUM_ACTIONBAR_BUTTONS)
end

local function GetCachedSlotMapping()
    local currentHash = GetCachedStateHash()
    if slotMappingCacheKey == currentHash and slotMappingCache then
        return slotMappingCache
    end

    local mapping = {}

    for buttonID = 1, NUM_ACTIONBAR_BUTTONS do
        local slot = CalculateActionSlot(buttonID, "main")
        mapping[slot] = "ACTIONBUTTON" .. buttonID
    end

    local barMappings = {
        { barType = "multibarbottomleft", pattern = "MULTIACTIONBAR1BUTTON" },
        { barType = "multibarbottomright", pattern = "MULTIACTIONBAR2BUTTON" },
        { barType = "multibarright", pattern = "MULTIACTIONBAR3BUTTON" },
        { barType = "multibarleft", pattern = "MULTIACTIONBAR4BUTTON" },
        { barType = "multibar5", pattern = "MULTIACTIONBAR5BUTTON" },
        { barType = "multibar6", pattern = "MULTIACTIONBAR6BUTTON" },
        { barType = "multibar7", pattern = "MULTIACTIONBAR7BUTTON" },
    }

    if LE_EXPANSION_LEVEL_CURRENT >= 11 then
        barMappings[1].pattern = "MULTIACTIONBAR2BUTTON"
        barMappings[2].pattern = "MULTIACTIONBAR1BUTTON"
    end

    for _, barData in ipairs(barMappings) do
        for buttonID = 1, NUM_ACTIONBAR_BUTTONS do
            local slot = CalculateActionSlot(buttonID, barData.barType)
            mapping[slot] = barData.pattern .. buttonID
        end
    end

    slotMappingCache = mapping
    slotMappingCacheKey = currentHash
    return mapping
end

local function ValidateAndBuildKeybindCache()
    if keybindCacheValid then
        return
    end

    local slotMapping = GetCachedSlotMapping()
    for slot, keybindPattern in pairs(slotMapping) do
        local key = GetCachedBindingKey(keybindPattern)
        if key and key ~= "" then
            keybindCache[slot] = key
        end
    end
    keybindCacheValid = true
end

local function GetKeybindForSlot(slot)
    if not slot or slot < 1 or slot > MAX_ACTION_SLOTS then
        return nil
    end
    return keybindCache[slot]
end

local function GetFormattedKeybind(key)
    if not key or key == "" then
        return ""
    end

    local upperKey = key:upper()

    upperKey = upperKey:gsub("SHIFT%-", "S")
    upperKey = upperKey:gsub("CTRL%-", "C")
    upperKey = upperKey:gsub("ALT%-", "A")
    upperKey = upperKey:gsub("STRG%-", "S")

    upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?UP", "MWU")
    upperKey = upperKey:gsub("MOUSE%s?WHEEL%s?DOWN", "MWD")
    upperKey = upperKey:gsub("MOUSE%s?BUTTON%s?", "M")
    upperKey = upperKey:gsub("BUTTON", "M")

    upperKey = upperKey:gsub("NUMPAD%s?PLUS", "N+")
    upperKey = upperKey:gsub("NUMPAD%s?MINUS", "N-")
    upperKey = upperKey:gsub("NUMPAD%s?MULTIPLY", "N*")
    upperKey = upperKey:gsub("NUMPAD%s?DIVIDE", "N/")
    upperKey = upperKey:gsub("NUMPAD%s?DECIMAL", "N.")
    upperKey = upperKey:gsub("NUMPAD%s?ENTER", "NEnt")
    upperKey = upperKey:gsub("NUMPAD%s?", "N")
    upperKey = upperKey:gsub("NUM%s?", "N")

    upperKey = upperKey:gsub("PAGE%s?UP", "PGU")
    upperKey = upperKey:gsub("PAGE%s?DOWN", "PGD")
    upperKey = upperKey:gsub("INSERT", "INS")
    upperKey = upperKey:gsub("DELETE", "DEL")
    upperKey = upperKey:gsub("SPACEBAR", "Spc")
    upperKey = upperKey:gsub("ENTER", "Ent")
    upperKey = upperKey:gsub("ESCAPE", "Esc")
    upperKey = upperKey:gsub("TAB", "Tab")
    upperKey = upperKey:gsub("CAPS%s?LOCK", "Caps")
    upperKey = upperKey:gsub("HOME", "Hom")
    upperKey = upperKey:gsub("END", "End")

    return upperKey
end

function Keybinds:GetActionsTableBySpellId()
    PrintDebug("Building Actions Table By Spell ID")

    local startSlot = 1
    local endSlot = 12

    if GetBonusBarOffset() > 0 then
        startSlot = 72 + (GetBonusBarOffset() - 1) * NUM_ACTIONBAR_BUTTONS + 1
        endSlot = startSlot + NUM_ACTIONBAR_BUTTONS - 1
    end

    local result = {}
    for slot = startSlot, endSlot do
        local actionType, id, subType = GetActionInfo(slot)
        if not result[id] then
            if (actionType == "macro" and subType == "spell") or (actionType == "spell") then
                result[id] = slot
            elseif actionType == "macro" then
                local macroSpellID = GetMacroSpell(id)
                if macroSpellID then
                    result[macroSpellID] = slot
                end
            end
        end
    end

    for slot = 13, MAX_ACTION_SLOTS do
        if (slot <= 72 or slot > 120) and HasAction(slot) then
            local actionType, id, subType = GetActionInfo(slot)
            if not result[id] then
                if (actionType == "macro" and subType == "spell") or (actionType == "spell") then
                    result[id] = slot
                elseif actionType == "macro" then
                    local macroSpellID = GetMacroSpell(id)
                    if macroSpellID then
                        result[macroSpellID] = slot
                    end
                end
            end
        end
    end
    return result
end

function Keybinds:GetActionsTableByItemId()
    PrintDebug("Building Actions Table By Item ID")

    local result = {}
    for slot = 1, MAX_ACTION_SLOTS do
        if HasAction(slot) then
            local actionType, id = GetActionInfo(slot)
            if actionType == "item" and id and not result[id] then
                result[id] = slot
            elseif actionType == "macro" then
                -- Check if macro contains an item
                local _, _, macroItemId = GetMacroItem(id)
                if macroItemId and not result[macroItemId] then
                    result[macroItemId] = slot
                end
            end
        end
    end
    return result
end

function Keybinds:FindKeybindForSpell(spellID, spellIdToSlotTable)
    if not spellID or spellID == 0 then
        return ""
    end

    local overrideSpellID = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
    local baseSpellID = C_Spell.GetBaseSpell and C_Spell.GetBaseSpell(spellID)

    local match = nil
    if spellIdToSlotTable[spellID] then
        match = spellIdToSlotTable[spellID]
    elseif overrideSpellID and spellIdToSlotTable[overrideSpellID] then
        match = spellIdToSlotTable[overrideSpellID]
    elseif baseSpellID and spellIdToSlotTable[baseSpellID] then
        match = spellIdToSlotTable[baseSpellID]
    end

    if match then
        local key = GetKeybindForSlot(match)
        if key and key ~= "" then
            return GetFormattedKeybind(key)
        end
    end

    return ""
end

function Keybinds:FindKeybindForItem(itemID, itemIdToSlotTable)
    if not itemID or itemID == 0 then
        return ""
    end

    local match = itemIdToSlotTable[itemID]
    if match then
        local key = GetKeybindForSlot(match)
        if key and key ~= "" then
            return GetFormattedKeybind(key)
        end
    end

    return ""
end

local function GetOrCreateKeybindText(icon, viewerSettingName)
    if icon.bcdmKeybindText and icon.bcdmKeybindText.text then
        return icon.bcdmKeybindText.text
    end

    local settings = GetKeybindSettings(viewerSettingName)
    icon.bcdmKeybindText = CreateFrame("Frame", nil, icon, "BackdropTemplate")
    icon.bcdmKeybindText:SetFrameLevel(icon:GetFrameLevel() + 4)
    local keybindText = icon.bcdmKeybindText:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    keybindText:SetPoint(settings.Anchor, icon, settings.Anchor, settings.OffsetX, settings.OffsetY)
    keybindText:SetTextColor(1, 1, 1, 1)
    keybindText:SetShadowColor(0, 0, 0, 1)
    keybindText:SetShadowOffset(1, -1)
    keybindText:SetDrawLayer("OVERLAY", 7)

    icon.bcdmKeybindText.text = keybindText
    return icon.bcdmKeybindText.text
end

local function GetKeybindFontName()
    if BCDM.db and BCDM.db.profile and BCDM.db.profile.CooldownManager.Keybinds then
        return BCDM.db.profile.CooldownManager.Keybinds.FontName
    end
    return BCDM.db.profile.General.Fonts.Font or "Friz Quadrata TT"
end

local function GetKeybindFontFlags()
    if BCDM.db and BCDM.db.profile and BCDM.db.profile.CooldownManager.Keybinds then
        return BCDM.db.profile.CooldownManager.Keybinds.FontFlags
    end
    return BCDM.db.profile.General.Fonts.FontFlag or "OUTLINE"
end

local function ApplyKeybindTextSettings(icon, viewerSettingName)
    if not icon.bcdmKeybindText then
        return
    end

    local settings = GetKeybindSettings(viewerSettingName)
    local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)

    icon.bcdmKeybindText:Show()
    keybindText:ClearAllPoints()
    keybindText:SetPoint(settings.Anchor, icon, settings.Anchor, settings.OffsetX, settings.OffsetY)

    local fontName = GetKeybindFontName()
    local fontPath = GetFontPath(fontName)
    local fontFlags = GetKeybindFontFlags()

    keybindText:SetFont(fontPath, settings.FontSize, fontFlags or "OUTLINE")
end

-- Extract spell ID from Blizzard cooldown viewer icons
local function ExtractSpellIDFromBlizzardIcon(icon)
    if icon.cooldownID then
        local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(icon.cooldownID)
        if info then
            return info.spellID
        end
    end
    return nil
end

-- Extract spell ID from BCDM custom icons
local function ExtractSpellIDFromCustomIcon(icon)
    if icon.spellID then
        return icon.spellID
    end
    -- Try to extract from frame name (e.g., "BCDM_Custom_12345")
    local frameName = icon:GetName()
    if frameName then
        local spellID = frameName:match("BCDM_Custom_(%d+)")
        if spellID then
            return tonumber(spellID)
        end
    end
    return nil
end

-- Extract item ID from BCDM item icons
local function ExtractItemIDFromIcon(icon)
    if icon.itemID then
        return icon.itemID
    end
    local frameName = icon:GetName()
    if frameName then
        local itemID = frameName:match("BCDM_Custom_(%d+)")
        if itemID then
            return tonumber(itemID)
        end
    end
    return nil
end

local function BuildIconSpellCacheForViewer(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    PrintDebug("BuildIconSpellCacheForViewer called for", viewerName)

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    iconSpellCache[viewerName] = iconSpellCache[viewerName] or {}
    wipe(iconSpellCache[viewerName])

    local children = { viewerFrame:GetChildren() }
    local actionsTableBySpellId = Keybinds:GetActionsTableBySpellId()
    local actionsTableByItemId = Keybinds:GetActionsTableByItemId()

    local isItemViewer = (settingName == "Item" or settingName == "Trinket" or settingName == "ItemSpell")
    local isBlizzardViewer = (settingName == "Essential" or settingName == "Utility")

    for _, child in ipairs(children) do
        if child and (child.Icon or child.icon) then
            local layoutIndex = child.layoutIndex or child:GetName() or tostring(child)
            local keybind = ""

            if isBlizzardViewer then
                local rawSpellID = ExtractSpellIDFromBlizzardIcon(child)
                if rawSpellID then
                    keybind = Keybinds:FindKeybindForSpell(rawSpellID, actionsTableBySpellId)
                end
            elseif isItemViewer then
                local itemID = ExtractItemIDFromIcon(child)
                if itemID then
                    keybind = Keybinds:FindKeybindForItem(itemID, actionsTableByItemId)
                    -- Also try spell lookup for items that cast spells
                    if keybind == "" then
                        local spellID = ExtractSpellIDFromCustomIcon(child)
                        if spellID then
                            keybind = Keybinds:FindKeybindForSpell(spellID, actionsTableBySpellId)
                        end
                    end
                end
            else
                -- Custom spell viewers
                local rawSpellID = ExtractSpellIDFromCustomIcon(child)
                if rawSpellID then
                    keybind = Keybinds:FindKeybindForSpell(rawSpellID, actionsTableBySpellId)
                end
            end

            local existingKeybind = (iconSpellCache[viewerName] and iconSpellCache[viewerName][layoutIndex] and iconSpellCache[viewerName][layoutIndex].keybind) or child._bcdm_keybind
            local finalKeybind = (keybind and keybind ~= "") and keybind or (existingKeybind or "")

            iconSpellCache[viewerName][layoutIndex] = {
                keybind = finalKeybind,
            }

            child._bcdm_keybind = finalKeybind
        end
    end
end

local function BuildAllIconSpellCaches()
    PrintDebug("BuildAllIconSpellCaches called")

    ValidateAndBuildKeybindCache()
    for viewerName, _ in pairs(viewersSettingKey) do
        BuildIconSpellCacheForViewer(viewerName)
    end

    return true
end

local function UpdateIconKeybind(icon, viewerSettingName)
    if not icon then
        return
    end

    local settings = GetKeybindSettings(viewerSettingName)
    if not settings.Enabled then
        if icon.bcdmKeybindText then
            icon.bcdmKeybindText:Hide()
        end
        return
    end

    local keybind = icon._bcdm_keybind

    if not keybind or keybind == "" then
        if icon.bcdmKeybindText then
            icon.bcdmKeybindText:Hide()
        end
        return
    end

    local keybindText = GetOrCreateKeybindText(icon, viewerSettingName)
    icon.bcdmKeybindText:Show()
    keybindText:SetText(keybind)
    keybindText:Show()
end

function Keybinds:UpdateViewerKeybinds(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child and (child.Icon or child.icon) then
            UpdateIconKeybind(child, settingName)
        end
    end
end

function Keybinds:UpdateAllKeybinds()
    for viewerName, _ in pairs(viewersSettingKey) do
        self:UpdateViewerKeybinds(viewerName)
        self:ApplyKeybindSettings(viewerName)
    end
end

function Keybinds:ApplyKeybindSettings(viewerName)
    local viewerFrame = _G[viewerName]
    if not viewerFrame then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    local children = { viewerFrame:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.bcdmKeybindText then
            ApplyKeybindTextSettings(child, settingName)
        end
    end
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if not isModuleEnabled then
        return
    end

    if event == "EDIT_MODE_LAYOUTS_UPDATED" then
        PrintDebug("EditMode layout changed - rebuilding cache")
        BuildAllIconSpellCaches()
        Keybinds:UpdateAllKeybinds()
    elseif event == "UPDATE_BINDINGS" then
        bindingCacheValid = false
        keybindCacheValid = false
        BuildAllIconSpellCaches()
        Keybinds:UpdateAllKeybinds()
    elseif event == "PLAYER_ENTERING_WORLD" then
        BuildAllIconSpellCaches()
        Keybinds:UpdateAllKeybinds()
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_BONUS_ACTIONBAR" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        keybindCacheValid = false
        cachedStateData.valid = false
        BuildAllIconSpellCaches()
        Keybinds:UpdateAllKeybinds()
    elseif event == "PLAYER_TALENT_UPDATE" or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_REGEN_DISABLED" or event == "ACTIONBAR_HIDEGRID" then
        C_Timer.After(0, function()
            bindingCacheValid = false
            keybindCacheValid = false
            cachedStateData.valid = false
            BuildAllIconSpellCaches()
            Keybinds:UpdateAllKeybinds()
        end)
    end
end)

function Keybinds:Shutdown()
    PrintDebug("Shutting down module")

    isModuleEnabled = false

    eventFrame:UnregisterAllEvents()

    wipe(bindingKeyCache)
    bindingCacheValid = false
    wipe(slotMappingCache)
    slotMappingCacheKey = 0
    wipe(keybindCache)
    keybindCacheValid = false
    wipe(iconSpellCache)
    cachedStateData.valid = false

    for viewerName, _ in pairs(viewersSettingKey) do
        local viewerFrame = _G[viewerName]
        if viewerFrame then
            local children = { viewerFrame:GetChildren() }
            for _, child in ipairs(children) do
                if child and child.bcdmKeybindText then
                    child.bcdmKeybindText:Hide()
                end
            end
        end
    end
end

function Keybinds:Enable()
    if isModuleEnabled then
        return
    end
    PrintDebug("Enabling module")

    isModuleEnabled = true

    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
    eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    eventFrame:RegisterEvent("UPDATE_BINDINGS")
    eventFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("ACTIONBAR_HIDEGRID")

    if not areHooksInitialized then
        areHooksInitialized = true

        -- Hook Blizzard viewers
        for viewerName, settingName in pairs(viewersSettingKey) do
            local viewerFrame = _G[viewerName]
            if viewerFrame and viewerFrame.RefreshLayout then
                hooksecurefunc(viewerFrame, "RefreshLayout", function()
                    if not isModuleEnabled then
                        return
                    end
                    PrintDebug("RefreshLayout called for viewer:", viewerName)
                    BuildIconSpellCacheForViewer(viewerName)
                    Keybinds:UpdateViewerKeybinds(viewerName)
                end)
            end
        end
    end

    BuildAllIconSpellCaches()
    Keybinds:UpdateAllKeybinds()
end

function Keybinds:Disable()
    if not isModuleEnabled then
        return
    end
    PrintDebug("Disabling module")

    self:Shutdown()
end

function Keybinds:Initialize()
    if not IsKeybindEnabledForAnyViewer() then
        PrintDebug("Not initializing - no viewers enabled")
        return
    end

    PrintDebug("Initializing module")

    self:Enable()
end

function Keybinds:OnSettingChanged(viewerSettingName)
    local shouldBeEnabled = IsKeybindEnabledForAnyViewer()

    if shouldBeEnabled and not isModuleEnabled then
        self:Enable()
    elseif not shouldBeEnabled and isModuleEnabled then
        self:Disable()
    elseif isModuleEnabled then
        if viewerSettingName then
            for viewerName, settingName in pairs(viewersSettingKey) do
                if settingName == viewerSettingName then
                    BuildIconSpellCacheForViewer(viewerName)
                    self:UpdateViewerKeybinds(viewerName)
                    self:ApplyKeybindSettings(viewerName)
                    return
                end
            end
        end
        self:UpdateAllKeybinds()
    end
end

-- Called when custom viewers are updated to refresh keybinds
function Keybinds:RefreshCustomViewerKeybinds(viewerName)
    if not isModuleEnabled then
        return
    end

    local settingName = viewersSettingKey[viewerName]
    if not settingName then
        return
    end

    C_Timer.After(0.1, function()
        BuildIconSpellCacheForViewer(viewerName)
        Keybinds:UpdateViewerKeybinds(viewerName)
        Keybinds:ApplyKeybindSettings(viewerName)
    end)
end
