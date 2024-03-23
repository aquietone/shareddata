# shareddata
Implements an actor based SharedData TLO for MacroQuest

# Usage

With lua parse:  

- Get list of character names which have data available:
```lua
> /lua parse mq.TLO.SharedData.Names()[1]
Character1
```
- Get data for a single character in lua table format
```lua
> /lua parse mq.TLO.SharedData.Characters('character1')().PctHPs
100
```
- Get data for all characters in lua table format
```lua
> /lua parse mq.TLO.SharedData.Characters().Character1.PctHPs
```

From a lua script:  
```lua
local names = mq.TLO.SharedData.Names()
for _,name in ipairs(names) do
    printf('PctHPs for %s: %s', name, mq.TLO.SharedData.Characters(name)().PctHPs)
end

local characterData = mq.TLO.SharedData.Characters('Character1')()
for k,v in pairs(characterData) do
    printf('%s: %s', k, v)
end

local allCharacters = mq.TLO.SharedData.Characters()
for name,data in pairs(allCharacters) do
    printf('PctHPs for %s: %s', name, data.PctHPs)
end
```

Add key,value pairs of data to be shared using UI or commands.

```
/noparse /sdc add PctEndurance ${Me.PctEndurance}
```

```
/sdc remove PctEndurance
```

```
/sdc list
```

# Other Settings

- `frequency` - Delay, in milliseconds, for the main loop.
- `cleanupInterval` - How often to scan, in milliseconds, character data table for stale data. Default: 15000
- `staleDataTimeout` - How long to wait, in milliseconds, for updates from a character before considering that characters data to be stale. Default: 60000