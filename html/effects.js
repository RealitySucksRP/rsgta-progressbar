/* Pointer-reactive depth. One pending frame at most; no idle animation loop. */
(() => {
  const editor = document.getElementById('styleEditor');
  const reduce = matchMedia('(prefers-reduced-motion: reduce)');
  const targets = editor.querySelectorAll('.style-frame-choice, .style-preview');
  let active = null, point = null, pending = null;
  function reset() {
    if (pending !== null) cancelAnimationFrame(pending);
    pending = null; point = null;
    if (active) {
      active.classList.remove('fx-hover');
      for (const name of ['--rx','--ry','--mx','--my','--px','--py']) active.style.removeProperty(name);
    }
    active = null;
  }
  function draw() {
    pending = null;
    if (!active || !point || editor.hidden || active.hidden || document.hidden || reduce.matches || editor.dataset.effects !== 'full') { reset(); return; }
    const rect = active.getBoundingClientRect();
    const x = Math.max(0, Math.min(1, (point.x - rect.left) / Math.max(rect.width, 1)));
    const y = Math.max(0, Math.min(1, (point.y - rect.top) / Math.max(rect.height, 1)));
    active.style.setProperty('--rx', `${(0.5-y)*6}deg`);
    active.style.setProperty('--ry', `${(x-0.5)*8}deg`);
    active.style.setProperty('--mx', `${x*100}%`);
    active.style.setProperty('--my', `${y*100}%`);
    active.style.setProperty('--px', `${(x-0.5)*8}px`);
    active.style.setProperty('--py', `${(y-0.5)*8}px`);
    active.classList.add('fx-hover');
  }
  for (const target of targets) {
    target.addEventListener('pointermove', event => {
      if (event.pointerType !== 'mouse' || reduce.matches || editor.hidden || editor.dataset.effects !== 'full') return;
      if (active !== target) { reset(); active = target; }
      point = {x:event.clientX,y:event.clientY};
      if (pending === null) pending = requestAnimationFrame(draw);
    }, {passive:true});
    target.addEventListener('pointerleave', () => { if (active === target) reset(); });
  }
  new MutationObserver(() => { if (editor.hidden || editor.dataset.effects !== 'full') reset(); }).observe(editor, {attributes:true,attributeFilter:['hidden','data-effects']});
  editor.querySelector('.frame-categories').addEventListener('click', reset);
  document.addEventListener('visibilitychange', reset);
  window.addEventListener('blur', reset);
  reduce.addEventListener('change', reset);
})();
