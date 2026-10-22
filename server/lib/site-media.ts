export type SiteImage = {
  /** Path under `server/public/`. */
  src: `/${string}`;
  width: number;
  height: number;
  alt: string;
};

/** Every image the landing page renders. `site-assets.test.ts` checks each file and its pixel size. */
export const SITE_MEDIA = {
  appIcon: {
    src: "/apple-touch-icon.png",
    width: 180,
    height: 180,
    alt: "",
  },
  framePhoto: {
    src: "/unlock-welcome.png",
    width: 680,
    height: 1024,
    alt: "",
  },
  macosLight: {
    src: "/showcase-macos-light.webp",
    width: 1200,
    height: 893,
    alt: "Gattey Photos welcome window on macOS with a framed photo and the sign-in form",
  },
  macosDark: {
    src: "/showcase-macos-dark.webp",
    width: 1200,
    height: 893,
    alt: "Gattey Photos welcome window on macOS in dark mode",
  },
  iphone: {
    src: "/showcase-iphone.webp",
    width: 603,
    height: 1311,
    alt: "Gattey Photos welcome screen on iPhone",
  },
  openAnyway: {
    src: "/macos-open-anyway.png",
    width: 1024,
    height: 903,
    alt: "Privacy and Security settings showing Gattey Photos was blocked with an Open Anyway button",
  },
} as const satisfies Record<string, SiteImage>;

/** Link-preview image only, never rendered on the page; the icons test checks its 1024px size. */
export const SHARE_ICON = {
  src: "/icon.png",
  width: 1024,
  height: 1024,
  alt: "Gattey Photos app icon",
} as const satisfies SiteImage;
