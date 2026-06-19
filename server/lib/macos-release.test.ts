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
});
