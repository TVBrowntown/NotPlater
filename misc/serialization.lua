-- Add these functions to NotPlater.lua or create a new file misc/serialization.lua

-- Base64 encoding/decoding (simplified version)
local base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return base64chars:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function base64decode(data)
    data = string.gsub(data, '[^'..base64chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(base64chars:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- Table serialization
local function serializeTable(t)
    local result = {}
    local function serialize(obj, path)
        path = path or ""
        if type(obj) == "table" then
            for k, v in pairs(obj) do
                local newPath = path == "" and tostring(k) or path .. "." .. tostring(k)
                serialize(v, newPath)
            end
        else
            local valueStr
            if type(obj) == "string" then
                valueStr = string.format("%q", obj)
            elseif type(obj) == "boolean" then
                valueStr = tostring(obj)
            elseif type(obj) == "number" then
                valueStr = tostring(obj)
            else
                valueStr = "nil"
            end
            table.insert(result, path .. "=" .. valueStr)
        end
    end
    serialize(t)
    return table.concat(result, ";")
end

local function deserializeTable(str)
    local result = {}
    
    for assignment in string.gmatch(str, "([^;]+)") do
        local path, value = string.match(assignment, "(.+)=(.+)")
        if path and value then
            -- Parse the value
            local parsedValue
            if value == "true" then
                parsedValue = true
            elseif value == "false" then
                parsedValue = false
            elseif tonumber(value) then
                parsedValue = tonumber(value)
            elseif string.match(value, '^".*"$') then
                -- Remove quotes and handle escaped characters
                parsedValue = string.gsub(string.sub(value, 2, -2), '\\"', '"')
            else
                parsedValue = value
            end
            
            -- Set the value in the result table
            local current = result
            local keys = {}
            for key in string.gmatch(path, "([^.]+)") do
                table.insert(keys, key)
            end
            
            for i = 1, #keys - 1 do
                local key = keys[i]
                if not current[key] then
                    current[key] = {}
                end
                current = current[key]
            end
            
            current[keys[#keys]] = parsedValue
        end
    end
    
    return result
end

-- Simple compression (RLE - Run Length Encoding for repeated characters)
local function compress(str)
    local result = ""
    local i = 1
    while i <= #str do
        local char = string.sub(str, i, i)
        local count = 1
        
        -- Count consecutive identical characters
        while i + count <= #str and string.sub(str, i + count, i + count) == char do
            count = count + 1
        end
        
        if count > 3 then
            -- Use RLE for sequences longer than 3
            result = result .. char .. "~" .. count .. "~"
        else
            -- Just repeat the character
            result = result .. string.rep(char, count)
        end
        
        i = i + count
    end
    return result
end

local function decompress(str)
    return string.gsub(str, "(.)(~)(%d+)(~)", function(char, sep1, count, sep2)
        return string.rep(char, tonumber(count))
    end)
end

-- Rewritten ExportSettingsString with larger window
function NotPlater:ExportSettingsString()
    if not self.db or not self.db.profile then
        self:Print("No settings to export!")
        return
    end
    
    -- Serialize the profile
    local serialized = serializeTable(self.db.profile)
    
    -- Compress
    local compressed = compress(serialized)
    
    -- Encode to base64
    local encoded = base64encode(compressed)
    
    -- Add version header
    local exportString = "!NP1!" .. encoded
    
    -- Calculate screen dimensions for half-screen sizing
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local frameWidth = math.min(800, screenWidth * 0.6)  -- 60% of screen width, max 800
    local frameHeight = math.min(600, screenHeight * 0.7) -- 70% of screen height, max 600
    
    -- Create export frame
    local exportFrame = self.exportFrame
    if not exportFrame then
        exportFrame = CreateFrame("Frame", "NotPlaterExportFrame", UIParent)
        exportFrame:SetFrameStrata("DIALOG")
        exportFrame:SetToplevel(true)
        exportFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        exportFrame:SetBackdropColor(0.1, 0.1, 0.2, 0.95)
        exportFrame:SetMovable(true)
        exportFrame:EnableMouse(true)
        exportFrame:RegisterForDrag("LeftButton")
        exportFrame:SetScript("OnDragStart", exportFrame.StartMoving)
        exportFrame:SetScript("OnDragStop", exportFrame.StopMovingOrSizing)
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, exportFrame)
        titleBar:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", 8, -8)
        titleBar:SetPoint("TOPRIGHT", exportFrame, "TOPRIGHT", -32, -8)
        titleBar:SetHeight(30)
        titleBar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true, tileSize = 16,
        })
        titleBar:SetBackdropColor(0.2, 0.2, 0.4, 0.8)
        
        local title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("NotPlater Settings Export")
        title:SetTextColor(1, 1, 1, 1)
        
        -- Text display area with scroll
        local scrollFrame = CreateFrame("ScrollFrame", "NotPlaterExportScroll", exportFrame)
        scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -35, 80)
        
        -- Scroll background
        scrollFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        scrollFrame:SetBackdropColor(0, 0, 0, 0.8)
        scrollFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        
        -- Content frame
        local contentFrame = CreateFrame("Frame", nil, scrollFrame)
        local contentWidth = frameWidth - 80
        contentFrame:SetSize(contentWidth, 100)
        
        -- Text display
        local textDisplay = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        textDisplay:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 10, -10)
        textDisplay:SetWidth(contentWidth - 20)
        textDisplay:SetJustifyH("LEFT")
        textDisplay:SetJustifyV("TOP")
        textDisplay:SetWordWrap(true)
        textDisplay:SetNonSpaceWrap(true)
        textDisplay:SetTextColor(0.9, 0.9, 1, 1)
        
        contentFrame.textDisplay = textDisplay
        scrollFrame:SetScrollChild(contentFrame)
        
        -- Scroll bar
        local scrollBar = CreateFrame("Slider", nil, scrollFrame)
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 20, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 20, 16)
        scrollBar:SetWidth(20)
        scrollBar:SetOrientation("VERTICAL")
        scrollBar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
        scrollBar:GetThumbTexture():SetSize(20, 24)
        scrollBar:SetBackdrop({
            bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
            edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
            tile = true, tileSize = 8, edgeSize = 8,
            insets = { left = 3, right = 3, top = 6, bottom = 6 }
        })
        
        scrollBar:SetScript("OnValueChanged", function(self, value)
            scrollFrame:SetVerticalScroll(value)
        end)
        
        -- Hidden EditBox for copying
        local hiddenEditBox = CreateFrame("EditBox", nil, exportFrame)
        hiddenEditBox:Hide()
        hiddenEditBox:SetMultiLine(true)
        hiddenEditBox:SetMaxLetters(0)
        hiddenEditBox:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", -2000, 0) -- Way off screen
        
        -- Button area
        local buttonFrame = CreateFrame("Frame", nil, exportFrame)
        buttonFrame:SetPoint("BOTTOMLEFT", exportFrame, "BOTTOMLEFT", 8, 8)
        buttonFrame:SetPoint("BOTTOMRIGHT", exportFrame, "BOTTOMRIGHT", -8, 8)
        buttonFrame:SetHeight(65)
        buttonFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true, tileSize = 16,
        })
        buttonFrame:SetBackdropColor(0.15, 0.15, 0.3, 0.8)
        
        -- Copy button (larger)
        local copyBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
        copyBtn:SetSize(120, 32)
        copyBtn:SetPoint("LEFT", buttonFrame, "LEFT", 20, 10)
        copyBtn:SetText("Copy to Clipboard")
        copyBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        
        copyBtn:SetScript("OnClick", function()
            hiddenEditBox:SetText(exportFrame.currentExportString or "")
            hiddenEditBox:Show()
            hiddenEditBox:SetFocus()
            hiddenEditBox:HighlightText()
            NotPlater:Print("|cff00ff00Export string copied to clipboard!|r Press Ctrl+V to paste")
            
            C_Timer.After(0.1, function()
                hiddenEditBox:Hide()
            end)
        end)
        
        -- Info text
        local infoText = buttonFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        infoText:SetPoint("CENTER", buttonFrame, "CENTER", 0, 10)
        infoText:SetText("Click 'Copy to Clipboard' then share the string with others")
        infoText:SetTextColor(1, 1, 0.7, 1)
        
        -- Stats text
        local statsText = buttonFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        statsText:SetPoint("CENTER", buttonFrame, "CENTER", 0, -10)
        statsText:SetTextColor(0.7, 0.7, 0.7, 1)
        buttonFrame.statsText = statsText
        
        -- Close button (larger)
        local closeBtn = CreateFrame("Button", nil, exportFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", exportFrame, "TOPRIGHT", -5, -5)
        closeBtn:SetSize(32, 32)
        closeBtn:SetScript("OnClick", function() 
            exportFrame:Hide()
            hiddenEditBox:Hide()
        end)
        
        -- Store references
        exportFrame.scrollFrame = scrollFrame
        exportFrame.contentFrame = contentFrame
        exportFrame.hiddenEditBox = hiddenEditBox
        exportFrame.scrollBar = scrollBar
        exportFrame.buttonFrame = buttonFrame
        
        self.exportFrame = exportFrame
    end
    
    -- Resize frame to calculated dimensions
    exportFrame:SetSize(frameWidth, frameHeight)
    exportFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    -- Update content
    exportFrame.currentExportString = exportString
    local textDisplay = exportFrame.contentFrame.textDisplay
    
    textDisplay:SetText(exportString)
    local textHeight = textDisplay:GetStringHeight()
    
    -- Pre-select text for copying
    exportFrame.hiddenEditBox:SetText(exportString)
    exportFrame.hiddenEditBox:HighlightText()
    
    -- Adjust content height and scroll
    exportFrame.contentFrame:SetHeight(math.max(textHeight + 20, frameHeight - 150))
    
    local scrollHeight = textHeight + 20 - exportFrame.scrollFrame:GetHeight()
    if scrollHeight > 0 then
        exportFrame.scrollBar:SetMinMaxValues(0, scrollHeight)
        exportFrame.scrollBar:SetValue(0)
        exportFrame.scrollBar:Show()
    else
        exportFrame.scrollBar:Hide()
    end
    
    -- Update stats
    exportFrame.buttonFrame.statsText:SetText(string.format("String length: %d characters | Compression ratio: %.1f%%", 
        #exportString, (#exportString / #serialized) * 100))
    
    exportFrame:Show()
    self:Print("Export window opened - settings ready to copy!")
end

-- Import function
function NotPlater:ImportSettingsString(importString)
    if not importString or importString == "" then
        self:Print("No import string provided!")
        return false
    end
    
    -- Check version header
    if not string.match(importString, "^!NP1!") then
        self:Print("Invalid or unsupported import string format!")
        return false
    end
    
    -- Remove header
    local encoded = string.sub(importString, 6)
    
    local success, result = pcall(function()
        -- Decode from base64
        local compressed = base64decode(encoded)
        
        -- Decompress
        local serialized = decompress(compressed)
        
        -- Deserialize
        local settings = deserializeTable(serialized)
        
        return settings
    end)
    
    if not success then
        self:Print("Failed to import settings: Invalid format or corrupted data")
        return false
    end
    
    -- Apply the settings
    for key, value in pairs(result) do
        self.db.profile[key] = value
    end
    
    -- Reload the addon with new settings
    self:Reload()
    
    self:Print("Settings imported successfully!")
    return true
end

-- Rewritten import window
function NotPlater:ShowImportFrame()
    -- Calculate screen dimensions
    local screenWidth = GetScreenWidth()
    local screenHeight = GetScreenHeight()
    local frameWidth = math.min(800, screenWidth * 0.6)
    local frameHeight = math.min(600, screenHeight * 0.7)
    
    local importFrame = self.importFrame
    if not importFrame then
        importFrame = CreateFrame("Frame", "NotPlaterImportFrame", UIParent)
        importFrame:SetFrameStrata("DIALOG")
        importFrame:SetToplevel(true)
        importFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        importFrame:SetBackdropColor(0.1, 0.2, 0.1, 0.95)
        importFrame:SetMovable(true)
        importFrame:EnableMouse(true)
        importFrame:RegisterForDrag("LeftButton")
        importFrame:SetScript("OnDragStart", importFrame.StartMoving)
        importFrame:SetScript("OnDragStop", importFrame.StopMovingOrSizing)
        
        -- Title bar
        local titleBar = CreateFrame("Frame", nil, importFrame)
        titleBar:SetPoint("TOPLEFT", importFrame, "TOPLEFT", 8, -8)
        titleBar:SetPoint("TOPRIGHT", importFrame, "TOPRIGHT", -32, -8)
        titleBar:SetHeight(30)
        titleBar:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true, tileSize = 16,
        })
        titleBar:SetBackdropColor(0.2, 0.4, 0.2, 0.8)
        
        local title = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
        title:SetText("NotPlater Settings Import")
        title:SetTextColor(1, 1, 1, 1)
        
        -- Input area
        local editBox = CreateFrame("EditBox", nil, importFrame)
        editBox:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
        editBox:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -20, 100)
        editBox:SetMultiLine(true)
        editBox:SetMaxLetters(0)
        editBox:SetFontObject(GameFontHighlight)
        editBox:SetAutoFocus(true)
        editBox:EnableMouse(true)
        editBox:SetScript("OnEscapePressed", function() editBox:ClearFocus() end)
        
        editBox:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 8, right = 8, top = 8, bottom = 8 }
        })
        editBox:SetBackdropColor(0, 0, 0, 0.7)
        editBox:SetBackdropBorderColor(0.4, 0.6, 0.4, 1)
        
        -- Placeholder text
        local placeholderText = editBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        placeholderText:SetPoint("TOPLEFT", editBox, "TOPLEFT", 10, -10)
        placeholderText:SetText("Paste your NotPlater export string here (starts with !NP1!)")
        placeholderText:SetTextColor(0.5, 0.5, 0.5, 1)
        
        editBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if text and text ~= "" then
                placeholderText:Hide()
            else
                placeholderText:Show()
            end
        end)
        
        -- Button area
        local buttonFrame = CreateFrame("Frame", nil, importFrame)
        buttonFrame:SetPoint("BOTTOMLEFT", importFrame, "BOTTOMLEFT", 8, 8)
        buttonFrame:SetPoint("BOTTOMRIGHT", importFrame, "BOTTOMRIGHT", -8, 8)
        buttonFrame:SetHeight(85)
        buttonFrame:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = true, tileSize = 16,
        })
        buttonFrame:SetBackdropColor(0.15, 0.3, 0.15, 0.8)
        
        -- Import button
        local importBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
        importBtn:SetSize(120, 32)
        importBtn:SetPoint("LEFT", buttonFrame, "LEFT", 20, 10)
        importBtn:SetText("Import Settings")
        importBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        
        importBtn:SetScript("OnClick", function()
            local importText = editBox:GetText()
            if importText and importText ~= "" then
                if NotPlater:ImportSettingsString(importText) then
                    importFrame:Hide()
                end
            else
                NotPlater:Print("|cffff4444Please paste an export string first!|r")
                editBox:SetFocus()
            end
        end)
        
        -- Clear button
        local clearBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
        clearBtn:SetSize(80, 32)
        clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 15, 0)
        clearBtn:SetText("Clear")
        clearBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        
        clearBtn:SetScript("OnClick", function()
            editBox:SetText("")
            editBox:SetFocus()
        end)
        
        -- Paste button
        local pasteBtn = CreateFrame("Button", nil, buttonFrame, "UIPanelButtonTemplate")
        pasteBtn:SetSize(100, 32)
        pasteBtn:SetPoint("LEFT", clearBtn, "RIGHT", 15, 0)
        pasteBtn:SetText("Paste & Import")
        pasteBtn:GetFontString():SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        
        pasteBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            -- Simulate paste - user still needs to Ctrl+V
            NotPlater:Print("Please press Ctrl+V to paste, then click Import Settings")
        end)
        
        -- Info text
        local infoText = buttonFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        infoText:SetPoint("CENTER", buttonFrame, "CENTER", 0, 10)
        infoText:SetText("Paste export string above and click 'Import Settings'")
        infoText:SetTextColor(1, 1, 0.7, 1)
        
        -- Warning text
        local warningText = buttonFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        warningText:SetPoint("CENTER", buttonFrame, "CENTER", 0, -15)
        warningText:SetText("⚠ This will overwrite your current NotPlater settings")
        warningText:SetTextColor(1, 0.7, 0.3, 1)
        
        -- Close button
        local closeBtn = CreateFrame("Button", nil, importFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", importFrame, "TOPRIGHT", -5, -5)
        closeBtn:SetSize(32, 32)
        closeBtn:SetScript("OnClick", function() importFrame:Hide() end)
        
        importFrame.editBox = editBox
        self.importFrame = importFrame
    end
    
    -- Resize and show
    importFrame:SetSize(frameWidth, frameHeight)
    importFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    
    importFrame.editBox:SetText("")
    importFrame.editBox:SetFocus()
    importFrame:Show()
    
    self:Print("Import window opened - paste your export string!")
end