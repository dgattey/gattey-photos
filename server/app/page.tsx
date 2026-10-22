import type { ReactNode } from "react";
import { getMacOSRelease } from "@/lib/macos-release";
import { SITE_MEDIA } from "@/lib/site-media";
import styles from "./page.module.css";

export const dynamic = "force-static";

const FEATURES: { title: string; body: string; glyph: ReactNode }[] = [
  {
    title: "Add and reorder photos",
    body: "Drop in photos from your Mac or phone, then drag them into the order you want the family to see.",
    glyph: (
      <div className={styles.glyphGrid}>
        <span />
        <span />
        <span />
        <span className={styles.glyphAdd}>+</span>
      </div>
    ),
  },
  {
    title: "Schedule each day",
    body: "Every photo gets a day on the frame. See what's showing today and what comes next at a glance.",
    glyph: (
      <div className={styles.glyphBadges}>
        <span className={styles.todayChip}>Today</span>
        <span className={styles.dateBadge}>Fri</span>
        <span className={styles.dateBadge}>Sat</span>
      </div>
    ),
  },
  {
    title: "Keep frames in sync",
    body: "Register your Bloomin8 frames once. The app pushes the current photo to each one automatically.",
    glyph: (
      <div className={styles.glyphFrame}>
        <span className={styles.glyphFrameMat} />
        <span className={styles.glyphSyncDot} />
      </div>
    ),
  },
];

