--[[
SharedData.lua v0.2
author: aquietone

This script provides a TLO with bot data made available via actors.
Per server/character configurations are stored in config/shareddata/ folder.

Run with:
/lua run shareddata

Run without showing UI on launch with:
/lua run shareddata bg

Available commands:
/sdc -- show help output
/sdc help -- show help output
/sdc reload -- reload settings for this character
/noparse /sdc add Key Expression -- add new property to be broadcast
/noparse /sdc addall Key Expression -- add new property to be broadcast for all characters
/sdc list -- list all properties
/sdc remove Key -- remove property from broadcasting
/sdc removeall Key -- remove property from broadcasting for all characters
/sdc addsource filename -- add config/shareddata/customfilename.lua as a data source
/sdc addsourceall filename -- add config/shareddata/filename.lua as a data source for all characters
/sdc removesource filename -- remove config/shareddata/filename.lua from custom data sources
/sdc removesourceall filename -- remove config/shareddata/filename.lua from custom data sources for all characters
/sdc listsources -- list all custom data sources
/sdc show -- open the UI
/sdc hide -- close the UI

TLO:
SharedData() -- print script version
SharedData.Names() -- return lua table of character names
SharedData.Characters() -- return lua table of all character data
SharedData.Characters('name1')() -- return lua table of name1 character data
SharedData.Frequency() -- get update frequency setting value
SharedData.CleanupInterval() -- get cleanupInterval setting value
SharedData.StaleDataTimeout() -- get staleDataTimeout setting value

For embedding SharedDataClient into another script, do:
local client = require('shareddata.client')
client.init(true, 'unique_mailbox_name', mq.luaDir..'/myscript/my_custom_data_source.lua')

while true do
    client.process()
    mq.delay(1000)
end


/lua parse example usage:  

- Get list of character names which have data available:
> /lua parse mq.TLO.SharedData.Names()[1]
Character1

- Get data for a single character in lua table format
> /lua parse mq.TLO.SharedData.Characters('character1')().PctHPs
100

- Get data for all characters in lua table format
> /lua parse mq.TLO.SharedData.Characters().Character1.PctHPs
100

Lua example usage:  

-- Use list of Names to output PctHPs value for each character
local names = mq.TLO.SharedData.Names()
for _,name in ipairs(names) do
    printf('PctHPs for %s: %s', name, mq.TLO.SharedData.Characters(name)().PctHPs)
end

-- Output PctHPs for a specific character by name
local characterData = mq.TLO.SharedData.Characters('Character1')()
for k,v in pairs(characterData) do
    printf('%s: %s', k, v)
end

-- Output PctHPs for all characters in characters table
local allCharacters = mq.TLO.SharedData.Characters()
for name,data in pairs(allCharacters) do
    printf('PctHPs for %s: %s', name, data.PctHPs)
end

Custom Data Source example:
-- begin config/shareddata/custom.lua
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
-- end config/shareddata/custom.lua

> /lua parse mq.TLO.SharedData.Characters('Character1')().BlockedBuffs[1]
30739

]]
local mq = require('mq')
local client = require('client')

local function main(args)
    local runInBackground = args and args[1] == 'bg'
    client.init(runInBackground)

    while true do
        client.process()
        mq.delay(client.settings.frequency)
    end
end

local args = {...}
main(args)