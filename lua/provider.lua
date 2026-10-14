local RESOURCE_NAME = GetCurrentResourceName()

local function log(message)
    print(('[RS Field Terminal Progressbar] %s'):format(message))
end


local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' and type(value) ~= 'userdata' then return false end

    local ok, metatable = pcall(getmetatable, value)
    return ok and metatable and type(metatable.__call) == 'function'
end

local function callSafely(label, callback, ...)
    if not isCallable(callback) then return true end

    local ok, err = pcall(callback, ...)
    if not ok then
        log(('%s callback failed: %s'):format(label, tostring(err)))
    end
    return ok
end

local function markCompatibilityCompletion(data)
    if type(data) ~= 'table' then return data end

    local copy = {}
    for key, value in pairs(data) do copy[key] = value end
    copy._completionAuthority = 'lua'
    return copy
end

local function replaceExport(resourceName, exportName, func)
    local eventName = ('__cfx_export_%s_%s'):format(resourceName, exportName)
    AddEventHandler(eventName, function(setCallback)
        setCallback(func)
    end)
end

-- --------------------------------------------------------------------------
-- Native / QBCore / Qbox common progressbar API
-- --------------------------------------------------------------------------

local function startNative(data, onFinish)
    return Progress:Start(data, nil, onFinish)
end

local function cancelNative(force)
    return Progress:Cancel(force == true, 'export')
end

local function isActive()
    return Progress:IsActive()
end

local function compatibilityDuration(data)
    if type(data) ~= 'table' then return 3000 end

    if type(data.stages) == 'table' and #data.stages > 0 then
        local total = 0
        for _, stage in ipairs(data.stages) do
            total = total + math.max(tonumber(stage.duration) or 0, 0)
        end
        if total > 0 then return total end
    end

    return math.max(tonumber(data.duration) or 3000, 1)
end

local function startQbCompatibility(data, onStart, onTick, onFinish)
    local settled = false

    if Config.devMode then
        log(('QBCore export received completion callback: type=%s callable=%s'):format(
            type(onFinish),
            tostring(isCallable(onFinish))
        ))
    end

    local function finishOnce(cancelled, minigameResult)
        if settled then return end
        settled = true
        if not isCallable(onFinish) then
            if Config.devMode then
                log(('QBCore compatibility callback missing or not callable (type=%s).'):format(type(onFinish)))
            end
            return
        end

        local ok = callSafely('QBCore compatibility', onFinish, cancelled == true, minigameResult)
        if ok and Config.devMode then
            log(('QBCore compatibility callback settled (cancelled=%s, type=%s).'):format(
                tostring(cancelled == true),
                type(onFinish)
            ))
        end
    end

    local started, reason = Progress:Start(markCompatibilityCompletion(data), onStart, finishOnce, onTick)
    if not started then
        finishOnce(true, nil)
        return false, reason
    end

    local runId = Progress._run_id
    local fallbackDelay = compatibilityDuration(data) + 750

    -- Exact QBCore resources such as qb-vehiclekeys award the result only from
    -- this callback. The main client already owns normal completion; this
    -- delayed ledger check is a second, once-only safety net for renamed or
    -- redesigned NUI builds so a visual completion can never silently lose the
    -- original QBCore completion callback.
    SetTimeout(fallbackDelay, function()
        if settled then return end

        local completion = Progress:GetCompletion(runId)
        if completion then
            finishOnce(completion.cancelled, nil)
            return
        end

        if Progress:IsActive() and Progress._run_id == runId then
            Progress:_sendNUI('COMPLETE', { sessionId = runId })
            Progress:_finalize(runId, false, Progress._minigame_result, 'qb_callback_failsafe')
            return
        end

        -- The run ended without a completion ledger. Never award a gameplay
        -- result when the outcome is unknown; resolve as cancelled instead of
        -- leaving qb-vehiclekeys or another caller permanently wedged.
        finishOnce(true, nil)
    end)

    return true
end

local function qbProgress(data, onFinish)
    return startQbCompatibility(data, nil, nil, onFinish)
end

local function qbProgressWithStart(data, onStart, onFinish)
    return startQbCompatibility(data, onStart, nil, onFinish)
