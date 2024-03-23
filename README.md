# shareddata
Implements an actor based SharedData TLO for MacroQuest

# Usage

## Run with
```
/lua run shareddata
```

## Run without showing UI on launch with
```
/lua run shareddata bg
```

## Available commands
| Command | Description |
| :--- | :---- |
|/sdc|show help output|
|/sdc help|show help output|
|/sdc reload|reload settings for this character|
|/noparse /sdc add Key Expression|add new property to be broadcast|
|/noparse /sdc addall Key Expression|add new property to be broadcast for all characters|
|/sdc list|list all properties|
|/sdc remove Key|remove property from broadcasting|
|/sdc removeall Key|remove property from broadcasting for all characters|
|/sdc show|open the UI|
|/sdc hide|close the UI|

## TLO
| TLO | Description |
| :--- | :---- |
|SharedData()|print script version|
|SharedData.Names()|return lua table of character names|
|SharedData.Characters()|return lua table of all character data|
|SharedData.Characters('name1')()|return lua table of name1 character data|
|SharedData.Frequency()|get update frequency setting value|
|SharedData.CleanupInterval()|get cleanupInterval setting value|
|SharedData.StaleDataTimeout()|get staleDataTimeout setting value|

## Examples read TLO with lua parse:  

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

## Examples read TLO from a lua script:  
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

## Adding Properties

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