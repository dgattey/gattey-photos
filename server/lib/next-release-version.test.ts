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
const SCRIPT = repoFile("scripts/next-release-version.sh");
const TEMPLATE = readFileSync(repoFile(".github/pull_request_template.md"), "utf8");

type Box = "Major" | "Minor" | "Patch";
const check = (body: string, box: Box) => body.replace(`- [ ] ${box}`, `- [x] ${box}`);
const uncheck = (body: string, box: Box) => body.replace(`- [x] ${box}`, `- [ ] ${box}`);
const templateWith = (box: Box) => check(uncheck(TEMPLATE, "Patch"), box);

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

const CURRENT_VERSION = "1.0.16";

async function next(args: string[], env: Record<string, string> = {}): Promise<string> {
  const result = await run(["--current", CURRENT_VERSION, ...args], env);
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trimEnd();
}

const nextForBody = (body: string) => next(["--pr-body", body]);

type Pull = { number: number; merged_at: string | null; merge_commit_sha: string; body: string };
const pulls = (...prs: Pull[]) => JSON.stringify(prs);

describe("next-release-version.sh PR template checkboxes", () => {
  it("bumps patch for the unedited template", async () => {
    assert.equal(await nextForBody(TEMPLATE), "1.0.17");
  });

  it("bumps minor when Minor is checked", async () => {
    assert.equal(await nextForBody(templateWith("Minor")), "1.1.0");
  });

  it("bumps major when Major is checked", async () => {
    assert.equal(await nextForBody(templateWith("Major")), "2.0.0");
  });

  it("matches checkboxes case-insensitively", async () => {
    assert.equal(await nextForBody("# Release info\n- [X] major"), "2.0.0");
    assert.equal(await nextForBody("# Release info\n- [x] MINOR"), "1.1.0");
  });

  it("prefers Major over Minor and Minor over Patch", async () => {
    assert.equal(await nextForBody(check(templateWith("Minor"), "Major")), "2.0.0");
    assert.equal(await nextForBody(check(TEMPLATE, "Minor")), "1.1.0");
  });

  it("falls back to patch when no box is checked", async () => {
    assert.equal(await nextForBody(uncheck(TEMPLATE, "Patch")), "1.0.17");
  });

  it("falls back to patch for a body without checkboxes", async () => {
    assert.equal(await nextForBody("Fixes the download splash on small screens."), "1.0.17");
  });

  it("falls back to patch for an empty body", async () => {
    assert.equal(await nextForBody(""), "1.0.17");
  });

  it("parses CRLF line endings", async () => {
    assert.equal(await nextForBody(templateWith("Major").replace(/\n/g, "\r\n")), "2.0.0");
    const scoped = "# What changed?\r\n- [x] Major cleanup\r\n# Release info\r\n- [x] Patch\r\n";
    assert.equal(await nextForBody(scoped), "1.0.17");
  });
});

describe("next-release-version.sh Release info section", () => {
  it("ignores checked boxes under What changed? when Release info has Patch", async () => {
    const body = TEMPLATE.replace("# What changed?\n\n- ", "# What changed?\n\n- [x] Major rewrite of the gallery");
    assert.equal(await nextForBody(body), "1.0.17");
  });

  it("reads the whole body when there is no Release info heading", async () => {
    assert.equal(await nextForBody("# What changed?\n- [x] Major rewrite of the gallery"), "2.0.0");
  });

  it("accepts a level-two Release info heading", async () => {
    assert.equal(await nextForBody("## What changed?\n- [x] Major\n\n## Release info\n- [x] Minor"), "1.1.0");
  });

  it("ends the section at the next heading", async () => {
    assert.equal(await nextForBody("# Release info\n- [x] Patch\n\n# Notes\n- [x] Major"), "1.0.17");
  });

  it("ends the section at the agent body end marker", async () => {
    const body = "# Release info\n- [x] Patch\n<!-- CURSOR_AGENT_PR_BODY_END -->\n- [x] Major";
    assert.equal(await nextForBody(body), "1.0.17");
  });
});

