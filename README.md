# shareddata
Implements an actor based SharedData TLO for MacroQuest

# Usage

With lua parse:  
```lua
/lua parse mq.TLO.SharedData.Characters('character1')().PctHPs
```

From a lua script:  
```lua
local characterData = mq.TLO.SharedData.Characters('Character1')()
for k,v in pairs(characterData) do
    printf('%s: %s', k, v)
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