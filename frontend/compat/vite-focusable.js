import { findModuleExport } from './vite-webpack.js';

export const Focusable = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    value.toString().includes('focusWithinClassName:') &&
    value.toString().includes('navOptions:'),
);
