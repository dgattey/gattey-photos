import { after, before, describe, it } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { createServer, type IncomingHttpHeaders } from "node:http";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoFile = (path: string) => fileURLToPath(new URL(`../../${path}`, import.meta.url));
const SCRIPT = repoFile("scripts/release-notes.sh");
const TEMPLATE = readFileSync(repoFile(".github/pull_request_template.md"), "utf8");

type Run = { status: number; stdout: string; stderr: string };

function run(args: string[], env: Record<string, string> = {}): Promise<Run> {
  const inherited = Object.fromEntries(
    Object.entries(process.env).filter(([key]) => !/^(GITHUB_|GATTEY_|GH_TOKEN$)/.test(key)),
  );
  return new Promise((resolve) => {
    execFile(
      SCRIPT,
      args,
      { encoding: "utf8", env: { ...inherited, GATTEY_COMMIT_MESSAGE: "", ...env } },
      (error, stdout, stderr) => {
        const status = error ? (typeof error.code === "number" ? error.code : 1) : 0;
        resolve({ status, stdout, stderr });
      },
    );
  });
}

async function formatNotes(args: string[], env: Record<string, string> = {}): Promise<string> {
  const result = await run(["--version", "1.2.3", ...args], env);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trimEnd();
}

describe("release-notes.sh section extraction and Markdown-to-HTML formatting", () => {
  it("prefers # Release notes over # What changed? when populated", async () => {
    const body = [
      "Closes GP-42",
      "",
      "# Release notes",
      "",
      "- Check for updates automatically on launch.",
      "- Render **Sparkle** release notes as clean bullet lists.",
      "",
      "# What changed?",
      "",
      "- Internal refactor of `macos/Sources/GatteyPhotosApp/AppUpdater.swift`.",
      "",
      "# Release info",
      "",
      "- [x] Patch",
    ].join("\n");

    const html = await formatNotes(["--pr-body", body]);
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Check for updates automatically on launch.</li>',
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Render <strong>Sparkle</strong> release notes as clean bullet lists.</li>',
        "</ul>",
      ].join("\n"),
    );
  });

  it("falls back to # What changed? when # Release notes only has the empty template bullet", async () => {
    const body = TEMPLATE.replace(
      "# What changed?\n\n- ",
      "# What changed?\n\n- Added `xattr -cr` instructions for **Open Anyway** (`server/app/page.tsx`, `scripts/package-macos.sh`).\n- Fixed [download redirect](https://photos.gattey.com/download/macos).",
    );

    const html = await formatNotes(["--pr-body", body]);
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Added <code>xattr -cr</code> instructions for <strong>Open Anyway</strong>.</li>',
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Fixed <a href="https://photos.gattey.com/download/macos">download redirect</a>.</li>',
        "</ul>",
      ].join("\n"),
    );
  });

  it("strips CURSOR_AGENT_PR_BODY markers, trailing agent footer divs, and standalone images", async () => {
    const body = [
      "<!-- CURSOR_AGENT_PR_BODY_BEGIN -->",
      "# What changed?",
      "",
      "![Screenshot](https://example.com/demo.png)",
      '<img src="https://example.com/banner.png" alt="banner" />',
      "- Improved gallery grid scrolling (`macos/Sources/GatteyPhotosUI/GalleryGridView.swift`).",
      "<!-- CURSOR_AGENT_PR_BODY_END -->",
      '<div><a href="https://cursor.com/agents/123">Open in Web</a></div>',
    ].join("\n");

    const html = await formatNotes(["--pr-body", body]);
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Improved gallery grid scrolling.</li>',
        "</ul>",
      ].join("\n"),
    );
  });

  it("falls back to Release v<version> when the template is unedited", async () => {
    const html = await formatNotes(["--pr-body", TEMPLATE]);
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        '<p style="margin: 0; line-height: 1.45;">Release v1.2.3</p>',
      ].join("\n"),
    );
  });

  it("formats plain commit messages without markdown headings", async () => {
    const html = await formatNotes([], {
      GATTEY_COMMIT_MESSAGE: "Fix Sparkle launch update check (#12)\n\n- Defer checkForUpdates until probing cycle finishes.",
    });
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        '<p style="margin: 0 0 8px 0; line-height: 1.45;">Fix Sparkle launch update check (#12)</p>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Defer checkForUpdates until probing cycle finishes.</li>',
        "</ul>",
      ].join("\n"),
    );
  });
});