describe("next-release-version.sh version math", () => {
  const cases: Array<[current: string, releaseType: string, expected: string]> = [
    ["1.0.16", "patch", "1.0.17"],
    ["1.0.16", "minor", "1.1.0"],
    ["1.0.16", "major", "2.0.0"],
    ["0.1.0", "patch", "0.1.1"],
    ["0.1.0", "minor", "0.2.0"],
    ["0.1.0", "major", "1.0.0"],
    ["1.2.3-beta.1", "patch", "1.2.4"],
    ["1.2.3-beta.1", "minor", "1.3.0"],
    ["1.2.3-beta.1", "major", "2.0.0"],
    ["2", "patch", "2.0.1"],
    ["1.4", "minor", "1.5.0"],
  ];
  for (const [current, releaseType, expected] of cases) {
    it(`bumps ${current} by ${releaseType} to ${expected}`, async () => {
      const result = await run(["--current", current, "--release-type", releaseType]);
      assert.equal(result.stdout, `${expected}\n`, result.stderr);
    });
  }

  it("reads the current version from GATTEY_CURRENT_VERSION", async () => {
    const result = await run(["--release-type", "minor"], { GATTEY_CURRENT_VERSION: "3.4.5" });
    assert.equal(result.stdout, "3.5.0\n", result.stderr);
  });

  it("rejects a current version that is not numeric", async () => {
    const result = await run(["--current", "v1.x", "--release-type", "patch"]);
    assert.equal(result.status, 2);
    assert.equal(result.stdout, "");
    assert.match(result.stderr, /'v1\.x'/);
  });
});

