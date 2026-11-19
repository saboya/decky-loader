// Experimental module-discovery adapter for the November 2026 Steam beta.
// The backend debugger must populate this cache before importing the frontend.
export const modules = window.__DECKY_VITE_MODULES;
if (!(modules instanceof Map) || !modules.size) {
  throw new Error('Steam Vite module cache is unavailable');
}

// Preserve the Webpack lookup API used by @decky/ui and plugins. Rolldown
// flattens modules, so individual bindings and the aggregate namespace are
// both searchable. Do not call arbitrary exports to try to initialize them.
const candidates = [...modules.entries()].filter(([id]) => !id.endsWith(':export') && id !== 'vite:namespace');
modules.clear();
for (const [id, value] of candidates) {
  try {
    if (value != null && typeof value?.toString === 'function') {
      value.toString();
      modules.set(id, value);
    }
  } catch {
    /* Native prototypes are not modules. */
  }
}
const namespace = Object.fromEntries(modules);
for (const [id, value] of candidates) {
  if (value && (typeof value === 'object' || typeof value === 'function')) {
    modules.set(`${id}:export`, { [id]: value });
  }
}
modules.set('vite:namespace', namespace);

export function findModule(filter) {
  for (const value of modules.values()) {
    if (value.default && filter(value.default)) return value.default;
    if (filter(value)) return value;
  }
}

export function findModuleDetailsByExport(filter, minExports) {
  for (const [id, value] of [['vite:namespace', namespace], ...modules]) {
    for (const mod of [value?.default, value]) {
      if (!mod || typeof mod !== 'object' || mod === window) continue;
      if (minExports && Object.keys(mod).length < minExports) continue;
      for (const key of Object.keys(mod)) {
        try {
          if (mod[key] && filter(mod[key], key)) return [mod, mod[key], key, id];
        } catch {
          /* Some Steam exports have throwing getters. */
        }
      }
    }
  }
  return [undefined, undefined, undefined, undefined];
}

export const findModuleByExport = (filter, min) => findModuleDetailsByExport(filter, min)[0];
export const findModuleExport = (filter, min) => findModuleDetailsByExport(filter, min)[1];
export const findModuleChild = (filter) => {
  for (const value of modules.values()) {
    for (const mod of [value.default, value]) {
      const result = filter(mod);
      if (result) return result;
    }
  }
};
export const findAllModules = (filter) => [...createModuleMapping(filter).values()];
export function createModuleMapping(filter) {
  const matches = new Map();
  for (const [id, value] of modules) {
    if (value.default && filter(value.default)) matches.set(id, value.default);
    if (filter(value)) matches.set(id, value);
  }
  return matches;
}
export const CommonUIModule = Object.fromEntries(
  Object.entries(namespace).filter(([, v]) => {
    try {
      v?.toString?.();
      return true;
    } catch {
      return false;
    }
  }),
);
export const IconsModule = findModuleByExport(
  (e) => e?.toString?.().includes('Spinner') && e.toString().includes('M18 '),
);
export const ReactRouter = Object.fromEntries(Object.entries(namespace).filter(([, v]) => typeof v === 'function'));
