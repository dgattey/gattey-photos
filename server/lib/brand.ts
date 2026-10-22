import type { CSSProperties } from "react";

/**
 * Web copies of the app brand colors. `site-assets.test.ts` fails when these drift from
 * `AppBrandColor.accentGreen` or the `macos/AppIcon.icon/icon.json` canvas gradient.
 */
export const BRAND = {
  green: "#467e61",
  greenOnDark: "#9ee0b3",
  iconGradientTop: "#5e9f85",
  iconGradientBottom: "#2e5c45",
} as const;

export const brandCssVariables = {
  "--brand-green": BRAND.green,
  "--brand-green-on-dark": BRAND.greenOnDark,
  "--brand-icon-top": BRAND.iconGradientTop,
  "--brand-icon-bottom": BRAND.iconGradientBottom,
} as CSSProperties;
