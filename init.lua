--[[
SharedData.lua v0.1
author: aquietone

This script provides a TLO with bot data made available via actors.

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

/lua parse example usage:  

- Get list of character names which have data available:
> /lua parse mq.TLO.SharedData.Names()[1]
Character1

- Get data for a single character in lua table format
> /lua parse mq.TLO.SharedData.Characters('character1')().PctHPs
100

- Get data for all characters in lua table format
> /lua parse mq.TLO.SharedData.Characters().Character1.PctHPs

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
]]
local mq = require 'mq'
local imgui = require 'ImGui'
local actors = require 'actors'

local SharedData = {
    _version = "0.1",
    properties = {
        -- Sample properties
        {key='PctHPs', expression='${Me.PctHPs}'},
        {key='PctMana', expression='${Me.PctMana}'}
    },
    settings = {
        frequency = 250,
        cleanupInterval = 10000,
        staleDataTimeout = 60000,
    },
    openGUI = true,
    shouldDrawGUI = true,
    openPropertyGUI = false,
    shouldDrawPropertyGUI = false,
    propertyGUIAction = 'Add',
    selectedCharacter = nil,
    selectedProperty = -1,
    data = {},
    propertyInput = {},
}

function SharedData.addProperty(key, expression)
    if key and expression then
        for _,property in ipairs(SharedData.properties) do
            if property.key == key then printf('\a-t[SharedData]\ax Key "\ay%s\ax" already present, skipping', key) return false end
        end
        printf('\a-t[SharedData]\ax Key "\ay%s\ax" added', key)
        table.insert(SharedData.properties, {key = key, expression = expression})
        SharedData.doSave = true
        return true
    end
end

function SharedData.removeProperty(key, index)
    if key then
        for i,property in ipairs(SharedData.properties) do if property.key == key then index = i break end end
    end
    if index and index > 0 and index <= #SharedData.properties then
        printf('\a-t[SharedData]\ax Key "\ay%s\ax" removed', key)
        table.remove(SharedData.properties, index)
        SharedData.doSave = true
    end
end

function SharedData.messageHandler(message)
    local content = message()
    if content.action then
        if content.action == 'add' then
            local key = content.key
            local expression = content.expression
            SharedData.addProperty(key, expression)
        elseif content.action == 'remove' then
            local key = content.key
            SharedData.removeProperty(key)
        end
    else
        SharedData.data[content.name] = SharedData.data[content.name] or {}
        for k, v in pairs(content) do
            if k ~= 'name' then
                SharedData.data[content.name][k] = v
            end
        end
    end
end

function SharedData.renderPropertyEditor()
    if not SharedData.openPropertyGUI then return end
    SharedData.openPropertyGUI, SharedData.shouldDrawPropertyGUI = imgui.Begin(SharedData.propertyGUIAction..' Property', SharedData.openPropertyGUI)
    if SharedData.shouldDrawPropertyGUI then
        if SharedData.propertyGUIAction == 'Add' then
            SharedData.propertyInput.key = imgui.InputText('Key', SharedData.propertyInput.key or '')
        else
            imgui.Text('Key: %s', SharedData.propertyInput.key)
        end
        SharedData.propertyInput.expression = imgui.InputText('Expression', SharedData.propertyInput.expression or '')
        if imgui.Button('Save') then
            if SharedData.propertyGUIAction == 'Add' then
                local added = SharedData.addProperty(SharedData.propertyInput.key, SharedData.propertyInput.expression)
                if added then
                    -- Add may fail if key already exists, keep window open and show error
                    SharedData.openPropertyGUI = false
                    SharedData.propertyInput = {}
                    SharedData.showAddError = false
                else
                    SharedData.showAddError = true
                end
            else
                SharedData.properties[SharedData.propertyInput.index] = {key = SharedData.propertyInput.key, expression = SharedData.propertyInput.expression}
                -- Always close/clear input after edit
                SharedData.openPropertyGUI = false
                SharedData.propertyInput = {}
                SharedData.doSave = true
            end
        end
        if SharedData.showAddError then
            imgui.TextColored(1,0,0,1, 'Property already exists')
        end
    end
    imgui.End()
end

