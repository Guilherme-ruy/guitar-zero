/* Scroll-driven illustration, not live audio detection. No dependencies or network calls. */
(() => {
  const hero = document.querySelector('.hero');
  if (!hero) return;
  const stage = hero.querySelector('.hero-stage');
  const value = hero.querySelector('.demo-value');
  const status = hero.querySelector('.demo-status');
  const preference = window.matchMedia('(prefers-reduced-motion: reduce)');
  let frame = 0;
  let visible = true;
  let active = false;
  let previousCents = null;
  let travel = 1;
  let start = 0;
  const clamp = (n) => Math.min(1, Math.max(0, n));

  function render() {
    frame = 0;
    if (!active || !visible) return;
    const progress = clamp((window.scrollY - start) / travel);
    const eased = 1 - Math.pow(1 - progress, 3);
    const cents = Math.round(-32 * (1 - eased));
    hero.style.setProperty('--needle', `${-32 * (1 - eased)}%`);
    hero.style.setProperty('--angle', `${-4 + eased * 5}deg`);
    hero.style.setProperty('--lift', `${8 - eased * 14}px`);
    hero.style.setProperty('--glow', String(eased));
    hero.style.setProperty('--hint', String(1 - clamp(progress * 3)));
    const orange = [180, 84, 27];
    const green = [23, 101, 75];
    const color = orange.map((channel, index) => Math.round(channel + (green[index] - channel) * eased));
    hero.style.setProperty('--tuning-color', `rgb(${color.join(',')})`);
    if (cents !== previousCents) {
      value.textContent = String(cents).replace('-', '−');
      status.textContent = cents === 0 ? 'No zero. Pode tocar.' : 'Ajuste a tarraxa.';
      previousCents = cents;
    }
  }

  function schedule() {
    if (!frame && active && visible) frame = window.requestAnimationFrame(render);
  }

  function measure() {
    // Pin only if the whole stage fits. Static content remains available otherwise.
    hero.classList.remove('has-motion');
    hero.removeAttribute('style');
    active = !preference.matches && !navigator.connection?.saveData &&
      stage.getBoundingClientRect().height + 32 < window.innerHeight;
    hero.classList.toggle('has-motion', active);
    if (active) {
      start = hero.getBoundingClientRect().top + window.scrollY - 6;
      travel = Math.max(1, hero.offsetHeight - stage.offsetHeight);
      previousCents = null;
      schedule();
    } else {
      value.textContent = '0';
      status.textContent = 'No zero.';
    }
  }

  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', measure, { passive: true });
  preference.addEventListener('change', measure);
  if ('IntersectionObserver' in window) {
    new IntersectionObserver(([entry]) => {
      visible = entry.isIntersecting;
      if (visible) schedule();
    }).observe(hero);
  }
  measure();
})();