end

local function qbProgressWithTick(data, onTick, onFinish)
    return startQbCompatibility(data, nil, onTick, onFinish)
end

local function qbProgressWithStartAndTick(data, onStart, onTick, onFinish)
    return startQbCompatibility(data, onStart, onTick, onFinish)
end

local commonExports = {
    Start = startNative,
    Progress = qbProgress,
    Progressbar = qbProgress,
    Cancel = cancelNative,
    isActive = isActive,
    isDoingSomething = isActive,
    ProgressWithStartEvent = qbProgressWithStart,
    ProgressWithTickEvent = qbProgressWithTick,
    ProgressWithStartAndTick = qbProgressWithStartAndTick,
}

-- Start, Cancel, and isActive are registered by lua/client.lua. Register the
-- remaining common exports here so every export has one deterministic owner.
local providerOwnedExports = {
    Progress = qbProgress,
    Progressbar = qbProgress,
    isDoingSomething = isActive,
    ProgressWithStartEvent = qbProgressWithStart,
    ProgressWithTickEvent = qbProgressWithTick,
    ProgressWithStartAndTick = qbProgressWithStartAndTick,
}

for name, func in pairs(providerOwnedExports) do
    exports(name, func)
end

-- Preserve direct integrations written against earlier RS releases. The
-- manifest also provides the old resource name for dependency resolution.
for name, func in pairs(commonExports) do
    replaceExport('rsfield-progressbar', name, func)
    -- Some third-party QBCore resources depend on a resource named
    -- `qb-progressbar` instead of the official `progressbar` name.
    replaceExport('qb-progressbar', name, func)
end

local progressbarEvents = {
    ['progressbar:client:cancel'] = function()
        Progress:Cancel(true, 'progressbar_event')
    end,
    ['progressbar:client:ToggleBusyness'] = function(value)
        -- Never set the internal active flag directly. Doing so can strand
        -- controls, props, animation, and inv_busy. False safely cancels.
        if value == false and Progress:IsActive() then
            Progress:Cancel(true, 'toggle_busyness')
        elseif value == true and not Progress:IsActive() and Config.devMode then
            log('Ignored ToggleBusyness(true); no progress task exists to own that state.')
        end
    end,
    ['progressbar:client:progress'] = qbProgress,
    ['progressbar:client:ProgressWithStartEvent'] = qbProgressWithStart,
    ['progressbar:client:ProgressWithTickEvent'] = qbProgressWithTick,
    ['progressbar:client:ProgressWithStartAndTick'] = qbProgressWithStartAndTick,
}

for eventName, handler in pairs(progressbarEvents) do
    RegisterNetEvent(eventName, handler)
end

-- --------------------------------------------------------------------------
-- ox-style adapter
--
-- This supports resources that can select or directly call a progress provider.
-- It intentionally does not overwrite ox_lib's own lib.progressBar function.
-- --------------------------------------------------------------------------

local function oxCancel()
    return Progress:Cancel(false, 'ox_style')
end

local function normalizeOxProp(prop)
    if type(prop) ~= 'table' then return nil end
    return {
        model = prop.model,
        bone = prop.bone,
        coords = prop.pos or prop.coords,
        rotation = prop.rot or prop.rotation,
        rotOrder = prop.rotOrder,
    }
end

