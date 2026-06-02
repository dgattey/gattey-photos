import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { mintSessionToken, verifySessionToken } from "./auth";

describe("session tokens", () => {
  const secret = "test-family-password";

  it("mints and verifies a token", () => {
    const token = mintSessionToken(secret);
    assert.ok(token.includes("."));
    assert.equal(verifySessionToken(secret, token), true);
  });

  it("rejects the raw password as a session token", () => {
    assert.equal(verifySessionToken(secret, secret), false);
  });

  it("rejects tampered tokens", () => {
    const token = mintSessionToken(secret);
    assert.equal(verifySessionToken(secret, `${token}x`), false);
    assert.equal(verifySessionToken("other-secret", token), false);
  });
});
