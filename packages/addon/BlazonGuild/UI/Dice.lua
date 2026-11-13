-- Dice drawn with BlazonGuild's own pieces (no game art has the six faces): an ivory bone die with its dark pips,
-- and a table where a throw falls in from above, bounces, spins and settles on its faces. The pips are drawn
-- only when the die lies still (a texture turns, a group of them does not): while it tumbles you see the bone
-- spinning, then it lands, gives a little jump and shows its face.
local _, BG = ...
local UI, C = BG.UI, BG.color

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local BONE = { 0.93, 0.89, 0.78 }
local BONE_EDGE = { 0.66, 0.58, 0.44 }
local PIP = { 0.17, 0.11, 0.07 }

-- Where the pips go for each face, on a 3 x 3 grid (column, row).
local FACES = {
  { { 2, 2 } },
  { { 1, 1 }, { 3, 3 } },
  { { 1, 1 }, { 2, 2 }, { 3, 3 } },
  { { 1, 1 }, { 3, 1 }, { 1, 3 }, { 3, 3 } },
  { { 1, 1 }, { 3, 1 }, { 2, 2 }, { 1, 3 }, { 3, 3 } },
  { { 1, 1 }, { 3, 1 }, { 1, 2 }, { 3, 2 }, { 1, 3 }, { 3, 3 } },
}

-- One die: d:SetFace(1..6 or nil), d:SetLook("pick" | "hint" | "dim" | nil), d:SetSpin(radians or nil: lying still).
function UI.Die(parent, size)
  local d = CreateFrame("Button", nil, parent)
  d:SetSize(size, size)
  d.size = size
  d.shadow = d:CreateTexture(nil, "BACKGROUND")
  d.shadow:SetTexture(WHITE)
  d.shadow:SetVertexColor(0, 0, 0, 0.35)
  d.shadow:SetSize(size, size)
  d.shadow:SetPoint("CENTER", 3, -4)
  d.glow = d:CreateTexture(nil, "BORDER")
  d.glow:SetTexture(WHITE)
  d.glow:SetSize(size + 8, size + 8)
  d.glow:SetPoint("CENTER")
  d.glow:Hide()
  d.edge = d:CreateTexture(nil, "ARTWORK", nil, 1)
  d.edge:SetTexture(WHITE)
  d.edge:SetVertexColor(BONE_EDGE[1], BONE_EDGE[2], BONE_EDGE[3])
  d.edge:SetSize(size, size)
  d.edge:SetPoint("CENTER")
  d.body = d:CreateTexture(nil, "ARTWORK", nil, 2)
  d.body:SetTexture(WHITE)
  d.body:SetVertexColor(BONE[1], BONE[2], BONE[3])
  d.body:SetSize(size - 4, size - 4)
  d.body:SetPoint("CENTER")
  d.shine = d:CreateTexture(nil, "ARTWORK", nil, 3)
  d.shine:SetTexture(WHITE)
  d.shine:SetVertexColor(1, 1, 1, 0.22)
  d.shine:SetSize(size - 4, math.floor((size - 4) / 3))
  d.shine:SetPoint("TOP", d.body, "TOP")
  d.pips = {}
  local step = (size - 4) / 4
  local pip = math.max(5, math.floor(size * 0.17))
  for col = 1, 3 do
    for row = 1, 3 do
      local p = d:CreateTexture(nil, "OVERLAY")
      p:SetTexture(ROUND)
      p:SetVertexColor(PIP[1], PIP[2], PIP[3])
      p:SetSize(pip, pip)
      p:SetPoint("CENTER", d, "TOPLEFT", 2 + col * step, -(2 + row * step))
      p:Hide()
      d.pips[col * 10 + row] = p
    end
  end
  function d:SetFace(v)
    self.face = v
    for _, p in pairs(self.pips) do
      p:Hide()
    end
    for _, at in ipairs(v and FACES[v] or {}) do
      self.pips[at[1] * 10 + at[2]]:SetShown(not self.spinning)
    end
  end
  function d:SetSpin(angle)
    self.spinning = angle ~= nil
    for _, t in ipairs({ self.edge, self.body, self.shadow }) do
      if t.SetRotation then
        t:SetRotation(angle or 0)
      end
    end
    self.shine:SetShown(angle == nil)
    self:SetFace(self.face)
  end
  function d:SetLook(look)
    self.look = look
    local c = look == "pick" and C.goldHi or (look == "hint" and C.gold or nil)
    self.glow:SetShown(c ~= nil)
    if c then
      self.glow:SetVertexColor(c[1], c[2], c[3], look == "pick" and 0.95 or 0.45)
    end
    self:SetAlpha(look == "dim" and 0.45 or 1)
  end
  return d
end

