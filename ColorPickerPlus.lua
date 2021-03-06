-- ColorPickerPlus hooks into the standard Color Picker to provide
-- 1. text entry for colors (RGB and hex values) and alpha (for opacity),
-- 2. copy to and paste from a dialog buffer,
-- 3. color swatches for the copied color and for the starting color.
--
-- Modified by SweedJesus (github.com/SweedJesus) to work with Ace2 for
-- 1.12 vanilla WoW servers (i.e. Nostalrius)

ColorPickerPlus = AceLibrary("AceAddon-2.0"):new(
"AceEvent-2.0",
"AceHook-2.1")

local ColorPickerPlus = ColorPickerPlus
local initialized = nil
local colorBuffer = {}
local editingText = nil

-- function ColorPickerPlus:OnInitialize()
--     self:RegisterChatCommand({ "/cpp" }, {
--         type = "group",
--         args = {
--             show = {
--                 name = "Show frame",
--                desc = "Show the color picker frame",
--                 type = "execute",
--                 func = function()
--                     ColorPickerFrame:Show()
--                 end
--             }
--         }
--     })
-- end

function ColorPickerPlus:OnEnable()
    -- Event received when starting, reloading or zoning
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function ColorPickerPlus:PLAYER_ENTERING_WORLD()
    if initialized then return end
    initialized = true

    -- hook the function to call when dialog first shows
    ColorPickerPlus:HookScript(ColorPickerFrame, "OnShow", function(self)
        ColorPickerPlus.hooks[ColorPickerFrame].OnShow(self)
        local self = self

        -- get color that will be replaced
        local r, g, b = ColorPickerFrame:GetColorRGB()
        ColorPPOldColorSwatch:SetTexture(r,g,b)

        -- show/hide the alpha box
        if ColorPickerFrame.hasOpacity then
            ColorPPBoxA:Show()
            ColorPPBoxLabelA:Show()
            ColorPPBoxH:SetScript("OnTabPressed", function(self) ColorPPBoxA:SetFocus()  end)
            ColorPickerPlus:UpdateAlphaText()

        else
            ColorPPBoxA:Hide()
            ColorPPBoxLabelA:Hide()
            ColorPPBoxH:SetScript("OnTabPressed", function(self) ColorPPBoxR:SetFocus()  end)
        end

    end)

    -- hook the function to call on a change of color via ColorSelect
    ColorPickerPlus:HookScript(ColorPickerFrame, "OnColorSelect", function(self)
        ColorPickerPlus.hooks[ColorPickerFrame].OnColorSelect(self)
        local self, arg1, arg2, arg3 = self;
        if not editingText then
            ColorPickerPlus:UpdateColorTexts()
        end
    end)

    -- hook the function to call on a change of color via OpacitySlider
    ColorPickerPlus:HookScript(OpacitySliderFrame, "OnValueChanged", function(self)
        local self = self;
        ColorPickerPlus.hooks[OpacitySliderFrame].OnValueChanged(self)
        if not editingText then
            ColorPickerPlus:UpdateAlphaText()
        end
    end)

    -- make the Color Picker dialog a bit taller, to make room for edit boxes
    local h = ColorPickerFrame:GetHeight()
    ColorPickerFrame:SetHeight(h+40)

    -- move the Color Swatch
    ColorSwatch:ClearAllPoints()
    ColorSwatch:SetPoint("TOPLEFT", ColorPickerFrame, "TOPLEFT", 230, -45)

    -- add Color Swatch for original color
    local t = ColorPickerFrame:CreateTexture("ColorPPOldColorSwatch")
    local w, h = ColorSwatch:GetWidth(), ColorSwatch:GetHeight()
    t:SetWidth(w*0.75)
    t:SetHeight(h*0.75)
    t:SetTexture(0,0,0)
    -- OldColorSwatch to appear beneath ColorSwatch
    t:SetDrawLayer("BORDER")
    t:SetPoint("BOTTOMLEFT", "ColorSwatch", "TOPRIGHT", -(w/2), -(h/3))

    -- add Color Swatch for the copied color
    t = ColorPickerFrame:CreateTexture("ColorPPCopyColorSwatch")
    t:SetWidth(w*0.75)
    t:SetHeight(h*0.75)
    t:SetTexture(0,0,0)
    t:Show()

    -- add copy button to the ColorPickerFrame
    local b = CreateFrame("Button", "ColorPPCopy", ColorPickerFrame, "UIPanelButtonTemplate")
    b:SetText("Copy")
    b:SetWidth("70")
    b:SetHeight("22")
    b:SetScale(0.80)
    b:SetPoint("TOPLEFT", "ColorSwatch", "BOTTOMLEFT", -15, -5)

    -- copy color into buffer on button click
    b:SetScript("OnClick", function(self)

        if IsShiftKeyDown() == 1 then
            -- this is a hidden utility for providing the WoW 0 to 1 based color numbers
            local r, g, b = ColorPickerFrame:GetColorRGB()
            print("ColorPickerPlus decimal -- r = "..string.format("%.3f", r).."  g = "..string.format("%.3f", g).."  b = "..string.format("%.3f",b))
            return
        end

        -- copy current dialog colors into buffer
        local c = colorBuffer
        c.r, c.g, c.b = ColorPickerFrame:GetColorRGB()

        -- enable Paste button and display copied color into swatch
        ColorPPPaste:Enable()
        local t = ColorPPCopyColorSwatch
        t:SetTexture(c.r, c.g, c.b)
        t:Show()

        if ColorPickerFrame.hasOpacity then
            c.a = OpacitySliderFrame:GetValue()
        else
            c.a = nil
        end
    end)

    -- add paste button to the ColorPickerFrame
    b = CreateFrame("Button", "ColorPPPaste", ColorPickerFrame, "UIPanelButtonTemplate")
    b:SetText("Paste")
    b:SetWidth("70")
    b:SetHeight("22")
    b:SetScale(0.8)
    b:SetPoint("TOPLEFT", "ColorPPCopy", "BOTTOMLEFT", 0, -7)
    b:Disable()  -- enable when something has been copied

    -- paste color on button click, updating frame components
    b:SetScript("OnClick", function(self)
        local c = colorBuffer
        ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
        ColorSwatch:SetTexture(c.r, c.g, c.b)
        if ColorPickerFrame.hasOpacity then
            if c.a then  --color copied had an alpha value
                OpacitySliderFrame:SetValue(c.a)
            end
        end
    end)

    -- locate Color Swatch for copy color
    ColorPPCopyColorSwatch:SetPoint("LEFT", "ColorSwatch", "LEFT")
    ColorPPCopyColorSwatch:SetPoint("TOP", "ColorPPPaste", "BOTTOM", 0, -5)

    -- move the Opacity Slider Frame to align with bottom of Copy ColorSwatch
    OpacitySliderFrame:ClearAllPoints()
    OpacitySliderFrame:SetPoint("BOTTOM", "ColorPPCopyColorSwatch", "BOTTOM", 0, -3)
    OpacitySliderFrame:SetPoint("RIGHT", "ColorPickerFrame", "RIGHT", -35, 0)

    -- set up edit box frames and interior label and text areas
    local boxes = { "R", "G", "B", "H", "A" }
    for i = 1, table.getn(boxes) do

        local rgb = boxes[i]
        local box = CreateFrame("EditBox", "ColorPPBox"..rgb, ColorPickerFrame, "InputBoxTemplate")
        box:SetID(i)
        box:SetFrameStrata("DIALOG")
        box:SetAutoFocus(false)
        box:SetTextInsets(0,5,0,0)
        box:SetJustifyH("RIGHT")
        box:SetHeight(24)

        if i == 4 then
            -- Hex entry box
            box:SetMaxLetters(6)
            box:SetWidth(56)
            box:SetNumeric(false)
        else
            box:SetMaxLetters(3)
            box:SetWidth(32)
            box:SetNumeric(true)
        end
        box:SetPoint("TOP", "ColorPickerWheel", "BOTTOM", 0, -15)

        -- label
        local label = box:CreateFontString("ColorPPBoxLabel"..rgb, "ARTWORK", "GameFontNormalSmall")
        label:SetTextColor(1, 1, 1)
        label:SetPoint("RIGHT", "ColorPPBox"..rgb, "LEFT", -5, 0)
        if i == 4 then
            -- Hex entry box
            label:SetText("#")
        else
            label:SetText(rgb)
        end

        -- set up scripts to handle event appropriately
        if i == 5 then
            -- Alpha entry box
            box:SetScript("OnEscapePressed", function()	box:ClearFocus() ColorPickerPlus:UpdateAlphaText() end)
            box:SetScript("OnEnterPressed", function() box:ClearFocus() ColorPickerPlus:UpdateAlphaText() end)
            box:SetScript("OnTextChanged", function() ColorPickerPlus:UpdateAlpha(box) end)
        else
            box:SetScript("OnEscapePressed", function()	box:ClearFocus() ColorPickerPlus:UpdateColorTexts() end)
            box:SetScript("OnEnterPressed", function() box:ClearFocus() ColorPickerPlus:UpdateColorTexts() end)
            box:SetScript("OnTextChanged", function() ColorPickerPlus:UpdateColor(box) end)
        end

        box:SetScript("OnEditFocusGained", function() --[[box:SetCursorPosition(0)]] box:HighlightText() end)
        box:SetScript("OnEditFocusLost", function() box:HighlightText(0,0) end)
        box:SetScript("OnTextSet", function() --[[self:ClearFocus()]] end)
        --box:SetScript("OnChar", function(self, text)	print(text) end)
        box:Show()
    end

    -- finish up with placement
    ColorPPBoxA:SetPoint("RIGHT", "OpacitySliderFrame", "RIGHT", 10, 0)
    ColorPPBoxH:SetPoint("RIGHT", "ColorPPPaste", "RIGHT")
    ColorPPBoxB:SetPoint("RIGHT", "ColorPPPaste", "LEFT", -40, 0)
    ColorPPBoxG:SetPoint("RIGHT", "ColorPPBoxB", "LEFT", -25, 0)
    ColorPPBoxR:SetPoint("RIGHT", "ColorPPBoxG", "LEFT", -25, 0)

    -- define the order of tab cursor movement
    ColorPPBoxR:SetScript("OnTabPressed", function(self) ColorPPBoxG:SetFocus() end)
    ColorPPBoxG:SetScript("OnTabPressed", function(self) ColorPPBoxB:SetFocus()  end)
    ColorPPBoxB:SetScript("OnTabPressed", function(self) ColorPPBoxH:SetFocus()  end)
    ColorPPBoxA:SetScript("OnTabPressed", function(self) ColorPPBoxR:SetFocus()  end)
    --  tab cursor movement from Hex box depends on whether alpha field is visible, so set in OnShow

    -- make the color picker movable.
    local cpf = ColorPickerFrame
    local mover = CreateFrame('Frame', nil, cpf)
    mover:SetPoint('TOPLEFT', cpf, 'TOP', -60, 0)
    mover:SetPoint('BOTTOMRIGHT', cpf, 'TOP', 60, -15)
    mover:EnableMouse(true)
    mover:SetScript('OnMouseDown', function() cpf:StartMoving() end)
    mover:SetScript('OnMouseUp', function() cpf:StopMovingOrSizing() end)
    mover:SetScript('OnHide', function() cpf:StopMovingOrSizing() end)
    cpf:SetUserPlaced(true)
    cpf:SetClampedToScreen(true)  -- keep color picker frame on-screen
    --cpf:SetClampRectInsets(120,-120,0,90) -- but allow for dragging partially off to sides and down
    --local b = cfg:GetBackdrop()
    --b.insets =
    cpf:EnableKeyboard(false)
