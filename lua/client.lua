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

function Progress:Start(input, onStart, onFinish, onTick)
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

        self:_sendNUI('START_PROGRESS', {
            sessionId = runId,
            label = task.label,
            icon = task.icon or 'fa-solid fa-spinner',
            iconColor = task.iconColor,
            progressColor = task.progressColor,
            canCancel = task.canCancel and (not Config.cancel or Config.cancel.enabled ~= false),
            stages = self:_nuiStages(task),
            duration = task.duration,
            theme = task.theme or Config.theme,
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
    if Progress._active then
        Progress:_finalize(Progress._run_id, true, Progress._minigame_result, 'resource_stop', true)
    else
        Progress:_cleanupProps()
        Progress:_releaseBusyState()
    end
end)
