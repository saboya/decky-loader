import { findModuleExport } from './vite-webpack.js';

// CSS-module property names are inlined by Rolldown. Match the component's
// prop structure instead of the removed `.PanelSection` string.
export const PanelSection = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    /let\{title:\w+,children:\w+\}=/.test(value.toString()) &&
    value.toString().includes('.spinner'),
);
export const PanelSectionRow = ({ children, className, ...props }) =>
  window.SP_REACT.createElement('div', { ...props, className }, children);
