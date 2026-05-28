export default function Home() {
  return (
    <main style={{ fontFamily: "system-ui", padding: 24 }}>
      <h1>Gattey Photos sync API</h1>
      <p>Use GET /api/gallery with Authorization: Bearer &lt;password&gt;.</p>
      <p>
        Local dev: set <code>GATTEY_LOCAL_STORAGE=1</code> and{" "}
        <code>SYNC_PASSWORD</code> in <code>.env.local</code>.
      </p>
    </main>
  );
}