describe("release-notes.sh cumulative version history", () => {
  let tempDir = "";
  before(() => {
    tempDir = mkdtempSync(join(tmpdir(), "gattey-release-notes-test-"));
  });
  after(() => {
    if (tempDir) {
      rmSync(tempDir, { recursive: true, force: true });
    }
  });

  it("migrates an un-headed <description> from --existing-appcast using <sparkle:shortVersionString>", async () => {
    const appcastPath = join(tempDir, "unheaded-appcast.xml");
    writeFileSync(
      appcastPath,
      [
        '<?xml version="1.0" standalone="yes"?>',
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">',
        "  <channel>",
        "    <item>",
        "      <title>1.1.9</title>",
        "      <sparkle:shortVersionString>1.1.9</sparkle:shortVersionString>",
        "      <description><![CDATA[<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Only show frames registered to your display name.</li>',
        "</ul>]]></description>",
        "    </item>",
        "  </channel>",
        "</rss>",
      ].join("\n"),
      "utf8",
    );

    const res = await run([
      "--version",
      "1.1.10",
      "--pr-body",
      "# Release notes\n\n- Show cumulative release notes across updates.",
      "--existing-appcast",
      appcastPath,
    ]);
    assert.equal(res.status, 0, res.stderr);
    assert.equal(
      res.stdout.trimEnd(),
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.1.10</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Show cumulative release notes across updates.</li>',
        "</ul>",
        '<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">1.1.9</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Only show frames registered to your display name.</li>',
        "</ul>",
      ].join("\n"),
    );
  });

  it("carries forward already-headed <h3> sections and deduplicates when re-running the same version", async () => {
    const appcastPath = join(tempDir, "headed-appcast.xml");
    writeFileSync(
      appcastPath,
      [
        '<?xml version="1.0" standalone="yes"?>',
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">',
        "  <channel>",
        "    <item>",
        "      <sparkle:shortVersionString>1.2.2</sparkle:shortVersionString>",
        "      <description><![CDATA[",
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.2</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Old 1.2.2 note.</li>',
        "</ul>",
        '<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">1.2.1</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Note from 1.2.1.</li>',
        "</ul>",
        "]]></description>",
        "    </item>",
        "  </channel>",
        "</rss>",
      ].join("\n"),
      "utf8",
    );

    const nextRes = await run([
      "--version",
      "1.2.3",
      "--pr-body",
      "# Release notes\n\n- Note from 1.2.3.",
      "--existing-appcast",
      appcastPath,
    ]);
    assert.equal(nextRes.status, 0, nextRes.stderr);
    assert.equal(
      nextRes.stdout.trimEnd(),
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Note from 1.2.3.</li>',
        "</ul>",
        '<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">1.2.2</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Old 1.2.2 note.</li>',
        "</ul>",
        '<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">1.2.1</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Note from 1.2.1.</li>',
        "</ul>",
      ].join("\n"),
    );

    const rerunRes = await run([
      "--version",
      "1.2.2",
      "--pr-body",
      "# Release notes\n\n- Updated 1.2.2 note.",
      "--existing-appcast",
      appcastPath,
    ]);
    assert.equal(rerunRes.status, 0, rerunRes.stderr);
    assert.equal(
      rerunRes.stdout.trimEnd(),
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.2</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Updated 1.2.2 note.</li>',
        "</ul>",
        '<h3 style="margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;">1.2.1</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Note from 1.2.1.</li>',
        "</ul>",
      ].join("\n"),
    );
  });

  it("caps cumulative release notes at 10 versions and drops the 11th oldest version", async () => {
    const appcastPath = join(tempDir, "ten-versions-appcast.xml");
    const existingSections: string[] = [];
    for (let patch = 10; patch >= 1; patch--) {
      const style =
        patch === 10
          ? "margin: 0 0 6px 0; font-size: 13px;"
          : "margin: 14px 0 6px 0; font-size: 13px; opacity: 0.75;";
      existingSections.push(
        `<h3 style="${style}">1.0.${patch}</h3>`,
        "<ul>",
        `  <li style="margin-bottom: 6px; line-height: 1.45;">Note for 1.0.${patch}.</li>`,
        "</ul>",
      );
    }
    writeFileSync(
      appcastPath,
      [
        '<?xml version="1.0" standalone="yes"?>',
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">',
        "  <channel>",
        "    <item>",
        "      <sparkle:shortVersionString>1.0.10</sparkle:shortVersionString>",
        `      <description><![CDATA[${existingSections.join("\n")}]]></description>`,
        "    </item>",
        "  </channel>",
        "</rss>",
      ].join("\n"),
      "utf8",
    );

    const res = await run([
      "--version",
      "1.0.11",
      "--pr-body",
      "# Release notes\n\n- Note for 1.0.11.",
      "--existing-appcast",
      appcastPath,
    ]);
    assert.equal(res.status, 0, res.stderr);
    const headings = Array.from(res.stdout.matchAll(/<h3[^>]*>([^<]+)<\/h3>/g), (m) => m[1]);
    assert.equal(headings.length, 10);
    assert.deepEqual(headings, [
      "1.0.11",
      "1.0.10",
      "1.0.9",
      "1.0.8",
      "1.0.7",
      "1.0.6",
      "1.0.5",
      "1.0.4",
      "1.0.3",
      "1.0.2",
    ]);
    assert.ok(!res.stdout.includes("1.0.1<"));
    assert.ok(!res.stdout.includes("Note for 1.0.1."));
  });
});

