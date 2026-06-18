import { getMacOSRelease } from "@/lib/macos-release";
import styles from "./page.module.css";

export const dynamic = "force-static";

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
            <a className={styles.downloadButton} href={release.zipPath} download>
              Download for macOS{release.version ? ` (v${release.version})` : ""}
            </a>
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
