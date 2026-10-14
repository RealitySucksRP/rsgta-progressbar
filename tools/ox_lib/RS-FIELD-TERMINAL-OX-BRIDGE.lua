-- RS_FIELD_TERMINAL_OX_BRIDGE_BEGIN
-- ============================================================================
-- RS Field Terminal Progressbar v4.0.3 — Optional ox_lib bridge
--
-- Append this entire block to the BOTTOM of an unmodified/current:
-- ox_lib/resource/interface/client/progress.lua
--
-- Do not replace ox_lib's original functions. This bridge stores them and uses
-- them as the fallback whenever RS Field Terminal Progressbar is unavailable.
-- ============================================================================

local rsFieldTerminalOriginalProgressBar = lib.progressBar
local rsFieldTerminalOriginalProgressCircle = lib.progressCircle
local rsFieldTerminalOriginalCancelProgress = lib.cancelProgress
local rsFieldTerminalOriginalProgressActive = lib.progressActive
local rsFieldTerminalActiveBackend -- 'rs' or 'ox' while a bridged call is running

local function rsFieldTerminalProgressbarReady()
    return GetResourceState('progressbar') == 'started'
        and GetResourceMetadata('progressbar', 'rs_field_terminal_progressbar', 0) == 'yes'
end

local function rsFieldTerminalProgressActive()
    if not rsFieldTerminalProgressbarReady() then return false end

    local ok, active = pcall(function()
        return exports['progressbar']:ox_lib_progressActive()
    end)

    return ok and active == true
end

local function rsFieldTerminalWaitForProgressSlot()
    while rsFieldTerminalActiveBackend ~= nil do Wait(0) end

    while rsFieldTerminalProgressActive() or rsFieldTerminalOriginalProgressActive() == true do
        Wait(0)
    end
end

local function rsFieldTerminalRunBackend(backend, callback)
    rsFieldTerminalActiveBackend = backend
    local ok, result = pcall(callback)
    rsFieldTerminalActiveBackend = nil

    if not ok then error(result, 0) end
    return result
end

function lib.progressBar(data)
    rsFieldTerminalWaitForProgressSlot()

    if rsFieldTerminalProgressbarReady() then
        return rsFieldTerminalRunBackend('rs', function()
            return exports['progressbar']:ox_lib_progressBar(data)
        end)
    end

    return rsFieldTerminalRunBackend('ox', function()
        return rsFieldTerminalOriginalProgressBar(data)
    end)
end

function lib.progressCircle(data)
    rsFieldTerminalWaitForProgressSlot()

    if rsFieldTerminalProgressbarReady() then
        return rsFieldTerminalRunBackend('rs', function()
            return exports['progressbar']:ox_lib_progressCircle(data)
        end)
    end

    return rsFieldTerminalRunBackend('ox', function()
        return rsFieldTerminalOriginalProgressCircle(data)
    end)
end

function lib.cancelProgress()
    if rsFieldTerminalActiveBackend == 'rs' or rsFieldTerminalProgressActive() then
        if not rsFieldTerminalProgressbarReady() then return false end
        return exports['progressbar']:ox_lib_cancelProgress()
    end

    if rsFieldTerminalActiveBackend == 'ox' or rsFieldTerminalOriginalProgressActive() == true then
        return rsFieldTerminalOriginalCancelProgress()
    end

    -- Preserve ox_lib's normal "No progress bar is active" behavior.
    return rsFieldTerminalOriginalCancelProgress()
end

function lib.progressActive()
    if rsFieldTerminalActiveBackend == 'rs' then
        return rsFieldTerminalProgressActive()
    end

    if rsFieldTerminalActiveBackend == 'ox' then
        return rsFieldTerminalOriginalProgressActive() == true
    end

    return rsFieldTerminalProgressActive() or rsFieldTerminalOriginalProgressActive() == true
end

-- ============================================================================
-- End RS Field Terminal Progressbar optional ox_lib bridge
-- ============================================================================
-- RS_FIELD_TERMINAL_OX_BRIDGE_END
