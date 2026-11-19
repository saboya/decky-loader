import { findModuleExport } from './vite-webpack.js';

export const Field = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    value.toString().includes('spacingBetweenLabelAndChild:') &&
    value.toString().includes('transparentBackground:'),
);
