import { getMacOSRelease } from "@/lib/macos-release";
import styles from "./page.module.css";

export const dynamic = "force-static";

export default function HomePage() {
  const release = getMacOSRelease();

  return (
    <main className={styles.page}>
      <div className={styles.heroUnit}>
        <div className={styles.photoColumn}>
          <div className={styles.frameOuter}>
            <div className={styles.frameMat}>
              <div className={styles.frameScreen}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src="/unlock-welcome.png"
                  alt=""
                  width={680}
                  height={1024}
                  fetchPriority="high"
                />
                <div className={styles.vignette} aria-hidden />
              </div>
            </div>
          </div>
        </div>

        {release ? (
          <>
            <div className={styles.downloadPrimary}>
              <div className={styles.headingBlock}>
                <h1 className={styles.title}>Welcome to Gattey Photos</h1>
                <p className={styles.subtitle}>
                  The macOS app for your family gallery — upload photos, manage frames, and keep
                  Bloomin8 displays in sync.
                </p>
              </div>

              <div className={styles.downloadCta}>
                <a className={styles.downloadButton} href="/download/macos">
                  Download for macOS{release.version ? ` (v${release.version})` : ""}
                </a>
                {!release.downloadReady ? (
                  <p className={styles.hint}>
                    That version is still deploying. Refresh in a minute if download fails.
                  </p>
                ) : null}

                <details className={styles.manualApproval}>
                  <summary>First time on this Mac? macOS may block the app</summary>
                  <div className={styles.manualApprovalBody}>
                    <p className={styles.finePrint}>
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
                      <div className={styles.manualApprovalMedia}>
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src="/macos-open-anyway.png"
                          alt='Privacy and Security settings showing Gattey Photos was blocked with an Open Anyway button'
                          width={1024}
                          height={903}
                          decoding="async"
                        />
                      </div>
                      <figcaption>
                        Open Anyway appears after you try to launch the app once.
                      </figcaption>
                    </figure>
                  </div>
                </details>
              </div>
            </div>
          </>
        ) : (
          <p className={styles.noRelease}>
            A macOS build is not published yet. Check back after the next release.
          </p>
        )}
      </div>
    </main>
  );
}
