local MAX_PROPS = 5
local DEFAULT_DURATION = 3000

local function log(message)
    print(('[RS Field Terminal Progressbar] %s'):format(message))
end

local function debugLog(message)
    if Config.devMode then log(message) end
end


local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' and type(value) ~= 'userdata' then return false end

    local ok, metatable = pcall(getmetatable, value)
    return ok and metatable and type(metatable.__call) == 'function'
end

local function safeCall(label, callback, ...)
    if not isCallable(callback) then return true end

    local ok, err = pcall(callback, ...)
    if not ok then
        log(('%s callback failed: %s'):format(label, tostring(err)))
    end
    return ok
end

local function tableCopy(input)
    local output = {}
    if type(input) ~= 'table' then return output end
    for key, value in pairs(input) do output[key] = value end
    return output
end

local function vectorComponent(value, key, index, default)
    if value == nil then return default end

    if type(value) == 'table' then
        local result = value[key]
        if result == nil then result = value[index] end
        return tonumber(result) or default
    end

    local ok, result = pcall(function() return value[key] end)
    if ok then return tonumber(result) or default end
    return default
end

local function normalizeVector3(value)
    return {
        x = vectorComponent(value, 'x', 1, 0.0),
        y = vectorComponent(value, 'y', 2, 0.0),
        z = vectorComponent(value, 'z', 3, 0.0),
    }
end

local function normalizeAnimation(animation)
    if type(animation) ~= 'table' then return nil end

    return {
        animDict = animation.animDict or animation.dict,
        anim = animation.anim or animation.clip or animation.lib,
        task = animation.task or animation.scenario or animation.Scenario,
        blendIn = tonumber(animation.blendIn) or 3.0,
        blendOut = tonumber(animation.blendOut) or 3.0,
        duration = tonumber(animation.duration),
        flags = tonumber(animation.flags or animation.flag) or 1,
        playbackRate = tonumber(animation.playbackRate) or 0.0,
        lockX = animation.lockX == true,
        lockY = animation.lockY == true,
        lockZ = animation.lockZ == true,
        onStart = animation.onStart,
        onTick = animation.onTick,
        onFinish = animation.onFinish,
    }
end

local function normalizeProp(prop)
    if type(prop) ~= 'table' or prop.model == nil then return nil end

    return {
        model = prop.model,
        bone = tonumber(prop.bone) or 60309,
        coords = normalizeVector3(prop.coords or prop.pos),
        rotation = normalizeVector3(prop.rotation or prop.rot),
        rotOrder = tonumber(prop.rotOrder) or 0,
    }
end

