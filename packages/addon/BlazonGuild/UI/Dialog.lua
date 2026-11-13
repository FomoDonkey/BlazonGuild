-- BlazonGuild's own dialog. The game's StaticPopup breaks when an addon opens one while the player uses
-- the gamepad interface (learned from Olympus's Dialog.lua, MIT), so every question the addon asks goes
-- through this frame instead: a plate with a title, paragraphs, optional bullet lines and two buttons.
local _, BG = ...
local UI, C = BG.UI, BG.color

local WIDTH, PAD = 560, 26
local dialog

local function build()
  local f = CreateFrame("Frame", "BlazonGuildDialog", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetSize(WIDTH, 300)
  f:SetPoint("CENTER", 0, 60)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()

  local plate = UI.Plate(f, { corners = 30, rail = 0.32 })
  plate:SetAllPoints()
  plate:SetFrameLevel(f:GetFrameLevel())

  f.title = UI.Text(f, 18, C.goldTitle, { font = BG.font.display })
  f.title:SetPoint("TOPLEFT", PAD, -PAD)
  f.title:SetPoint("RIGHT", -PAD, 0)
  f.rule = f:CreateTexture(nil, "ARTWORK")
  f.rule:SetColorTexture(1, 1, 1, 1)
  f.rule:SetGradient("HORIZONTAL", CreateColor(C.gold[1], C.gold[2], C.gold[3], 0.6), CreateColor(C.gold[1], C.gold[2], C.gold[3], 0))
  f.rule:SetHeight(1)
  f.rule:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -10)
  f.rule:SetPoint("RIGHT", -PAD, 0)

  f.blocks = {}
  f.primary = UI.Button(f, "Aceptar", { primary = true, height = 30, width = 190 })
  f.primary:SetPoint("BOTTOMRIGHT", -PAD, PAD - 4)
  f.secondary = UI.Button(f, "Cancelar", { height = 30, width = 150 })
  f.secondary:SetPoint("RIGHT", f.primary, "LEFT", -12, 0)

  tinsert(UISpecialFrames, "BlazonGuildDialog") -- Escape closes it, as "secondary"
  f:SetScript("OnHide", function(self)
    local pending = self.onDismiss
    self.onDismiss = nil
    if pending then
      pending()
    end
    -- (a question that came by itself while another was on screen: its turn now)
    if UI.dialogQueue and UI.dialogQueue[1] then
      local nextSpec = table.remove(UI.dialogQueue, 1)
      C_Timer.After(0.3, function()
        UI.Dialog(nextSpec)
      end)
    end
  end)
  return f
end

local function block(f, i, bullet)
  local b = f.blocks[i]
  if not b then
    b = { text = UI.Text(f, 13, C.text, { wrap = true }), icon = f:CreateTexture(nil, "ARTWORK") }
    b.icon:SetTexture(BG.media .. "lozenge.png")
    b.icon:SetSize(9, 9)
    f.blocks[i] = b
  end
  b.text:ClearAllPoints()
  b.icon:SetShown(bullet)
  return b
end

-- spec: { title, items = { "paragraph" | { bullet = "text" } | { note = "small grey text" } },
--         choices = { { label, fn }, ... } | nil (a row of buttons above the main two),
--         primary = { label, fn }, secondary = { label, fn } | nil, dismiss = fn | nil }
-- Each button runs its own fn; Escape runs only spec.dismiss (no answer is assumed from it).
-- spec.wait: a question that comes by itself (another addon's permission, sharing the gear…): if another is on
-- screen, it waits its turn instead of covering it.
function UI.Dialog(spec)
  dialog = dialog or build()
  local f = dialog
  if spec.wait and f:IsShown() then
    UI.dialogQueue = UI.dialogQueue or {}
    table.insert(UI.dialogQueue, spec)
    return
  end
  if f:IsShown() then
    f.onDismiss = nil
    f:Hide()
  end
  f.title:SetText(spec.title or "BlazonGuild")
  local y = -PAD - 30
  local used = 0
  for i, item in ipairs(spec.items or {}) do
    local isBullet = type(item) == "table" and item.bullet ~= nil
    local isNote = type(item) == "table" and item.note ~= nil
    local b = block(f, i, isBullet)
    local text = type(item) == "table" and (item.bullet or item.note) or item
    local left = isBullet and (PAD + 18) or PAD
    b.text:SetPoint("TOPLEFT", left, y)
    b.text:SetWidth(WIDTH - left - PAD)
    b.text:SetFont(BG.font.body, isNote and 11 or 13, "")
    local c = isNote and C.text3 or C.text
    b.text:SetTextColor(c[1], c[2], c[3])
    b.text:SetText(text)
    b.text:Show()
    if isBullet then
      b.icon:SetPoint("TOPLEFT", PAD + 2, y - 3)
    end
    local h = b.text:GetStringHeight() or 16
    y = y - math.max(h, 14) - (isBullet and 8 or 14)
    used = i
  end
  for i = used + 1, #f.blocks do
    f.blocks[i].text:Hide()
    f.blocks[i].icon:Hide()
  end

  -- A row of choices (for example, how long to mute someone): each runs its fn and closes the dialog.
  f.choices = f.choices or {}
  local choices = spec.choices or {}
  local n = #choices
  local gap = 6
  local cw = n > 0 and math.floor((WIDTH - PAD * 2 - gap * (n - 1)) / n) or 0
  for i, ch in ipairs(choices) do
    local b = f.choices[i]
    if not b then
      b = UI.Button(f, ch.label, { height = 28 })
      f.choices[i] = b
    end
    b.text:SetText(ch.label)
    b:SetWidth(cw)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", PAD + (i - 1) * (cw + gap), y - 2)
    b:SetScript("OnClick", function()
      f.onDismiss = nil
      f:Hide()
      ch.fn()
    end)
    b:Show()
  end
  for i = n + 1, #f.choices do
    f.choices[i]:Hide()
  end
  if n > 0 then
    y = y - 40
  end

  f.primary.text:SetText(spec.primary and spec.primary.label or "Aceptar")
  f.primary:SetScript("OnClick", function()
    f.onDismiss = nil
    f:Hide()
    BG.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    if spec.primary and spec.primary.fn then
      spec.primary.fn()
    end
  end)
  f.secondary:SetShown(spec.secondary ~= nil)
  if spec.secondary then
    f.secondary.text:SetText(spec.secondary.label)
    f.secondary:SetScript("OnClick", function()
      f.onDismiss = nil
      f:Hide()
      if spec.secondary.fn then
        spec.secondary.fn()
      end
    end)
  end
  f.onDismiss = spec.dismiss -- Escape: neither button was chosen
  f:SetHeight(-y + 30 + PAD + 6)
  f:Show()
  BG.Sound("IG_MAINMENU_OPEN")
  return f
end

function UI.DialogShown()
  return dialog ~= nil and dialog:IsShown()
end
