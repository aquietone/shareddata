# shareddata
Implements an actor based SharedData TLO for MacroQuest.

## Overview

The script will broadcast messages over the actor system at the configured frequency containing key/value pairs of all configured properties.  
Properties include a key (the name the property will be exposed as in the character data) and an expression (a parsable line of lua or macroscript like `mq.TLO.Me.PctHPs()` or `${Me.PctHPs}`).  
Properties will only be included in messages when the value has changed.  
Messages will still be published even if no properties have changed, just as a heartbeat mechanism.  
Characters which stop broadcasting data will have their data marked as stale after the configured staleDataTimeout amount of time.  
The script will check for stale character data and remove it after the configured cleanupInterval amount of time.  
Per server/character configurations are stored in config/shareddata/ folder.  

Includes support for defining custom data sources to output data other than what is available via existing MQ TLOs. See section on Custom Data Sources.

The script can be included into other scripts with require as well. See section on requiring SharedDataClient.

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
|/noparse /sdc add Key Type Expression|add new property to be broadcast|
|/noparse /sdc addall Key Type Expression|add new property to be broadcast for all characters|
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
/sdc add PctHPs lua mq.TLO.Me.PctHPs()
```

```
/noparse /sdc add PctEndurance macro ${Me.PctEndurance}
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

# Custom Data Sources

Properties are limited to returning what is available via MacroScript such as `${Me.PctHPs}`. Custom data sources provide a way to implement your own lua functions to expose customized character data.

1. Create a new file under `config/shareddata` such as `custom.lua`.  
2. Return a table of key/value pairs from `custom.lua`.  
3. Add `custom.lua` via the UI `Custom Sources` tab or with `/sdc addsource custom.lua`.  

The key/value pairs returned by your `custom.lua` can return complex data such as lua tables. For example, below code outputs a key `BlockedBuffs` whose value is a lua table of blocked buff IDs.  

```lua
local mq = require 'mq'
return {
    BlockedBuffs = function()
        local blockedBuffs = {}
        for i=1,20 do
            local blockedBuff = mq.TLO.Me.BlockedBuff(i)
            if blockedBuff() then
                table.insert(blockedBuffs, blockedBuff.ID())
            end
        end
        return blockedBuffs
    end,
}
```

This can then be accessed through the TLO like:  
```lua
> /lua parse mq.TLO.SharedData.Characters('Character1')().BlockedBuffs[1]
30739
```

# Requiring SharedDataClient in other scripts

To make use of SharedDataClient from another lua script, follow below example:
```lua
local client = require('shareddata.client')
client.init(true, 'unique_mailbox_name', mq.luaDir..'/myscript/my_custom_data_source.lua')

while true do
    -- let the client publish whatever data it needs to publish
    client.process()
    -- make use of the data received by the client
    for charname, chardata in pairs(client.data) do
        -- do stuff
    end
    mq.delay(1000)
end
```
A path to a custom data source file (like above) should be provided when requiring SharedDataClient from another script. When run in this mode, the client won't publish any other
values except those defined in the provided custom data source file. The UI, CLI and TLO will also be disabled, so that just the script which includes the client can
access its relevant data through `client.data`.