describe("release-notes.sh GitHub PR lookup", () => {
  let baseUrl = "";
  let reply: { status: number; body: string } = { status: 200, body: "[]" };
  const requests: Array<{ url: string | undefined; headers: IncomingHttpHeaders }> = [];
  const server = createServer((request, response) => {
    requests.push({ url: request.url, headers: request.headers });
    response.writeHead(reply.status, { "content-type": "application/json" });
    response.end(reply.body);
  });

  before(async () => {
    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  });
  after(() => server.close());

  it("fetches the merged PR body for GITHUB_SHA when no --pr-body is passed", async () => {
    requests.length = 0;
    reply = {
      status: 200,
      body: JSON.stringify([
        {
          number: 11,
          merged_at: "2026-10-15T18:15:00Z",
          merge_commit_sha: "abc123",
          body: "# Release notes\n\n- Stripped Xcode toolchain `LC_RPATH` entries (`scripts/package-macos.sh`).\n\n# Release info\n- [x] Patch",
        },
      ]),
    };

    const html = await formatNotes([], {
      GITHUB_API_URL: baseUrl,
      GITHUB_REPOSITORY: "dgattey/gattey-photos",
      GITHUB_SHA: "abc123",
      GH_TOKEN: "test-token",
    });

    assert.equal(requests.length, 1);
    assert.equal(requests[0].url, "/repos/dgattey/gattey-photos/commits/abc123/pulls");
    assert.equal(
      html,
      [
        '<h3 style="margin: 0 0 6px 0; font-size: 13px;">1.2.3</h3>',
        "<ul>",
        '  <li style="margin-bottom: 6px; line-height: 1.45;">Stripped Xcode toolchain <code>LC_RPATH</code> entries.</li>',
        "</ul>",
      ].join("\n"),
    );
  });
});
