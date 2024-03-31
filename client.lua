--[[
SharedData.lua v0.3
author: aquietone
For details, see init.lua
]]
local mq = require 'mq'
local imgui = require 'ImGui'
local actors = require 'actors'

---@class SharedData
---@field data table # Contains all received character data from configured properties and data sources
---@field settings table # Contains settings values for the script
local SharedData = {
    _version = "0.3",
    properties = {
        -- Sample properties
        {key='PctHPs', expression='${Me.PctHPs}', type='MacroScript'},
        {key='PctMana', expression='mq.TLO.Me.PctMana()', type='Lua'}
    },
    settings = {
        frequency = 250,
        cleanupInterval = 10000,
        staleDataTimeout = 60000,
    },
    customDataSources = {},
    customData = {},
    openGUI = true,
    shouldDrawGUI = true,
    openPropertyGUI = false,
    shouldDrawPropertyGUI = false,
    propertyGUIAction = 'Add',
    selectedCharacter = nil,
    selectedProperty = -1,
    showAddError = false,
    resendAll = true,
    data = {},
    propertyInput = {},
}

local loadstringTemplate = [[
local mq = require 'mq'
return %s
]]

local function pcallString(luastring)
    local func, err = load(luastring)
    if not func then
        return false, err
    end
    return pcall(func)
end

local function evaluateString(luastring)
    return pcallString((loadstringTemplate):format(luastring))
end

local function fileExists(filename)
    local f = io.open(filename, "r")
    if f ~= nil then io.close(f) return true else return false end
end

function SharedData.addProperty(key, type, expression)
    if key and expression and type then
        for _,property in ipairs(SharedData.properties) do
            if property.key == key then printf('\a-t[SharedData]\ax Key "\ay%s\ax" already present, skipping', key) return false end
        end
        printf('\a-t[SharedData]\ax Key "\ay%s\ax" added', key)
        table.insert(SharedData.properties, {key = key, expression = expression, type = type})
        SharedData.doSave = true
        return true
    end
end

function SharedData.removeProperty(key, index)
    if key then
        for i,property in ipairs(SharedData.properties) do if property.key == key then index = i break end end
    end
    if index and index > 0 and index <= #SharedData.properties then
        key = SharedData.properties[index].key
        printf('\a-t[SharedData]\ax Key "\ay%s\ax" removed', key)
        table.remove(SharedData.properties, index)
        SharedData.doSave = true
    end
end

function SharedData.addSource(filename)
    if filename then
        if not fileExists(mq.configDir..'/shareddata/'..filename) then
            printf('\a-t[SharedData]\ax File \ay%s\ax does not exist', filename)
            SharedData.errorMessage = 'File does not exist'
            return false
        end
        for _,f in ipairs(SharedData.customDataSources) do
            if filename == f then
                printf('\a-t[SharedData]\ax Custom Data Source \ay%s\ax is already present, skipping', filename)
                return false
            end
        end
        table.insert(SharedData.customDataSources, filename)
        local ok, customData = pcall(loadfile, mq.configDir..'/shareddata/'..filename)
        if ok and customData then
            SharedData.customData[filename] = customData()
        end
        SharedData.doSave = true
        return true
    end
end

function SharedData.removeSource(filename)
    if filename then
        local removeIdx = -1
        for i,f in ipairs(SharedData.customDataSources) do
            if filename == f then removeIdx = i break end
        end
        if removeIdx ~= -1 then
            table.remove(SharedData.customDataSources, removeIdx)
            printf('\a-t[SharedData]\ax Custom Data Source \ay%s\ax removed', filename)
            SharedData.customData[filename] = nil
            SharedData.doSave = true
        end
    end
end

local function processTable(parent, tableName, tableValue)
    parent[tableName] = {}
    for key, value in pairs(tableValue) do
        if type('value') == 'table' then
            processTable(parent[tableName], key, value)
        else
            parent[tableName][key] = value
        end
    end
end