end

function ColorPickerPlus:UpdateColor(tbox)

    local r, g, b = ColorPickerFrame:GetColorRGB()

    local id = tbox:GetID()

    if id == 1 then
        r = string.format("%d", tbox:GetNumber())
        if not r then r = 0 end
        r = r/255
    elseif id == 2 then
        g = string.format("%d", tbox:GetNumber())
        if not g then g = 0 end
        g = g/255
    elseif id == 3 then
        b = string.format("%d", tbox:GetNumber())
        if not b then b = 0 end
        b = b/255
    elseif id == 4 then
        -- hex values
        if tbox:GetNumLetters() == 6 then
            local rgb = tbox:GetText()

            r = tonumber(strsub(rgb, 0, 2), 16)
            g = tonumber(strsub(rgb, 3, 4), 16)
            b = tonumber(strsub(rgb, 5, 6), 16)

            if not r then r = 0 else r = r/255 end
            if not g then g = 0 else g = g/255 end
            if not b then b = 0 else b = b/255 end
        else return
        end
    end

    -- This takes care of updating the hex entry when changing rgb fields and vice versa
    ColorPickerPlus:UpdateColorTexts(r,g,b)

    editingText = true
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorSwatch:SetTexture(r, g, b)
    editingText = nil

end


function ColorPickerPlus:UpdateColorTexts(r, g, b)
    if not r then r, g, b = ColorPickerFrame:GetColorRGB() end

    r = math.floor (r*255 + 0.5)
    g = math.floor (g*255 + 0.5)
    b = math.floor (b*255 + 0.5)

    ColorPPBoxR:SetText(string.format("%d", r))
    ColorPPBoxG:SetText(string.format("%d", g))
    ColorPPBoxB:SetText(string.format("%d", b))
    ColorPPBoxH:SetText(string.format("%.2x", r)..string.format("%.2x",g)..string.format("%.2x", b))
end

function ColorPickerPlus:UpdateAlpha(tbox)
    local a = tonumber(tbox:GetText())
    if a > 100 then
        a = 100
        ColorPPBoxA:SetText(string.format("%d", a))
    end
    a = a/100
    editingText = true
    OpacitySliderFrame:SetValue(a)
    editingText = nil
end

function ColorPickerPlus:UpdateAlphaText()

    local a = OpacitySliderFrame:GetValue()
    a = a * 100
    a = math.floor(a +.05)
    ColorPPBoxA:SetText(string.format("%d", a))

end

