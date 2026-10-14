local MAX_PROPS_PER_PLAYER = 5
local ENTITY_WAIT_MS = 1500

local playerProps = {}
local recentlyReleased = {}

local blacklistedProps = {
    [`prop_beach_fire`] = true,
}

local function log(message)
    print(('[RS Field Terminal Progressbar] %s'):format(message))
end

local function ensurePlayerTables(src)
    playerProps[src] = playerProps[src] or {}
    recentlyReleased[src] = recentlyReleased[src] or {}
end

local function markReleased(src, netId)
    ensurePlayerTables(src)
    recentlyReleased[src][netId] = true
    SetTimeout(5000, function()
        if recentlyReleased[src] then recentlyReleased[src][netId] = nil end
    end)
end

local function waitForEntity(netId)
    local startedAt = GetGameTimer()
    local entity = NetworkGetEntityFromNetworkId(netId)

    while (entity == 0 or not DoesEntityExist(entity)) and GetGameTimer() - startedAt < ENTITY_WAIT_MS do
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end

    if entity == 0 or not DoesEntityExist(entity) then return 0 end
    return entity
end

local function entityOwnedBy(entity, src)
    if type(NetworkGetEntityOwner) ~= 'function' then return true end
    local owner = NetworkGetEntityOwner(entity)
    return owner == src
end

local function isObjectEntity(entity)
    if type(GetEntityType) ~= 'function' then return true end
    return GetEntityType(entity) == 3
end

local function deleteTrackedEntity(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function registerProps(src, netIds, models)
    if type(netIds) ~= 'table' or type(models) ~= 'table' then return end
    if #netIds == 0 or #netIds ~= #models or #netIds > MAX_PROPS_PER_PLAYER then
        log(('Rejected malformed prop registration from player %s.'):format(src))
        return
    end

    ensurePlayerTables(src)

    CreateThread(function()
        for index = 1, #netIds do
            if not GetPlayerName(src) then return end

            local netId = tonumber(netIds[index]) or 0
            local claimedModel = tonumber(models[index]) or 0
            if netId == 0 or claimedModel == 0 then
                log(('Rejected invalid prop data from player %s.'):format(src))
                goto continue
            end

            if recentlyReleased[src] and recentlyReleased[src][netId] then goto continue end

            local entity = waitForEntity(netId)
            if entity == 0 then
                log(('Could not resolve prop net ID %s from player %s.'):format(netId, src))
                goto continue
            end

            local actualModel = GetEntityModel(entity)
            local valid = isObjectEntity(entity)
                and entityOwnedBy(entity, src)
                and actualModel == claimedModel
                and not blacklistedProps[actualModel]

            if not valid then
                log(('Rejected prop from player %s (netId=%s, claimed=%s, actual=%s).'):format(
                    src,
                    netId,
                    claimedModel,
                    actualModel
                ))
                if entityOwnedBy(entity, src) then DeleteEntity(entity) end
                goto continue
            end

            local trackedCount = 0
            for _ in pairs(playerProps[src]) do trackedCount = trackedCount + 1 end
            if trackedCount >= MAX_PROPS_PER_PLAYER then
                DeleteEntity(entity)
                log(('Player %s exceeded the prop limit.'):format(src))
                goto continue
            end

            playerProps[src][netId] = true

            ::continue::
        end
    end)
end

local function cleanupProps(src, netIds)
    if type(netIds) ~= 'table' or #netIds > MAX_PROPS_PER_PLAYER then return end
    ensurePlayerTables(src)

    for _, rawNetId in ipairs(netIds) do
        local netId = tonumber(rawNetId) or 0
        if netId ~= 0 then
            markReleased(src, netId)
            if playerProps[src][netId] then
                deleteTrackedEntity(netId)
                playerProps[src][netId] = nil
            end
        end
    end
end


RegisterNetEvent('progressbar:server:register_props', function(netIds, models)
    registerProps(source, netIds, models)
end)

RegisterNetEvent('progressbar:server:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

-- Branded v3.x event names remain accepted for in-place upgrades.
RegisterNetEvent('rsfield-progressbar:server:register_props', function(netIds, models)
    registerProps(source, netIds, models)
end)

RegisterNetEvent('rsfield-progressbar:server:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

-- Legacy keep-progressbar event names remain accepted for older integrations.
RegisterNetEvent('keep-progressbar:server:register_props', function(netIds, models)
    registerProps(source, netIds, models)
end)

RegisterNetEvent('keep-progressbar:server:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

RegisterNetEvent('keep-progressbar:serer:cleanup_props', function(netIds)
    cleanupProps(source, netIds)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playerProps[src] then
        for netId in pairs(playerProps[src]) do deleteTrackedEntity(netId) end
    end
    playerProps[src] = nil
    recentlyReleased[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, props in pairs(playerProps) do
        for netId in pairs(props) do deleteTrackedEntity(netId) end
    end
end)

CreateThread(function()
    Wait(3000)

    local resourceName = GetCurrentResourceName()
    local version = GetResourceMetadata(resourceName, 'version', 0) or 'unknown'

    if resourceName ~= 'progressbar' then
        log(('INSTALL ERROR: resource folder is named "%s". Rename it to exactly "progressbar" before starting the server.'):format(resourceName))
        return
    end

    log(('v%s server safety ready — validated prop tracking and cleanup enabled.'):format(version))
end)
