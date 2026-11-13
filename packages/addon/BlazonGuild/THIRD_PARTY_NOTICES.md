# Third-party notices

BlazonGuild includes code from the following project.

## Olympus addon — parts of `Data/Arena.lua`

The reader of the game's format strings in `Data/Arena.lua` (turning a line such as `DUEL_WINNER_KNOCKOUT` into a
pattern, positional arguments included) is adapted from Olympus' `ArenaParse.lua`, and the rating's numbers (start,
K factors, level points, the pair window, the tiers' shares) are those of its `ArenaRating.lua`, same project, version
and licence as below.

## Olympus addon — `Core/Ed25519.lua`

`Core/Ed25519.lua` (Ed25519 signatures and SHA-512 in plain Lua 5.1) is taken from the Olympus addon,
`dnl-gentile/olympus-addon`, version 1.5.7 (commit `eb91d5b`). Changes for BlazonGuild: the addon's namespace
(`BG.Ed25519`) and its error log. Its curve arithmetic is a port of TweetNaCl (public domain).

```
MIT License

Copyright (c) 2026 Olympus addon contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
