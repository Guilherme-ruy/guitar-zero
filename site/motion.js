/* GSAP ScrollTrigger + a bounded WebP frame cache. All resources are local. */
(() => {
  const hero = document.querySelector('.hero');
  if (!hero) return;
  const stage = hero.querySelector('.hero-stage');
  const art = hero.querySelector('.hero-sequence');
  const canvas = hero.querySelector('.hero-canvas');
  const context = canvas.getContext('2d');
  const value = hero.querySelector('.demo-value');
  const status = hero.querySelector('.demo-status');
  const hint = hero.querySelector('.scroll-hint');
  const frameCount = 70;
  const state = { frame: 0 };
  let tween = null;
  let cache = null;
  let currentWidth = 0;
  let previousCents = null;
  let resizeTimer;
  let currentPinned = false;

  function createFrameCache(width) {
    const frames = new Map();
    const pending = new Set();
    const failed = new Set();
    const queue = [];
    const abort = new AbortController();
    const limit = width === 480 ? 8 : 12;
    let busy = 0;
    let wanted = 0;
    let drawn = -1;
    let closed = false;

    function draw() {
      if (closed || !frames.has(wanted) || drawn === wanted) return;
      const image = frames.get(wanted);
      frames.delete(wanted);
      frames.set(wanted, image);
      context.clearRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      drawn = wanted;
      canvas.hidden = false;
      art.classList.add('sequence-ready');
      canvas.dataset.frame = String(drawn);
    }

    function evict() {
      while (frames.size > limit) {
        const oldest = [...frames.keys()].find(index => index !== wanted && index !== drawn);
        if (oldest === undefined) break;
        frames.get(oldest).close();
        frames.delete(oldest);
      }
      canvas.dataset.cachedFrames = String(frames.size);
    }

    async function load(index) {
      busy += 1;
      try {
        const number = String(index).padStart(3, '0');
        const response = await fetch(`assets/hero-sequence/${width}/frame-${number}.webp?v=1`, {
          signal: abort.signal, cache: 'force-cache'
        });
        if (!response.ok) throw new Error('Frame unavailable');
        const image = await createImageBitmap(await response.blob());
        if (closed) { image.close(); return; }
        frames.set(index, image);
        evict();
        draw();
      } catch (error) {
        if (!closed && error.name !== 'AbortError') failed.add(index);
      } finally {
        pending.delete(index);
        busy -= 1;
        if (!closed) pump();
      }
    }

    function pump() {
      queue.sort((a, b) => Math.abs(a - wanted) - Math.abs(b - wanted));
      while (busy < 3 && queue.length) {
        const index = queue.shift();
        // Discard queued work far from a newer scroll target.
        if (Math.abs(index - wanted) > 5) { pending.delete(index); continue; }
        load(index);
      }
    }

    return {
      show(index) {
        if (closed) return;
        wanted = Math.max(0, Math.min(frameCount - 1, Math.round(index)));
        const neighbors = [wanted, wanted + 1, wanted - 1, wanted + 2, wanted - 2, wanted + 3];
        neighbors.forEach(frame => {
          if (frame < 0 || frame >= frameCount || frames.has(frame) || pending.has(frame) || failed.has(frame)) return;
          pending.add(frame);
          queue.push(frame);
        });
        pump();
        draw();
      },
      close() {
        closed = true;
        abort.abort();
        frames.forEach(image => image.close());
        frames.clear();
        queue.length = 0;
      }
    };
  }

  function render() {
    const progress = Math.max(0, Math.min(1, state.frame / (frameCount - 1)));
    const cents = Math.round(-32 * (1 - progress));
    hero.style.setProperty('--needle', `${-32 * (1 - progress)}%`);
    hero.style.setProperty('--hint', String(1 - Math.min(1, progress * 4)));
    const orange = [180, 84, 27];
    const green = [23, 101, 75];
    const color = orange.map((channel, index) => Math.round(channel + (green[index] - channel) * progress));
    hero.style.setProperty('--tuning-color', `rgb(${color.join(',')})`);
    if (cents !== previousCents) {
      value.textContent = String(cents).replace('-', '−');
      status.textContent = cents === 0 ? 'No zero. Pode tocar.' : 'Ajuste a tarraxa.';
      previousCents = cents;
    }
    cache?.show(state.frame);
  }

  function stop() {
    tween?.scrollTrigger?.kill();
    tween?.kill();
    tween = null;
    cache?.close();
    cache = null;
    hero.classList.remove('has-motion');
    hero.removeAttribute('style');
    art.classList.remove('sequence-ready');
    canvas.hidden = true;
    delete canvas.dataset.frame;
    delete canvas.dataset.cachedFrames;
    hero.dataset.motion = 'static';
    value.textContent = '0';
    status.textContent = 'No zero.';
  }

  function configure() {
    const supported = context && window.gsap && window.ScrollTrigger && window.createImageBitmap;
    const baseBottom = parseFloat(getComputedStyle(stage).getPropertyValue('--base-bottom')) || 38;
    const alreadyPinned = hero.classList.contains('has-motion');
    const hintSpace = alreadyPinned ? hint.getBoundingClientRect().height + parseFloat(getComputedStyle(hint).marginTop) : 29;
    const extraSpace = hintSpace + 26 - baseBottom;
    const staticHeight = stage.getBoundingClientRect().height - (alreadyPinned ? extraSpace : 0);
    const fits = staticHeight + extraSpace + 12 < window.innerHeight;
    const width = window.matchMedia('(min-width: 600px)').matches ? 864 : 480;
    if (!supported) { stop(); return; }
    if (tween && currentWidth === width && currentPinned === fits) { ScrollTrigger.refresh(); return; }
    stop();
    currentWidth = width;
    currentPinned = fits;
    canvas.width = width;
    canvas.height = Math.round(width * 9 / 16);
    hero.classList.toggle('has-motion', fits);
    hero.dataset.motion = 'scroll';
    cache = createFrameCache(width);
    state.frame = 0;
    previousCents = null;
    gsap.registerPlugin(ScrollTrigger);
    tween = gsap.to(state, {
      frame: frameCount - 1,
      ease: 'none',
      onUpdate: render,
      scrollTrigger: {
        trigger: hero,
        start: 'top 6px',
        end: () => `+=${fits ? Math.max(1, hero.offsetHeight - stage.offsetHeight) : Math.max(1, stage.offsetHeight * 0.6)}`,
        scrub: 0.18,
        invalidateOnRefresh: true
      }
    });
    render();
  }

  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(configure, 150);
  }, { passive: true });
  window.addEventListener('pagehide', stop);
  window.addEventListener('pageshow', configure);
  configure();
})();
