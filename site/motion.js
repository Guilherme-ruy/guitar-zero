/* GSAP ScrollTrigger + a bounded WebP frame cache. All resources are local. */
(() => {
  const hero = document.querySelector('.hero');
  if (!hero) return;
  const art = hero.querySelector('.hero-sequence');
  const canvas = hero.querySelector('.hero-canvas');
  const poster = hero.querySelector('.hero-poster');
  const context = canvas.getContext('2d');
  const frameCount = 70;
  const state = { frame: 0 };
  let tween = null;
  let meterMotion = null;
  let cache = null;
  let currentWidth = 0;
  let currentLimit = 0;
  let resizeTimer;

  function createFrameCache(width, limit) {
    const frames = new Map();
    const pending = new Set();
    const failed = new Set();
    const queue = [];
    const abort = new AbortController();
    const concurrency = width === 1920 ? 2 : 3;
    let busy = 0;
    let wanted = 0;
    let direction = 1;
    let drawn = -1;
    let draws = 0;
    let closed = false;
    const files = new Map();
    const requests = new Map();
    const networkQueue = [];
    const unavailable = new Set();
    let fetching = 0;
    let warming = false;

    function fetchFile(index) {
      if (closed || unavailable.has(index)) return Promise.reject(new Error('Frame unavailable'));
      if (files.has(index)) return Promise.resolve(files.get(index));
      if (requests.has(index)) return requests.get(index).promise;
      const job = { index };
      job.promise = new Promise((resolve, reject) => { job.resolve = resolve; job.reject = reject; });
      requests.set(index, job);
      networkQueue.push(job);
      pumpNetwork();
      return job.promise;
    }

    function pumpNetwork() {
      if (closed) return;
      networkQueue.sort((a, b) => Math.abs(a.index - wanted) - Math.abs(b.index - wanted));
      while (fetching < 3 && networkQueue.length) {
        const job = networkQueue.shift();
        fetching += 1;
        const number = String(job.index).padStart(3, '0');
        fetch(`assets/hero-sequence/${width}/frame-${number}.webp?v=4`, {
          signal: abort.signal, cache: 'force-cache'
        }).then(response => {
          if (!response.ok) throw new Error('Frame unavailable');
          return response.blob();
        }).then(blob => {
          if (closed) throw new Error('Frame cache closed');
          files.set(job.index, blob);
          canvas.dataset.loadedFrames = String(files.size);
          job.resolve(blob);
          pump();
        }).catch(error => {
          if (!closed) unavailable.add(job.index);
          job.reject(error);
        }).finally(() => {
          requests.delete(job.index);
          fetching -= 1;
          pumpNetwork();
        });
      }
    }

    function warmFiles() {
      if (warming || closed) return;
      warming = true;
      // Keep compressed files, not 70 decoded bitmaps. First pose has priority.
      const order = Array.from({ length: frameCount }, (_, index) => index);
      order.sort((a, b) => Math.abs(a - wanted) - Math.abs(b - wanted));
      order.forEach(index => fetchFile(index).catch(() => {}));
    }

    function draw() {
      if (closed || !frames.size) return;
      if (drawn < 0 && !frames.has(wanted)) return;
      let nearest = frames.has(drawn) ? drawn : frames.keys().next().value;
      for (const index of frames.keys()) {
        if (Math.abs(index - wanted) < Math.abs(nearest - wanted)) nearest = index;
      }
      if (drawn === nearest) return;
      const image = frames.get(nearest);
      frames.delete(nearest);
      frames.set(nearest, image);
      context.clearRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      drawn = nearest;
      canvas.hidden = false;
      art.classList.add('sequence-ready');
      hero.classList.add('scene-ready');
      canvas.dataset.frame = String(drawn);
      canvas.dataset.drawCount = String(++draws);
      warmFiles();
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
        const image = await createImageBitmap(files.get(index));
        if (closed) { image.close(); return; }
        frames.set(index, image);
        draw();
        evict();
      } catch (error) {
        if (!closed && error.name !== 'AbortError') failed.add(index);
      } finally {
        pending.delete(index);
        busy -= 1;
        if (!closed) pump();
      }
    }

    function pump() {
      if (closed) return;
      for (let i = queue.length - 1; i >= 0; i -= 1) {
        if (Math.abs(queue[i] - wanted) > 5) pending.delete(queue.splice(i, 1)[0]);
      }
      queue.sort((a, b) => Math.abs(a - wanted) - Math.abs(b - wanted));
      while (busy < concurrency && queue.length) {
        const ready = queue.findIndex(index => files.has(index));
        if (ready < 0) break;
        const index = queue.splice(ready, 1)[0];
        load(index);
      }
    }

    return {
      show(index) {
        if (closed) return;
        const target = Math.max(0, Math.min(frameCount - 1, Math.round(index)));
        if (target !== wanted) direction = target > wanted ? 1 : -1;
        wanted = target;
        canvas.dataset.targetFrame = String(wanted);
        const neighbors = [wanted, wanted + direction, wanted - direction, wanted + 2 * direction, wanted - 2 * direction, wanted + 3 * direction].slice(0, Math.min(6, limit - 1));
        neighbors.forEach(frame => {
          if (frame < 0 || frame >= frameCount || frames.has(frame) || pending.has(frame) || failed.has(frame)) return;
          pending.add(frame);
          queue.push(frame);
          fetchFile(frame).catch(() => {
            if (!closed) failed.add(frame);
            pending.delete(frame);
            const queued = queue.indexOf(frame);
            if (queued >= 0) queue.splice(queued, 1);
          });
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
        requests.forEach(job => job.reject(new Error('Frame cache closed')));
        requests.clear();
        networkQueue.length = 0;
        files.clear();
      }
    };
  }

  function render() {
    cache?.show(state.frame);
  }

  function createTuningBackdrop() {
    const meter = hero.querySelector('.tuning-demo');
    const value = meter.querySelector('.demo-value');
    const currentNumber = value.querySelector('.demo-current');
    const nextNumber = value.querySelector('.demo-next');
    const scene = hero.querySelector('.hero-scene');
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
    const tuning = { progress: 0, exit: 0 };
    let visible = true;
    let closed = false;
    let animation = 0;
    let lastPaint = null;
    let displayed = null;
    let meterOpacity = 1;
    let activeTime = 0;
    let zeroSince = null;
    let previousCurrent;
    let previousNext;
    const smooth = n => {
      n = Math.max(0, Math.min(1, n));
      return n * n * (3 - 2 * n);
    };
    const label = number => number < 0 ? `−${Math.abs(number)}` : '0';

    function wake() {
      if (!closed && !animation && visible && !document.hidden) animation = requestAnimationFrame(paint);
    }

    function pause() {
      cancelAnimationFrame(animation);
      animation = 0;
      lastPaint = null;
    }

    function visibilityChanged() {
      pause();
      wake();
    }

    function paint(time) {
      animation = 0;
      if (closed || !visible || document.hidden) return;
      const elapsed = lastPaint === null ? 1 / 60 : Math.min(.05, Math.max(0, (time - lastPaint) / 1000));
      lastPaint = time;
      activeTime += elapsed * 1000;
      const progress = tuning.progress;
      const complete = progress >= 1;
      const amplitude = 1 - smooth(progress);
      const phase = time / 1000;
      const drift = reduced.matches ? 0 : Math.sin(phase * .48) * 1.25 + Math.sin(phase * .29) * .45;
      const target = complete ? 0 : -Math.max(1, 24 * (1 - progress) + drift * amplitude);

      if (displayed === null || reduced.matches) displayed = target;
      else {
        // One shared value drives both the glyphs and the needle. Limit speed
        // as well as damping so a fast reversal cannot skip entire numbers.
        const change = (target - displayed) * (1 - Math.exp(-elapsed / .16));
        displayed += Math.max(-20 * elapsed, Math.min(20 * elapsed, change));
      }
      if (complete && Math.abs(displayed) < .015) displayed = 0;

      // Keep zero out of both visible layers until the scroll has completed
      // and the shared value is already close to the center.
      const nearZero = complete && displayed > -.35;
      const numberPosition = nearZero ? Math.max(-1, displayed / .35) : Math.min(-1, displayed);
      const from = reduced.matches ? Math.min(0, complete ? 0 : Math.round(numberPosition)) : Math.floor(numberPosition);
      const to = Math.min(0, from + 1);
      const blend = reduced.matches ? 0 : smooth(numberPosition - from);
      if (from !== previousCurrent) { currentNumber.textContent = label(from); previousCurrent = from; }
      if (to !== previousNext) { nextNumber.textContent = label(to); previousNext = to; }
      currentNumber.style.opacity = String(1 - blend);
      nextNumber.style.opacity = String(blend);
      currentNumber.style.transform = `translateY(${reduced.matches ? 0 : -blend * 4}px)`;
      nextNumber.style.transform = `translateY(${reduced.matches ? 0 : (1 - blend) * 4}px)`;

      const exitOpacity = 1 - smooth(tuning.exit);
      // The exit trigger can finish before the scrubbed tuning value does.
      // Keep zero visible before fading, including after a quick scroll jump.
      const finishing = complete || motion.scrollTrigger.progress >= 1;
      const settled = complete && displayed === 0;
      if (!settled) zeroSince = null;
      else if (reduced.matches) zeroSince = activeTime - 180;
      else if (zeroSince === null) zeroSince = activeTime;
      const holdingZero = settled && activeTime - zeroSince < 180;
      const opacityTarget = !reduced.matches && finishing && (!settled || holdingZero) ? 1 : exitOpacity;
      if (reduced.matches) meterOpacity = opacityTarget;
      else {
        // About 180ms to cover 95% of a fade; reversals remain continuous.
        meterOpacity += (opacityTarget - meterOpacity) * (1 - Math.exp(-elapsed / .06));
        if (Math.abs(opacityTarget - meterOpacity) < .003) meterOpacity = opacityTarget;
      }
      meter.style.setProperty('--needle', `${50 + displayed * 1.2}%`);
      meter.style.setProperty('--meter-opacity', String(meterOpacity));
      meter.style.setProperty('--meter-x', reduced.matches ? '0px' : `${Math.sin(phase * .28) * 3 * amplitude}px`);
      meter.style.setProperty('--meter-y', `${progress * 32 + (reduced.matches ? 0 : Math.sin(phase * .35) * 4 * amplitude)}px`);
      const finishingZero = finishing && (!settled || holdingZero);
      const fading = meterOpacity !== opacityTarget;
      if (!reduced.matches && (finishingZero || fading || (!complete && tuning.exit < 1))) wake();
      else lastPaint = null;
    }

    const zeroAt = () => Math.max(220, Math.min(
      hero.offsetTop + hero.offsetHeight - window.innerHeight * 0.48,
      scene.getBoundingClientRect().top + window.scrollY + 40
    ));
    const motion = gsap.to(tuning, {
      progress: 1,
      ease: 'none',
      onUpdate: wake,
      scrollTrigger: {
        trigger: hero,
        start: 0,
        end: zeroAt,
        scrub: 0.6,
        invalidateOnRefresh: true
      }
    });
    const exit = gsap.to(tuning, {
      exit: 1,
      ease: 'none',
      onUpdate: wake,
      scrollTrigger: {
        trigger: hero,
        start: () => zeroAt() + 36,
        end: () => zeroAt() + 110,
        scrub: 0.4,
        invalidateOnRefresh: true
      }
    });
    const observer = new IntersectionObserver(entries => {
      visible = entries[0].isIntersecting;
      pause();
      if (visible) wake();
    });
    observer.observe(hero);
    document.addEventListener('visibilitychange', visibilityChanged);
    reduced.addEventListener('change', visibilityChanged);
    wake();
    return {
      close() {
        closed = true;
        motion.scrollTrigger.kill();
        motion.kill();
        exit.scrollTrigger.kill();
        exit.kill();
        observer.disconnect();
        pause();
        document.removeEventListener('visibilitychange', visibilityChanged);
        reduced.removeEventListener('change', visibilityChanged);
      }
    };
  }

  function stop() {
    tween?.scrollTrigger?.kill();
    tween?.kill();
    tween = null;
    meterMotion?.close();
    meterMotion = null;
    cache?.close();
    cache = null;
    art.classList.remove('sequence-ready');
    hero.classList.remove('scene-ready');
    canvas.hidden = true;
    delete canvas.dataset.frame;
    delete canvas.dataset.cachedFrames;
    delete canvas.dataset.loadedFrames;
    delete canvas.dataset.drawCount;
    delete canvas.dataset.targetFrame;
    hero.dataset.motion = 'static';
  }

  function configure() {
    const supported = context && window.gsap && window.ScrollTrigger && window.createImageBitmap && window.IntersectionObserver;
    const mobile = window.matchMedia('(max-width: 599px)').matches;
    const targetWidth = poster.getBoundingClientRect().width * Math.min(window.devicePixelRatio || 1, 2);
    const width = [960, 1440, 1920].find(size => size >= targetWidth) || 1920;
    // Compressed files and the canvas are separate from the decoded bitmap budget.
    const limit = Math.min(mobile ? 8 : 12, Math.floor(32 * 1024 * 1024 / (width * width * 9 / 16 * 4)));
    if (!supported) { stop(); return; }
    if (tween && currentWidth === width && currentLimit === limit) {
      ScrollTrigger.refresh();
      tween.progress(tween.scrollTrigger.progress);
      render();
      return;
    }
    stop();
    currentWidth = width;
    currentLimit = limit;
    canvas.width = width;
    canvas.height = Math.round(width * 9 / 16);
    hero.dataset.motion = 'scroll';
    try { cache = createFrameCache(width, limit); }
    catch { stop(); return; }
    state.frame = 0;
    gsap.registerPlugin(ScrollTrigger);
    meterMotion = createTuningBackdrop();
    tween = gsap.to(state, {
      frame: frameCount - 1,
      ease: 'none',
      onUpdate: render,
      scrollTrigger: {
        trigger: hero,
        start: () => Math.max(0, hero.offsetTop - 120),
        end: () => `+=${Math.max(200, Math.min(340, window.innerHeight * 0.32))}`,
        scrub: 0.5,
        invalidateOnRefresh: true
      }
    });
    tween.progress(tween.scrollTrigger.progress);
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
