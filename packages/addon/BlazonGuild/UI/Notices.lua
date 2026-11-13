-- On-screen notices for what concerns you, as it happens in the guild: a new raid, a raid you are going to
-- being cancelled, someone asking to join your group, your request being accepted or declined.
-- Only for changes made by others (Store fires BG_RECORD for records that arrive), and never in combat floods:
-- one notice per record and change. /bg avisos turns them off or on.
local _, BG = ...
local Names, Instances, UI = BG.Names, BG.Instances, BG.UI

local ROLE = { TANK = "tanque", HEALER = "sanador", DPS = "daño" }

local function on()
  return BG.db and BG.db.settings.notices ~= false
end

local function instName(key)
  local i = Instances.Any(key)
  return i and i.name or key
end

BG:On("BG_RECORD", function(kind, r, old)
  if not on() then
    return
  end
  local me = Names.Me()
  if kind == "raids" and r.d then
    if not old and not Names.Same(r.by, me) and r.d.status ~= "CANCELLED" then
      BG:Notify("Nueva raid: " .. r.d.title, UI.FormatDate(r.d.start, true) .. ". La organiza " .. (r.d.leader or r.by) .. ". Pulsa para apuntarte.",
        { kind = "info", view = "raids", icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" })
    elseif old and old.d and old.d.status ~= "CANCELLED" and r.d.status == "CANCELLED" then
      local mine = BG.Raids.MySignup(r.id)
      if mine and mine.d.status ~= "DECLINED" then
        BG:Notify("Raid cancelada", r.d.title .. ", " .. UI.FormatDate(r.d.start, true) .. ".", { kind = "warning", view = "raids" })
      end
    end
  elseif kind == "requests" and r.d and not old then
    local g = BG.Groups.Get(r.d.group)
    if g and Names.Same(g.d.leader, me) then
      BG:Notify("Piden plaza en tu grupo", r.d.name .. " quiere entrar como " .. (ROLE[r.d.role] or "") .. " en " .. instName(g.d.key) .. ".",
        { kind = "info", view = "dungeons", sound = "READY_CHECK" })
    end
  elseif kind == "groups" and r.d and old and old.d and me then
    local function inside(d)
      for _, m in ipairs(d.members) do
        if Names.Same(m.name, me) then
          return true
        end
      end
      return false
    end
    if inside(r.d) and not inside(old.d) then
      BG:Notify("Te han aceptado", "Entras en el grupo de " .. r.d.leader .. " para " .. instName(r.d.key) .. ". Te llegará su invitación.", { kind = "success", view = "dungeons" })
    elseif r.d.declined[me] and not old.d.declined[me] then
      BG:Notify("No hay sitio", "El grupo de " .. r.d.leader .. " para " .. instName(r.d.key) .. " no puede llevarte esta vez.", { kind = "warning", view = "dungeons" })
    end
  end
end)

BG.commands = BG.commands or {}
BG.commands.avisos = function()
  BG.db.settings.notices = not on()
  BG:Notify("Avisos " .. (on() and "activados" or "desactivados"), on() and "Verás aquí lo que te afecta en la hermandad." or "Escribe /bg avisos para volver a activarlos.", { kind = "info" })
end
