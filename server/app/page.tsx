import { getMacOSRelease } from "@/lib/macos-release";
import styles from "./page.module.css";

export const dynamic = "force-static";

const TRUST_PROFILE_PATH = "/gattey-photos-trust.mobileconfig";

export default function HomePage() {
  const release = getMacOSRelease();

  return (
    <main className={styles.page}>
      <div className={styles.shell}>
        <div className={styles.photoColumn}>
          <div className={styles.frameOuter}>
            <div className={styles.frameMat}>
              <div className={styles.frameScreen}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src="/unlock-welcome.png"
                  alt=""
                  width={1200}
                  height={1600}
                  fetchPriority="high"
                />
                <div className={styles.vignette} aria-hidden />
              </div>
            </div>
          </div>
        </div>

        <div className={styles.downloadColumn}>
          <div className={styles.headingBlock}>
            <h1 className={styles.title}>Welcome to Gattey Photos</h1>
            <p className={styles.subtitle}>
              The macOS app for your family gallery — upload photos, manage frames,
              and keep Bloomin8 displays in sync.
            </p>
          </div>

          {release ? (
            <div className={styles.downloadActions}>
              <a className={styles.downloadButton} href={release.zipPath} download>
                Download for macOS{release.version ? ` (v${release.version})` : ""}
              </a>

              <div className={styles.trustBlock}>
                <p className={styles.trustLead}>First time on this Mac?</p>
                <a
                  className={styles.trustButton}
                  href={TRUST_PROFILE_PATH}
                  download="gattey-photos-trust.mobileconfig"
                >
                  Install macOS trust
                </a>
                <ol className={styles.trustSteps}>
                  <li>Click the button above — macOS downloads a small profile.</li>
                  <li>Open it (double-click the download or follow the Safari prompt).</li>
                  <li>
                    In System Settings, install <strong>Gattey Photos — macOS trust</strong>{" "}
                    and enter your Mac password.
                  </li>
                  <li>Then download the app and open it from Applications.</li>
                </ol>
              </div>

              <details className={styles.manualApproval}>
                <summary>If macOS still blocks the app</summary>
                <div className={styles.manualApprovalBody}>
                  <p className={styles.finePrint}>
                    You may need to approve the app once in System Settings even after installing
                    the trust profile.
                  </p>
                  <ol className={styles.trustSteps}>
                    <li>
                      Try opening <strong>Gattey Photos</strong> once so macOS records the block.
                    </li>
                    <li>
                      Open <strong>System Settings → Privacy & Security</strong>.
                    </li>
                    <li>
                      Under Security, click <strong>Open Anyway</strong> next to the Gattey Photos
                      message.
                    </li>
                    <li>Open the app again from Applications.</li>
                  </ol>
                  <figure className={styles.manualApprovalFigure}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img
                      src="/macos-open-anyway.png"
                      alt='Privacy and Security settings showing Gattey Photos was blocked with an Open Anyway button'
                      width={520}
                      height={360}
                    />
                    <figcaption>
                      Open Anyway appears after you try to launch the app once.
                    </figcaption>
                  </figure>
                </div>
              </details>
            </div>
          ) : (
            <p className={styles.hint}>
              A macOS build is not published yet. Check back after the next release.
            </p>
          )}
        </div>
      </div>
    </main>
  );
}
