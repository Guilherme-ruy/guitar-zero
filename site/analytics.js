/* GA4 is loaded only after consent, on the public HTTPS domain. */
(() => {
  'use strict';

  const measurementId = 'G-JND41JTZB8';
  const storageKey = 'guitarzero.analytics-consent.v1';
  const consentLifetime = 180 * 24 * 60 * 60 * 1000;
  const disableKey = `ga-disable-${measurementId}`;
  const publicSite = window.location.protocol === 'https:' &&
    ['guitarzero.com.br', 'www.guitarzero.com.br'].includes(window.location.hostname);
  let tagStarted = false;
  let returnFocus = null;

  window[disableKey] = true;

  function readChoice() {
    try {
      const saved = JSON.parse(window.localStorage.getItem(storageKey));
      const age = Date.now() - saved?.updatedAt;
      if (['granted', 'denied'].includes(saved?.status) &&
          Number.isFinite(saved.updatedAt) && age >= 0 && age < consentLifetime) {
        return saved.status;
      }
    } catch { /* Storage can be unavailable; ask again without loading GA. */ }
    return null;
  }

  function clearAnalyticsCookies() {
    const domains = ['', window.location.hostname, '.guitarzero.com.br'];
    for (const cookie of document.cookie.split(';')) {
      const name = cookie.trim().split('=')[0];
      if (!/^_ga(?:_|$)/.test(name)) continue;
      for (const domain of domains) {
        document.cookie = `${name}=; Max-Age=0; Path=/; SameSite=Lax; Secure${domain ? `; Domain=${domain}` : ''}`;
      }
    }
  }

  function startAnalytics() {
    if (!publicSite || tagStarted) return;
    tagStarted = true;
    window[disableKey] = false;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };

    const denied = {
      analytics_storage: 'denied', ad_storage: 'denied',
      ad_user_data: 'denied', ad_personalization: 'denied',
    };
    window.gtag('consent', 'default', denied);
    window.gtag('consent', 'update', { ...denied, analytics_storage: 'granted' });
    window.gtag('js', new Date());
    window.gtag('set', 'ads_data_redaction', true);
    let referrer = '';
    try { referrer = new URL(document.referrer).origin; } catch { /* Direct visit. */ }
    window.gtag('config', measurementId, {
      allow_google_signals: false,
      allow_ad_personalization_signals: false,
      cookie_expires: consentLifetime / 1000,
      cookie_update: false,
      cookie_flags: 'SameSite=Lax;Secure',
      page_location: window.location.origin + window.location.pathname,
      page_referrer: referrer,
    });

    const script = document.createElement('script');
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${measurementId}`;
    document.head.append(script);
  }

  const banner = document.createElement('section');
  banner.className = 'analytics-banner';
  banner.setAttribute('aria-labelledby', 'analytics-title');
  banner.hidden = true;
  banner.innerHTML = `
    <h2 id="analytics-title">Podemos contar sua visita?</h2>
    <p>Com sua permissão, usamos cookies do Google Analytics para medir as visitas ao site. Você pode mudar sua escolha no rodapé. <a href="privacidade.html" target="_blank" rel="noopener noreferrer">Saiba mais <span aria-hidden="true">↗</span></a></p>
    <div class="analytics-actions">
      <button type="button" data-analytics-deny>Recusar</button>
      <button type="button" data-analytics-accept>Aceitar</button>
    </div>`;
  document.body.append(banner);
  const settingsButtons = document.querySelectorAll('[data-analytics-settings]');

  function showBanner(show) {
    banner.hidden = !show;
    for (const button of settingsButtons) button.setAttribute('aria-expanded', String(show));
  }

  function applyChoice(status) {
    showBanner(status === null);
    if (status === 'granted') {
      startAnalytics();
    } else {
      window[disableKey] = true;
      clearAnalyticsCookies();
      // A fresh page removes the loaded Google library after withdrawal.
      if (tagStarted) window.location.reload();
    }
  }

  function saveChoice(status) {
    try {
      window.localStorage.setItem(storageKey, JSON.stringify({ status, updatedAt: Date.now() }));
    } catch { /* The choice still applies to this page. */ }
    applyChoice(status);
    returnFocus?.focus();
    returnFocus = null;
  }

  banner.querySelector('[data-analytics-deny]').addEventListener('click', () => saveChoice('denied'));
  banner.querySelector('[data-analytics-accept]').addEventListener('click', () => saveChoice('granted'));
  for (const button of settingsButtons) {
    button.hidden = false;
    button.addEventListener('click', () => {
      returnFocus = button;
      showBanner(true);
      banner.querySelector('[data-analytics-deny]').focus();
    });
  }
  window.addEventListener('storage', (event) => {
    if (event.key === storageKey || event.key === null) applyChoice(readChoice());
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') applyChoice(readChoice());
  });
  applyChoice(readChoice());
})();