function SharedData.messageHandler(message)
    local content = message()
    if content.action then
        if content.action == 'add' then
            local key = content.key
            local type = content.type
            local expression = content.expression
            SharedData.addProperty(key, type, expression)
        elseif content.action == 'remove' then
            local key = content.key
            SharedData.removeProperty(key)
        elseif content.action == 'addsource' then
            local filename = content.filename
            SharedData.addSource(filename)
        elseif content.action == 'removesource' then
            local filename = content.filename
            SharedData.removeSource(filename)
        end
    else
        -- If we see a new character show up, trigger re-sending all properties once even if their values haven't changed.
        if not SharedData.data[content.name] then SharedData.resendAll = true end
        SharedData.data[content.name] = SharedData.data[content.name] or {}
        for k, v in pairs(content) do
            if k ~= 'name' then
                if v == 'TRUE' then
                    v = true
                elseif v == 'FALSE' then
                    v = false
                elseif tostring(tonumber(v)) == v then
                    v = tonumber(v)
                elseif v == 'NULL' then
                    v = nil
                elseif type(v) == 'table' then
                    processTable(SharedData.data[content.name], k, v)
                end
                SharedData.data[content.name][k] = v
            end
        end
    end
end

function SharedData.renderPropertyEditor()
    if not SharedData.openPropertyGUI then return end
    SharedData.openPropertyGUI, SharedData.shouldDrawPropertyGUI = imgui.Begin(SharedData.propertyGUIAction, SharedData.openPropertyGUI)
    if SharedData.shouldDrawPropertyGUI then
        if SharedData.propertyGUIAction == 'Add Property' then
            local pressed = imgui.RadioButton('Lua', SharedData.propertyInput.type == 'Lua')
            if pressed then SharedData.propertyInput.type = 'Lua' end
            imgui.SameLine()
            pressed = imgui.RadioButton('MacroScript', SharedData.propertyInput.type == 'MacroScript')
            if pressed then SharedData.propertyInput.type = 'MacroScript' end
            SharedData.propertyInput.key = imgui.InputText('Key', SharedData.propertyInput.key or '')
            SharedData.propertyInput.expression = imgui.InputText('Expression', SharedData.propertyInput.expression or '')
        elseif SharedData.propertyGUIAction == 'Add Data Source' then
            SharedData.propertyInput.key = imgui.InputText('Filename', SharedData.propertyInput.key or '')
        else
            imgui.Text('Key: %s', SharedData.propertyInput.key)
            SharedData.propertyInput.expression = imgui.InputText('Expression', SharedData.propertyInput.expression or '')
        end
        if imgui.Button('Save') then
            if SharedData.propertyGUIAction == 'Add Property' then
                local added = SharedData.addProperty(SharedData.propertyInput.key, SharedData.propertyInput.type, SharedData.propertyInput.expression)
                if added then
                    -- Add may fail if key already exists, keep window open and show error
                    SharedData.openPropertyGUI = false
                    SharedData.propertyInput = {}
                    SharedData.showAddError = false
                    SharedData.errorMessage = nil
                else
                    SharedData.showAddError = true
                end
            elseif SharedData.propertyGUIAction == 'Add Data Source' then
                local added = SharedData.addSource(SharedData.propertyInput.key)
                if added then
                    SharedData.openPropertyGUI = false
                    SharedData.propertyInput = {}
                    SharedData.showAddError = false
                    SharedData.errorMessage = nil
                else
                    SharedData.showAddError = true
                end
            else
                SharedData.properties[SharedData.propertyInput.index] = {key = SharedData.propertyInput.key, expression = SharedData.propertyInput.expression, type = SharedData.propertyInput.type}
                -- Always close/clear input after edit
                SharedData.openPropertyGUI = false
                SharedData.propertyInput = {}
                SharedData.doSave = true
            end
        end
        if SharedData.showAddError then
            imgui.TextColored(1,0,0,1, SharedData.errorMessage or 'Entry already exists')
        end
    end
    imgui.End()
end

