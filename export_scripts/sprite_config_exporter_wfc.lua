local spr = app.activeSprite
if not spr then return print('No active sprite') end

local path,title = spr.filename:match("^(.+[/\\])(.-).([^.]*)$")

local prefConfigPath = app.fs.userConfigPath .. 'wfc_sprite_prefs' .. '.json'

local atlasConfigPath, spriteAtlasPath, spriteConfigPath, spriteAnimPath = nil, nil, nil, nil


function LoadExporterPrefs()
    -- Set default values
    atlasConfigPath = path .. 'atlas_config' .. '.json'
    spriteAtlasPath = path .. title .. '.png'
    spriteConfigPath = path .. title .. '.json'
    spriteAnimPath = path .. title .. '_animation' .. '.json'

    local prefsTable = DecodeFileIntoTable(prefConfigPath)
    if prefsTable then
        if prefsTable["atlasConfigPath"] then
            local justPath = prefsTable["atlasConfigPath"]
            atlasConfigPath = app.fs.joinPath(justPath, 'atlas_config.json')
        end
        if prefsTable["spriteAtlasPath"] then
            local justPath = prefsTable["spriteAtlasPath"]
            local endPath = title .. '.png'
            spriteAtlasPath = app.fs.joinPath(justPath, endPath)
        end
        if prefsTable["spriteConfigPath"] then
            local justPath = prefsTable["spriteConfigPath"]
            local endPath = title .. '.json'
            spriteConfigPath = app.fs.joinPath(justPath, endPath)
        end
        if prefsTable["animConfigPath"] then
            local justPath = prefsTable["animConfigPath"]
            local endPath = title .. '_animation' .. '.json'
            spriteAnimPath = app.fs.joinPath(justPath, endPath)
        end
    end
end


function SaveExporterPref(prefKey, prefValue)
    local prefsTable = DecodeFileIntoTable(prefConfigPath)
    if prefsTable == nil then
        prefsTable = {}
    end

    prefsTable[prefKey] = prefValue;

    local myFilePath = prefConfigPath
    local json_as_string = json.encode(prefsTable)
    local newFile = io.open(myFilePath, "w")
    newFile.write(newFile, json_as_string)
    newFile.close(newFile)

end


function DecodeFileIntoTable(path)
    local pathToJsonFile = io.open(path, "r")
    if pathToJsonFile then
        local contentAsString = pathToJsonFile:read("a")
        local myTable = json.decode(contentAsString)
        return myTable;
    end
    return nil
end


function RunStandardExport(name)
    -- local fn = path .. title
    app.command.ExportSpriteSheet {
        ui = false,
        type = SpriteSheetType.PACKED,
        textureFilename = spriteAtlasPath,
        dataFilename = name .. '.json',
        dataFormat = SpriteSheetDataFormat.JSON_ARRAY,
        filenameFormat = "{title}_{frame}",
        listLayers = false,
        listTags = false,
        listSlices = false
    }
end


function AtlasExistsInConfig(dataTable, atlasRef)
    if dataTable == nil then
        return false
    end

    for key, entry in pairs(dataTable) do
        if key == atlasRef then
            return true
        end
    end
    return false
end


function AddToAtlasConfig(name, optionalConfigData)
    local dataTable = DecodeFileIntoTable(atlasConfigPath)
    local exportFile = false;

    if not AtlasExistsInConfig(dataTable, name) then
        -- Data we always include
        local newAtlas = {
            atlasRef = name,
            atlasConfigPath = name .. '.json',
            atlasPath = name .. '.png'
        }

        -- Additional data we can include if needed
        -- if optionalConfigData ~= nil then
        --     for _, entry in pairs(optionalConfigData) do
        --         table.insert(newAtlas, entry)
        --     end
        -- end

        if dataTable == nil then
            dataTable = {}
            dataTable[name] = newAtlas
        else
            dataTable[name] = newAtlas
        end

        -- TODO: Remove this and just mark exportFile as true
        local myFilePath = atlasConfigPath
        local json_as_string = json.encode(dataTable)
        local newFile = io.open(myFilePath, "w")
        newFile.write(newFile, json_as_string)
        newFile.close(newFile)
    else
        -- The atlas exists, if we have optionalConfigData then we need to add that
        if dataTable ~= nil and optionalConfigData ~= nil then
            for atlasKey, entry in pairs(dataTable) do
                if atlasKey == name then
                    for key, data in pairs(optionalConfigData) do
                        if entry[key] == nil then
                            entry[key] = data
                            exportFile = true
                        end
                    end
                end
            end
        end
    end

    if exportFile then
        local myFilePath = atlasConfigPath
        local json_as_string = json.encode(dataTable)
        local newFile = io.open(myFilePath, "w")
        newFile.write(newFile, json_as_string)
        newFile.close(newFile)
    end
end


function SpriteHasTags()
    return spr.tags ~= nil;
end


function GetSpriteTableForFrames(name, startFrame, endFrame)
    local spriteTable = {};
    for i = startFrame, endFrame, 1 do
        local frameRef = name .. "_" .. tostring(i - 1)
        table.insert(spriteTable, frameRef)
    end

    return spriteTable;
