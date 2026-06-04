// static/js/storage.js
// Centralized localStorage access with key constants and JSON parse safety

const LEGACY_PREFIX = 'odysseus-';
const CURRENT_PREFIX = 'basedcode-';

function migrateLegacyKeys() {
  try {
    const moves = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const key = localStorage.key(i);
      if (!key || !key.startsWith(LEGACY_PREFIX)) continue;
      const nextKey = CURRENT_PREFIX + key.slice(LEGACY_PREFIX.length);
      if (localStorage.getItem(nextKey) === null) {
        moves.push([key, nextKey, localStorage.getItem(key)]);
      } else {
        moves.push([key, null, null]);
      }
    }
    moves.forEach(([oldKey, nextKey, value]) => {
      if (nextKey !== null && value !== null) localStorage.setItem(nextKey, value);
      localStorage.removeItem(oldKey);
    });
  } catch (_) {}
}

migrateLegacyKeys();

// ── Key constants ──
export const KEYS = {
  THEME: 'basedcode-theme',
  TOGGLES: 'basedcode-toggles',
  SIDEBAR_COLLAPSED: 'sidebar-collapsed',
  SIDEBAR_WIDTH: 'sidebar-width',
  SIDEBAR_SIDE: 'sidebar-side',
  CURRENT_SESSION: 'currentSessionId',
  COMPARE_SAVE: 'compare-save-results',
  COMPARE_CHAT: 'compare-continue-chat',
  COMPARE_BLIND: 'compare-blind',
  COMPARE_RANDOM: 'compare-randomize',
  MODELS_EXPANDED: 'basedcode-model-expanded',
  MODEL_ENDPOINTS: 'basedcode-model-endpoints',
  MODEL_SELECTED: 'basedcode-selected-model',
  SORT_ORDER: 'basedcode-sessions-sort',
  CHAT_SEARCH_SCOPE: 'basedcode-search-scope',
  INCOGNITO: 'basedcode-incognito',
  RAG_ACTIVE: 'basedcode-rag-active',
  MCP_ACTIVE: 'basedcode-mcp-active',
  SECTION_ORDER: 'sidebar-section-order',
  ADMIN_LAST_TAB: 'admin-last-tab',
  DENSITY: 'basedcode-density'
};

/**
 * Safely get and parse a JSON value from localStorage.
 * Returns fallback on any error.
 */
export function getJSON(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    if (raw === null) return fallback !== undefined ? fallback : null;
    return JSON.parse(raw);
  } catch (e) {
    console.warn('[Storage] Failed to parse key "' + key + '":', e.message);
    return fallback !== undefined ? fallback : null;
  }
}

/**
 * Set a JSON-serialized value in localStorage.
 */
export function setJSON(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch (e) {
    console.warn('[Storage] Failed to set key "' + key + '":', e.message);
  }
}

/**
 * Get a raw string value from localStorage.
 */
export function get(key, fallback) {
  try {
    const val = localStorage.getItem(key);
    return val !== null ? val : (fallback !== undefined ? fallback : null);
  } catch (e) {
    return fallback !== undefined ? fallback : null;
  }
}

/**
 * Set a raw string value in localStorage.
 */
export function set(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch (e) {
    console.warn('[Storage] Failed to set key "' + key + '":', e.message);
  }
}

/**
 * Remove a key from localStorage.
 */
export function remove(key) {
  try {
    localStorage.removeItem(key);
  } catch (e) {
    // Ignore removal errors
  }
}

// ── Toggle state helpers ──

export function loadToggleState() {
  return getJSON(KEYS.TOGGLES, {});
}

export function saveToggleState(state) {
  setJSON(KEYS.TOGGLES, state);
}

export function getToggle(name, fallback) {
  const state = loadToggleState();
  return state[name] !== undefined ? state[name] : (fallback !== undefined ? fallback : false);
}

export function setToggle(name, value) {
  const state = loadToggleState();
  state[name] = value;
  saveToggleState(state);
}

const Storage = {
  KEYS,
  getJSON,
  setJSON,
  get,
  set,
  remove,
  loadToggleState,
  saveToggleState,
  getToggle,
  setToggle
};

export default Storage;