function SharedData.renderPropertyListTab()
    if imgui.BeginTabItem('Properties') then
        if imgui.SmallButton('Add Property') then
            SharedData.openPropertyGUI = true
            SharedData.propertyGUIAction = 'Add'
            SharedData.showAddError = false
        end
        if SharedData.selectedProperty ~= -1 then
            imgui.SameLine()
            if imgui.SmallButton('Edit Property') then
                SharedData.openPropertyGUI = true
                SharedData.propertyGUIAction = 'Edit'
                SharedData.showAddError = false
                SharedData.propertyInput = {key = SharedData.properties[SharedData.selectedProperty].key, expression = SharedData.properties[SharedData.selectedProperty].expression, index = SharedData.selectedProperty}
            end
            imgui.SameLine()
            if imgui.SmallButton('Remove Property') then
                SharedData.removeProperty(nil, SharedData.selectedProperty)
                SharedData.selectedProperty = -1
                SharedData.doSave = true
            end
        end
        if imgui.BeginTable('properties', 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.BordersInner, ImGuiTableFlags.RowBg), ImVec2(-1,-1)) then
            imgui.TableSetupColumn('##selected', ImGuiTableColumnFlags.None, 1)
            imgui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2)
            imgui.TableSetupColumn('Expression', ImGuiTableColumnFlags.None, 4)
            imgui.TableSetupScrollFreeze(0, 1)
            imgui.TableHeadersRow()

            local clipper = ImGuiListClipper.new()
            clipper:Begin(#SharedData.properties)
            local remove_idx = -1
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                    local property = SharedData.properties[row_n+1]

                    imgui.TableNextRow()
                    imgui.TableNextColumn()

                    local value, pressed = imgui.Checkbox('##selected'..property.key, row_n+1 == SharedData.selectedProperty)
                    if pressed then
                        if value then
                            SharedData.selectedProperty = row_n+1
                        else
                            SharedData.selectedProperty = -1
                        end
                    end
                    imgui.TableNextColumn()

                    imgui.Text(property.key)
                    imgui.TableNextColumn()

                    imgui.Text(property.expression)
                end
            end
            if remove_idx ~= -1 then table.remove(SharedData.properties, remove_idx) end

            imgui.EndTable()
        end
        imgui.EndTabItem()
    end
end

function SharedData.renderDataPreviewTab()
    if imgui.BeginTabItem('Data Preview') then
        if ImGui.BeginCombo('Character', SharedData.selectedCharacter or 'Select a character...') then
            for name,_ in pairs(SharedData.data) do
                if ImGui.Selectable(name, name == SharedData.selectedCharacter) then
                    SharedData.selectedCharacter = name
                end
            end
            ImGui.EndCombo()
        end
        if SharedData.data[SharedData.selectedCharacter] then
            if imgui.BeginTable('Data', 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.BordersInner, ImGuiTableFlags.RowBg), ImVec2(-1,-1)) then
                imgui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2)
                imgui.TableSetupColumn('Expression', ImGuiTableColumnFlags.None, 3)
                imgui.TableSetupScrollFreeze(0, 1)
                imgui.TableHeadersRow()

                for k,v in pairs(SharedData.data[SharedData.selectedCharacter]) do

                    imgui.TableNextRow()
                    imgui.TableNextColumn()

                    imgui.Text(k)

                    imgui.TableNextColumn()

                    imgui.Text(v)
                end

                imgui.EndTable()
            end
        end
        imgui.EndTabItem()
    end
end

function SharedData.renderSettingsTab()
    if imgui.BeginTabItem('Settings') then
        SharedData.settings.frequency = imgui.InputInt('Frequency', SharedData.settings.frequency)
        SharedData.settings.cleanupInterval = imgui.InputInt('Cleanup Interval', SharedData.settings.cleanupInterval)
        SharedData.settings.staleDataTimeout = imgui.InputInt('Stale Data Timeout', SharedData.settings.staleDataTimeout)
        imgui.EndTabItem()
    end
end

function SharedData.render()
    if not SharedData.openGUI then return end
    SharedData.openGUI, SharedData.shouldDrawGUI = imgui.Begin('SharedDataConfig', SharedData.openGUI)
    if SharedData.shouldDrawGUI then
        if imgui.BeginTabBar('SharedDataTabs') then
            SharedData.renderPropertyListTab()
            SharedData.renderDataPreviewTab()
            SharedData.renderSettingsTab()

            imgui.EndTabBar()
        end
    end
    imgui.End()

    SharedData.renderPropertyEditor()
end

function SharedData.publish()
    local me = mq.TLO.Me() or ''
    local message = {sentAt = mq.gettime(), name=me}
    for _,property in ipairs(SharedData.properties) do
        SharedData.data[me] = SharedData.data[me] or {}
        local current = mq.parse(property.expression)
        if SharedData.data[me][property.key] ~= current then
            message[property.key] = current
        end
    end
    SharedData.actor:send(message)
