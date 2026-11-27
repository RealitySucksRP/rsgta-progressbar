/* Cosmetic-only client UI: never modifies task duration, callbacks or items. */
(() => {
  const editor = document.getElementById('styleEditor');
  const preview = document.getElementById('stylePreview');
  const title = document.getElementById('previewFrameTitle');
  const seek = document.getElementById('previewSeek');
  const playButton = document.getElementById('previewPlay');
  const gauge = document.getElementById('previewGauge');
  const progressLabel = document.getElementById('previewProgressLabel');
  const remainingLabel = document.getElementById('previewRemaining');
  const dockPercent = document.getElementById('previewDockPercent');
  const dockTime = document.getElementById('previewDockTime');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const duration = 6000;
  const names = { streetglass:'STREET GLASS', neonrunner:'NEON RUNNER', carbonracer:'CARBON RACER', tactical:'TACTICAL GRID', arcade:'ARCADE CHROME',pipboi420:'PIP-BOI 420',trackstrike:'TRACK STRIKE',nightshift:'NIGHT SHIFT',streetcrew:'STREET CREW',violetsyndicate:'VIOLET SYNDICATE' };
  const validThemes = new Set(['default', 'theme-0', 'theme-1', 'theme-2', 'theme-3', 'theme-4', 'theme-5', 'theme-6']);
  const validBars = new Set(['auto', 'segmented', 'pulse', 'race', 'dots', 'liquid']);
  const auto = {streetglass:'segmented',neonrunner:'pulse',carbonracer:'race',tactical:'dots',arcade:'liquid',pipboi420:'segmented',trackstrike:'race',nightshift:'race',streetcrew:'segmented',violetsyndicate:'pulse'};
  const validEffects = new Set(['full', 'low', 'off']);
  const defaults = { frame: 'streetglass', theme: 'theme-2', bar: 'auto', effects: 'full' };
  let selection = { ...defaults };
  let opened = false;
  let category = 'all';
  function setCategory(value) {
    category = value;
    document.querySelectorAll('[data-frame-category]').forEach(b => {
      const active = b.dataset.frameCategory === value;
      b.classList.toggle('is-selected', active); b.setAttribute('aria-pressed', String(active));
    });
    document.querySelectorAll('[data-style-frame]').forEach(b => { b.hidden = value !== 'all' && b.dataset.frameGroup !== value; });
    document.getElementById('styleFrames').scrollTop = 0;
  }
  let elapsed = 0;
  let playbackFrame = null;
  let lastTime = null;
  let lastPercent = -1;
  let lastRemaining = '';

  function showProgress() {
    const progress = elapsed / duration * 100;
    const percent = Math.floor(progress);
    preview.dataset.result = percent >= 100 ? 'complete' : 'active';
    const remaining = ((duration - elapsed) / 1000).toFixed(1);
    preview.style.setProperty('--preview-progress', `${progress}%`);
    gauge.style.setProperty('--preview-progress', `${progress}%`);
    if (percent !== lastPercent) {
      lastPercent = percent;
      seek.value = String(percent);
      gauge.textContent = dockPercent.textContent = `${percent}%`;
      progressLabel.textContent = `${percent}% COMPLETE`;
    }
    if (remaining !== lastRemaining) {
      lastRemaining = remaining;
      remainingLabel.textContent = remaining === '0.0' ? 'DONE' : `${remaining}S LEFT`;
      dockTime.textContent = `00:${remaining.padStart(4, '0')}`;
    }
  }

  function pausePreview() {
    if (playbackFrame !== null) cancelAnimationFrame(playbackFrame);
    playbackFrame = null;
    lastTime = null;
    preview.dataset.playing = 'false';
    playButton.textContent = 'Play';
  }

  function tickPreview(now) {
    if (lastTime !== null) elapsed = Math.min(duration, elapsed + now - lastTime);
    lastTime = now;
    showProgress();
    if (elapsed < duration) {
      playbackFrame = requestAnimationFrame(tickPreview);
    } else {
      pausePreview();
    }
  }

  function playPreview() {
    if (!opened || playbackFrame !== null) return;
    if (elapsed >= duration) elapsed = 0;
    showProgress();
    preview.dataset.playing = 'true';
    playButton.textContent = 'Pause';
    playbackFrame = requestAnimationFrame(tickPreview);
  }

  function post(action, data) {
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'progressbar';
    fetch(`https://${resource}/${action}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data || {}) }).catch(() => {});
  }
  function update() {
    const frame = names[selection.frame] ? selection.frame : defaults.frame;
    const bar = selection.bar === 'auto' ? auto[frame] : selection.bar;
    preview.dataset.frame = frame;
    preview.dataset.theme = selection.theme;
    preview.dataset.bar = bar;
    preview.dataset.effects = editor.dataset.effects = selection.effects;
    document.getElementById('fxDescription').textContent = { full: 'Reactive depth, lighting and particles.', low: 'Static lighting and minimal motion.', off: 'Clean display with decorative motion disabled.' }[selection.effects];
    document.querySelectorAll('[data-style-effects]').forEach(button => {
      const selected = button.dataset.styleEffects === selection.effects;
      button.classList.toggle('is-selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    title.textContent = names[frame];
    document.querySelectorAll('[data-style-frame]').forEach(button => {
      const selected = button.dataset.styleFrame === frame;
      button.classList.toggle('is-selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    document.querySelectorAll('[data-style-theme]').forEach(button => {
      const selected = button.dataset.styleTheme === selection.theme;
      button.classList.toggle('is-selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    document.querySelectorAll('[data-style-bar]').forEach(button => {
      const selected = button.dataset.styleBar === selection.bar;
      button.classList.toggle('is-selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
  }
  function close() {
    pausePreview();
    opened = false;
    editor.hidden = true;
    document.body.classList.remove('style-open');
  }
  function open(data) {
    const saved = data && data.style || {};
    selection = {
      frame: names[saved.frame] ? saved.frame : defaults.frame,
      theme: validThemes.has(saved.theme) ? saved.theme : defaults.theme,
      bar: validBars.has(saved.bar) ? saved.bar : defaults.bar,
      effects: validEffects.has(saved.effects) ? saved.effects : defaults.effects
    };
    opened = true;
    editor.hidden = false;
    document.body.classList.add('style-open');
    setCategory(document.querySelector(`[data-style-frame="${selection.frame}"]`).dataset.frameGroup);
    update();
    pausePreview();
    elapsed = 0;
    showProgress();
    if (!reducedMotion.matches) playPreview();
    document.getElementById('styleEditorClose').focus();
  }
  window.addEventListener('message', event => {
    const payload = event.data || {};
    if (payload.action === 'EDITOR_OPEN') open(payload.data);
    if (payload.action === 'EDITOR_CLOSE') close();
  });
  document.querySelectorAll('[data-frame-category]').forEach(button => button.addEventListener('click', () => setCategory(button.dataset.frameCategory)));
  document.querySelectorAll('[data-style-frame]').forEach(button => button.addEventListener('click', () => { selection.frame = button.dataset.styleFrame; update(); }));
  document.querySelectorAll('[data-style-theme]').forEach(button => button.addEventListener('click', () => { selection.theme = button.dataset.styleTheme; update(); }));
  document.querySelectorAll('[data-style-bar]').forEach(button => button.addEventListener('click', () => { selection.bar = button.dataset.styleBar; update(); }));
  document.querySelectorAll('[data-style-effects]').forEach(button => button.addEventListener('click', () => { selection.effects = button.dataset.styleEffects; update(); }));
  document.addEventListener('visibilitychange', () => { if (document.hidden) pausePreview(); });
  document.getElementById('styleEditorSave').addEventListener('click', () => { if (opened) post('styleSave', selection); });
  document.getElementById('styleEditorReset').addEventListener('click', () => { selection = { ...defaults }; setCategory('original'); update(); });
  document.getElementById('styleEditorClose').addEventListener('click', () => { if (opened) post('styleClose'); });
  playButton.addEventListener('click', () => {
    if (playbackFrame === null) playPreview();
    else pausePreview();
  });
  document.getElementById('previewReplay').addEventListener('click', () => {
    pausePreview();
    elapsed = 0;
    playPreview();
  });
  seek.addEventListener('pointerdown', pausePreview);
  seek.addEventListener('input', () => {
    pausePreview();
    elapsed = Number(seek.value) * duration / 100;
    showProgress();
  });
  document.addEventListener('keydown', event => { if (opened && event.key === 'Escape') { event.preventDefault(); post('styleClose'); } });
  setCategory(category);
  update();
})();
