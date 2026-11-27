(function () {
  const app = document.getElementById('app');
  const wrapper = document.getElementById('terminal-wrapper');
  const taskLabel = document.getElementById('taskLabel');
  const taskStage = document.getElementById('taskStage');
  const progressFill = document.getElementById('progressFill');
  const percentValue = document.getElementById('percentValue');
  const timeValue = document.getElementById('timeValue');
  const phaseValue = document.getElementById('phaseValue');
  const stageNodes = document.getElementById('stageNodes');
  const cancelHint = document.getElementById('cancelHint');
  const statusText = document.getElementById('statusText');
  const systemState = document.getElementById('systemState');
  const timerReadout = document.querySelector('.readout--timer');
  const dockLabel = document.getElementById('dockLabel');
  const dockFill = document.getElementById('dockFill');
  const dockPercent = document.getElementById('dockPercent');
  const dockTimer = document.getElementById('dockTimer');
  const scanner = document.querySelector('.scanner-field');
  const assetPhotoPanel = document.getElementById('assetPhotoPanel');
  const assetPhoto = document.getElementById('assetPhoto');
  const assetPhotoName = document.getElementById('assetPhotoName');
  const assetPhotoFallback = document.getElementById('assetPhotoFallback');

  const state = {
    windowConfig: {
      label: 'Progress',
      theme: 'default',
      position: 'center-bottom',
      cancelKey: 'X',
      frame: 'streetglass',
      barStyle: 'auto',
    },
    stages: [],
    currentStageIndex: 0,
    totalDuration: 0,
    canCancel: false,
    locale: {},
    progress: 0,
    active: false,
    intervalId: null,
    remainingIntervalId: null,
    stageStartTime: null,
    finishing: false,
    sequence: 0,
    sessionId: null,
    assetVisual: null,
    assetExtensions: ['webp', 'png', 'jpg', 'jpeg', 'avif'],
    assetPhotoToken: 0,
  };

  function getParentName() {
    return typeof GetParentResourceName === 'function'
      ? GetParentResourceName()
      : 'progressbar';
  }

  function postNui(action, payload) {
    const body = payload && typeof payload === 'object' ? { ...payload } : {};
    if (state.sessionId !== null && state.sessionId !== undefined && body.sessionId === undefined) {
      body.sessionId = state.sessionId;
    }

    try {
      return fetch(`https://${getParentName()}/${action}`, {
        method: 'POST',
        body: JSON.stringify(body),
      }).catch(() => {});
    } catch (e) {
      return Promise.resolve();
    }
  }

  function sanitizeText(value, fallback) {
    if (typeof value === 'string') {
      const text = value
        .replace(/\u00c3\u00a2\u00e2\u201a\u00ac\u00c2\u00a6|\u00e2\u20ac\u00a6|\u00e2\u0080\u00a6|\u2026/g, '...')
        .replace(/[\u0000-\u001f\u007f]/g, ' ').trim();
      if (text) return text;
    }
    return fallback || '';
  }

  function stripHtml(value) {
    if (!value) return '';
    const div = document.createElement('div');
    div.innerHTML = value;
    return (div.textContent || div.innerText || '').trim();
  }

  function formatRemaining(ms) {
    const safe = Math.max(0, Math.floor(ms));
    const totalSeconds = safe / 1000;

    if (totalSeconds >= 3600) {
      const hours = Math.floor(totalSeconds / 3600);
      const minutes = Math.floor((totalSeconds % 3600) / 60);
      const seconds = Math.floor(totalSeconds % 60);
      return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
    }

    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${String(minutes).padStart(2, '0')}:${seconds.toFixed(1).padStart(4, '0')}`;
  }

  function getProgressPercent() {
    return Math.max(0, Math.min(100, state.progress));
  }

  function getCurrentStage() {
    return state.stages[state.currentStageIndex] || null;
  }

  function stagePercentStart(index) {
    if (!state.totalDuration) return 0;
    const elapsedBefore = state.stages
      .slice(0, index)
      .reduce((sum, stage) => sum + (Number(stage.duration) || 0), 0);
    return (elapsedBefore / state.totalDuration) * 100;
  }

  function stagePercentEnd(index) {
    if (!state.totalDuration) return 100;
    const elapsedTo = state.stages
      .slice(0, index + 1)
      .reduce((sum, stage) => sum + (Number(stage.duration) || 0), 0);
    return (elapsedTo / state.totalDuration) * 100;
  }

  function elapsedBeforeCurrent() {
    return state.stages
      .slice(0, state.currentStageIndex)
      .reduce((sum, stage) => sum + (Number(stage.duration) || 0), 0);
  }

  function updateRemainingTime() {
    if (!state.active) return;
    const runningElapsed = state.stageStartTime ? (Date.now() - state.stageStartTime) : 0;
    const remaining = Math.max(state.totalDuration - elapsedBeforeCurrent() - runningElapsed, 0);
    const formatted = formatRemaining(remaining);
    if (timeValue.textContent !== formatted) {
      timeValue.textContent = formatted;
      dockTimer.textContent = formatted;
      timerReadout.classList.toggle('is-hours', remaining >= 3600000);
    }
  }

  // A stage count from an external resource can be very large. Always fit the
  // phase visualization inside the live glass, while retaining the exact count.
  function renderStageNodes() {
    const total = Math.max(state.stages.length, 1);
    const visible = Math.min(total, 7);
    stageNodes.replaceChildren();
    for (let i = 0; i < visible; i++) {
      const start = Math.floor(i * total / visible);
      const end = Math.max(start, Math.floor((i + 1) * total / visible) - 1);
      const node = document.createElement('div');
      node.className = 'stage-node';
      if (end < state.currentStageIndex || (end === total - 1 && state.stages[end]?.finished)) {
        node.classList.add('is-finished');
      } else if (start <= state.currentStageIndex && state.currentStageIndex <= end) {
        node.classList.add('is-current');
      }
      stageNodes.appendChild(node);
    }
  }

  function fitDevice() {
    // Keep the physical shell AND its entire menu together. Never scale text
    // independently from the screen cutout. Clamp to fit smaller resolutions.
    const authoredWidth = 960;
    const authoredHeight = authoredWidth * (941 / 1672);
    const preferred = Math.min(1.25, Math.max(0.60, Number(state.windowConfig.uiScale) || 1));
    const bottomOffset = Math.min(300, Math.max(0, Number(state.windowConfig.uiBottomOffset) || 0));
    const reserved = 24 + (state.windowConfig.position === 'center-bottom' ? bottomOffset : 0);
    const width = document.documentElement.clientWidth || window.innerWidth || 1920;
    const height = document.documentElement.clientHeight || window.innerHeight || 1080;
    const availableWidth = Math.max(100, width - 24);
    const availableHeight = Math.max(100, height - reserved - 24);
    const fit = Math.min(1, availableWidth / (authoredWidth * preferred), availableHeight / (authoredHeight * preferred));
    wrapper.style.setProperty('--ui-scale', String(preferred * fit));
    wrapper.style.paddingBottom = state.windowConfig.position === 'center-bottom' ? `${24 + bottomOffset}px` : '';
  }

  // Filenames are plain vehicle spawn codes, e.g. adder.webp or sultanrs.png.
  // No JSON index to maintain as the server owner adds all 922 images.
  function photoKey(value) {
    if (typeof value !== 'string') return '';
    const name = value.toLowerCase().trim();
    return /^[a-z0-9_-]{1,64}$/.test(name) ? name : '';
  }

  function clearAssetPhoto() {
    state.assetPhotoToken += 1;
    assetPhotoPanel.hidden = true;
    assetPhotoPanel.classList.remove('has-image');
    assetPhoto.removeAttribute('src');
    assetPhotoName.textContent = '';
    assetPhotoFallback.textContent = 'IMAGE NOT AVAILABLE';
    state.assetVisual = null;
  }

  function showAssetPhoto(visual) {
    clearAssetPhoto();
    if (!visual || !Array.isArray(visual.entries)) return;
    const allowedFolders = new Set(['items', 'vehicles', 'categories']);
    const entries = visual.entries
      .map((entry) => {
        if (!entry || typeof entry !== 'object') return null;
        const folder = typeof entry.folder === 'string' ? entry.folder.toLowerCase().trim() : '';
        const name = photoKey(entry.name);
        if (!allowedFolders.has(folder) || !name) return null;
        return { folder, name };
      })
      .filter(Boolean)
      .slice(0, 40);
    if (!entries.length) return;
    // Only ask NUI to fetch an image AFTER the Lua resource confirms it exists.
    // This prevents F8 "Unable to find file ...webp" spam for stock PNG assets.
    const configured = Array.isArray(state.assetExtensions) ? state.assetExtensions : [];
    const extensions = [...new Set(['png', ...configured.map(photoKey), 'webp', 'jpg', 'jpeg', 'avif'])]
      .filter((ext) => /^(webp|png|jpg|jpeg|avif)$/.test(ext));
    const files = entries.flatMap((entry) => extensions.map((ext) => `assets/${entry.folder}/${entry.name}.${ext}`));
    assetPhotoPanel.hidden = false;
    assetPhotoName.textContent = typeof visual.displayName === 'string' ? visual.displayName.slice(0, 54) : entries[0].name;
    assetPhotoFallback.textContent = 'SCANNING IMAGE ...';
    const token = state.assetPhotoToken;
    const missingText = typeof visual.fallbackText === 'string' && visual.fallbackText.trim()
      ? visual.fallbackText.trim() : 'IMAGE NOT AVAILABLE';
    function applyVerifiedPath(path) {
      if (token !== state.assetPhotoToken) return;
      if (typeof path !== 'string' || !files.includes(path)) {
        assetPhotoFallback.textContent = missingText;
        return;
      }
      assetPhoto.onload = () => {
        if (token !== state.assetPhotoToken) return;
        assetPhotoPanel.classList.add('has-image');
      };
      assetPhoto.onerror = () => {
        if (token !== state.assetPhotoToken) return;
        assetPhotoPanel.classList.remove('has-image');
        assetPhotoFallback.textContent = missingText;
      };
      assetPhoto.src = path;
    }
    if (typeof GetParentResourceName === 'function') {
      // Single, bounded NUI callback per action; Lua checks local resource files.
      postNui('rsResolveProgressAsset', {files: files.slice(0, 200)})
        .then(response => response && response.ok ? response.json() : null)
        .then(data => applyVerifiedPath(data && data.file))
        .catch(() => { if (token === state.assetPhotoToken) assetPhotoFallback.textContent = missingText; });
      return;
    }
    // Outside FiveM (browser previews), normal probing is still useful.
    let cursor = 0;
    function next() {
      if (token !== state.assetPhotoToken) return;
      if (cursor >= files.length) { assetPhotoFallback.textContent = missingText; return; }
      const path = files[cursor++];
      const probe = new Image();
      probe.onload = () => applyVerifiedPath(path);
      probe.onerror = next;
      probe.src = path;
    }
    next();
  }

  function inferUiCategory(subject, visual) {
    const explicit = visual && typeof visual.category === 'string' ? visual.category.toLowerCase().trim() : '';
    if (explicit) {
      if (['food', 'drink', 'consume', 'alcohol', 'smoke'].includes(explicit)) return 'consume';
      if (['medical', 'drug'].includes(explicit)) return explicit === 'medical' ? 'medical' : 'consume';
      if (['vehicle', 'tool', 'ammo', 'search'].includes(explicit)) return explicit === 'vehicle' ? 'vehicle' : (explicit === 'search' ? 'search' : 'misc');
      if (['craft', 'gather', 'carry'].includes(explicit)) return explicit;
    }
    return /medical|heal|bandag|reviv|medkit|first[ _]?aid|ifak|treating|treatment|treat patient|treat wound|trauma|defib|cpr|resuscitat|stabili[sz]/.test(subject) ? 'medical'
      : /lock|loot|search|steal|rob/.test(subject) ? 'search'
      : /vehicle|engine|tire|tyre|car|repair/.test(subject) ? 'vehicle'
      : /food|drink|consum|eat|smok|alcohol|beer|water/.test(subject) ? 'consume'
      : /craft|build|assembl/.test(subject) ? 'craft'
      : /lift|carry/.test(subject) ? 'carry'
      : /harvest|gather|mine|fish/.test(subject) ? 'gather'
      : 'general';
  }

  function renderText() {
    const current = getCurrentStage();
    const totalStages = Math.max(state.stages.length, 1);
    const currentNumber = Math.min(state.currentStageIndex + 1, totalStages);

    taskLabel.textContent = sanitizeText(state.windowConfig.label, 'WORKING...').toUpperCase();
    taskLabel.classList.toggle('is-long', taskLabel.textContent.length > 24);
    dockLabel.textContent = taskLabel.textContent;
    const subject = (taskLabel.textContent + ' ' + (current?.message || '')).toLowerCase();
    const category = inferUiCategory(subject, state.assetVisual);
    wrapper.dataset.category = category;
    document.querySelectorAll('.side-category').forEach((el) => el.classList.toggle('is-active', el.dataset.cat === category));
    scanner.classList.toggle('is-vehicle', !!(state.assetVisual && state.assetVisual.kind === 'vehicle') || /\b(vehicle|engine|car|hotwire|lockpick|ignition|trunk)\b/.test(subject));
    if (state.assetVisual) assetPhotoPanel.hidden = false;
    taskStage.textContent = sanitizeText(current?.message, state.windowConfig.label || 'Working...');
    phaseValue.textContent = `PHASE ${String(currentNumber).padStart(2, '0')} / ${String(totalStages).padStart(2, '0')}`;
    statusText.textContent = state.active ? 'STATUS: ACTIVE' : 'STATUS: IDLE';
    systemState.textContent = state.active && current?.condition ? 'HOLD' : 'OK';

    const cancelText = state.canCancel
      ? (stripHtml(state.locale.can_cancel) || 'Press Cancel Key to Cancel').replace(/cancel key/gi, state.windowConfig.cancelKey || 'X')
      : 'ACTION LOCKED';

    cancelHint.textContent = cancelText.toUpperCase();
    cancelHint.classList.toggle('is-locked', !state.canCancel);
  }

  function setBarRatio(ratio) {
    const clamped = Math.max(0, Math.min(1, Number(ratio) || 0));
    progressFill.style.setProperty('--progress', String(clamped));
    dockFill.style.setProperty('--progress', String(clamped));
  }

  function renderProgress() {
    const pct = getProgressPercent();
    setBarRatio(pct / 100);
    const percent = String(pct >= 100 ? 100 : Math.max(0, Math.floor(pct)));
    if (percentValue.textContent !== percent) {
      percentValue.textContent = percent;
      dockPercent.textContent = `${percent}%`;
    }
  }

  function renderAll() {
    renderText();
    renderStageNodes();
    renderProgress();
    updateRemainingTime();
  }

  function clearTimers() {
    if (state.intervalId) {
      clearInterval(state.intervalId);
      state.intervalId = null;
    }
    if (state.remainingIntervalId) {
      clearInterval(state.remainingIntervalId);
      state.remainingIntervalId = null;
    }
    state.stageStartTime = null;
  }

  function resetState() {
    clearTimers();
    clearAssetPhoto();
    state.assetVisual = null;
    state.stages = [];
    state.currentStageIndex = 0;
    state.totalDuration = 0;
    state.progress = 0;
    state.active = false;
    state.finishing = false;
    wrapper.dataset.result = 'idle';
    state.sessionId = null;
    setBarRatio(0);
    percentValue.textContent = '0';
    timeValue.textContent = '00:00.0';
    dockLabel.textContent = '';
    dockPercent.textContent = '0%';
    dockTimer.textContent = '00:00.0';
    timerReadout.classList.remove('is-hours');
    stageNodes.innerHTML = '';
  }

  function hideUi() {
    wrapper.classList.remove('is-visible');
    wrapper.setAttribute('aria-hidden', 'true');
    setTimeout(() => {
      if (!state.active) {
        app.classList.add('nui-hidden');
        document.body.classList.remove('nui-open');
      }
    }, 190);
  }

  function finish(cancelled) {
    if (!state.active || state.finishing) return;
    state.finishing = true;
    wrapper.dataset.result = cancelled ? 'cancelled' : 'complete';
    clearTimers();
    const sequence = state.sequence;

    if (!cancelled) {
      state.progress = 100;
      renderProgress();
      timeValue.textContent = formatRemaining(0);
      dockTimer.textContent = timeValue.textContent;
      statusText.textContent = 'STATUS: COMPLETE';
    } else {
      statusText.textContent = 'STATUS: CANCELLED';
    }

    setTimeout(() => {
      if (state.sequence !== sequence) return;
      state.active = false;
      hideUi();
      postNui('progressFinished', { cancelled });
      setTimeout(() => {
        if (state.sequence === sequence && !state.active) resetState();
      }, 200);
    }, 230);
  }

  function runStage() {
    if (!state.active) return;

    if (state.currentStageIndex >= state.stages.length) {
      finish(false);
      return;
    }

    const stage = getCurrentStage();
    if (!stage) {
      finish(false);
      return;
    }

    renderAll();

    postNui('stageStart', {
      stage_index: state.currentStageIndex,
      timestamp: Date.now(),
    });

    if (stage.condition) return;

    if (stage.minigame) {
      postNui('stageMinigame', {
        stage_index: state.currentStageIndex,
        timestamp: Date.now(),
      });
    }

    state.stageStartTime = Date.now();
    const progressStart = stagePercentStart(state.currentStageIndex);
    const progressEnd = stagePercentEnd(state.currentStageIndex);

    if (state.intervalId) clearInterval(state.intervalId);
    state.intervalId = setInterval(() => {
      const duration = Math.max(Number(stage.duration) || 0, 1);
      const elapsed = Date.now() - state.stageStartTime;
      const ratio = Math.min(elapsed / duration, 1);

      state.progress = progressStart + (progressEnd - progressStart) * ratio;
      renderProgress();

      if (ratio >= 1) {
        clearInterval(state.intervalId);
        state.intervalId = null;

        state.stages[state.currentStageIndex].finished = true;
        renderStageNodes();

        postNui('stageFinished', {
          stage_index: state.currentStageIndex,
          stage: state.stages[state.currentStageIndex],
          timestamp: Date.now(),
        });

        if (state.currentStageIndex < state.stages.length - 1) {
          state.currentStageIndex += 1;
          runStage();
        } else {
          finish(false);
        }
      }
    }, 60);
  }

  function skipCurrentStage() {
    if (state.intervalId) {
      clearInterval(state.intervalId);
      state.intervalId = null;
    }

    state.stageStartTime = null;
    const idx = state.currentStageIndex;

    if (state.stages[idx]) {
      state.stages[idx].finished = true;
    }

    state.progress = stagePercentEnd(idx);
    renderAll();

    postNui('stageFinished', {
      stage_index: idx,
      skipped: true,
      timestamp: Date.now(),
    });

    if (idx < state.stages.length - 1) {
      state.currentStageIndex += 1;
      const sequence = state.sequence;
      setTimeout(() => { if (state.sequence === sequence && state.active && !state.finishing) runStage(); }, 10);
    } else {
      finish(false);
    }
  }

  function startProgress(data) {
    const nextSequence = state.sequence + 1;
    resetState();
    state.sequence = nextSequence;
    state.sessionId = Number.isFinite(Number(data.sessionId)) ? Number(data.sessionId) : null;

    state.windowConfig.label = sanitizeText(data.label, 'Progress');
    state.windowConfig.theme = sanitizeText(data.theme, 'theme-2');
    const frames = ['streetglass', 'neonrunner', 'carbonracer', 'tactical', 'arcade', 'pipboi420', 'trackstrike', 'nightshift', 'streetcrew', 'violetsyndicate'];
    const bars = ['auto', 'segmented', 'pulse', 'race', 'dots', 'liquid'];
    state.windowConfig.frame = frames.includes(data.frame) ? data.frame : 'streetglass';
    const chosenBar = bars.includes(data.barStyle) ? data.barStyle : 'auto';
    const autoBars = { streetglass: 'segmented', neonrunner: 'pulse', carbonracer: 'race', tactical: 'dots', arcade: 'liquid', pipboi420: 'segmented', trackstrike: 'race', nightshift: 'race', streetcrew: 'segmented', violetsyndicate: 'pulse' };
    state.windowConfig.barStyle = chosenBar === 'auto' ? autoBars[state.windowConfig.frame] : chosenBar;
    state.windowConfig.position = sanitizeText(data.position, 'center-bottom');
    state.windowConfig.uiScale = data.uiScale;
    state.windowConfig.uiBottomOffset = data.uiBottomOffset;
    state.windowConfig.cancelKey = sanitizeText(data.cancelKey, 'X').slice(0, 12);
    state.canCancel = !!data.canCancel;
    state.assetExtensions = Array.isArray(data.assetImageExtensions || data.vehicleImageExtensions) ? (data.assetImageExtensions || data.vehicleImageExtensions) : ['webp', 'png', 'jpg', 'jpeg', 'avif'];
    state.assetVisual = data.assetVisual || data.vehicleVisual || null;

    const incomingStages = Array.isArray(data.stages) && data.stages.length > 0
      ? data.stages
      : [{
          message: sanitizeText(data.label, 'Working...'),
          duration: Number(data.duration) || 3000,
          progressColor: data.progressColor,
        }];

    state.stages = incomingStages.map((stage) => ({
      ...stage,
      duration: Number(stage.duration) || 0,
      finished: !!stage.finished,
      message: sanitizeText(stage.message, sanitizeText(data.label, 'Working...')),
    }));

    state.totalDuration = state.stages.reduce((sum, stage) => sum + (Number(stage.duration) || 0), 0);
    state.currentStageIndex = 0;
    state.progress = 0;
    state.active = true;
    state.finishing = false;

    wrapper.dataset.theme = state.windowConfig.theme || 'theme-2';
    wrapper.dataset.effects = ['full', 'low', 'off'].includes(data.effects) ? data.effects : 'full';
    wrapper.dataset.result = 'active';
    wrapper.dataset.frame = state.windowConfig.frame;
    wrapper.dataset.bar = state.windowConfig.barStyle;
    const brand = document.getElementById('terminalBrand');
    if (brand) brand.textContent = state.windowConfig.frame === 'pipboi420' ? 'PIP-BOI 420' : 'RS LIVE PROGRESS';
    wrapper.dataset.position = state.windowConfig.position || 'center-bottom';

    fitDevice();
    document.body.classList.add('nui-open');
    app.classList.remove('nui-hidden');
    wrapper.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => { if (state.sequence === nextSequence && state.active) wrapper.classList.add('is-visible'); });

    renderAll();
    showAssetPhoto(state.assetVisual);
    state.assetVisual = data.assetVisual || data.vehicleVisual || null;

    state.remainingIntervalId = setInterval(updateRemainingTime, 60);
    runStage();
  }

  function handleMessage(event) {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || {};
    if (['CANCEL', 'COMPLETE', 'CONDITIONAL_SKIP', 'MINIGAME_RESULT'].includes(action)) {
      if (!state.active || state.finishing) return;
      if (data.sessionId != null && Number(data.sessionId) !== state.sessionId) return;
      if (action === 'CONDITIONAL_SKIP' && data.index != null && Number(data.index) !== state.currentStageIndex) return;
      if (action === 'MINIGAME_RESULT' && Number(data.stage_index) !== state.currentStageIndex + 1) return;
    }

    if (action === 'START_PROGRESS') {
      startProgress(data);
    } else if (action === 'CANCEL') {
      finish(true);
    } else if (action === 'COMPLETE') {
      finish(false);
    } else if (action === 'CONDITIONAL_SKIP') {
      if (!state.active || !state.stages[state.currentStageIndex]) return;
      state.stages[state.currentStageIndex].finished = true;
      postNui('stageFinished', {
        stage_index: state.currentStageIndex,
        timestamp: Date.now(),
      });
      state.currentStageIndex += 1;
      runStage();
    } else if (action === 'MINIGAME_RESULT') {
      if (data.result === true && state.currentStageIndex === data.stage_index - 1) {
        skipCurrentStage();
      } else {
        const stage = getCurrentStage();
        postNui('minigameFailed', {
          stage_index: state.currentStageIndex,
          stage,
          data,
          timestamp: Date.now(),
        });

        if (stage && stage.cancelMode === 'hard') {
          finish(true);
        }
      }
    } else if (action === 'SET_LOCALE') {
      state.locale = data.locale || {};
      renderText();
    }
  }

  window.addEventListener('message', handleMessage);
  window.addEventListener('resize', fitDevice);
  postNui('ready', { timestamp: Date.now() });

})();