end


function ExportAnimationConfig(atlasRef, width, height)
    local animationsTable = {}
    for i, tag in ipairs(spr.tags) do
        local data = {
            animRef = tag.name,
            sprites = GetSpriteTableForFrames(atlasRef, tag.fromFrame.frameNumber, tag.toFrame.frameNumber),
            frameCount = tag.frames,
        }

        table.insert(animationsTable, data)
    end
    
    local animConfigData = {
        atlasRef = atlasRef,
        animData = animationsTable,
        spriteWidth = width,
        spriteHeight = height,
    }

    local myFilePath = spriteAnimPath
    local json_as_string = json.encode(animConfigData)
    local newFile = io.open(myFilePath, "w")
    newFile.write(newFile, json_as_string)
    newFile.close(newFile)
end


function ExportSpriteConfig()
    local fn = path .. title
    
    RunStandardExport(fn)

    local dataTable = DecodeFileIntoTable(fn .. '.json')

    if dataTable == nil then
        return;
    end

    -- We are assuming all sprites have the same width and height
    local width, height = 0, 0

    -- Update the table here with data we want
    local framesTable = dataTable["frames"]
    for _, val in pairs(framesTable) do
        -- Clear values we don't care about
        val["duration"] = nil
        val["rotated"] = nil
        val["sourceSize"] = nil
        val["spriteSourceSize"] = nil
        val["trimmed"] = nil

        width = val["frame"]["w"]
        height = val["frame"]["h"]
    end

    -- We are assuming all sprites have the same width and height
    -- local width, height = 0, 0
    -- if framesTable[0] and framesTable[0]["frame"] then
    --     width = framesTable[0]["frame"]["w"]
    --     height = framesTable[0]["frame"]["h"]
    -- end

    -- Add atlas ref to the meta table
    local metaDataTable = dataTable["meta"]
    metaDataTable["atlasRef"] = title

    -- Write the file again after the changes
    local myFilePath = spriteConfigPath
    local json_as_string = json.encode(dataTable)
    local newFile = io.open(myFilePath, "w")
    newFile.write(newFile, json_as_string)
    newFile.close(newFile)


    local optionalConfigData = {}

    -- Optional animation config file
    -- If any tags exist, we want to export a corresponding config file for the animations they represent
    if SpriteHasTags() then
        optionalConfigData["animationConfigPath"] = title .. '_animation' .. '.json';
        ExportAnimationConfig(title, width, height);
    end

    -- TODO: Check to see if a relationship data file exists, and if so add it to the atlas config

    AddToAtlasConfig(title, optionalConfigData)
end


function UpdateAtlasConfigFilepath(data)
    atlasConfigPath = data.atlasConfigFile
    local justPath = app.fs.filePath(atlasConfigPath)
    SaveExporterPref("atlasConfigPath", justPath)
end


function UpdateSpriteExportFilepath(data)
    spriteAtlasPath = data.spriteAtlasFile
    local justPath = app.fs.filePath(spriteAtlasPath)
    SaveExporterPref("spriteAtlasPath", justPath)
end


function UpdateSpriteConfigFilepath(data)
    spriteConfigPath = data.spriteAtlasFile
    local justPath = app.fs.filePath(spriteConfigPath)
    SaveExporterPref("spriteConfigPath", justPath)
end


function UpdateSpriteAnimFilepath(data)
    spriteAnimPath = data.animConfigFile
    local justPath = app.fs.filePath(spriteAnimPath)
    SaveExporterPref("animConfigPath", justPath)
end


-- UI
LoadExporterPrefs()

local dlg = Dialog{ title="Sprite Config Exporter"}

dlg:file {
    id="atlasConfigFile",
    label="Atlas Config:",
    open=false,
    save=true,
    filename=atlasConfigPath,
    filetypes={'json'},
    onchange=function ()
        local dlgData = dlg.data
        UpdateAtlasConfigFilepath(dlgData)
    end
}

dlg:file {
    id="spriteAtlasFile",
    label="Sprite Atlas:",
    open=false,
    save=true,
    filename=spriteAtlasPath,
    filetypes={'png'},
    onchange=function ()
        local dlgData = dlg.data
        UpdateSpriteExportFilepath(dlgData)
    end
}

dlg:file {
    id="spriteConfigFile",
    label="Sprite Config:",
    open=false,
    save=true,
    filename=spriteConfigPath,
    filetypes={'json'},
    onchange=function ()
        local dlgData = dlg.data
        UpdateSpriteConfigFilepath(dlgData)
    end
}

dlg:file {
    id="animConfigFile",
    label="Sprite Anim Config:",
    open=false,
    save=true,
    filename=spriteAnimPath,
    filetypes={'json'},
    onchange=function ()
        local dlgData = dlg.data
        UpdateSpriteAnimFilepath(dlgData)
    end
}

dlg:button {
    id="exportButtonID",
    text="Export Sprites",
    onclick=function ()
        ExportSpriteConfig()
        dlg:close()
    end
}

dlg:show()