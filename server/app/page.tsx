import { Feature, Features, Hero, latestRelease, ReleaseNotes, Section, Showcase, site, SitePage } from "@dylkit/web";
import styles from "./page.module.css";

export default async function HomePage() {
  const release = await latestRelease(site);
  return (
    <SitePage>
      <Hero
        release={release}
        visual={<PictureFrame />}
        title="Welcome to Gattey Photos"
        lead="Upload family photos, schedule what each Bloomin8 frame shows, and keep every frame in sync."
      />
      <Section
        id="showcase"
        eyebrow="One gallery, every screen"
        title="Made for Mac, iPhone, and iPad"
        lead="The same family gallery and frame schedule on every device. iPhone and iPad builds aren't public yet, so downloads are Mac-only for now."
      >
        <Showcase mac="showcase-macos-light.webp" phone="showcase-iphone.webp" />
      </Section>
      <Features>
        <Feature
          title="Add and reorder photos"
          glyph={
            <div className={styles.glyphGrid}>
              <span />
              <span />
              <span />
              <span className={styles.glyphAdd}>+</span>
            </div>
          }
        >
          Drop in photos from your Mac or phone, then drag them into the order you want the family to see.
        </Feature>
        <Feature
          title="Schedule each day"
          glyph={
            <div className={styles.glyphBadges}>
              <span className={styles.todayChip}>Today</span>
              <span className={styles.dateBadge}>Fri</span>
              <span className={styles.dateBadge}>Sat</span>
            </div>
          }
        >
          Every photo gets a day on the frame. See what&apos;s showing today and what comes next at a glance.
        </Feature>
        <Feature
          title="Keep frames in sync"
          glyph={
            <div className={styles.glyphFrame}>
              <span className={styles.glyphFrameMat} />
              <span className={styles.glyphSyncDot} />
            </div>
          }
        >
          Register your Bloomin8 frames once. The app pushes the current photo to each one automatically.
        </Feature>
      </Features>
      <ReleaseNotes release={release} />
    </SitePage>
  );
}

/** A Bloomin8 frame on the wall, as the Mac app's welcome screen draws it. */
function PictureFrame() {
  return (
    <figure className={styles.framed}>
      <div className={styles.frameOuter}>
        <div className={styles.frameMat}>
          <div className={styles.frameScreen}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/unlock-welcome.png" alt="" width={680} height={1024} fetchPriority="high" />
          </div>
        </div>
      </div>
      <figcaption className={styles.nowShowing}>
        <span className={styles.eyebrow}>Now showing</span>
        <span className={styles.nowShowingTitle}>Added by Dylan</span>
        <span className={styles.nowShowingDetail}>Until today</span>
      </figcaption>
    </figure>
  );
}
