// No Google requests: execute the consent controller with a small DOM fixture.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { runInNewContext } = require('node:vm');
const source = readFileSync(join(__dirname, '..', 'analytics.js'), 'utf8');
const key = 'guitarzero.analytics-consent.v1';
const disableKey = 'ga-disable-G-JND41JTZB8';
const lifetime = 180 * 86400000;

function fixture({ host = 'guitarzero.com.br', protocol = 'https:', saved, blocked = false } = {}) {
  class Element {
    constructor() { this.listeners = {}; this.attributes = {}; this.hidden = true; this.children = {}; }
    setAttribute(name, value) { this.attributes[name] = value; }
    addEventListener(name, fn) { this.listeners[name] = fn; }
    querySelector(selector) { return this.children[selector] ||= new Element(); }
    focus() { this.focused = true; }
    click() { this.listeners.click(); }
  }
  const settings = new Element();
  const scripts = [];
  const body = [];
  const values = new Map(saved === undefined ? [] : [[key, typeof saved === 'string' ? saved : JSON.stringify(saved)]]);
  const cookieWrites = [];
  const documentListeners = {};
  const document = {
    createElement: () => new Element(),
    head: { append: e => scripts.push(e) },
    body: { append: e => body.push(e) },
    querySelectorAll: () => [settings],
    referrer: 'https://example.com/private-path?email=private@example.com#private',
    visibilityState: 'visible',
    addEventListener: (name, fn) => { documentListeners[name] = fn; },
    get cookie() { return '_ga=old; _ga_JND41JTZB8=old; unrelated=keep'; },
    set cookie(value) { cookieWrites.push(value); },
  };
  const events = {};
  let reloads = 0;
  const window = {
    location: { hostname: host, protocol, origin: `${protocol}//${host}`, pathname: '/index.html', search: '?email=private', hash: '#private', reload: () => reloads++ },
    localStorage: {
      getItem: k => { if (blocked) throw new Error('blocked'); return values.get(k) ?? null; },
      setItem: (k, v) => { if (blocked) throw new Error('blocked'); values.set(k, v); },
    },
    addEventListener: (name, fn) => { events[name] = fn; },
  };
  runInNewContext(source, { window, document, URL, Date, Number, JSON });
  const banner = body[0];
  return {
    window, scripts, values, events, documentListeners, document, settings, banner, cookieWrites,
    accept: () => banner.querySelector('[data-analytics-accept]').click(),
    deny: () => banner.querySelector('[data-analytics-deny]').click(),
    get reloads() { return reloads; },
  };
}

test('unknown choice: no Google tag or queue; choice remains optional', () => {
  const f = fixture();
  assert.equal(f.scripts.length, 0);
  assert.equal(f.window.dataLayer, undefined);
  assert.equal(f.window[disableKey], true);
  assert.equal(f.banner.hidden, false);
  assert.equal(f.settings.hidden, false);
});

test('refusal persists without loading GA; cookie cleanup leaves unrelated cookies alone', () => {
  const f = fixture(); f.deny();
  assert.equal(f.scripts.length, 0);
  assert.equal(JSON.parse(f.values.get(key)).status, 'denied');
  assert.equal(f.banner.hidden, true);
  assert.ok(f.cookieWrites.length > 0);
  assert.ok(f.cookieWrites.every(c => !c.startsWith('unrelated=')));
  assert.equal(f.reloads, 0);
});

test('acceptance loads GA once, with basic consent and no advertising', () => {
  const f = fixture(); f.accept(); f.accept();
  assert.equal(f.scripts.length, 1);
  assert.equal(f.scripts[0].src, 'https://www.googletagmanager.com/gtag/js?id=G-JND41JTZB8');
  const queue = f.window.dataLayer.map(args => Array.from(args));
  assert.equal(queue[0][0], 'consent');
  assert.equal(queue[0][2].analytics_storage, 'denied');
  assert.equal(queue[1][2].analytics_storage, 'granted');
  assert.equal(queue[1][2].ad_storage, 'denied');
  assert.equal(queue[1][2].ad_user_data, 'denied');
  assert.equal(queue[1][2].ad_personalization, 'denied');
  const config = queue.find(args => args[0] === 'config')[2];
  assert.equal(config.allow_google_signals, false);
  assert.equal(config.allow_ad_personalization_signals, false);
  assert.equal(config.page_location, 'https://guitarzero.com.br/index.html');
  assert.equal(config.page_referrer, 'https://example.com');
  assert.equal(config.cookie_expires, lifetime / 1000);
  assert.equal(config.cookie_update, false);
});

test('both public hosts load with saved acceptance; local, preview and HTTP never load', () => {
  const saved = { status: 'granted', updatedAt: Date.now() };
  for (const host of ['guitarzero.com.br', 'www.guitarzero.com.br']) {
    assert.equal(fixture({ host, saved }).scripts.length, 1);
  }
  for (const host of ['localhost', '127.0.0.1', 'preview.guitarzero.com.br', 'guitarzero.com.br.example.com']) {
    const f = fixture({ host, saved }); f.accept();
    assert.equal(f.scripts.length, 0, host);
  }
  const insecure = fixture({ protocol: 'http:', saved }); insecure.accept();
  assert.equal(insecure.scripts.length, 0);
});

test('saved refusal, expired, malformed, future and inaccessible storage never grant consent', () => {
  const cases = [
    { saved: { status: 'denied', updatedAt: Date.now() } },
    { saved: { status: 'granted', updatedAt: Date.now() - lifetime - 1 } },
    { saved: { status: 'granted', updatedAt: Date.now() + 60000 } },
    { saved: { status: 'granted', updatedAt: 'today' } },
    { saved: 'invalid json' }, { blocked: true },
  ];
  for (const options of cases) assert.equal(fixture(options).scripts.length, 0);
  const f = fixture({ blocked: true }); f.deny();
  assert.equal(f.scripts.length, 0);
});

test('footer reopens choices, supports withdrawal and restores focus', () => {
  const f = fixture(); f.accept(); f.settings.click();
  assert.equal(f.banner.hidden, false);
  assert.equal(f.banner.querySelector('[data-analytics-deny]').focused, true);
  f.deny();
  assert.equal(f.window[disableKey], true);
  assert.equal(f.reloads, 1);
  assert.equal(JSON.parse(f.values.get(key)).status, 'denied');
  assert.equal(f.settings.focused, true);
});

test('withdrawal and clearing preferences in another tab stop a loaded tag', () => {
  for (const status of ['denied', null]) {
    const f = fixture(); f.accept();
    if (status) f.values.set(key, JSON.stringify({ status, updatedAt: Date.now() }));
    else f.values.clear();
    f.events.storage({ key: status ? key : null });
    assert.equal(f.window[disableKey], true);
    assert.equal(f.reloads, 1);
  }
});