local function oxProgressStart(input)
    if type(input) ~= 'table' then return false end

    local data = {}
    for key, value in pairs(input) do data[key] = value end
    data._oxSemantics = true

    if type(input.anim) == 'string' then
        data.animation = { task = input.anim }
    elseif type(input.anim) == 'table' then
        local anim = input.anim
        data.animation = {
            animDict = anim.dict,
            anim = anim.clip,
            flags = anim.flag,
            duration = anim.duration,
            blendIn = anim.blendIn,
            blendOut = anim.blendOut,
            lockX = anim.lockX,
            lockY = anim.lockY,
            lockZ = anim.lockZ,
            playbackRate = anim.playbackRate,
            task = anim.scenario,
        }
    end

    if type(input.disable) == 'table' then
        data.controlDisables = {
            disableMovement = input.disable.move,
            disableMouse = input.disable.mouse,
            disableSprint = input.disable.sprint,
            disableCarMovement = input.disable.car,
            disableCombat = input.disable.combat,
        }
    end

    if type(input.prop) == 'table' then
        if input.prop.model then
            data.prop = normalizeOxProp(input.prop)
        else
            data.props = {}
            for _, prop in ipairs(input.prop) do
                local normalized = normalizeOxProp(prop)
                if normalized then data.props[#data.props + 1] = normalized end
            end
        end
    end

    if input.position == 'middle' then
        data.position = 'center'
    elseif input.position == 'top' then
        data.position = 'center-top'
    elseif input.position == 'bottom' then
        data.position = 'center-bottom'
    end

    local deferred = promise.new()
    local started = Progress:Start(data, nil, function(cancelled)
        deferred:resolve(not cancelled)
    end)

    if not started then deferred:resolve(false) end
    return Citizen.Await(deferred)
end

local oxExports = {
    ox_lib_cancelProgress = oxCancel,
    ox_lib_progressBar = oxProgressStart,
    ox_lib_progressCircle = oxProgressStart,
    ox_lib_progressActive = isActive,
    cancelProgress = oxCancel,
    progressBar = oxProgressStart,
    progressCircle = oxProgressStart,
    progressActive = isActive,
}

for name, func in pairs(oxExports) do
    exports(name, func)
    replaceExport('rsfield-progressbar', name, func)
end

-- --------------------------------------------------------------------------
-- ESX / esx_progressbar compatibility
-- --------------------------------------------------------------------------

local function esxCancel()
    return Progress:Cancel(true, 'esx_progressbar')
end

local function esxProgressbar(message, length, options)
    options = type(options) == 'table' and options or {}

    local data = {
        label = message or 'Progress',
        duration = tonumber(length) or 3000,
        canCancel = options.canCancel ~= false,
        controlDisables = options.controlDisables,
    }

    if type(options.animation) == 'table' then
        if options.animation.type == 'anim' then
            data.animation = {
                animDict = options.animation.dict,
                anim = options.animation.lib or options.animation.clip,
                flags = options.animation.flag or options.animation.flags,
            }
        elseif options.animation.type == 'Scenario' or options.animation.type == 'scenario' then
            data.animation = {
                task = options.animation.Scenario or options.animation.scenario,
            }
        end
    end

    local ped = PlayerPedId()
    if options.FreezePlayer then FreezeEntityPosition(ped, true) end

    local started = Progress:Start(markCompatibilityCompletion(data), nil, function(cancelled, minigameResult)
        if options.FreezePlayer then FreezeEntityPosition(ped, false) end

        if cancelled then
            if isCallable(options.onCancel) then
                local ok, err = pcall(options.onCancel, minigameResult)
                if not ok then log(('ESX onCancel failed: %s'):format(tostring(err))) end
            end
            return
        end

        if isCallable(options.onFinish) then
            local ok, err = pcall(options.onFinish, minigameResult)
            if not ok then log(('ESX onFinish failed: %s'):format(tostring(err))) end
        end
    end)

    if not started then
        if options.FreezePlayer then FreezeEntityPosition(ped, false) end
        if isCallable(options.onCancel) then
            SetTimeout(0, function()
                local ok, err = pcall(options.onCancel)
                if not ok then log(('Rejected ESX onCancel failed: %s'):format(tostring(err))) end
            end)
        end
    end

    return started
end

-- Useful when a custom ESX script calls this resource by its real name.
exports('Progressbar', esxProgressbar)
exports('CancelProgressbar', esxCancel)
exports('ESXProgressbar', esxProgressbar)
exports('ESXCancelProgressbar', esxCancel)

-- Standard ESX Legacy path: exports['esx_progressbar']:Progressbar(...)
replaceExport('esx_progressbar', 'Progressbar', esxProgressbar)
replaceExport('esx_progressbar', 'CancelProgressbar', esxCancel)

-- --------------------------------------------------------------------------
-- Optional live QBCore callback smoke test
-- --------------------------------------------------------------------------

local function resolveQBCoreProgressbar(timeoutMs)
    local deadline = GetGameTimer() + math.max(tonumber(timeoutMs) or 10000, 1000)
    local last = {
        state = 'export-probe',
        exportOk = false,
        exportError = nil,
        coreType = 'nil',
        functionsType = 'nil',
        progressbarType = 'nil',
    }

    while GetGameTimer() < deadline do
        local qbxState = GetResourceState('qbx_core')
        last.state = (qbxState == 'started' or qbxState == 'starting')
            and ('qbx_core:' .. qbxState)
            or 'qb-core-export-probe'

        local ok, coreOrError = pcall(function()
            -- Capability probing is reliable for both a real qb-core resource
            -- and Qbox's optional QB compatibility export. A provided resource
            -- name is not assumed to have a meaningful GetResourceState value.
            return exports['qb-core']:GetCoreObject({ 'Functions' })
        end)

        last.exportOk = ok
        if not ok then
            last.exportError = tostring(coreOrError)
        else
            last.coreType = type(coreOrError)
            local functions = coreOrError and coreOrError.Functions
            last.functionsType = type(functions)
            local progressbar = functions and functions.Progressbar
            last.progressbarType = type(progressbar)

            if isCallable(progressbar) then
                return coreOrError, last
            end
        end

        -- Fall back to the normal full-object request used by
        -- qb-vehiclekeys. This also provides useful diagnostics when a
        -- custom qb-core changes its filtered-object behavior.
        local fullOk, fullCoreOrError = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        if fullOk then
            last.exportOk = true
            last.coreType = type(fullCoreOrError)
            local functions = fullCoreOrError and fullCoreOrError.Functions
            last.functionsType = type(functions)
            local progressbar = functions and functions.Progressbar
            last.progressbarType = type(progressbar)

            if isCallable(progressbar) then
                return fullCoreOrError, last
            end
        else
            last.exportError = tostring(fullCoreOrError)
        end

        Wait(250)
    end

    return nil, last
end

if Config.devMode then
    RegisterCommand('rsfieldqbtest', function()
        CreateThread(function()
            if Progress:IsActive() then
                log('QB TEST WAITING: another progress action is active. Waiting up to 15 seconds...')
                local busyDeadline = GetGameTimer() + 15000
                while Progress:IsActive() and GetGameTimer() < busyDeadline do
                    Wait(100)
                end

                if Progress:IsActive() then
                    log('QB TEST FAILED: another progress action remained active for 15 seconds.')
                    return
                end
            end

            log('QB TEST: waiting for qb-core client functions...')
            local QBCore, diagnostic = resolveQBCoreProgressbar(10000)

            if not QBCore then
                log(('QB TEST FAILED: QBCore Progressbar was unavailable after 10 seconds. state=%s exportOk=%s core=%s Functions=%s Progressbar=%s error=%s')
                    :format(
                        tostring(diagnostic.state),
                        tostring(diagnostic.exportOk),
                        tostring(diagnostic.coreType),
                        tostring(diagnostic.functionsType),
                        tostring(diagnostic.progressbarType),
                        tostring(diagnostic.exportError or 'none')
                    ))
                log('QB TEST NOTE: this failure is in qb-core object discovery; it does not mean an already-running progress action failed.')
                return
            end

            local successCount = 0
            local cancelCount = 0

            log('QB TEST STARTED: invoking the exact QBCore.Functions.Progressbar wrapper used by qb-vehiclekeys...')
            local ok, err = pcall(function()
                QBCore.Functions.Progressbar(
                    'rsfield_qb_callback_test',
                    'Testing vehicle-key callback...',
                    1500,
                    false,
                    true,
                    { disableMovement = false, disableCarMovement = false, disableMouse = false, disableCombat = false },
                    {}, {}, {},
                    function()
                        successCount = successCount + 1
                        log(('QB TEST SUCCESS CALLBACK: count=%d'):format(successCount))
                    end,
                    function()
                        cancelCount = cancelCount + 1
                        log(('QB TEST CANCEL CALLBACK: count=%d'):format(cancelCount))
                    end
                )
            end)

            if not ok then
                log(('QB TEST FAILED WHILE CALLING WRAPPER: %s'):format(tostring(err)))
                return
            end

            Wait(3000)

            if successCount == 1 and cancelCount == 0 then
                log('QB TEST PASSED: QBCore success callback fired exactly once as qb-vehiclekeys expects.')
            elseif successCount == 0 and cancelCount == 1 then
                log('QB TEST RESULT: the action was cancelled and the cancel callback fired exactly once.')
            else
                log(('QB TEST FAILED: success callbacks=%d, cancel callbacks=%d.'):format(successCount, cancelCount))
            end
        end)
    end, false)
end

-- --------------------------------------------------------------------------
-- Server-owner diagnostics
-- --------------------------------------------------------------------------

local function actualResourceExists(name)
    if type(GetNumResources) ~= 'function' or type(GetResourceByFindIndex) ~= 'function' then
        return GetResourceState(name) ~= 'missing'
    end

    for index = 0, GetNumResources() - 1 do
        if GetResourceByFindIndex(index) == name then return true end
    end
    return false
end

local function detectEnvironment()
    local qbxState = GetResourceState('qbx_core')
    if qbxState == 'started' or qbxState == 'starting' then return 'Qbox', 'qbx_core' end

    local qbState = GetResourceState('qb-core')
    if qbState == 'started' or qbState == 'starting' then return 'QBCore', 'qb-core' end

    local esxState = GetResourceState('es_extended')
    if esxState == 'started' or esxState == 'starting' then return 'ESX', 'es_extended' end

    return 'Standalone', 'none'
end

local function printDiagnostics()
    local framework, resource = detectEnvironment()
    local version = GetResourceMetadata(RESOURCE_NAME, 'version', 0) or 'unknown'
    local oxState = GetResourceState('ox_lib')

    log(('DIAG | version=%s | folder=%s | environment=%s | frameworkResource=%s | ox_lib=%s | nuiReady=%s | active=%s')
        :format(version, RESOURCE_NAME, framework, resource, oxState, tostring(Progress.is_nui_ready), tostring(Progress:IsActive())))

    local duplicates = {}
    for _, name in ipairs({ 'qb-progressbar', 'esx_progressbar', 'rspipboi-progressbar', 'rsfield-progressbar', 'keep-progressbar' }) do
        if name ~= RESOURCE_NAME and actualResourceExists(name) then
            local state = GetResourceState(name)
            if state == 'started' or state == 'starting' then duplicates[#duplicates + 1] = name .. ':' .. state end
        end
    end

    if #duplicates > 0 then
        log('DIAG WARNING | other progress providers are running: ' .. table.concat(duplicates, ', '))
    else
        log('DIAG | no separate duplicate progress provider detected.')
    end

    if framework == 'Qbox' then
        log('DIAG | Qbox: QB-compatible callers can use exports[\'progressbar\']; hardcoded lib.progressBar remains ox_lib unless the optional bridge is installed.')
    elseif framework == 'QBCore' then
        log('DIAG | QBCore: QBCore.Functions.Progressbar routes to exports[\'progressbar\']:Progress().')
    elseif framework == 'ESX' then
        log('DIAG | ESX: ESX.Progressbar routes through the provided esx_progressbar compatibility name.')
    else
        log('DIAG | Standalone: use exports[\'progressbar\']:Progress(...) or Start(...).')
    end
end

RegisterCommand('rsprogressdiag', function()
    printDiagnostics()
end, false)

-- --------------------------------------------------------------------------
-- Startup validation
-- --------------------------------------------------------------------------

CreateThread(function()
    Wait(2500)

    if RESOURCE_NAME ~= 'progressbar' then
        log(('INSTALL ERROR: folder is named "%s". Rename the actual resource folder to exactly "progressbar" or QBCore.Functions.Progressbar will reject calls.'):format(RESOURCE_NAME))
        return
    end

    local version = GetResourceMetadata(RESOURCE_NAME, 'version', 0) or 'unknown'
    local framework = detectEnvironment()
    log(('v%s ready — environment=%s | QBCore, Qbox, ESX, ox-style and standalone APIs loaded.'):format(version, framework))
    printDiagnostics()
end)