function SharedData.renderPropertyListTab()
    if imgui.BeginTabItem('Properties') then
        if SharedData.currentTab ~= 'Properties' then
            SharedData.currentTab = 'Properties'
            SharedData.selectedProperty = -1
        end
        if imgui.SmallButton('Add Property') then
            SharedData.openPropertyGUI = true
            SharedData.propertyGUIAction = 'Add Property'
            SharedData.showAddError = false
            SharedData.errorMessage = nil
            SharedData.propertyInput = {type='Lua'}
        end
        if SharedData.selectedProperty ~= -1 then
            imgui.SameLine()
            if imgui.SmallButton('Edit Property') then
                SharedData.openPropertyGUI = true
                SharedData.propertyGUIAction = 'Edit Property'
                SharedData.showAddError = false
                SharedData.errorMessage = nil
                SharedData.propertyInput = {
                    key = SharedData.properties[SharedData.selectedProperty].key,
                    expression = SharedData.properties[SharedData.selectedProperty].expression,
                    type = SharedData.properties[SharedData.selectedProperty].type,
                    index = SharedData.selectedProperty
                }
            end
            imgui.SameLine()
            if imgui.SmallButton('Remove Property') then
                SharedData.removeProperty(nil, SharedData.selectedProperty)
                SharedData.selectedProperty = -1
                SharedData.doSave = true
            end
        end
        if imgui.BeginTable('properties', 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.BordersInner, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY), ImVec2(-1,-1)) then
            imgui.TableSetupColumn('##selected', ImGuiTableColumnFlags.None, 1)
            imgui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2)
            imgui.TableSetupColumn('Expression', ImGuiTableColumnFlags.None, 4)
            imgui.TableSetupScrollFreeze(0, 1)
            imgui.TableHeadersRow()

            local clipper = ImGuiListClipper.new()
            clipper:Begin(#SharedData.properties)
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

                    imgui.Text('%s', property.key)
                    imgui.TableNextColumn()

                    imgui.Text('%s', property.expression)
                end
            end

            imgui.EndTable()
        end
        imgui.EndTabItem()
    end
end

function SharedData.renderCustomDataSourcesTab()
    if imgui.BeginTabItem('Custom Sources') then
        if SharedData.currentTab ~= 'Custom Sources' then
            SharedData.currentTab = 'Custom Sources'
            SharedData.selectedProperty = -1
        end
        if imgui.SmallButton('Add Data Source') then
            SharedData.openPropertyGUI = true
            SharedData.propertyGUIAction = 'Add Data Source'
            SharedData.showAddError = false
            SharedData.errorMessage = nil
        end
        if SharedData.selectedProperty ~= -1 then
            imgui.SameLine()
            if imgui.SmallButton('Remove Data Source') then
                SharedData.removeSource(SharedData.customDataSources[SharedData.selectedProperty])
                SharedData.selectedProperty = -1
                SharedData.doSave = true
            end
        end
        if imgui.BeginTable('customsources', 3, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.BordersInner, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY), ImVec2(-1,-1)) then
            imgui.TableSetupColumn('##selected', ImGuiTableColumnFlags.None, 1)
            imgui.TableSetupColumn('Filename', ImGuiTableColumnFlags.None, 2)
            imgui.TableSetupScrollFreeze(0, 1)
            imgui.TableHeadersRow()

            local clipper = ImGuiListClipper.new()
            clipper:Begin(#SharedData.customDataSources)
            while clipper:Step() do
                for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
                    local filename = SharedData.customDataSources[row_n+1]

                    imgui.TableNextRow()
                    imgui.TableNextColumn()

                    local value, pressed = imgui.Checkbox('##selected'..filename, row_n+1 == SharedData.selectedProperty)
                    if pressed then
                        if value then
                            SharedData.selectedProperty = row_n+1
                        else
                            SharedData.selectedProperty = -1
                        end
                    end
                    imgui.TableNextColumn()

                    imgui.Text(filename)
                end
            end

            imgui.EndTable()
        end
        imgui.EndTabItem()
    end
end

local YELLOW = ImVec4(1, 1, 0, 1)
local function drawNestedTableTree(table)
    for k, v in pairs(table) do
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        if type(v) == 'table' then
            local open = ImGui.TreeNodeEx(tostring(k), ImGuiTreeNodeFlags.SpanFullWidth)
            if open then
                drawNestedTableTree(v)
                ImGui.TreePop()
            end
        else
            ImGui.TextColored(YELLOW, '%s', k)
            ImGui.TableNextColumn()
            ImGui.Text('%s', v)
        end
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
            if imgui.BeginTable('Data', 2, bit32.bor(ImGuiTableFlags.Borders, ImGuiTableFlags.RowBg, ImGuiTableFlags.ScrollY), ImVec2(-1,-1)) then
                imgui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2)
                imgui.TableSetupColumn('Value', ImGuiTableColumnFlags.None, 3)
                imgui.TableSetupScrollFreeze(0, 1)
                imgui.TableHeadersRow()

                drawNestedTableTree(SharedData.data[SharedData.selectedCharacter])

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
            SharedData.renderCustomDataSourcesTab()
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
        local expression = property.expression or ''
        if property.type == 'Lua' then
            local success, result = evaluateString(expression)
            if success then
                if SharedData.resendAll or SharedData.data[me][property.key] ~= result then
                    message[property.key] = result
                end
            end
        else
            local current = mq.parse(property.expression)
            if SharedData.resendAll or SharedData.data[me][property.key] ~= current then
                message[property.key] = current
            end
        end
    end
    for _,customDataTable in pairs(SharedData.customData) do
        for k,v in pairs(customDataTable) do
            local current = v
            if type(v) == 'function' then
                local ok, result = pcall(v)
                if ok then
                    current = result
                end
            end
            if SharedData.resendAll or SharedData.data[me][k] ~= current then
                message[k] = current
            end
        end
    end
    SharedData.resendAll = false
    if SharedData.mailboxName then
        SharedData.actor:send({mailbox=SharedData.mailboxName}, message)
    else
        SharedData.actor:send(message)
    end
