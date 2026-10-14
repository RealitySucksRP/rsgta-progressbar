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

  const state = {
    windowConfig: {
      label: 'Progress',
      theme: 'default',
      position: 'center-bottom'
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
    if (typeof value === 'string' && value.trim() !== '') return value.trim();
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
    timeValue.textContent = formatRemaining(remaining);
  }

  function renderStageNodes() {
    const totalStages = Math.max(state.stages.length, 1);
    stageNodes.innerHTML = '';

    for (let i = 0; i < totalStages; i++) {
      const node = document.createElement('div');
      node.className = 'stage-node';

      if (state.stages[i]?.finished) node.classList.add('is-finished');
      if (!state.stages[i]?.finished && i === state.currentStageIndex) node.classList.add('is-current');

      stageNodes.appendChild(node);
    }
  }

  function renderText() {
    const current = getCurrentStage();
    const totalStages = Math.max(state.stages.length, 1);
    const currentNumber = Math.min(state.currentStageIndex + 1, totalStages);

    taskLabel.textContent = sanitizeText(state.windowConfig.label, 'WORKING...').toUpperCase();
    taskStage.textContent = sanitizeText(current?.message, state.windowConfig.label || 'Working...');
    phaseValue.textContent = `PHASE ${String(currentNumber).padStart(2, '0')} / ${String(totalStages).padStart(2, '0')}`;
    statusText.textContent = state.active ? 'STATUS: ACTIVE' : 'STATUS: IDLE';

    const cancelText = state.canCancel
      ? (stripHtml(state.locale.can_cancel) || 'Press Cancel Key to Cancel')
      : 'ACTION LOCKED';

    cancelHint.textContent = cancelText.toUpperCase();
    cancelHint.classList.toggle('is-locked', !state.canCancel);
  }

  function renderProgress() {
    const pct = getProgressPercent();
    progressFill.style.width = `${pct}%`;
    percentValue.textContent = String(pct >= 100 ? 100 : Math.max(0, Math.floor(pct)));
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
    state.stages = [];
    state.currentStageIndex = 0;
    state.totalDuration = 0;
    state.progress = 0;
    state.active = false;
    state.finishing = false;
    state.sessionId = null;
    progressFill.style.width = '0%';
    percentValue.textContent = '0';
    timeValue.textContent = '00:00.0';
    stageNodes.innerHTML = '';
  }

  function hideUi() {
    wrapper.classList.remove('is-visible');
    wrapper.setAttribute('aria-hidden', 'true');
    setTimeout(() => {
      if (!state.active) {
        app.classList.add('nui-hidden');
      }
    }, 190);
  }

  function finish(cancelled) {
    if (state.finishing) return;
    state.finishing = true;
    clearTimers();
    const sequence = state.sequence;

    if (!cancelled) {
      state.progress = 100;
      renderProgress();
      timeValue.textContent = formatRemaining(0);
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
      setTimeout(runStage, 10);
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
    state.windowConfig.theme = sanitizeText(data.theme, 'default');
    state.windowConfig.position = sanitizeText(data.position, 'center-bottom');
    state.canCancel = !!data.canCancel;

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

    wrapper.dataset.theme = state.windowConfig.theme || 'default';
    wrapper.dataset.position = state.windowConfig.position || 'center-bottom';

    app.classList.remove('nui-hidden');
    wrapper.setAttribute('aria-hidden', 'false');
    requestAnimationFrame(() => wrapper.classList.add('is-visible'));

    renderAll();

    state.remainingIntervalId = setInterval(updateRemainingTime, 60);
    runStage();
  }

  function handleMessage(event) {
    const payload = event.data || {};
    const action = payload.action;
    const data = payload.data || {};

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
  postNui('ready', { timestamp: Date.now() });

})();
