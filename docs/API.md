# BlazonGuildAPI — for other addons

BlazonGuild (World of Warcraft: Forever) lets other addons **read** what the player already sees on BlazonGuild's own
screens. Only read, only with the player's yes, and never anything private.

## Registering

```lua
local BG = BlazonGuildAPI and BlazonGuildAPI.Register("MyAddon")
if BG then
  -- The player is asked once, in BlazonGuild's own dialog, after logging in.
  -- Nothing comes back until they say yes (BG:Allowed() is false until then).
end
```

- `BlazonGuildAPI.VERSION` — `1`.
- `BlazonGuildAPI.Register(name)` → a handle (the same one every time for the same name), or `nil, "nombre"`.
- `handle:Allowed()` → `true` once the player allowed your addon (and BlazonGuild's privacy is accepted).
- `handle:Ask()` → shows the question again (call it from a click of the player, not on a timer).
- The player can take the permission back at any time: `/bg api quitar MyAddon`. Every getter then returns `nil`.

## Reading

Each getter returns `nil` without permission. Tables are copies built field by field: change them freely.

| Call | Returns |
| --- | --- |
| `handle:GetGuild()` | `{ inGuild, name, faction, members, online, withAddon }` (`{ inGuild = false }` without a guild) |
| `handle:GetMe()` | `{ name, rank, level, classFile, organiser, role }` |
| `handle:GetRaids()` | the coming raids: `{ title, instance, start, state, going, maybe, tanks, healers, dps }` — counts only, never names |
| `handle:GetArena()` | the season's Arena ranking: `{ name, rating, place, tier, wins, losses, champion }` |
| `handle:GetWanted()` | «Se busca»: `{ name, classFile, bounty, deaths }` |
| `handle:GetHonors()` | the honours: `{ key, title, holder }` |

`start` is the server's time (`GetServerTime()`). Names are "First Surname", as Forever writes them.

## Events

```lua
BG:On("raids", function() --[[ something changed: read again ]] end)
```

`"raids"`, `"arena"`, `"wanted"`, `"honors"`, `"guild"`. Callbacks get no arguments, run only while your addon is
allowed, and errors in them are caught.

## What it never gives

Whispers, positions, sightings, moderation (reports, cases, mutes, BattleTags), the treasury's ledger, the alliance's key
or signatures, anyone's private data, or a way to send or change anything.
