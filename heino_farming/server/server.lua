local lastActions = {}
local locales = {}

local function loadLocales()
    local files = {
        da = LoadResourceFile(GetCurrentResourceName(), 'locales/da.json'),
        en = LoadResourceFile(GetCurrentResourceName(), 'locales/en.json'),
    }
    
    for lang, data in pairs(files) do
        if data then
            local success, result = pcall(json.decode, data)
            if success then
                locales[lang] = result
            end
        end
    end
end

loadLocales()

local function getLocale(key, ...)
    local lang = Config.lang or 'en'
    local locale = locales[lang] or locales['en']
    local text = locale and locale[key] or key
    
    if ... then
        return text:format(...)
    end
    return text
end

local function isPointInPolygon(point, polygon)
    local x, y = point.x, point.y
    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        local xi, yi = polygon[i].x, polygon[i].y
        local xj, yj = polygon[j].x, polygon[j].y

        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end

        j = i
    end

    return inside
end

local function isPlayerInZone(src, points)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local coords = GetEntityCoords(ped)
    if not isPointInPolygon(coords, points) then return false end

    local minZ, maxZ = points[1].z, points[1].z
    for i = 2, #points do
        local z = points[i].z
        if z < minZ then minZ = z end
        if z > maxZ then maxZ = z end
    end

    return coords.z >= minZ - 5.0 and coords.z <= maxZ + 5.0
end

local function getItemConfig(itemId)
    return Config.Items[itemId]
end

local function getLocationPoints(itemId)
    local config = getItemConfig(itemId)
    if not config then return nil end
    
    if config.type == 'farm' then
        return Lokationer.Marker[itemId] and Lokationer.Marker[itemId].points
    elseif config.type == 'process' then
        return Lokationer.Omdanner[itemId] and Lokationer.Omdanner[itemId].points
    end
    return nil
end

lib.callback.register('drugs:server:getZones', function()
    local zones = { Marker = {}, Omdanner = {} }
    
    for itemId, config in pairs(Config.Items) do
        if config.type == 'farm' and Lokationer.Marker[itemId] then
            zones.Marker[itemId] = {
                points = Lokationer.Marker[itemId].points,
                label = config.label,
                farmTime = config.farmTime,
                scenario = config.scenario,
                animDict = config.animDict,
                animName = config.animName,
                icon = config.icon,
                iconColor = config.iconColor,
                type = 'farm',
            }
        elseif config.type == 'process' and Lokationer.Omdanner[itemId] then
            zones.Omdanner[itemId] = {
                points = Lokationer.Omdanner[itemId].points,
                label = config.label,
                processTime = config.processTime,
                animDict = config.animDict,
                animName = config.animName,
                icon = config.icon,
                iconColor = config.iconColor,
                requires = config.processRequires,
                processAmount = config.processAmount,
                type = 'process',
            }
        end
    end
    
    return zones
end)

lib.callback.register('drugs:server:giveItem', function(source, itemId)
    local src = source
    local config = getItemConfig(itemId)
    
    if not config then
        lib.logger.warn(('%s - %s: %s'):format(src, GetPlayerName(src), getLocale('invalid_item')))
        return false
    end
    
    local points = getLocationPoints(itemId)
    if not points then
        return false
    end
    
    if not isPlayerInZone(src, points) then
        lib.logger.warn(('%s - %s: %s'):format(src, GetPlayerName(src), getLocale('outside_zone')))
        return false
    end
    
    local timeToDo = (config.farmTime or config.processTime or 10500) - 1000
    
    if lastActions[src] and lastActions[src].time + timeToDo / 1000 > os.time() then
        lib.logger.warn(('%s - %s: %s'):format(src, GetPlayerName(src), getLocale('too_fast')))
        return false
    end
    
    lastActions[src] = { item = itemId, time = os.time() }
    
    if config.type == 'process' then
        for reqItem, reqAmount in pairs(config.processRequires) do
            if not exports['ox_inventory']:RemoveItem(src, reqItem, reqAmount) then
                lib.notify(src, { title = getLocale('no_items'), type = 'error' })
                return false
            end
        end
    end
    
    local amount = config.type == 'farm' and config.farmAmount or config.processAmount
    exports['ox_inventory']:AddItem(src, itemId, amount)
    
    lib.notify(src, { 
        title = getLocale('item_added', amount, config.label), 
        type = 'success' 
    })
    
    return true
end)

lib.callback.register('drugs:server:hasRecipe', function(src, itemId)
    local config = getItemConfig(itemId)
    if not config or config.type ~= 'process' then return false end
    
    local points = getLocationPoints(itemId)
    if not points or not isPlayerInZone(src, points) then
        return false
    end
    
    for reqItem, amount in pairs(config.processRequires) do
        local count = exports.ox_inventory:Search(src, 'count', reqItem)
        if count < amount then
            return false, reqItem
        end
    end
    
    return true
end)