end

function SharedData.useProvidedDataSource(dataSource)
    if not fileExists(dataSource) then return false end
    local ok, customData = pcall(loadfile, dataSource)
    if ok and customData then
        SharedData.customDataSources = {}
        SharedData.customData = {}
        SharedData.properties = {}
        SharedData.usingProvidedDataSource = true
        SharedData.customData[dataSource] = customData()
    end
end

function SharedData.loadSettings()
    local configFile = ('%s/shareddata/%s_%s_shareddata.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me())
    if not fileExists(configFile) then return end
    local settings = assert(loadfile(configFile))()
    if not settings then return end
    for k,v in pairs(settings.settings) do SharedData.settings[k] = v end
    for k,v in pairs(settings.properties) do
        SharedData.properties[k] = v
        if SharedData.properties[k].type == nil then SharedData.properties[k].type = 'MacroScript' end
    end
    for _,v in ipairs(settings.customDataSources or {}) do
        table.insert(SharedData.customDataSources, v)
        local ok, customData = pcall(loadfile, mq.configDir..'/shareddata/'..v)
        if ok and customData then
            SharedData.customData[v] = customData()
        end
    end
end

function SharedData.saveSettings()
    local configFile = ('%s/shareddata/%s_%s_shareddata.lua'):format(mq.configDir, mq.TLO.EverQuest.Server(), mq.TLO.Me())
    mq.pickle(configFile, {settings=SharedData.settings, properties=SharedData.properties, customDataSources=SharedData.customDataSources, version=SharedData._version})
    SharedData.doSave = false
end

function SharedData.bind(...)
    local args = {...}
    -- help
    if #args == 0 or args[1] == 'help' then
        local output = '\a-t[SharedDataClient]\ax v\ay%s\ax\n'
        output = output .. '\t\aw- /sdc add key type expression'
        output = output .. '\t\aw- /sdc addall key type expression'
        output = output .. '\t\aw- /sdc remove key'
        output = output .. '\t\aw- /sdc removeall key'
        output = output .. '\t\aw- /sdc list'
        output = output .. '\t\aw- /sdc addsource filename'
        output = output .. '\t\aw- /sdc addsourceall filename'
        output = output .. '\t\aw- /sdc removesource filename'
        output = output .. '\t\aw- /sdc removesourceall filename'
        output = output .. '\t\aw- /sdc listsources'
        output = output .. '\t\aw- /sdc show'
        output = output .. '\t\aw- /sdc hide'
        output = output .. '\t\aw- /sdc help'
        printf(output, SharedData._version)
    -- add property
    elseif args[1] == 'add' then
        if args[3] == 'lua' then args[3] = 'Lua' elseif args[3] == 'macro' then args[3] = 'MacroScript' end
        SharedData.addProperty(args[2], args[3], args[4])
    -- broadcast add to everyone
    elseif args[1] == 'addall' then
        if args[3] == 'lua' then args[3] = 'Lua' elseif args[3] == 'macro' then args[3] = 'MacroScript' end
        local key = args[2]
        local type = args[3]
        local value = args[4]
        if key and type and value then
            SharedData.actor:send({action = 'add', key = key, expression = value, type = type})
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
    -- add custom data source filename to this character
    elseif args[1] == 'addsource' then
        SharedData.addSource(args[2])
    -- add custom data source filename to all characters
    elseif args[1] == 'addsourceall' then
        local filename = args[2]
        if filename then
            SharedData.actor:send({action = 'addsource', filename = filename})
        end
    -- remove custom data source filename on this character
    elseif args[1] == 'removesource' then
        SharedData.removeSource(args[2])
    -- remove custom data source filename on all characters
    elseif args[1] == 'removesourceall' then
        local filename = args[2]
        if filename then
            SharedData.actor:send({action = 'removesource', filename = filename})
        end
    -- list custom data source filenames
    elseif args[1] == 'listsources' then
        local output = ''
        for _,filename in ipairs(SharedData.customDataSources) do
            output = output .. ('- \aw%s\ax\n'):format(filename)
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

---Initializes the SharedData client. Providing a dataSource value will result in no other configured
---properties or custom data sources being used. The CLI, UI and TLO will also be disabled when dataSource
---is provided. Character data can be accessed via SharedData.data table instead in this mode.
---@param runInBackground boolean # Set true to start the script with UI closed.
---@param mailboxName? string # Name to be used for actor mailbox.
---@param dataSource? string # Path to custom data source lua file which should be loaded.
function SharedData.init(runInBackground, mailboxName, dataSource)
    -- read config
    SharedData.loadSettings()
    if runInBackground then SharedData.openGUI = false end

    -- If embedded in another script, that script may provide the source for what should be published.
    -- When run in this way, no other configured properties or custom sources will be used.
    if dataSource then
        SharedData.useProvidedDataSource(dataSource)
    end

    -- When embedded in another script which provides its own datasource, do not setup the CLI, UI or TLO.
    -- Received data will just be available via SharedData.Characters to the embedding script.
    if not SharedData.usingProvidedDataSource then
        -- setup binds
        mq.bind('/sdc', SharedData.bind)

        -- setup gui
        mq.imgui.init('SharedData', SharedData.render)

        -- setup TLO
        SharedData.initTLO()
    end

    -- setup actor
    -- When embedded in another script, a custom mailbox name may be provided to avoid conflicts.
    if mailboxName then
        SharedData.actor = actors.register(mailboxName, SharedData.messageHandler)
        SharedData.mailboxName = mailboxName
    else
        SharedData.actor = actors.register(SharedData.messageHandler)
    end
end

function SharedData.cleanup()
    if mq.gettime() - SharedData.settings.cleanupInterval < 15000 then return end
    for name, data in pairs(SharedData.data) do
        if mq.gettime() - (data.sentAt or 0) > SharedData.settings.staleDataTimeout then
            SharedData.data[name] = nil
        end
    end
end

---Main loop component of the SharedData client. Responsible for publishing data and cleaning stored data.
function SharedData.process()
    local inGame = mq.TLO.EverQuest.GameState()
    SharedData.cleanup()
    if inGame == 'INGAME' then SharedData.publish() end
    if SharedData.doSave then SharedData.saveSettings() end
end

return {
    init = SharedData.init,
    process = SharedData.process,
    settings = SharedData.settings,
    data = SharedData.data,
}