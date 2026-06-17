local polyzones = {}
local isLooping = false
local Zones = lib.callback.await('drugs:server:getZones', false)
local timerRunning = false
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

local function progressActive()
    return timerRunning
end

local function cancelProgress()
    if timerRunning then
        exports.mt_lib:hideTimer()
        timerRunning = false
    end
end

local function progressBar(options)
    if timerRunning then return false end

    local durationSeconds = math.max(1, math.ceil(options.duration / 1000))
    local finished = false

    timerRunning = true
    exports.mt_lib:showTimer(options.label, durationSeconds, 'bottom', function()
        finished = true
        timerRunning = false
    end)

    while timerRunning and not finished do
        Wait(0)
    end

    return finished
end

local function ToggleFarm(item)
    local playerPed = cache.ped
    local zone = Zones.Marker[item]
    local hasAnim = zone.animDict ~= nil
    local dict = hasAnim and zone.animDict or nil
    local animName = hasAnim and zone.animName or nil

    if hasAnim and dict then
        lib.requestAnimDict(dict)
    end

    if isLooping then
        isLooping = false
        ClearPedTasks(playerPed)
        SetEntityCollision(playerPed, true, true)
        FreezeEntityPosition(playerPed, false)
        if hasAnim and dict then
            RemoveAnimDict(dict)
        end
        if progressActive() then cancelProgress() end
        lib.showTextUI(string.format('[E] %s', getLocale('farm_start')), {
            alignIcon = 'center',
            icon = zone.icon,
            iconColor = zone.iconColor,
        })
    else
        isLooping = true
        if hasAnim and dict then
            TaskPlayAnim(playerPed, dict, animName, 2.0, -8.0, -1, 35, 0, 0, 0, 0)
        else
            TaskStartScenarioInPlace(playerPed, zone.scenario, 0, true)
        end
        FreezeEntityPosition(playerPed, true)
        SetEntityCollision(playerPed, false, false)
        lib.showTextUI(string.format('[E] %s', getLocale('farm_stop')), {
            alignIcon = 'center',
            icon = zone.icon,
            iconColor = zone.iconColor,
        })
        CreateThread(function()
            while isLooping do
                Wait(0)
                if progressBar({
                        duration = zone.farmTime,
                        label = string.format('%s...', getLocale('farming')),
                    }) then
                    local newPlayerped = cache.ped
                    local stillActive = (hasAnim and dict and IsEntityPlayingAnim(newPlayerped, dict, animName, 3)) or (not hasAnim and IsPedUsingScenario(newPlayerped, zone.scenario))

                    if playerPed ~= newPlayerped or not stillActive then
                        isLooping = false
                        ClearPedTasks(newPlayerped)
                        SetEntityCollision(newPlayerped, true, true)
                        FreezeEntityPosition(playerPed, false)
                        if hasAnim and dict then
                            RemoveAnimDict(dict)
                        end
                        lib.showTextUI(string.format('[E] %s', getLocale('farm_start')), {
                            alignIcon = 'center',
                            icon = zone.icon,
                            iconColor = zone.iconColor,
                        })
                        return
                    end
                    lib.callback.await('drugs:server:giveItem', false, item)
                end
            end
            SetEntityCollision(playerPed, true, true)
            FreezeEntityPosition(playerPed, false)
            if hasAnim and dict then
                RemoveAnimDict(dict)
            end
        end)
    end
end

local function ToggleOmdan(item)
    local zone = Zones.Omdanner[item]
    local hasRecipe, missingItem = lib.callback.await('drugs:server:hasRecipe', false, item)
    if not hasRecipe then
        if missingItem then
            lib.notify({ title = getLocale('missing_item', missingItem), type = 'inform' })
        end
        return
    end
    local dict = zone.animDict
    local animName = zone.animName
    lib.requestAnimDict(dict)
    local playerPed = cache.ped
    if isLooping then
        isLooping = false
        ClearPedTasks(playerPed)
        SetEntityCollision(playerPed, true, true)
        FreezeEntityPosition(playerPed, false)
        RemoveAnimDict(dict)
        if progressActive() then cancelProgress() end
        lib.showTextUI(string.format('[E] %s', getLocale('process_start')), {
            alignIcon = 'center',
            icon = zone.icon,
            iconColor = zone.iconColor,
        })
    else
        isLooping = true
        FreezeEntityPosition(playerPed, true)
        TaskPlayAnim(playerPed, dict, animName, 2.0, -8.0, -1, 35, 0, 0, 0, 0)
        SetEntityCollision(playerPed, false, false)
        lib.showTextUI(string.format('[E] %s', getLocale('process_stop')), {
            alignIcon = 'center',
            icon = zone.icon,
            iconColor = zone.iconColor,
        })
        CreateThread(function()
            while isLooping do
                Wait(0)
                hasRecipe, missingItem = lib.callback.await('drugs:server:hasRecipe', false, item)
                if not hasRecipe then
                    isLooping = false
                    ClearPedTasks(playerPed)
                    SetEntityCollision(playerPed, true, true)
                    FreezeEntityPosition(playerPed, false)
                    RemoveAnimDict(dict)
                    lib.showTextUI(string.format('[E] %s', getLocale('process_start')), {
                        alignIcon = 'center',
                        icon = zone.icon,
                        iconColor = zone.iconColor,
                    })
                    if missingItem then
                        lib.notify({ title = getLocale('missing_item', missingItem), type = 'inform' })
                    end
                    return
                end
                if progressBar({
                        duration = zone.processTime,
                        label = string.format('%s...', getLocale('processing')),
                    }) then
                    local newPlayerped = cache.ped
                    if playerPed ~= newPlayerped or not IsEntityPlayingAnim(playerPed, dict, animName, 3) then
                        isLooping = false
                        ClearPedTasks(newPlayerped)
                        SetEntityCollision(newPlayerped, true, true)
                        FreezeEntityPosition(newPlayerped, false)
                        RemoveAnimDict(dict)
                        lib.showTextUI(string.format('[E] %s', getLocale('process_start')), {
                            alignIcon = 'center',
                            icon = zone.icon,
                            iconColor = zone.iconColor,
                        })
                        return
                    end
                    lib.callback.await('drugs:server:giveItem', false, item)
                end
            end
            SetEntityCollision(playerPed, true, true)
            FreezeEntityPosition(playerPed, false)
        end)
    end
end

CreateThread(function()
    for k, v in pairs(Zones.Marker) do
        polyzones[k] = lib.zones.poly({
            name = k,
            points = v.points,
            debug = Config.Dev,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    ToggleFarm(k)
                end
            end,
            onEnter = function()
                lib.showTextUI(string.format('[E] %s', getLocale('farm_start')), {
                    alignIcon = 'center',
                    icon = v.icon,
                    iconColor = v.iconColor,
                })
            end,
            onExit = function()
                isLooping = false
                lib.hideTextUI()
            end
        })
    end

    for k, v in pairs(Zones.Omdanner) do
        polyzones[k] = lib.zones.poly({
            name = k,
            points = v.points,
            debug = Config.Dev,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    ToggleOmdan(k)
                end
            end,
            onEnter = function()
                lib.showTextUI(string.format('[E] %s', getLocale('process_start')), {
                    alignIcon = 'center',
                    icon = v.icon,
                    iconColor = v.iconColor,
                })
            end,
            onExit = function()
                isLooping = false
                lib.hideTextUI()
            end
        })
    end
end)