local function normalizeTask(input)
    if type(input) ~= 'table' then return nil, 'task must be a table' end

    local task = tableCopy(input)
    task.label = tostring(task.label or 'Progress')
    task.duration = math.max(tonumber(task.duration) or DEFAULT_DURATION, 1)
    task.canCancel = task.canCancel ~= false
    task.useWhileDead = task.useWhileDead == true
    task.showLocation = task.showLocation ~= false
    if task.location ~= nil then
        task.location = tostring(task.location)
    elseif task.locationText ~= nil then
        task.location = tostring(task.locationText)
    end

    if task.position == 'middle' or task.position == 'center' then
        task.position = 'center'
    elseif task.position == 'top' or task.position == 'center-top' then
        task.position = 'center-top'
    else
        task.position = 'center-bottom'
    end

    task.animation = normalizeAnimation(task.animation or task.anim)

    if type(task.animations) == 'table' then
        local animations = {}
        for _, animation in ipairs(task.animations) do
            local normalized = normalizeAnimation(animation)
            if normalized then animations[#animations + 1] = normalized end
        end
        task.animations = animations
    else
        task.animations = nil
    end

    local disables = tableCopy(task.controlDisables or task.disable)
    local aliases = {
        disableMouse = task.disableMouse,
        disableMovement = task.disableMovement,
        disableSprint = task.disableSprint,
        disableCarMovement = task.disableCarMovement,
        disableCombat = task.disableCombat,
    }
    for key, value in pairs(aliases) do
        if value ~= nil then disables[key] = value == true end
    end
    task.controlDisables = disables

    local props = {}
    if type(task.props) == 'table' then
        if task.props.model then
            local normalized = normalizeProp(task.props)
            if normalized then props[#props + 1] = normalized end
        else
            for _, prop in ipairs(task.props) do
                local normalized = normalizeProp(prop)
                if normalized then props[#props + 1] = normalized end
            end
        end
    end

    local firstProp = normalizeProp(task.prop)
    local secondProp = normalizeProp(task.propTwo)
    if firstProp and not props[1] then props[#props + 1] = firstProp end
    if secondProp and not props[2] then props[#props + 1] = secondProp end

    while #props > MAX_PROPS do table.remove(props) end
    task.props = props
    task.prop = nil
    task.propTwo = nil

    if type(task.stages) == 'table' and #task.stages > 0 then
        local stages = {}
        for _, inputStage in ipairs(task.stages) do
            if type(inputStage) == 'table' then
                local stage = tableCopy(inputStage)
                stage.message = tostring(stage.message or stage.label or task.label)
                stage.duration = math.max(tonumber(stage.duration) or task.duration, 1)
                stage.animation = normalizeAnimation(stage.animation)
                stage.triggered = false
                if isCallable(stage.minigame) and not stage.cancelMode then
                    stage.cancelMode = 'hard'
                end
                stages[#stages + 1] = stage
            end
        end
        task.stages = #stages > 0 and stages or nil
    else
        task.stages = nil
    end

    return task
end

local function currentLocationLabel(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return '' end

    local coords = GetEntityCoords(ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash and streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ''
    local crossing = crossingHash and crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

    local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
    local zone = ''
    if zoneCode and zoneCode ~= '' then
        local translated = GetLabelText(zoneCode)
        if translated and translated ~= '' and translated ~= 'NULL' then
            zone = translated
        else
            zone = zoneCode
        end
    end

    if street ~= '' and crossing ~= '' and crossing ~= street then
        if zone ~= '' then return ('%s / %s · %s'):format(street, crossing, zone) end
        return ('%s / %s'):format(street, crossing)
    end

    if street ~= '' then
        if zone ~= '' then return ('%s · %s'):format(street, zone) end
        return street
    end

    return zone
end

local function taskDuration(task)
    if type(task.stages) == 'table' and #task.stages > 0 then
        local total = 0
        for _, stage in ipairs(task.stages) do total = total + stage.duration end
        return total
    end
    return task.duration
end

local function taskHasConditionalStage(task)
    if type(task.stages) ~= 'table' then return false end
    for _, stage in ipairs(task.stages) do
        if isCallable(stage.condition) then return true end
    end
    return false
end

local function blockedOxPlayerState(task, ped)
    if task._oxSemantics ~= true then return nil end
    if task.allowRagdoll ~= true and IsPedRagdoll(ped) then return 'ragdoll' end
    if task.allowSwimming ~= true and IsPedSwimming(ped) then return 'swimming' end
    if task.allowCuffed ~= true and IsPedCuffed(ped) then return 'cuffed' end
    if task.allowFalling ~= true and IsPedFalling(ped) then return 'falling' end
    return nil
end

local function modelHash(model)
    if type(model) == 'number' then return model end
    if type(model) == 'string' and model ~= '' then return GetHashKey(model) end
    return 0
end

local function loadStreamingResource(requestFn, checkFn, value, timeoutMs)
    timeoutMs = timeoutMs or 1500
    local startedAt = GetGameTimer()
    requestFn(value)

    while not checkFn(value) do
        Wait(50)
        requestFn(value)
        if GetGameTimer() - startedAt >= timeoutMs then
            return false
        end
    end

    return true
end

Progress = {
    _active = false,
    _task_instance = {},
    _run_id = 0,
    _current_stage_index = 1,
    _minigame_result = nil,
    _net_props = {},
    _owns_inv_busy = false,
    is_nui_ready = false,
    _last_completion = nil,

    _controls = {
        disableMouse = { 1, 2, 106 },
        disableMovement = { 30, 31, 36, 21, 75 },
        disableSprint = { 21 },
        disableCarMovement = { 63, 64, 71, 72 },
        disableCombat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 263, 264, 257 },
    },

    _locales = {},
}

function Progress:_sendNUI(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function Progress:_registerNUI(name, fn)
    RegisterNuiCallback(name, function(data, cb)
        local ok, err = pcall(fn, data or {})
        if not ok then log(('NUI callback %s failed: %s'):format(name, tostring(err))) end
        cb('ok')
    end)
end

function Progress:_registerLocale(lang, translations, uiDirection)
    local locale = tableCopy(translations)
    locale.ui_direction = uiDirection or 'ltr'
    self._locales[lang] = locale
end

function Progress:_uiLocale()
    local locale = tableCopy(self._locales[Config.locale] or self._locales.en or {})
    local key = Config.cancel and Config.cancel.key or 'X'
    if type(locale.can_cancel) == 'string' then
        locale.can_cancel = locale.can_cancel:gsub('{key}', tostring(key))
    end
    return locale
end

function Progress:IsActive()
    return self._active == true
end

function Progress:GetCompletion(runId)
    local completion = self._last_completion
    if type(completion) ~= 'table' or completion.runId ~= runId then return nil end
    return completion
end

function Progress:_setPlayerState(key, value)
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set(key, value, true)
    end
end

function Progress:_acquireBusyState()
    self:_setPlayerState('progressbar_active', true)
    self:_setPlayerState('rsfield_progress_active', true)
    self._owns_inv_busy = false

    if Config.useInventoryBusyState == false then return end
    if LocalPlayer and LocalPlayer.state and not LocalPlayer.state.inv_busy then
        self._owns_inv_busy = true
        self:_setPlayerState('inv_busy', true)
    end
end

function Progress:_releaseBusyState()
    self:_setPlayerState('progressbar_active', false)
    self:_setPlayerState('rsfield_progress_active', false)
    if self._owns_inv_busy then
        self:_setPlayerState('inv_busy', false)
    end
    self._owns_inv_busy = false
end

function Progress:_createObject(prop)
    local hash = modelHash(prop.model)
    if hash == 0 or not IsModelInCdimage(hash) or not IsModelValid(hash) then
        log(('Rejected invalid prop model: %s'):format(tostring(prop.model)))
        return 0, 0, 0
    end

    if not loadStreamingResource(RequestModel, HasModelLoaded, hash) then
        log(('Timed out loading prop model: %s'):format(tostring(prop.model)))
        return 0, 0, hash
    end

    local coords = GetEntityCoords(self.player_ped_id)
    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, true, true, false)
    if entity == 0 or not DoesEntityExist(entity) then
        SetModelAsNoLongerNeeded(hash)
        return 0, 0, hash
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
    end

    SetModelAsNoLongerNeeded(hash)
    return entity, netId, hash
end

function Progress:_attachEntityToPed(entity, prop)
    local boneIndex = GetPedBoneIndex(self.player_ped_id, prop.bone)
    AttachEntityToEntity(
        entity,
        self.player_ped_id,
        boneIndex,
        prop.coords.x,
        prop.coords.y,
        prop.coords.z,
        prop.rotation.x,
        prop.rotation.y,
        prop.rotation.z,
        true,
        true,
        false,
        true,
        prop.rotOrder,
        true
    )
end

function Progress:_initializeProps(runId)
    self._net_props = {}
    local models = {}

    for _, prop in ipairs(self._task_instance.props or {}) do
        if not self._active or self._run_id ~= runId then break end
        local entity, netId, hash = self:_createObject(prop)
        if entity ~= 0 and netId ~= 0 then
            self:_attachEntityToPed(entity, prop)
            self._net_props[#self._net_props + 1] = netId
            models[#models + 1] = hash
        end
    end

    if #self._net_props > 0 then
        TriggerServerEvent('progressbar:server:register_props', self._net_props, models)
    end
end

function Progress:_cleanupProps()
    local netProps = self._net_props or {}
    self._net_props = {}

    for _, netId in ipairs(netProps) do
        local entity = NetToObj(netId)
        if entity ~= 0 and DoesEntityExist(entity) then
            DetachEntity(entity, true, true)
            DeleteEntity(entity)
        end
    end

    if #netProps > 0 then
        TriggerServerEvent('progressbar:server:cleanup_props', netProps)
    end
end

function Progress:_disableControls(runId)
    CreateThread(function()
        local playerId = PlayerId()
        while self._active and self._run_id == runId do
            for disableType, enabled in pairs(self._task_instance.controlDisables or {}) do
                if enabled and self._controls[disableType] then
                    for _, control in ipairs(self._controls[disableType]) do
                        DisableControlAction(0, control, true)
                    end
                end
            end

            if self._task_instance.controlDisables.disableCombat then
                DisablePlayerFiring(playerId, true)
            end
            Wait(0)
        end
    end)
end

function Progress:_stopSingleAnimation(animation)
    if not animation or not self.player_ped_id then return end
    if animation.animDict and animation.anim then
        StopAnimTask(self.player_ped_id, animation.animDict, animation.anim, 1.0)
    elseif animation.task then
        ClearPedTasks(self.player_ped_id)
    end
end

function Progress:_stopAnimation()
    local hadAnimation = self._task_instance.animation ~= nil or self.currentAnimation ~= nil

    if type(self._task_instance.animations) == 'table' and #self._task_instance.animations > 0 then
        hadAnimation = true
        for _, animation in ipairs(self._task_instance.animations) do
            self:_stopSingleAnimation(animation)
        end
    end

    self:_stopSingleAnimation(self._task_instance.animation)
    self:_stopSingleAnimation(self.currentAnimation)
    self.currentAnimation = nil

    if hadAnimation and self.player_ped_id then ClearPedSecondaryTask(self.player_ped_id) end
end

function Progress:_playAnimation(animation, runId)
    if not animation or not self._active or self._run_id ~= runId then return end

    if animation.task then
        TaskStartScenarioInPlace(self.player_ped_id, animation.task, 0, true)
        return
    end

    if not animation.animDict or not animation.anim then return end
    if not loadStreamingResource(RequestAnimDict, HasAnimDictLoaded, animation.animDict) then
        log(('Timed out loading animation dictionary: %s'):format(animation.animDict))
        return
    end

    TaskPlayAnim(
        self.player_ped_id,
        animation.animDict,
        animation.anim,
        animation.blendIn,
        animation.blendOut,
        animation.duration or -1,
        animation.flags,
        animation.playbackRate,
        animation.lockX,
        animation.lockY,
        animation.lockZ
    )
    RemoveAnimDict(animation.animDict)
end

function Progress:_startAnimation(runId)
    self:_stopAnimation()

    local sequence = self._task_instance.animations
    if type(sequence) == 'table' and #sequence > 0 then
        CreateThread(function()
            for _, animation in ipairs(sequence) do
                if not self._active or self._run_id ~= runId then break end
                safeCall('animation onStart', animation.onStart)
                self:_playAnimation(animation, runId)

                if animation.duration and animation.duration > 0 then
                    local startedAt = GetGameTimer()
                    while self._active and self._run_id == runId and GetGameTimer() - startedAt < animation.duration do
                        if isCallable(animation.onTick) then
                            pcall(animation.onTick, GetGameTimer() - startedAt)
                        end
                        Wait(0)
                    end
                end

                if self._active and self._run_id == runId then
                    safeCall('animation onFinish', animation.onFinish)
                end
            end
        end)
    else
        self:_playAnimation(self._task_instance.animation, runId)
    end
end

function Progress:_startActions(runId)
    self:_startAnimation(runId)
    self:_initializeProps(runId)
    self:_disableControls(runId)
end

local function invokeCallback(label, callback, ...)
    return safeCall(label, callback, ...)
end

function Progress:_invokeFinishCallbacks(task, onFinish, cancelled, minigameResult, suppressCallbacks)
    if suppressCallbacks then return end

    invokeCallback('provider completion', onFinish, cancelled, minigameResult)
    invokeCallback('task on_finish', task.on_finish, cancelled, minigameResult)

    if cancelled then
        invokeCallback('task onCancel', task.onCancel, minigameResult)
    else
        invokeCallback('task onFinish', task.onFinish, minigameResult)
    end
end

function Progress:_finalize(runId, cancelled, minigameResult, reason, suppressCallbacks)
    if not self._active or self._run_id ~= runId then return false end

    local task = self._task_instance
    local onFinish = self._on_finish

    self._active = false
    self._minigame_result = minigameResult
    self._last_completion = {
        runId = runId,
        cancelled = cancelled == true,
        reason = reason,
        finishedAt = GetGameTimer(),
    }
    self:_stopAnimation()
    self:_cleanupProps()
    self:_releaseBusyState()

    debugLog(('Finished run %s (%s, cancelled=%s)'):format(runId, tostring(reason), tostring(cancelled)))

    -- Clear the completed run before callbacks. A completion callback is allowed
    -- to start the next progress task immediately without this cleanup erasing it.
    self._task_instance = {}
    self._on_finish = nil
    self._on_start = nil
    self._on_tick = nil
    self.player_ped_id = nil

    self:_invokeFinishCallbacks(task, onFinish, cancelled == true, minigameResult, suppressCallbacks)
    return true
end

function Progress:Cancel(force, reason)
    if not self._active then return false end
    if not force and self._task_instance.canCancel == false then return false end

    local runId = self._run_id
    self:_sendNUI('CANCEL', { sessionId = runId })
    return self:_finalize(runId, true, self._minigame_result, reason or 'cancelled')
end

function Progress:_monitor(runId, task, onStart, onTick)
    safeCall('provider onStart', onStart, GetGameTimer())
    if not self._active or self._run_id ~= runId then return end

    safeCall('task onStart', task.onStart, GetGameTimer())
    if not self._active or self._run_id ~= runId then return end

    if isCallable(onTick) then
        CreateThread(function()
            while self._active and self._run_id == runId do
                safeCall('provider onTick', onTick, GetGameTimer())
                Wait(100)
            end
        end)
    end

    CreateThread(function()
        while self._active and self._run_id == runId do
            if IsEntityDead(self.player_ped_id) and not task.useWhileDead then
                self:_sendNUI('CANCEL', { sessionId = runId })
                self:_finalize(runId, true, self._minigame_result, 'player_died')
                return
            end

            local blockedState = blockedOxPlayerState(task, self.player_ped_id)
            if blockedState then
                self:_sendNUI('CANCEL', { sessionId = runId })
                self:_finalize(runId, true, self._minigame_result, 'ox_' .. blockedState)
                return
            end
            Wait(100)
        end
    end)
end

function Progress:_handleStages(runId)
    if type(self._task_instance.stages) ~= 'table' then return end

    CreateThread(function()
        while self._active and self._run_id == runId do
            local stage = self._task_instance.stages[self._current_stage_index]
            if stage and isCallable(stage.condition) and not stage.triggered then
                local ok, result = pcall(stage.condition)
                if ok and result == true then
                    stage.triggered = true
                    self:_sendNUI('CONDITIONAL_SKIP', {
                        sessionId = runId,
                        index = self._current_stage_index - 1,
                    })
                elseif not ok then
                    log(('Stage condition failed: %s'):format(tostring(result)))
                    stage.triggered = true
                    self:_sendNUI('CANCEL', { sessionId = runId })
                    self:_finalize(runId, true, self._minigame_result, 'stage_condition_error')
                    return
                end
            end
            Wait(100)
        end
    end)
end

function Progress:_scheduleLuaCompletion(runId, task)
    -- QBCore/Qbox/common-progressbar actions such as qb-vehiclekeys are single-duration
    -- tasks whose reward is granted only from the completion callback. The NUI
    -- remains responsible for visuals, but Lua now owns the authoritative timer
    -- so a dropped NUI POST can never leave the action looking complete while
    -- silently withholding the reward.
    if task._completionAuthority ~= 'lua' then return end
    if type(task.stages) == 'table' and #task.stages > 0 then return end

    local duration = taskDuration(task)
    SetTimeout(duration, function()
        if not self._active or self._run_id ~= runId then return end

        self:_sendNUI('COMPLETE', { sessionId = runId })
        self:_finalize(runId, false, self._minigame_result, 'lua_timer_finished')
    end)
end

function Progress:_watchdog(runId, task)
    if Config.watchdog == nil or Config.watchdog.enabled == false then return end
    if not self._active or self._run_id ~= runId then return end
    if taskHasConditionalStage(task) then return end

    local timeoutMs = taskDuration(task) + math.max(tonumber(Config.watchdog.graceMs) or 5000, 1000)
    SetTimeout(timeoutMs, function()
        if not self._active or self._run_id ~= runId then return end
        log(('NUI watchdog cancelled run %s after %sms; inventory state was released.'):format(runId, timeoutMs))
        self:_sendNUI('CANCEL', { sessionId = runId })
        self:_finalize(runId, true, self._minigame_result, 'nui_watchdog')
    end)
end

function Progress:_nuiStages(task)
    local output = {}
    if type(task.stages) ~= 'table' then return output end

    for _, stage in ipairs(task.stages) do
        output[#output + 1] = {
            message = stage.message,
            duration = stage.duration,
            progressColor = stage.progressColor,
            cancelMode = stage.cancelMode,
            condition = isCallable(stage.condition),
            minigame = isCallable(stage.minigame),
        }
    end
    return output
end

-- Resolve vehicle art before a progress starts, while the player is still
-- beside the target. All data sent to NUI is a harmless model/image key, never
-- an entity handle, arbitrary URL, or filesystem path.
local vehicleModelNamesByHash

local function vehicleImageKey(value)
    if type(value) ~= 'string' then return nil end
    local key = value:lower():match('^%s*(.-)%s*$')
    if #key == 0 or #key > 64 or not key:match('^[%w_%-]+$') then return nil end
    return key
end

local function vehicleAction(task)
    if task.vehicleImage == false or task.showVehicleImage == false then return false end
    if task.vehicleImage == true or task.showVehicleImage == true then return true end
    if task.vehicleModel ~= nil or task.vehicleImageModel ~= nil or task.vehicleEntity ~= nil
       or task.targetVehicle ~= nil or task.vehicleNetId ~= nil
       or type(task.vehicle) == 'number' or type(task.vehicle) == 'table' then return true end
    local label = (tostring(task.label or '') .. ' ' .. tostring(task.name or '')):lower()
    if type(task.stages) == 'table' then
        for _, stage in ipairs(task.stages) do
            label = label .. ' ' .. tostring(stage.message or ''):lower()
        end
    end
    for _, word in ipairs({
        'vehicle', 'lockpick', 'lock pick', 'hotwir', 'car key', 'car door',
        'trunk', 'glovebox', 'ignition', 'engine', 'tyre', 'tire', 'wheel',
        'repair car', 'car repair', 'searching car', 'searching for the car',
        'search the car', 'search the vehicle', 'break into', 'breaking into',
        'steal car', 'unlock car', 'car lock', 'jimmy', 'slim jim',
    }) do
        if label:find(word, 1, true) then return true end
    end
    return false
end

local function validVehicleEntity(entity)
    return type(entity) == 'number' and entity ~= 0
        and DoesEntityExist(entity) and GetEntityType(entity) == 2
end

local function resolveVehicleFromNetId(id)
    local netId = tonumber(id)
    if not netId or netId <= 0 then return nil end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return nil end
    local entity = NetToVeh(netId)
    if validVehicleEntity(entity) then return entity end
    return nil
end

local function nearestVehicleForArt(ped, radius)
    local from = GetEntityCoords(ped)
    local best, bestDistance = nil, radius * radius
    local pool = GetGamePool('CVehicle')
    if type(pool) ~= 'table' then return nil end
    for _, vehicle in ipairs(pool) do
        if validVehicleEntity(vehicle) then
            local where = GetEntityCoords(vehicle)
            local dx, dy, dz = from.x - where.x, from.y - where.y, from.z - where.z
            local distSq = dx * dx + dy * dy + dz * dz
            if distSq < bestDistance then
                best, bestDistance = vehicle, distSq
            end
        end
    end
    return best
end

local function spawnNameForHash(hash)
    if not hash or hash == 0 then return nil end
    if vehicleModelNamesByHash == nil then
        vehicleModelNamesByHash = {}
        -- FiveM knows the registered spawn names, including addon vehicles.
        -- Compute this once; no per-frame scanning or vehicle image index is needed.
        if type(GetAllVehicleModels) == 'function' then
            local ok, models = pcall(GetAllVehicleModels)
            if ok and type(models) == 'table' then
                for _, model in ipairs(models) do
                    local name = vehicleImageKey(model)
                    if name then
                        vehicleModelNamesByHash[GetHashKey(name) % 4294967296] = name
                    end
                end
            end
        end
    end
    return vehicleModelNamesByHash[hash % 4294967296]
end

local function resolveVehicleVisual(task, ped)
    local cfg = Config.vehicleImages or {}
    if cfg.enabled == false or not vehicleAction(task) then return nil end

    local directModel = task.vehicleImageModel or task.vehicleModel or task.vehicleSpawnName
    local vehicle = task.vehicleEntity or task.targetVehicle or task.targetEntity or task.vehicle
    if type(vehicle) == 'table' then
        directModel = directModel or vehicle.model or vehicle.spawnName
        vehicle = vehicle.entity or vehicle.handle
    end
    if not validVehicleEntity(vehicle) then
        vehicle = resolveVehicleFromNetId(task.vehicleNetId)
    end

    if not validVehicleEntity(vehicle) and directModel == nil and cfg.autoNearby ~= false then
        vehicle = GetVehiclePedIsIn(ped, false)
        if not validVehicleEntity(vehicle) then
            local aiming, aimedAt = GetEntityPlayerIsFreeAimingAt(PlayerId())
            vehicle = aiming and validVehicleEntity(aimedAt) and aimedAt or nil
        end
        if not validVehicleEntity(vehicle) then
            vehicle = nearestVehicleForArt(ped, math.max(1.0, math.min(tonumber(cfg.nearbyRadius) or 5.0, 12.0)))
        end
    end

    local hash
    if validVehicleEntity(vehicle) then hash = GetEntityModel(vehicle) end
    if type(directModel) == 'number' then hash = directModel end
    if type(directModel) == 'string' and tonumber(directModel) then hash = tonumber(directModel) end
    if type(directModel) == 'string' and not tonumber(directModel) then hash = GetHashKey(directModel) end
    if not hash or hash == 0 then return nil end

    local candidates, added = {}, {}
    local function add(value)
        local key = vehicleImageKey(value)
        if key and not added[key] then
            added[key] = true
            candidates[#candidates + 1] = key
        end
    end

    local explicit = vehicleImageKey(directModel)
    if type(directModel) == 'string' and not tonumber(directModel) then add(explicit) end

    local archetype
    if validVehicleEntity(vehicle) and type(GetEntityArchetypeName) == 'function' then
        local ok, name = pcall(GetEntityArchetypeName, vehicle)
        if ok then archetype = vehicleImageKey(name) end
    end
    local registered = spawnNameForHash(hash)
    local modelName = explicit or archetype or registered
    local aliases = cfg.aliases or {}
    if type(aliases) == 'table' then
        add(aliases[modelName] or aliases[archetype] or aliases[registered])
    end
    add(archetype)
    add(registered)

    local displayName = ''
    if type(GetDisplayNameFromVehicleModel) == 'function' then
        local ok, name = pcall(GetDisplayNameFromVehicleModel, hash)
        if ok and type(name) == 'string' and name ~= 'NULL' and name ~= 'CARNOTFOUND' then
            add(name)
            displayName = name
            local translated = GetLabelText(name)
            if translated and translated ~= 'NULL' and translated ~= '' then displayName = translated end
        end
    end
    -- Hash filenames are accepted as a last resort for model/label mismatches.
    local unsigned = hash % 4294967296
    add(tostring(math.floor(unsigned)))
    local signed = unsigned >= 2147483648 and unsigned - 4294967296 or unsigned
    add(tostring(math.floor(signed)))
    if cfg.devMode == true or Config.devMode then
        debugLog(('Vehicle image: entity=%s model=%s files=%s'):format(
            tostring(vehicle), tostring(modelName or hash), table.concat(candidates, ', ')))
    end
    return {
        models = candidates,
        model = modelName or '',
        displayName = displayName ~= '' and displayName or modelName or 'VEHICLE',
    }
end


local function assetImageKey(value)
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    local key = value:lower():gsub('%s+', '_'):match('^%s*(.-)%s*$')
    if #key == 0 or #key > 96 or not key:match('^[%w_%-]+$') then return nil end
    return key
end

local function taskTextBlob(task)
    local text = tostring(task.label or '') .. ' ' .. tostring(task.name or '')
    if type(task.stages) == 'table' then
        for _, stage in ipairs(task.stages) do
            text = text .. ' ' .. tostring(stage.message or '')
        end
    end
    return text:lower()
end

local function inferAssetCategory(task)
    local explicit = assetImageKey(task.assetCategory or task.category or task.progressCategory or task.itemCategory)
    if explicit then return explicit end
    if vehicleAction(task) then return 'vehicle' end
    local label = taskTextBlob(task)
    local map = {
        -- Check treatment before food: "treating" also contains "eat".
        { 'medical', { 'medical', 'heal', 'bandag', 'medkit', 'suture', 'reviv', 'first aid',
            'firstaid', 'first_aid', 'ifak', 'treating', 'treatment', 'treat patient', 'treat wound',
            'trauma', 'defib', 'cpr', 'resuscitat', 'stabiliz', 'stabilis' } },
        { 'drug', { 'drug', 'meth', 'coke', 'weed', 'joint', 'pill', 'oxy', 'lean', 'syringe', 'heroin' } },
        { 'alcohol', { 'alcohol', 'beer', 'vodka', 'whiskey', 'tequila', 'wine', 'moonshine' } },
        { 'smoke', { 'smok', 'cig', 'cigar', 'vape', 'joint' } },
        { 'ammo', { 'ammo', 'bullet', 'round', 'magazine', 'clip', 'shell' } },
        { 'tool', { 'lockpick', 'hotwir', 'repair kit', 'tool', 'wrench', 'jimmy', 'slim jim', 'drill' } },
        { 'drink', { 'drink', 'water', 'cola', 'soda', 'coffee', 'juice' } },
        { 'food', { 'food', 'eat', 'burger', 'sandwich', 'taco', 'pizza', 'meal', 'snack' } },
        { 'craft', { 'craft', 'build', 'assembl', 'cook' } },
        { 'gather', { 'gather', 'harvest', 'mine', 'fish' } },
        { 'carry', { 'carry', 'lift', 'drag' } },
        { 'search', { 'search', 'loot', 'rob', 'steal' } },
    }
    for _, pair in ipairs(map) do
        for _, keyword in ipairs(pair[2]) do
            if label:find(keyword, 1, true) then return pair[1] end
        end
    end
    if label:find('consum', 1, true) or label:find('use', 1, true) then return 'consume' end
    return 'general'
end


local DEFAULT_ASSET_PRESETS = {
    water = { 'water_bottle', 'water', 'water_bottle2', 'watercup' },
    waterbottle = { 'water_bottle', 'water', 'water_bottle2' },
    -- Generic 'drink' has no known item identity: use category art instead.
    soda = { 'soda', 'cola', 'ecola', 'cocacola' },
    cola = { 'cola', 'ecola', 'cocacola', 'coca_cola_pop' },
    coffee = { 'coffee', 'icedcoffee', 'cold_brew_coffee', 'burger-coffee' },
    beer = { 'beer', 'duffbeer', 'ambeer', 'jar_beer' },
    whiskey = { 'whiskey', 'whiskey_bottle' },
    whisky = { 'whiskey', 'whiskey_bottle' },
    vodka = { 'vodka', 'vodka_bottle', 'vodka_shot' },
    bandage = { 'bandage', 'firstaid_bandage', 'bandage1', 'bandage2' },
    firstaid = { 'firstaid', 'medkit', 'firstaid_box', 'firstaid_bandage' },
    medkit = { 'medkit', 'firstaid', 'firstaid_box' },
    medical = { 'ifaks', 'firstaid', 'medkit', 'bandage' },
    cigarette = { 'cigarette', 'cigarettes_redwood' },
    cig = { 'cigarette', 'cigarettes_redwood' },
    smokes = { 'cigarette', 'cigarettes_redwood' },
    smoke = { 'cigarette', 'cigarettes_redwood' },
    vape = { 'vape', 'cigarette' },
    joint = { 'joint', 'joint_normal', 'joint1' },
    weed = { 'joint', 'rolling_paper' },
    rollingpaper = { 'rolling_paper', 'rolling_papers' },
    rollingpapers = { 'rolling_paper', 'rolling_papers' },
    ammo = { 'ammo-rifle', 'ammo-9', 'ammo-shotgun' },
    bullet = { 'ammo9mmbulletball', 'ammo-9' },
    bullets = { 'ammo9mmbulletball', 'ammo-9' },
    ammobox = { 'ammo-rifle', 'ammo-9' },
    lockpick = { 'lockpick', 'lockpick2', 'lockpick_blue' },
    advancedlockpick = { 'advancedlockpick', 'advancedlockpick_blue', 'advancedlockpick_green' },
    hotwire = { 'hotwire_kit', 'advancedlockpick', 'lockpick' },
    hotwirekit = { 'hotwire_kit', 'advancedlockpick', 'lockpick' },
    repairkit = { 'repairkit', 'repair_kit', 'toolbox' },
    toolkit = { 'toolkit', 'toolbox', 'repairkit' },
    keys = { 'access_key', 'key', 'car_key', 'carkey' },
    carkey = { 'car_key', 'carkey', 'access_key', 'key' },
}

local function pushCandidate(list, seen, value)
    value = assetImageKey(value)
    if not value or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

-- Walk varargs rather than ipairs({ ... }): nil is common between optional
-- fields and must not truncate the list or scramble explicit priorities.
local function eachPresent(callback, ...)
    for i = 1, select('#', ...) do
        local value = select(i, ...)
        if type(value) == 'table' then value = value.name or value.item or value.id end
        if value ~= nil then callback(value) end
    end
end

local function assetCandidateNames(value, aliases, useSmartPresets)
    local out, seen = {}, {}
    local key = assetImageKey(value)
    if not key then return out end
    pushCandidate(out, seen, key)

    local function pushAlias(source)
        local alias = aliases and aliases[source] or nil
        if alias then pushCandidate(out, seen, alias) end
    end

    pushAlias(key)

    local compact = key:gsub('[^%w]', '')
    if compact ~= key then
        pushCandidate(out, seen, compact)
        pushAlias(compact)
    end

    local dashed = key:gsub('_', '-')
    if dashed ~= key then
        pushCandidate(out, seen, dashed)
        pushAlias(dashed)
    end

    local underscored = key:gsub('-', '_')
    if underscored ~= key then
        pushCandidate(out, seen, underscored)
        pushAlias(underscored)
    end

    local singular = key:gsub('s$', '')
    if singular ~= key then
        pushCandidate(out, seen, singular)
        pushAlias(singular)
    end

    local base = key:gsub('[_-]?item$', ''):gsub('[_-]?tool$', ''):gsub('[_-]?kit$', '')
    if base ~= key then
        pushCandidate(out, seen, base)
        pushAlias(base)
    end

    local numericBase = key:gsub('%d+$', '')
    if numericBase ~= key then
        pushCandidate(out, seen, numericBase)
        pushAlias(numericBase)
    end

    if useSmartPresets ~= false then
        for _, presetKey in ipairs({ key, compact, underscored, dashed, singular, base, numericBase }) do
            local preset = DEFAULT_ASSET_PRESETS[presetKey]
            if type(preset) == 'table' then
                for _, candidate in ipairs(preset) do
                    pushCandidate(out, seen, candidate)
                    pushAlias(candidate)
                end
            end
        end
    end

    return out
end

-- Ordered, unambiguous visual cues for legacy callers that send only a label.
-- More specific names MUST come before short/general cues. Do not pretend a
-- generic "Using item" label identifies a particular inventory item.
local ACTION_IMAGE_CUES = {
    { 'hamburger', 'hamburger', 'food' },
    { 'chicken burger', 'burger_chicken', 'food' },
    { 'cheeseburger', 'burger', 'food' },
    { 'burger', 'burger', 'food' },
    { 'hotdog', 'hotdog', 'food' },
    { 'hot dog', 'hotdog', 'food' },
    { 'burrito', 'burrito', 'food' },
    { 'taco', 'taco1', 'food' },
    { 'pizza slice', 'pizza_slice', 'food' },
    { 'pizza', 'pizza', 'food' },
    { 'sandwich', 'sandwich', 'food' },
    { 'fries', 'fries', 'food' },
    { 'donut', 'donut', 'food' },
    { 'chocolate', 'chocolate', 'food' },
    { 'ice cream', 'icecream', 'food' },
    { 'icecream', 'icecream', 'food' },
    { 'ramen', 'ramen', 'food' },
    { 'steak', 'cookedsteak', 'food' },
    { 'chips', 'chips', 'food' },
    { 'iced coffee', 'icedcoffee', 'drink' },
    { 'icedcoffee', 'icedcoffee', 'drink' },
    { 'cold brew', 'cold_brew_coffee', 'drink' },
    { 'coffee', 'coffee', 'drink' },
    { 'espresso', 'espresso', 'drink' },
    { 'lemonade', 'lemonade', 'drink' },
    { 'apple juice', 'applejuice', 'drink' },
    { 'grape juice', 'grapejuice', 'drink' },
    { 'juice', 'applejuice', 'drink' },
    { 'energy drink', 'energy_drink', 'drink' },
    { 'energy_drink', 'energy_drink', 'drink' },
    { 'matcha', 'matchatea', 'drink' },
    { 'milk', 'milk', 'drink' },
    { 'sprunk light', 'sprunklight', 'drink' },
    { 'sprunk', 'sprunk', 'drink' },
    { 'ecola diet', 'ecoladiet', 'drink' },
    { 'ecola light', 'ecolalight', 'drink' },
    { 'ecola', 'ecola', 'drink' },
    { 'e-cola', 'ecola', 'drink' },
    { 'cola', 'ecola', 'drink' },
    { 'soda', 'soda', 'drink' },
    { 'watercup', 'watercup', 'drink' },
    { 'water cup', 'watercup', 'drink' },
    { 'water bottle', 'water_bottle', 'drink' },
    { 'water', 'water_bottle', 'drink' },
    { 'vodka', 'vodka', 'alcohol' },
    { 'whiskey', 'whiskey_bottle', 'alcohol' },
    { 'whisky', 'whiskey_bottle', 'alcohol' },
    { 'cigarette', 'cigarette', 'smoke' },
    { 'cig ', 'cigarette', 'smoke' },
    { 'cigar', 'cigar', 'smoke' },
    { 'vape', 'vape', 'smoke' },
    { 'blunt', 'blunt', 'smoke' },
    { 'joint', 'joint', 'smoke' },
    { 'smoking', 'cigarette', 'smoke' },
    { 'bandage', 'bandage', 'medical' },
    { 'medkit', 'medkit', 'medical' },
    { 'first aid', 'firstaid', 'medical' },
    { 'painkiller', 'painkiller', 'medical' },
    { 'morphine', 'morphine', 'medical' },
    { 'splint', 'splint', 'medical' },
    { 'tourniquet', 'tourniquet', 'medical' },
}

local function labelItemVisual(task)
    local label = ' ' .. taskTextBlob(task):gsub('[_%-]', ' ') .. ' '
    for _, cue in ipairs(ACTION_IMAGE_CUES) do
        if label:find(cue[1], 1, true) then
            return cue[2], cue[3]
        end
    end
    return nil, nil
end

local function addVisualEntry(entries, seen, folder, name)
    folder = assetImageKey(folder)
    name = assetImageKey(name)
    if not folder or not name then return end
    local key = folder .. ':' .. name
    if seen[key] then return end
    seen[key] = true
    entries[#entries + 1] = { folder = folder, name = name }
end

local function addVisualStrings(entries, seen, folder, ...)
    for index = 1, select('#', ...) do
        local value = select(index, ...)
        if type(value) == 'table' then
            for _, nested in ipairs(value) do addVisualStrings(entries, seen, folder, nested) end
        else
            addVisualEntry(entries, seen, folder, value)
        end
    end
end

local function resolveAssetVisual(task, ped)
    local cfg = Config.assetImages or {}
    if cfg.enabled == false then return nil end

    local folderCfg = cfg.folders or {}
    local itemFolder = assetImageKey(folderCfg.items) or 'items'
    local vehicleFolder = assetImageKey(folderCfg.vehicles) or 'vehicles'
    local categoryFolder = assetImageKey(folderCfg.categories) or 'categories'
    local aliases = type(cfg.aliases) == 'table' and cfg.aliases or {}
    local category = inferAssetCategory(task)
    local entries, seen = {}, {}

    local explicitFolder = assetImageKey(task.assetFolder or task.imageFolder)
    -- A Lua ipairs over a table with nil holes silently skips later fields.
    -- Build densely so any single image field can be resolved on its own.
    eachPresent(function(value)
        local key = assetImageKey(value)
        if key then
            addVisualEntry(entries, seen, explicitFolder or itemFolder, aliases[key] or key)
            for _, candidate in ipairs(assetCandidateNames(key, aliases, cfg.useSmartPresets ~= false)) do
                addVisualEntry(entries, seen, explicitFolder or itemFolder, candidate)
            end
        end
    end, task.asset, task.assetName, task.assetImage, task.image,
        task.imageName, task.displayImage, task.picture)

    local useSmartPresets = cfg.useSmartPresets ~= false
    -- Explicit item identity wins over words inferred from a generic label.
    eachPresent(function(value)
        for _, candidate in ipairs(assetCandidateNames(value, aliases, useSmartPresets)) do
            addVisualEntry(entries, seen, itemFolder, candidate)
        end
    end, task.item, task.itemName, task.itemname, task.item_id,
        task.itemId, task.consumeItem, task.usableItem)

    eachPresent(function(value)
        for _, candidate in ipairs(assetCandidateNames(value, aliases, useSmartPresets)) do
            addVisualEntry(entries, seen, itemFolder, candidate)
        end
    end, task.tool, task.toolName, task.toolItem, task.toolImage)

    if type(task.assetCandidates) == 'table' then
        for _, value in ipairs(task.assetCandidates) do
            if type(value) == 'table' then
                addVisualEntry(entries, seen, value.folder or itemFolder, aliases[assetImageKey(value.name or value.file or value.asset) or ''] or value.name or value.file or value.asset)
            else
                for _, candidate in ipairs(assetCandidateNames(value, aliases, cfg.useSmartPresets ~= false)) do
                    addVisualEntry(entries, seen, itemFolder, candidate)
                end
            end
        end
    end

    -- Label-only QBCore/ESX/ox callers: infer a specific image (hamburger,
    -- beverage, cigarette...) before falling back to a category illustration.
    -- Explicit item, image and tool codes always remain first in search order.
    local inferredName, inferredCategory = labelItemVisual(task)
    if inferredName then
        for _, candidate in ipairs(assetCandidateNames(inferredName, aliases, useSmartPresets)) do
            addVisualEntry(entries, seen, itemFolder, candidate)
        end
        if category == 'consume' or category == 'general' then category = inferredCategory end
    end

    local vehicleVisual = resolveVehicleVisual(task, ped)
    local useVehicleImage = task.useVehicleImage ~= false and task.showVehicleImage ~= false and task.vehicleImage ~= false
    if vehicleVisual and vehicleAction(task) and useVehicleImage then
        for _, name in ipairs(vehicleVisual.models or {}) do
            addVisualEntry(entries, seen, vehicleFolder, name)
        end
    end

    -- Doctor/EMS progress calls often provide only a treatment label, with no item.
    -- Keep explicit asset/item/tool choices first, then use a real trauma kit.
    if category == 'medical' and useSmartPresets then
        for _, candidate in ipairs(assetCandidateNames('medical', aliases, true)) do
            addVisualEntry(entries, seen, itemFolder, candidate)
        end
    end

    local categoryDefaults = type(cfg.categoryDefaults) == 'table' and cfg.categoryDefaults or {}
    local categoryName = assetImageKey(categoryDefaults[category] or category)
    if categoryName then
        addVisualEntry(entries, seen, categoryFolder, categoryName)
    end

    if #entries == 0 then return nil end

    local displayName = task.assetLabel or task.displayAssetName or task.itemLabel or task.itemName or inferredName or task.label or 'ACTION'
    if vehicleVisual and vehicleAction(task) and useVehicleImage then
        displayName = vehicleVisual.displayName or displayName
    end

    local fallbackLabel = string.upper(tostring(category or 'ACTION')) .. ' IMAGE NOT AVAILABLE'
    return {
        kind = vehicleVisual and vehicleAction(task) and useVehicleImage and 'vehicle' or 'item',
        category = category,
        displayName = tostring(displayName),
        fallbackText = fallbackLabel,
        entries = entries,
    }
end

-- Visual customization remains client-local. Gameplay actions, exports and
-- duration authority never read or depend on the cosmetic preference.
local STYLE_KVP = 'rs_progressbar_visuals_v1'
local VALID_FRAMES = { streetglass = true, neonrunner = true, carbonracer = true,
    tactical = true, arcade = true, pipboi420 = true, trackstrike = true, nightshift = true, streetcrew = true, violetsyndicate = true }
local VALID_BARS = { auto = true, segmented = true, pulse = true, race = true,
    dots = true, liquid = true }
local VALID_EFFECTS = { full = true, low = true, off = true }
local VALID_THEMES = { default = true, ['theme-0'] = true,
    ['theme-1'] = true, ['theme-2'] = true, ['theme-3'] = true,
    ['theme-4'] = true, ['theme-5'] = true, ['theme-6'] = true }
local function styleDefaults()
    local cfg = Config.style or {}
    return {
        frame = VALID_FRAMES[cfg.defaultFrame] and cfg.defaultFrame or 'streetglass',
        theme = VALID_THEMES[cfg.defaultTheme] and cfg.defaultTheme or 'theme-2',
        bar = VALID_BARS[cfg.defaultBar] and cfg.defaultBar or 'auto',
        effects = VALID_EFFECTS[cfg.defaultEffects] and cfg.defaultEffects or 'full',
    }
end
local function sanitizeStyle(value)
    local cfg = styleDefaults()
    if type(value) ~= 'table' then return cfg end
    if VALID_FRAMES[value.frame] then cfg.frame = value.frame end
    if VALID_THEMES[value.theme] then cfg.theme = value.theme end
    if VALID_BARS[value.bar] then cfg.bar = value.bar end
    if VALID_EFFECTS[value.effects] then cfg.effects = value.effects end
    return cfg
end
local function readStyle()
    local raw = GetResourceKvpString(STYLE_KVP)
    if not raw or raw == '' then return styleDefaults() end
    local ok, decoded = pcall(json.decode, raw)
    return sanitizeStyle(ok and decoded or nil)
end
local userStyle = readStyle()
local editorOpen = false

local function closeStyleEditor()
    if not editorOpen then return end
    editorOpen = false
    SetNuiFocus(false, false)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    Progress:_sendNUI('EDITOR_CLOSE', {})
end

local function openStyleEditor()
    if Config.style and Config.style.allowPlayerCustomization == false then return end
    if Progress._active or not Progress.is_nui_ready then
        log('Finish the current progress action before editing its frame.')
        return
    end
    if editorOpen then return end
    userStyle = readStyle()
    editorOpen = true
    SetNuiFocus(true, true)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(false) end
    Progress:_sendNUI('EDITOR_OPEN', { style = userStyle })
end

-- Resolve only files that actually exist before returning a NUI image URL.
-- Browser probes for every extension used to spam F8 with nonexistent .webp
-- requests, even though the stock library is mostly PNG.
-- Native resource reads are cached per path; player-supplied paths are constrained
-- to known image folders and never evaluated or used as arbitrary file reads.
local checkedAssetPaths = {}
RegisterNuiCallback('rsResolveProgressAsset', function(data, cb)
    local result = false
    if type(data) == 'table' and type(data.files) == 'table' then
        for i = 1, math.min(#data.files, 200) do
            local path = data.files[i]
            if type(path) == 'string' and #path <= 112 then
                local folder, name, extension = path:match('^assets/([a-z]+)/([a-z0-9_%-]+)%.([a-z]+)$')
                if (folder == 'items' or folder == 'vehicles' or folder == 'categories')
                    and name and #name <= 64
                    and (extension == 'png' or extension == 'webp' or extension == 'jpg'
                         or extension == 'jpeg' or extension == 'avif') then
                    local found = checkedAssetPaths[path]
                    if found == nil then
                        local ok, bytes = pcall(LoadResourceFile, GetCurrentResourceName(), 'html/' .. path)
                        found = ok and bytes ~= nil
                        checkedAssetPaths[path] = found
                    end
                    if found then result = path break end
                end
            end
        end
    end
    cb({ file = result })
end)

Progress:_registerNUI('styleSave', function(data)
    if not editorOpen or Progress._active then return end
    local chosen = sanitizeStyle(data)
    SetResourceKvp(STYLE_KVP, json.encode(chosen))
    userStyle = chosen
    closeStyleEditor()
end)

Progress:_registerNUI('styleClose', function()
    closeStyleEditor()
end)

RegisterCommand('rsprogressui', function()
    if editorOpen then closeStyleEditor() else openStyleEditor() end
end, false)

-- Dedicated local shortcut avoids relying on server/chat slash-command ACL.
-- F10 was chosen to avoid F6/F7 used by other RS resources; can be rebound
-- in FiveM Settings > Key Bindings > FiveM.
RegisterCommand('+rsprogress_frame_studio', function()
    if editorOpen then closeStyleEditor() else openStyleEditor() end
end, false)
RegisterCommand('-rsprogress_frame_studio', function() end, false)
if type(RegisterKeyMapping) == 'function' then
    RegisterKeyMapping('+rsprogress_frame_studio', 'RS Progressbar - Frame Studio', 'keyboard', 'F5')
end

RegisterCommand('rsprogressstyle', function(_, args)
    if Config.style and Config.style.allowPlayerCustomization == false then return end
    if not args[1] then openStyleEditor() return end
    if Progress._active or editorOpen then
        log('Cannot change the progress frame during an active action or open editor.')
        return
    end
    local frame = tostring(args[1]):lower()
    if not VALID_FRAMES[frame] then
        log('Frame must be streetglass, neonrunner, carbonracer, tactical, arcade, pipboi420, trackstrike, nightshift, streetcrew, violetsyndicate.')
        return
    end
    local chosen = readStyle()
    chosen.frame = frame
    if args[2] and VALID_THEMES[tostring(args[2]):lower()] then chosen.theme = tostring(args[2]):lower() end
    if args[3] and VALID_BARS[tostring(args[3]):lower()] then chosen.bar = tostring(args[3]):lower() end
    if args[4] and VALID_EFFECTS[tostring(args[4]):lower()] then chosen.effects = tostring(args[4]):lower() end
    SetResourceKvp(STYLE_KVP, json.encode(chosen))
    userStyle = chosen
    log(('Player visuals: frame=%s color=%s progress=%s effects=%s'):format(chosen.frame, chosen.theme, chosen.bar, chosen.effects))
end, false)

CreateThread(function()
    while true do
        if editorOpen then
            -- NUI owns the mouse/keyboard. Do not permit movement, weapon
            -- actions, camera controls or phone keybinds to leak into the game.
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

function Progress:Start(input, onStart, onFinish, onTick)
    if editorOpen then closeStyleEditor() end
    if self._active then
        debugLog('Start rejected because another progress task is active.')
        return false, 'busy'
    end

    if not self.is_nui_ready then
        log('Start rejected because the NUI is not ready. Check html files and the client console.')
        return false, 'nui_not_ready'
    end

    local task, validationError = normalizeTask(input)
    if not task then
        log(('Start rejected: %s'):format(validationError))
        return false, 'invalid_task'
    end

    self.player_ped_id = PlayerPedId()
    if IsEntityDead(self.player_ped_id) and not task.useWhileDead then
        return false, 'player_dead'
    end

    local blockedState = blockedOxPlayerState(task, self.player_ped_id)
    if blockedState then
        return false, 'player_' .. blockedState
    end

    self._run_id = self._run_id + 1
    local runId = self._run_id
    self._active = true
    self._task_instance = task
    self._current_stage_index = 1
    self._minigame_result = nil
    self._on_start = onStart
    self._on_finish = onFinish
    self._on_tick = onTick

    self:_acquireBusyState()

    local ok, err = pcall(function()
        self:_handleStages(runId)
        self:_startActions(runId)

        local location = task.location or ''
        local globalShowLocation = Config.ui == nil or Config.ui.showLocation ~= false
        if location == '' and task.showLocation ~= false and globalShowLocation then
            location = currentLocationLabel(self.player_ped_id)
        end

        -- A visual lookup must never interrupt a real progress action or its callbacks.
        local assetOk, assetVisual = pcall(resolveAssetVisual, task, self.player_ped_id)
        if not assetOk then
            debugLog(('Asset image lookup failed (nonfatal): %s'):format(tostring(assetVisual)))
            assetVisual = nil
        end
        self:_sendNUI('START_PROGRESS', {
            sessionId = runId,
            assetVisual = assetVisual,
            assetImageExtensions = (Config.assetImages or {}).extensions or (Config.vehicleImages or {}).extensions or { 'webp', 'png', 'jpg', 'jpeg' },
            label = task.label,
            icon = task.icon or 'fa-solid fa-spinner',
            iconColor = task.iconColor,
            progressColor = task.progressColor,
            canCancel = task.canCancel and (not Config.cancel or Config.cancel.enabled ~= false),
            cancelKey = Config.cancel and Config.cancel.key or Config.cancelKey or 'X',
            stages = self:_nuiStages(task),
            duration = task.duration,
            theme = task.theme or userStyle.theme or Config.theme,
            frame = (VALID_FRAMES[task.frame] and task.frame) or userStyle.frame,
            barStyle = (VALID_BARS[task.barStyle] and task.barStyle) or userStyle.bar,
            effects = userStyle.effects,
            position = task.position or 'center-bottom',
            uiScale = math.min(math.max(tonumber(Config.ui and Config.ui.scale) or 0.82, 0.60), 1.25),
            uiBottomOffset = math.min(math.max(tonumber(Config.ui and Config.ui.bottomOffset) or 34, 0), 300),
            location = location,
        })
        self:_monitor(runId, task, onStart, onTick)
        self:_scheduleLuaCompletion(runId, task)
        self:_watchdog(runId, task)
    end)

    if not ok then
        log(('Start failed: %s'):format(tostring(err)))
        self:_sendNUI('CANCEL', { sessionId = runId })
        self:_finalize(runId, true, nil, 'start_error')
        return false, 'start_error'
    end

    debugLog(('Started run %s (%sms)'):format(runId, taskDuration(task)))
    return true
end

Progress:_registerNUI('ready', function()
    Progress.is_nui_ready = true
    Progress:_sendNUI('SET_LOCALE', { locale = Progress:_uiLocale() })
    debugLog('NUI ready handshake received.')
end)

Progress:_registerNUI('progressFinished', function(data)
    local sessionId = tonumber(data.sessionId)
    if not Progress._active or sessionId ~= Progress._run_id then return end
    Progress:_finalize(sessionId, data.cancelled == true, Progress._minigame_result, 'nui_finished')
end)

Progress:_registerNUI('stageStart', function(data)
    local sessionId = tonumber(data.sessionId)
    if not Progress._active or sessionId ~= Progress._run_id then return end

    local index = (tonumber(data.stage_index) or -1) + 1
    local stage = Progress._task_instance.stages and Progress._task_instance.stages[index]
    if not stage then return end

    Progress._current_stage_index = index
    Progress:_stopSingleAnimation(Progress.currentAnimation)
    Progress.currentAnimation = stage.animation
    Progress:_playAnimation(stage.animation, sessionId)
end)

Progress:_registerNUI('stageFinished', function(data)
    local sessionId = tonumber(data.sessionId)
    if not Progress._active or sessionId ~= Progress._run_id then return end

    local index = (tonumber(data.stage_index) or -1) + 1
    local stage = Progress._task_instance.stages and Progress._task_instance.stages[index]
    if not stage then return end

    Progress._current_stage_index = math.min(index + 1, #Progress._task_instance.stages)
    safeCall('stage onFinish', stage.onFinish, GetGameTimer(), data.timestamp, data.skipped == true)
end)

Progress:_registerNUI('stageMinigame', function(data)
    local sessionId = tonumber(data.sessionId)
    if not Progress._active or sessionId ~= Progress._run_id then return end

    local index = (tonumber(data.stage_index) or -1) + 1
    local stage = Progress._task_instance.stages and Progress._task_instance.stages[index]
    if not stage or not isCallable(stage.minigame) then return end

    local ok, result = pcall(stage.minigame, GetGameTimer(), data.timestamp)
    Progress._minigame_result = ok and result or false
    Progress:_sendNUI('MINIGAME_RESULT', {
        sessionId = sessionId,
        result = Progress._minigame_result,
        stage_index = index,
    })
end)

Progress:_registerNUI('minigameFailed', function(data)
    local sessionId = tonumber(data.sessionId)
    if not Progress._active or sessionId ~= Progress._run_id then return end

    local index = (tonumber(data.stage_index) or -1) + 1
    local stage = Progress._task_instance.stages and Progress._task_instance.stages[index]
    if stage and stage.cancelMode == 'hard' then
        Progress:_finalize(sessionId, true, Progress._minigame_result, 'minigame_failed')
    end
end)

local function cancelFromKey()
    if Config.cancel and Config.cancel.enabled == false then return end
    Progress:Cancel(false, 'keybind')
end

RegisterCommand('+rsfield_progress_cancel', cancelFromKey, false)
RegisterCommand('-rsfield_progress_cancel', function() end, false)

if Config.cancel and Config.cancel.legacyCommand == true then
    RegisterCommand('+keep_progreebar:cancel', cancelFromKey, false)
    RegisterCommand('-keep_progreebar:cancel', function() end, false)
    TriggerEvent('chat:removeSuggestion', '/+keep_progreebar:cancel')
end

if Config.cancel and Config.cancel.enabled ~= false then
    RegisterKeyMapping('+rsfield_progress_cancel', 'Cancel current progress', 'KEYBOARD', Config.cancel.key or 'X')
end

TriggerEvent('chat:removeSuggestion', '/+rsfield_progress_cancel')

if Config.devMode then
    RegisterCommand('rsfieldtest', function()
        Progress:Start({
            label = 'Testing Infection Protocol...',
            duration = 5000,
            canCancel = true,
            disableCombat = true,
        }, nil, function(cancelled)
            log(('Test finished. cancelled=%s'):format(tostring(cancelled)))
        end)
    end, false)
end

exports('Start', function(data, onFinish)
    return Progress:Start(data, nil, onFinish)
end)

exports('isActive', function()
    return Progress:IsActive()
end)

exports('Cancel', function(force)
    return Progress:Cancel(force == true, 'native_export')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeStyleEditor()
    if Progress._active then
        Progress:_finalize(Progress._run_id, true, Progress._minigame_result, 'resource_stop', true)
    else
        Progress:_cleanupProps()
        Progress:_releaseBusyState()
    end
end)
