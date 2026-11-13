-- «Ver como miembro» (entrega 13; the idea of Olympus' ViewAs.lua, MIT): an organiser, or the master, sees BlazonGuild as
-- a member (or the master as an officer) sees it, to check what their guild sees. Only downwards, only on this
-- screen, for ten minutes at most, and never across a /reload: Store.IsOrganiser and Store.IsMaster answer for this
-- player as the preview's rank, while the Store's own work (what it keeps and whom it trusts) keeps the real one
-- (Store.RealOrganiser). Every other guildmate's addon still checks the real rank of whatever this player does.
local _, BG = ...
local Store, Names = BG.Store, BG.Names
local LAST = 10 * 60

local function refresh()
  BG:Fire("BG_VIEWAS_CHANGED", BG.viewAs)
  if BG.window and BG.window:IsShown() and BG.db.settings.lastView then
    BG:ShowView(BG.db.settings.lastView)
  end
end

-- role: "member", "officer" or nil (back to one's own view). Returns true, or nil and why.
function BG.SetViewAs(role)
  local me = Names.Me()
  if role ~= nil then
    local rank = me and Store.RankOf(me)
    if role == "member" and not (me and Store.RealOrganiser(me)) then
      return nil, "ya"
    end
    if role == "officer" and rank ~= 0 then
      return nil, "ya"
    end
    if role ~= "member" and role ~= "officer" then
      return nil, "rango"
    end
  end
  BG.viewAs = role
  local stamp = role and GetTime() or nil
  BG.viewAsSince = stamp
  if role then
    C_Timer.After(LAST, function()
      if BG.viewAs and BG.viewAsSince == stamp then
        BG.SetViewAs(nil)
      end
    end)
    BG:Notify(role == "member" and "Vista de miembro" or "Vista de oficial", "Ves BlazonGuild como lo ve " .. (role == "member" and "un miembro" or "un oficial")
      .. ". Durante 10 minutos como mucho; vuelve antes en Administración o con /bg vista.", { kind = "info" })
  else
    BG:Notify("Tu vista", "Vuelves a ver BlazonGuild con tu propio rango.", { kind = "info" })
  end
  refresh()
  return true
end

BG.commands = BG.commands or {}
BG.commands.vista = function(arg)
  if BG.viewAs or arg == "yo" then
    return BG.SetViewAs(nil)
  end
  local ok, why = BG.SetViewAs(arg == "oficial" and "officer" or "member")
  if not ok then
    BG:Print(why == "ya" and "ya ves BlazonGuild con ese rango o uno menor." or "uso: /bg vista [miembro | oficial | yo]")
  end
end