export default function HomePage() {
  const release = getMacOSRelease();
  const recentNotes = release?.releaseNotes.slice(0, 3) ?? [];

  return (
    <div className={styles.page}>
      <header className={styles.topBar}>
        <a className={styles.brand} href="/">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            className={styles.brandIcon}
            src={SITE_MEDIA.appIcon.src}
            alt={SITE_MEDIA.appIcon.alt}
            width={SITE_MEDIA.appIcon.width}
            height={SITE_MEDIA.appIcon.height}
          />
          <span className={styles.wordmark}>Gattey Photos</span>
        </a>
      </header>

      <main>
        <section className={styles.hero} aria-labelledby="hero-title">
          <div className={styles.heroCopy}>
            <h1 id="hero-title" className={styles.title}>
              Welcome to Gattey Photos
            </h1>
            <p className={styles.subtitle}>
              Upload family photos, schedule what each Bloomin8 frame shows, and keep every frame
              in sync.
            </p>

            {release ? (
              <div className={styles.downloadActions}>
                <div className={styles.buttonRow}>
                  <a className={styles.buttonProminent} href="/download/macos">
                    Download for Mac
                    {release.version ? (
                      <span className={styles.buttonVersion}>v{release.version}</span>
                    ) : null}
                  </a>
                  {recentNotes.length > 0 ? (
                    <a className={styles.buttonTinted} href="#whats-new">
                      What&apos;s new
                    </a>
                  ) : null}
                </div>
                <p className={styles.finePrint}>
                  {release.minimumSystemVersion
                    ? `Requires macOS ${release.minimumSystemVersion}+ on Apple silicon`
                    : "Requires a Mac with Apple silicon"}
                </p>
                {!release.downloadReady ? (
                  <p className={styles.hint}>
                    That version is still deploying. Refresh in a minute if download fails.
                  </p>
                ) : null}

                <details className={styles.manualApproval}>
                  <summary>First time on this Mac? macOS may block the app</summary>
                  <div className={styles.manualApprovalBody}>
                    <p>
                      After you download and try to open Gattey Photos once, approve it in System
                      Settings.
                    </p>
                    <ol className={styles.manualSteps}>
                      <li>
                        Try opening <strong>Gattey Photos</strong> from Applications so macOS
                        records the block.
                      </li>
                      <li>
                        Open <strong>System Settings → Privacy & Security</strong>.
                      </li>
                      <li>
                        Under Security, click <strong>Open Anyway</strong> next to the Gattey
                        Photos message.
                      </li>
                      <li>Open the app again.</li>
                    </ol>
                    <figure className={styles.manualApprovalFigure}>
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={SITE_MEDIA.openAnyway.src}
                        alt={SITE_MEDIA.openAnyway.alt}
                        width={SITE_MEDIA.openAnyway.width}
                        height={SITE_MEDIA.openAnyway.height}
                        decoding="async"
                        loading="lazy"
                      />
                      <figcaption>Open Anyway appears after you try to launch the app once.</figcaption>
                    </figure>
                    <p>
                      On MDM-managed work Macs where <strong>Open Anyway</strong> still blocks the
                      app, clear quarantine once in Terminal:{" "}
                      <code>xattr -cr &quot;/Applications/Gattey Photos.app&quot;</code>
                    </p>
                  </div>
                </details>
              </div>
            ) : (
              <p className={styles.hint}>
                A macOS build is not published yet. Check back after the next release.
              </p>
            )}
          </div>

          <div className={styles.heroVisual}>
            <figure className={styles.framed}>
              <div className={styles.frameOuter}>
                <div className={styles.frameMat}>
                  <div className={styles.frameScreen}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src={SITE_MEDIA.framePhoto.src}
                      alt={SITE_MEDIA.framePhoto.alt}
                      width={SITE_MEDIA.framePhoto.width}
                      height={SITE_MEDIA.framePhoto.height}
                      fetchPriority="high"
                    />
                  </div>
                </div>
              </div>
              <figcaption className={styles.nowShowing}>
                <span className={styles.eyebrow}>Now showing</span>
                <span className={styles.nowShowingTitle}>Added by Dylan</span>
                <span className={styles.nowShowingDetail}>Until today</span>
              </figcaption>
            </figure>
          </div>
        </section>

        <section className={styles.section} aria-labelledby="showcase-title">
          <div className={styles.sectionHeading}>
            <p className={styles.eyebrow}>One gallery, every screen</p>
            <h2 id="showcase-title" className={styles.sectionTitle}>
              Made for Mac, iPhone, and iPad
            </h2>
            <p className={styles.sectionLead}>
              The same family gallery and frame schedule on every device. iPhone and iPad builds
              aren&apos;t public yet, so downloads are Mac-only for now.
            </p>
          </div>
          <div className={styles.showcase}>
            <picture className={styles.showcaseMac}>
              <source media="(prefers-color-scheme: dark)" srcSet={SITE_MEDIA.macosDark.src} />
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={SITE_MEDIA.macosLight.src}
                alt={SITE_MEDIA.macosLight.alt}
                width={SITE_MEDIA.macosLight.width}
                height={SITE_MEDIA.macosLight.height}
              />
            </picture>
            <div className={styles.phone}>
              <div className={styles.phoneBezel}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={SITE_MEDIA.iphone.src}
                  alt={SITE_MEDIA.iphone.alt}
                  width={SITE_MEDIA.iphone.width}
                  height={SITE_MEDIA.iphone.height}
                />
              </div>
            </div>
          </div>
        </section>

        <section className={styles.section} aria-labelledby="features-title">
          <h2 id="features-title" className={styles.visuallyHidden}>
            What it does
          </h2>
          <ul className={styles.features}>
            {FEATURES.map((feature) => (
              <li key={feature.title} className={styles.feature}>
                <div className={styles.glyph} aria-hidden>
                  {feature.glyph}
                </div>
                <h3 className={styles.featureTitle}>{feature.title}</h3>
                <p className={styles.featureBody}>{feature.body}</p>
              </li>
            ))}
          </ul>
        </section>

        {recentNotes.length > 0 ? (
          <section id="whats-new" className={styles.section} aria-labelledby="whats-new-title">
            <div className={styles.sectionHeading}>
              <p className={styles.eyebrow}>Release notes</p>
              <h2 id="whats-new-title" className={styles.sectionTitle}>
                What&apos;s new
              </h2>
            </div>
            <ol className={styles.releases}>
              {recentNotes.map((section, index) => (
                <li key={section.version} className={styles.release}>
                  <div className={styles.releaseHeader}>
                    <h3 className={styles.releaseVersion}>Version {section.version}</h3>
                    {index === 0 ? <span className={styles.latestChip}>Latest</span> : null}
                  </div>
                  <ul className={styles.releaseNotes}>
                    {section.notes.map((note) => (
                      <li key={note}>{note}</li>
                    ))}
                  </ul>
                </li>
              ))}
            </ol>
          </section>
        ) : null}
      </main>

      <footer className={styles.footer}>
        <span>
          Made by <a href="https://www.dylangattey.com">Dylan Gattey</a>
        </span>
        {release ? <a href="/download/macos">Download for Mac</a> : null}
      </footer>
    </div>
  );
}