end

local function fileExists(file_name)
    local f = io.open(file_name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function SharedData.loadSettings()
    local configFile = ('%s/shareddata/%s_%s_shareddata.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me())
    if not fileExists(configFile) then return end
    local settings = assert(loadfile(configFile))()
    if not settings then return end
    for k,v in pairs(settings.settings) do SharedData.settings[k] = v end
    for k,v in pairs(settings.properties) do SharedData.properties[k] = v end
end

function SharedData.saveSettings()
    local configFile = ('%s/shareddata/%s_%s_shareddata.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me())
    printf('pickling')
    mq.pickle(configFile, {settings=SharedData.settings, properties=SharedData.properties, version=SharedData._version})
end

function SharedData.bind(...)
    local args = {...}
    -- help
    if #args == 0 or args[1] == 'help' then
        local output = '\a-t[SharedDataClient]\ax v\ay%s\ax\n'
        output = output .. '\t\aw- /sdc add key expression'
        output = output .. '\t\aw- /sdc remove key'
        output = output .. '\t\aw- /sdc list'
        output = output .. '\t\aw- /sdc show'
        output = output .. '\t\aw- /sdc hide'
        output = output .. '\t\aw- /sdc help'
        printf(output, SharedData._version)
    -- add property
    elseif args[1] == 'add' then
        SharedData.addProperty(args[2], args[3])
    -- broadcast add to everyone
    elseif args[1] == 'addall' then
        local key = args[2]
        local value = args[3]
        if key and value then
            SharedData.actor:send({action = 'add', key = key, expression = value})
        end
    -- remove property
    elseif args[1] == 'remove' then
        SharedData.removeProperty(args[2])
    -- broadcast remove to everyone
    elseif args[1] == 'removeall' then
        local key = args[2]
        if key then
            SharedData.actor:send({action = 'remove', key = key})
        end
    -- list properties
    elseif args[1] == 'list' then
        local output = ''
        for _,property in ipairs(SharedData.properties) do
            output = output .. ('- \ay%s\ax: \aw%s\ax\n'):format(property.key, property.expression)
        end
        print(output)
    -- show ui
    elseif args[1] == 'show' then
        SharedData.openGUI = true
    -- hide ui
    elseif args[1] == 'hide' then
        SharedData.openGUI = false
    elseif args[1] == 'reload' then
        SharedData.loadSettings()
    end
end

function SharedData.initTLO()
    local SharedDataType

    local function SharedDataTLO(index)
        return SharedDataType, {}
    end

    local tloMembers = {
        Frequency = function() return 'int', SharedData.settings.frequency end,
        CleanupInterval = function() return 'int', SharedData.settings.cleanupInterval end,
        StaleDataTimeout = function() return 'int', SharedData.settings.staleDataTimeout end,
        Names = function() local peers = {} for name,_ in pairs(SharedData.data) do table.insert(peers, name) end return 'table', peers end,
        Characters = function(i) return 'table', i and SharedData.data[i] or SharedData.data end
    }

    SharedDataType = mq.DataType.new('SharedDataType', {
        Members = tloMembers,
        ToString = function() return ('SharedData v%s'):format(SharedData._version) end
    })

    mq.AddTopLevelObject('SharedData', SharedDataTLO)
end

function SharedData.init(args)
    -- read config
    SharedData.loadSettings()
    if args and args[1] == 'bg' then SharedData.openGUI = false end

    -- setup binds
    mq.bind('/sdc', SharedData.bind)

    -- setup actor
    SharedData.actor = actors.register(SharedData.messageHandler)

    -- setup TLO
    SharedData.initTLO()

    -- setup gui
    mq.imgui.init('SharedData', SharedData.render)
end

function SharedData.cleanup()
    if mq.gettime() - SharedData.settings.cleanupInterval < 15000 then return end
    for name, data in pairs(SharedData.data) do
        if mq.gettime() - (data.sentAt or 0) > SharedData.settings.staleDataTimeout then
            SharedData.data[name] = nil
        end
    end
end

local function main(args)
    SharedData.init(args)

    while true do
        local inGame = mq.TLO.EverQuest.GameState()
        SharedData.cleanup()
        if inGame == 'INGAME' then SharedData.publish() end
        if SharedData.doSave then SharedData.saveSettings() SharedData.doSave = false end
        mq.delay(SharedData.settings.frequency)
    end
end

local args = {...}
main(args)