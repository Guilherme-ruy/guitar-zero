/* Visual preview only: no audio capture or microphone access. */
(() => {
  const demo = document.querySelector('.mode-demo');
  if (!demo) return;

  function createModePreview(root) {
    const modes = [...root.querySelectorAll('button[data-tuning-mode]')];
    const choices = [...root.querySelectorAll('button[data-string]')];
    const description = root.querySelector('[data-mode-description]');
    const note = root.querySelector('[data-mode-note]');
    const stringLabel = root.querySelector('[data-mode-string]');
    const needle = root.querySelector('[data-mode-needle]');
    const result = root.querySelector('[data-mode-result]');
    const frame = root.querySelector('.headstock-frame');
    const image = root.querySelector('[data-headstock-image]');
    const lines = root.querySelector('[data-headstock-lines]');
    const instrumentLabel = root.querySelector('[data-preview-instrument]');
    const section = root.closest?.('.how-section');
    const instruments = [...section?.querySelectorAll('button[data-instrument-choice]') || []];
    if (!modes.length || !choices.length || !note || !stringLabel || !needle || !result) return null;

    const strings = [
      { number: '6', note: 'E', pitch: 'Mi grave, E2' },
      { number: '5', note: 'A', pitch: 'Lá, A2' },
      { number: '4', note: 'D', pitch: 'Ré, D3' },
      { number: '3', note: 'G', pitch: 'Sol, G3' },
      { number: '2', note: 'B', pitch: 'Si, B3' },
      { number: '1', note: 'E', pitch: 'Mi agudo, E4' }
    ];
    // Exact normalized geometry from HeadstockLayout in the Flutter app.
    const layouts = {
      acoustic: {
        asset: 'assets/acoustic-576.webp', label: 'Violão · Padrão', regularMinHeight: 320,
        keys: [[.188057, .519258], [.18984, .342368], [.192513, .166904], [.809269, .166904], [.802139, .342368], [.807487, .519258]],
        buttons: [[.04, .519258], [.04, .342368], [.04, .166904], [.96, .166904], [.96, .342368], [.96, .519258]],
        compactButtons: [[.04, .519258], [.04, .342368], [.04, .166904], [.96, .166904], [.96, .342368], [.96, .519258]]
      },
      electric: {
        asset: 'assets/electric-576.webp', label: 'Guitarra · Padrão', regularMinHeight: 500,
        keys: [[.257576, .612696], [.296791, .510699], [.336898, .410128], [.37344, .308845], [.414439, .2097], [.456328, .107703]],
        buttons: [[.087576, .612696], [.126791, .510699], [.166898, .410128], [.20344, .308845], [.244439, .2097], [.286328, .107703]],
        compactButtons: [[.075, .8], [.075, .66], [.075, .52], [.075, .38], [.075, .24], [.075, .1]]
      }
    };
    let instrument = root.dataset.instrument === 'electric' ? 'electric' : 'acoustic';
    const selected = choices.find(button => button.getAttribute('aria-pressed') === 'true');
    let index = Math.max(0, strings.findIndex(string => string.number === (selected?.dataset.string || '5')));
    let mode = root.dataset.mode === 'manual' ? 'manual' : 'auto';
    let timer = null;
    let needleAnimation = null;
    let visible = false;
    let hovering = false;
    let suspended = false;
    let closed = false;
    const cleanup = [];
    const media = window.matchMedia?.('(prefers-reduced-motion: reduce)');
    let observer;
    let geometryObserver;

    function listen(target, type, handler) {
      target.addEventListener(type, handler);
      cleanup.push(() => target.removeEventListener(type, handler));
    }

    function cancelTimer() {
      if (timer !== null) clearTimeout(timer);
      timer = null;
    }

    function cancelNeedle() {
      needleAnimation?.cancel();
      needleAnimation = null;
      root.dataset.state = 'ready';
      result.textContent = 'Afinada';
    }

    function animateNeedle() {
      cancelNeedle();
      if (!visible || suspended || document.hidden || media?.matches || typeof needle.animate !== 'function') return;
      const resting = window.getComputedStyle?.(needle).transform || 'none';
      const offset = index % 2 ? -40 : 40;
      try {
        const animation = needle.animate([
          { transform: `${resting === 'none' ? '' : resting} translateX(${offset}px)`, opacity: .45 },
          { transform: resting, opacity: 1 }
        ], { duration: 1100, easing: 'cubic-bezier(.22,.61,.36,1)' });
        needleAnimation = animation;
        root.dataset.state = 'tuning';
        result.textContent = 'Afinando';
        animation.onfinish = () => {
          if (needleAnimation !== animation) return;
          needleAnimation = null;
          root.dataset.state = 'ready';
          result.textContent = 'Afinada';
        };
      } catch { needleAnimation = null; }
    }

    function render(animate = false) {
      const string = strings[index];
      root.dataset.mode = mode;
      modes.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.tuningMode === mode)));
      choices.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.string === string.number)));
      if (description) description.textContent = mode === 'auto' ? 'Toque. O app identifica a corda.' : 'Escolha a corda. Depois, toque.';
      note.textContent = string.note;
      note.setAttribute('aria-label', string.pitch);
      stringLabel.textContent = `${string.number}ª corda`;
      result.textContent = 'Afinada';
      if (animate) animateNeedle();
      else cancelNeedle();
    }

    function updateGeometry() {
      if (closed || !frame) return;
      const { width, height } = frame.getBoundingClientRect();
      if (width <= 0 || height <= 0) return;
      const layout = layouts[instrument];
      const buttons = height >= layout.regularMinHeight ? layout.buttons : layout.compactButtons;
      let spacing = Infinity;
      buttons.forEach((point, i) => buttons.slice(i + 1).forEach(other => {
        spacing = Math.min(spacing, Math.hypot((point[0] - other[0]) * width, (point[1] - other[1]) * height));
      }));
      const size = Math.max(30, Math.min(48, spacing - 4));
      frame.style.setProperty('--string-size', `${size}px`);
      frame.style.setProperty('--string-hit', `${Math.max(size, Math.min(44, spacing))}px`);
      choices.forEach(button => {
        const position = buttons[strings.findIndex(string => string.number === button.dataset.string)];
        if (!position) return;
        button.style.left = `${position[0] * 100}%`;
        button.style.top = `${position[1] * 100}%`;
      });
      if (!lines) return;
      const connectors = [];
      buttons.forEach((point, i) => {
        const from = [point[0] * width, point[1] * height];
        const to = [layout.keys[i][0] * width, layout.keys[i][1] * height];
        const dx = to[0] - from[0];
        const dy = to[1] - from[1];
        const length = Math.hypot(dx, dy);
        const radius = size / 2;
        const keyRadius = width * .035;
        if (length <= radius + keyRadius) return;
        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', String((from[0] + dx / length * radius) / width * 100));
        line.setAttribute('y1', String((from[1] + dy / length * radius) / height * 100));
        line.setAttribute('x2', String((to[0] - dx / length * keyRadius) / width * 100));
        line.setAttribute('y2', String((to[1] - dy / length * keyRadius) / height * 100));
        line.setAttribute('vector-effect', 'non-scaling-stroke');
        line.setAttribute('stroke-linecap', 'round');
        connectors.push(line);
      });
      lines.replaceChildren(...connectors);
    }

    function selectInstrument(selection) {
      if (!layouts[selection]) return;
      instrument = selection;
      const layout = layouts[instrument];
      root.dataset.instrument = instrument;
      instruments.forEach(button => button.setAttribute('aria-pressed', String(button.dataset.instrumentChoice === instrument)));
      if (image && image.getAttribute('src') !== layout.asset) image.setAttribute('src', layout.asset);
      if (instrumentLabel) instrumentLabel.textContent = layout.label;
      updateGeometry();
    }

    function canCycle() {
      return !closed && !suspended && mode === 'auto' && visible && !document.hidden && !media?.matches && !hovering && !root.contains(document.activeElement);
    }

    function schedule() {
      cancelTimer();
      if (!canCycle()) return;
      timer = setTimeout(() => {
        timer = null;
        if (!canCycle()) return;
        index = (index + 1) % strings.length;
        render(true);
        schedule();
      }, 4800);
    }

    modes.forEach(button => listen(button, 'click', () => {
      if (button.disabled || !['auto', 'manual'].includes(button.dataset.tuningMode)) return;
      mode = button.dataset.tuningMode;
      render();
      schedule();
    }));
    choices.forEach(button => listen(button, 'click', () => {
      if (button.disabled) return;
      const selection = strings.findIndex(string => string.number === button.dataset.string);
      if (selection < 0) return;
      index = selection;
      mode = 'manual';
      render(true);
      schedule();
    }));
    instruments.forEach(button => listen(button, 'click', () => {
      if (!button.disabled) selectInstrument(button.dataset.instrumentChoice);
    }));
    if (frame && window.ResizeObserver) {
      geometryObserver = new ResizeObserver(updateGeometry);
      geometryObserver.observe(frame);
    } else if (frame) listen(window, 'resize', updateGeometry);
    if (image) listen(image, 'load', updateGeometry);
    listen(root, 'focusin', schedule);
    listen(root, 'focusout', () => { Promise.resolve().then(schedule); });
    listen(root, 'pointerenter', event => { if (event.pointerType === 'mouse') { hovering = true; schedule(); } });
    listen(root, 'pointerleave', event => { if (event.pointerType === 'mouse') { hovering = false; schedule(); } });
    listen(document, 'visibilitychange', () => {
      if (document.hidden) cancelNeedle();
      schedule();
    });
    listen(window, 'pagehide', () => { suspended = true; cancelTimer(); cancelNeedle(); });
    listen(window, 'pageshow', () => { suspended = false; schedule(); });
    const motionChanged = () => { cancelNeedle(); schedule(); };
    if (media?.addEventListener) listen(media, 'change', motionChanged);
    else if (media?.addListener) {
      media.addListener(motionChanged);
      cleanup.push(() => media.removeListener(motionChanged));
    }
    if (window.IntersectionObserver) {
      observer = new IntersectionObserver(entries => {
        visible = entries[0].isIntersecting;
        if (!visible) cancelNeedle();
        schedule();
      }, { threshold: .2 });
      observer.observe(root);
    }
    selectInstrument(instrument);
    render();
    return {
      close() {
        closed = true;
        cancelTimer();
        cancelNeedle();
        observer?.disconnect();
        geometryObserver?.disconnect();
        cleanup.forEach(remove => remove());
      }
    };
  }

  createModePreview(demo);
})();
