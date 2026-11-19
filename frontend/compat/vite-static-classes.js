import { findModuleExport, modules } from './vite-webpack.js';

const section = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    /let\{title:\w+,children:\w+\}=/.test(value.toString()) &&
    value.toString().includes('.spinner'),
);
const sectionTree = section?.({ title: 'Decky' });
const titleComponent = findModuleExport(
  (value) =>
    typeof value === 'function' &&
    value.toString().includes('children:') &&
    /\.locId\)\}/.test(value.toString()) &&
    value.toString().length < 200,
);

export const quickAccessMenuClasses = {
  Title: titleComponent?.({ locId: '#QuickAccess_Tab_Settings_Title' })?.props?.className ?? '',
};
export const staticClasses = quickAccessMenuClasses;
export const quickAccessControlsClasses = {
  PanelSection: sectionTree?.props?.className ?? '',
  PanelSectionTitle: sectionTree?.props?.children?.[0]?.props?.className ?? '',
};
const classModules = [...modules.values()].filter((value) => value && typeof value === 'object');
const find = (name) => classModules.find((value) => value[name]);
export const scrollPanelClasses = find('ScrollPanel') ?? {};
export const scrollClasses = scrollPanelClasses;
export const gamepadDialogClasses = find('GamepadDialogContent') ?? {};
export const updaterFieldClasses = find('OOBEUpdateStatusContainer') ?? {};
export const playSectionClasses = find('PlayBarDetailLabel') ?? {};
export const gamepadSliderClasses = find('SliderControlPanelGroup') ?? {};
export const appDetailsHeaderClasses = find('TopCapsule') ?? {};
export const appDetailsClasses = find('HeaderLoaded') ?? {};
export const gamepadUIClasses = find('BasicUiRoot') ?? {};
export const gamepadTabbedPageClasses = find('GamepadTabbedPage') ?? {};
export const gamepadContextMenuClasses = find('BasicContextMenuModal') ?? {};
export const achievementListClasses = find('AchievementListItemBase') ?? {};
export const achievementClasses = achievementListClasses;
export const achievementPageClasses = {};
export const mainMenuAppRunningClasses = {};
export const basicAppDetailsSectionStylerClasses = {};
export const steamSpinnerClasses = find('SpinnerLoaderContainer') ?? {};
export const footerClasses = find('QuickAccessFooter') ?? {};
export const appActionButtonClasses = find('PlayButtonContainer') ?? {};
export const libraryAssetImageClasses = {};
export const gamepadLibraryClasses = find('GamepadLibrary') ?? {};
export const focusRingClasses = find('FocusRingRoot') ?? {};
export const searchBarClasses = {};
export const mainBrowserClasses = {};
export const vrDashboardClasses = {};