describe("next-release-version.sh release type sources", () => {
  let dir = "";
  const eventFile = (name: string, event: object) => {
    const path = join(dir, name);
    writeFileSync(path, JSON.stringify(event));
    return path;
  };

  before(() => {
    dir = mkdtempSync(join(tmpdir(), "next-release-version-"));
  });
  after(() => rmSync(dir, { recursive: true, force: true }));

  it("uses --release-type over the PR body", async () => {
    assert.equal(await next(["--release-type", "major", "--pr-body", templateWith("Minor")]), "2.0.0");
  });

  it("uses GATTEY_RELEASE_TYPE case-insensitively", async () => {
    assert.equal(await next([], { GATTEY_RELEASE_TYPE: "Minor" }), "1.1.0");
  });

  it("uses --release-type over GATTEY_RELEASE_TYPE", async () => {
    assert.equal(await next(["--release-type", "patch"], { GATTEY_RELEASE_TYPE: "major" }), "1.0.17");
  });

  it("ignores an empty GATTEY_RELEASE_TYPE from push events", async () => {
    assert.equal(await next(["--pr-body", templateWith("Major")], { GATTEY_RELEASE_TYPE: "" }), "2.0.0");
  });

  for (const [label, args, env] of [
    ["--release-type", ["--release-type", "huge"], {}],
    ["GATTEY_RELEASE_TYPE", [], { GATTEY_RELEASE_TYPE: "huge" }],
  ] as const) {
    it(`rejects an invalid release type from ${label}`, async () => {
      const result = await run(["--current", "1.0.16", ...args], env);
      assert.equal(result.status, 2);
      assert.equal(result.stdout, "");
      assert.match(result.stderr, /'huge'/);
    });
  }

  it("reads the PR body from GATTEY_PR_BODY", async () => {
    assert.equal(await next([], { GATTEY_PR_BODY: templateWith("Minor") }), "1.1.0");
  });

  it("uses --pr-body over the event payload", async () => {
    const event = eventFile("major-pr.json", { pull_request: { body: templateWith("Major") } });
    assert.equal(await next(["--pr-body", templateWith("Minor"), "--event-path", event]), "1.1.0");
  });

  it("reads pull_request.body from --event-path", async () => {
    const event = eventFile("minor-pr.json", { pull_request: { body: templateWith("Minor") } });
    assert.equal(await next(["--event-path", event]), "1.1.0");
  });

  it("reads pull_request.body from GITHUB_EVENT_PATH", async () => {
    const event = eventFile("major-pr-env.json", { pull_request: { body: templateWith("Major") } });
    assert.equal(await next([], { GITHUB_EVENT_PATH: event }), "2.0.0");
  });

  it("uses the event body over the merged PR", async () => {
    const event = eventFile("major-pr-over-pulls.json", { pull_request: { body: templateWith("Major") } });
    const merged = pulls({ number: 3, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: "abc", body: templateWith("Minor") });
    assert.equal(await next(["--event-path", event], { GATTEY_PULLS_JSON: merged }), "2.0.0");
  });

  it("falls through a push payload to the merged PR", async () => {
    const event = eventFile("push.json", { before: "0123abc", after: "abc" });
    const merged = pulls({ number: 3, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: "abc", body: templateWith("Minor") });
    assert.equal(await next(["--event-path", event], { GATTEY_PULLS_JSON: merged, GITHUB_SHA: "abc" }), "1.1.0");
  });

  it("prefers the merged PR whose merge commit is GITHUB_SHA", async () => {
    const prs = pulls(
      { number: 5, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: "aaa", body: templateWith("Minor") },
      { number: 9, merged_at: "2026-10-02T00:00:00Z", merge_commit_sha: "bbb", body: templateWith("Major") },
    );
    assert.equal(await next([], { GATTEY_PULLS_JSON: prs, GITHUB_SHA: "aaa" }), "1.1.0");
  });

  it("picks the highest-numbered merged PR when no merge commit matches", async () => {
    const prs = pulls(
      { number: 9, merged_at: "2026-10-02T00:00:00Z", merge_commit_sha: "bbb", body: templateWith("Major") },
      { number: 5, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: "aaa", body: templateWith("Minor") },
    );
    assert.equal(await next([], { GATTEY_PULLS_JSON: prs, GITHUB_SHA: "ccc" }), "2.0.0");
  });

  it("skips an unmerged PR and falls back to the commit message", async () => {
    const open = pulls({ number: 4, merged_at: null, merge_commit_sha: "abc", body: templateWith("Major") });
    const env = { GATTEY_PULLS_JSON: open, GITHUB_SHA: "abc", GATTEY_COMMIT_MESSAGE: templateWith("Minor") };
    assert.equal(await next([], env), "1.1.0");
  });

  it("falls back to patch when there are no PRs and the commit message has no boxes", async () => {
    const env = { GATTEY_PULLS_JSON: "[]", GATTEY_COMMIT_MESSAGE: "Fix typo in the download page" };
    assert.equal(await next([], env), "1.0.17");
  });

  it("reads checkboxes from the commit message", async () => {
    assert.equal(await next([], { GATTEY_COMMIT_MESSAGE: `Ship albums (#12)\n\n${templateWith("Major")}` }), "2.0.0");
  });
});

describe("next-release-version.sh GitHub API lookup", () => {
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

  const apiEnv = (extra: Record<string, string> = {}) => ({
    GITHUB_API_URL: baseUrl,
    GITHUB_REPOSITORY: "dgattey/gattey-photos",
    GITHUB_SHA: "abc123",
    GH_TOKEN: "test-token",
    ...extra,
  });

  it("reads the merged PR for GITHUB_SHA with the GH_TOKEN", async () => {
    requests.length = 0;
    reply = {
      status: 200,
      body: pulls({ number: 7, merged_at: "2026-10-01T00:00:00Z", merge_commit_sha: "abc123", body: templateWith("Minor") }),
    };
    assert.equal(await next([], apiEnv()), "1.1.0");
    assert.equal(requests.length, 1);
    assert.equal(requests[0].url, "/repos/dgattey/gattey-photos/commits/abc123/pulls");
    assert.equal(requests[0].headers.authorization, "Bearer test-token");
  });

  it("falls back to the commit message when the API request fails", async () => {
    reply = { status: 500, body: "{}" };
    assert.equal(await next([], apiEnv({ GATTEY_COMMIT_MESSAGE: templateWith("Minor") })), "1.1.0");
  });
});
