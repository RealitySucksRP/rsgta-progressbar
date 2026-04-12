-- ═══════════════════════════════════════════════════════════════════
--  RealitySucks-ProgBargtaV  |  client.lua
-- ═══════════════════════════════════════════════════════════════════

SetNuiFocus(false, false)

local _running  = false
local _cb       = nil
local handsUpActive = false
local handsUpAnim   = { dict = "random@mugging3", clip = "handsup_standing_base" }

function RSIsRunning()
    return _running
end

function RSProgress(data, cb)
    if _running then return false end
    if type(data) ~= 'table' then return false end

    _running = true
    _cb      = cb or data.onFinish

    local duration   = data.duration   or Config.DefaultDuration
    local label      = tostring(data.label or '')
    local cancelOk   = data.canCancel  ~= false
    local cancelMove = data.cancelOnMove == true

    -- Animation
    if data.animation and data.animation.dict and data.animation.clip then
        local dict = data.animation.dict
        local clip = data.animation.clip
        RequestAnimDict(dict)
        local t = GetGameTimer() + 3000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(PlayerPedId(), dict, clip, 2.0, -2.0, duration, 49, 0, false, false, false)
        end
    end

    SendNUIMessage({
        action      = 'START_PROGRESS',
        data        = {
            label       = label,
            duration    = duration,
            canCancel   = cancelOk,
            style       = Config.BarStyle,
            accentColor = Config.AccentColor,
            serverName  = Config.ServerName,
            logoSrc     = Config.LogoFile,
        }
    })

    if cancelMove then
        local startPos = GetEntityCoords(PlayerPedId())
        CreateThread(function()
            while _running do
                Wait(200)
                if #(GetEntityCoords(PlayerPedId()) - startPos) > 1.5 then
                    RSStop()
                end
            end
        end)
    end

    if cancelOk then
        CreateThread(function()
            while _running do
                Wait(0)
                if IsControlJustPressed(0, Config.CancelKey) then
                    RSStop()
                end
            end
        end)
    end

    return true
end

function RSStop()
    if not _running then return end
    _running = false
    ClearPedTasks(PlayerPedId())
    SendNUIMessage({ action = 'stop' })
    if _cb then
        pcall(_cb, true)
        _cb = nil
    end
end

-- NUI fires this when bar completes naturally
RegisterNUICallback('progressComplete', function(data, cb)
    cb('ok')
    local cancelled = data and data.cancelled == true
    ClearPedTasks(PlayerPedId())
    _running = false
    if _cb then
        pcall(_cb, cancelled)
        _cb = nil
    end
end)

exports('Progress',     function(data, cb) return RSProgress(data, cb or (type(data) == 'table' and data.onFinish)) end)
exports('StopProgress', RSStop)
exports('IsRunning',    RSIsRunning)

-- ── Hands Up ─────────────────────────────────────────────────────────

local function startHandsUp()
    handsUpActive = true
    RequestAnimDict(handsUpAnim.dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(handsUpAnim.dict) and GetGameTimer() < t do Wait(0) end
    TaskPlayAnim(PlayerPedId(), handsUpAnim.dict, handsUpAnim.clip,
        2.0, -2.0, -1, 49, 0, false, false, false)
    RSProgress({ label = "Hands Up", duration = 99000, canCancel = false }, function() end)
end

local function stopHandsUp()
    handsUpActive = false
    RSStop()
    ClearPedTasks(PlayerPedId())
end

-- ── Revive ────────────────────────────────────────────────────────────

local function getNearestDownedPed()
    local playerPos = GetEntityCoords(PlayerPedId())
    local peds = GetGamePool('CPed')
    local closest, closestDist = nil, Config.ReviveDistance
    for _, ped in ipairs(peds) do
        if ped ~= PlayerPedId() and IsEntityDead(ped) then
            local dist = #(GetEntityCoords(ped) - playerPos)
            if dist < closestDist then closest = ped; closestDist = dist end
        end
    end
    return closest
end

-- ── Keybind thread ────────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.HandsUpKey) then
            if handsUpActive then stopHandsUp()
            elseif not _running then startHandsUp() end
        end
        if IsControlJustPressed(0, Config.ReviveKey) and not _running then
            local ped = getNearestDownedPed()
            if ped then
                RSProgress({
                    label = 'Reviving...', duration = Config.ReviveDuration,
                    canCancel = true,
                    animation = { dict = 'mini@cpr@char_a@cpr_str', clip = 'cpr_pumpchest' },
                }, function(cancelled)
                    if cancelled or not DoesEntityExist(ped) then return end
                    ResurrectPed(ped)
                    SetEntityHealth(ped, math.random(Config.ReviveHealthMin + 100, Config.ReviveHealthMax + 100))
                end)
            end
        end
    end
end)