-- The throw's motion: each die falls from above with a bounce, sliding a little and spinning, one after another.
local function bounce(p) -- (the usual "ease out bounce")
  if p < 1 / 2.75 then
    return 7.5625 * p * p
  elseif p < 2 / 2.75 then
    p = p - 1.5 / 2.75
    return 7.5625 * p * p + 0.75
  elseif p < 2.5 / 2.75 then
    p = p - 2.25 / 2.75
    return 7.5625 * p * p + 0.9375
  end
  p = p - 2.625 / 2.75
  return 7.5625 * p * p + 0.984375
end

-- A row of dice on a table frame. row:Throw(values or nil: they come later), row:Land(values), row:Step(dt),
-- row:Busy(), row:Show(values) without motion, row.dice[i].
function UI.DiceRow(table, n, size, gap)
  local row = { dice = {}, n = n, size = size, gap = gap }
  local width = n * size + (n - 1) * gap
  for i = 1, n do
    local d = UI.Die(table, size)
    d.bx = -width / 2 + (i - 1) * (size + gap) + size / 2
    d:SetPoint("CENTER", table, "CENTER", d.bx, 0)
    row.dice[i] = d
  end
  local DUR, STAGGER, DROP, SHAKE_MAX = 0.85, 0.07, 70, 2.5

  function row:Place(d, x, y)
    d:ClearAllPoints()
    d:SetPoint("CENTER", table, "CENTER", d.bx + x, (d.lift or 0) + y)
  end

  -- How many show: the throw's dice (the rest of the six are kept aside, not on the table).
  function row:Count(k)
    for i, d in ipairs(self.dice) do
      d:SetShown(i <= k)
    end
  end

  function row:Throw(values, k)
    k = k or (values and #values) or self.n
    self:Count(k)
    self.anim = { t = 0, k = k, values = values, spin = {}, slide = {} }
    for i = 1, k do
      local d = self.dice[i]
      d.lift = 0
      d:SetLook(nil)
      d:SetFace(math.random(1, 6))
      self.anim.spin[i] = (math.random() < 0.5 and -1 or 1) * (3 + math.random() * 3) * math.pi
      self.anim.slide[i] = (math.random() - 0.5) * 30
      d:SetSpin(self.anim.spin[i])
      self:Place(d, self.anim.slide[i], DROP)
    end
  end

  function row:Land(values)
    if self.anim then
      self.anim.values = values
    else
      self:Throw(values)
    end
  end

  function row:Busy()
    return self.anim ~= nil
  end

  function row:Step(dt)
    local a = self.anim
    if not a then
      return
    end
    a.t = a.t + dt
    local done = true
    for i = 1, a.k do
      local d = self.dice[i]
      local p = math.max(0, math.min(1, (a.t - (i - 1) * STAGGER) / DUR))
      if p < 1 or not a.values then
        done = false
      end
      if p < 1 then
        local fall = DROP * (1 - bounce(p))
        local spin = a.spin[i] * (1 - p) * (1 - p)
        d:SetSpin(spin + 0.0001)
        if math.floor(a.t * 14) ~= d.tick then
          d.tick = math.floor(a.t * 14)
          d:SetFace(math.random(1, 6)) -- (hidden while spinning: it shows on landing if the values are late)
        end
        self:Place(d, a.slide[i] * (1 - p), fall)
      elseif not a.values then
        -- (our own throw, waiting for the game's /roll: the dice keep rattling on the table)
        local shake = SHAKE_MAX * math.sin(a.t * 40 + i)
        d:SetSpin(0.12 * math.sin(a.t * 30 + i * 2))
        self:Place(d, shake, 0)
      else
        d:SetSpin(nil)
        d:SetFace(a.values[i])
        self:Place(d, 0, 0)
      end
    end
    if done then
      self.anim = nil
      for i = 1, a.k do
        self.dice[i]:SetSpin(nil)
        self.dice[i]:SetFace(a.values[i])
        self:Place(self.dice[i], 0, 0)
      end
      if self.onLanded then
        self.onLanded(a.values)
      end
    end
  end

  -- Without motion (a refresh, or the dice already known).
  function row:Show(values)
    self.anim = nil
    self:Count(values and #values or 0)
    for i, v in ipairs(values or {}) do
      local d = self.dice[i]
      d:SetSpin(nil)
      d:SetFace(v)
      self:Place(d, 0, 0)
    end
  end

  -- The table's clock: twenty-odd steps a second while dice move.
  local acc = 0
  table:SetScript("OnUpdate", function(_, elapsed)
    if row.anim then
      acc = acc + (elapsed or 0)
      if acc >= 0.016 then
        row:Step(acc)
        acc = 0
      end
    end
  end)
  return row
end
