import { findModuleExport } from './vite-webpack.js';

export const Tabs = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    value.toString().includes('canBeHeaderBackground:') &&
    value.toString().includes('cancelSkipTabHeader:'),
);
