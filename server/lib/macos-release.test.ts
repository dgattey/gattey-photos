import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { parseAppcastXml } from "./macos-release.ts";

const SAMPLE = `<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Gattey Photos</title>
    <item>
      <title>1.0.7</title>
      <sparkle:version>45</sparkle:version>
      <sparkle:shortVersionString>1.0.7</sparkle:shortVersionString>
      <enclosure url="https://photos.gattey.com/Gattey-Photos-1.0.7.zip" length="1" type="application/octet-stream"/>
    </item>
  </channel>
</rss>`;

describe("parseAppcastXml", () => {
  it("parses version, build, and absolute download URL", () => {
    const release = parseAppcastXml(SAMPLE);
    assert.ok(release);
    assert.equal(release.version, "1.0.7");
    assert.equal(release.build, "45");
    assert.equal(release.zipPath, "/Gattey-Photos-1.0.7.zip");
    assert.equal(release.downloadUrl, "https://photos.gattey.com/Gattey-Photos-1.0.7.zip");
  });

  it("returns null for invalid xml", () => {
    assert.equal(parseAppcastXml("<rss></rss>"), null);
  });

  it("reads minimum macOS and plain-text release notes from the description", () => {
    const xml = SAMPLE.replace(
      "<enclosure",
      `<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[<h3 style="margin: 0">1.0.7</h3>
<ul>
  <li style="line-height: 1.45;">Fix signature validation (<code>-67050</code>) &amp; retries</li>
  <li>Faster startup</li>
</ul>
<h3 style="opacity: 0.75;">1.0.6</h3>
<p>PR title only</p>
<ul>
  <li>Embed release notes</li>
</ul>
<h3>1.0.5</h3>
<p>No bullets</p>
]]></description>
      <enclosure`,
    );
    const release = parseAppcastXml(xml);
    assert.ok(release);
    assert.equal(release.minimumSystemVersion, "14.0");
    assert.deepEqual(release.releaseNotes, [
      { version: "1.0.7", notes: ["Fix signature validation (-67050) & retries", "Faster startup"] },
      { version: "1.0.6", notes: ["Embed release notes"] },
    ]);
  });

  it("returns empty release notes when the appcast has no description", () => {
    const release = parseAppcastXml(SAMPLE);
    assert.ok(release);
    assert.equal(release.minimumSystemVersion, null);
    assert.deepEqual(release.releaseNotes, []);
  });
});
