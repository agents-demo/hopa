# Backend week 1, slice B: Postgres, RLS, pairing, wake, traces, deploy

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking.

**Goal:** Replace slice A's in-memory seams with Postgres behind row-level
security, pair a device with a QR code and opaque tokens, refill the queue with
the same rows after a restart, wake an offline phone through FCM without leaking
payload, record the trace of every message, and ship the container through
Render's Blueprint.

**Architecture:** One Gradle build, `services/backend`, that includes `:core` and
`:data`. `store/Database` owns the Hikari pool and the only two ways to touch SQL:
`tenant(householdId)` sets `hopa.household_id` for the transaction, and
`token(hash)` sets `hopa.token_hash` so a token row can only be read by a caller
who already holds that token. Repositories are plain JDBC behind the slice-A
interfaces (`AuthPort`, `DeviceDirectory`, `TaskStore`, plus new `PushPort`,
`TraceRecorder`, `EventLog`), so the gateway and router keep working unchanged in
their tests. `FakeDevice` stays the phone and the PC; a JDK `HttpServer` is the
fake FCM, so wake assertions also travel a real socket.

**Tech Stack:** Kotlin 2.0.21, JDK 17 toolchain (JDK 21 runs Gradle), Ktor 3.0.3,
kotlinx.serialization 1.7.3, JUnit 4, PostgreSQL 16 via Testcontainers 1.21.4,
Flyway 11.20.3, HikariCP 6.3.3, PostgreSQL JDBC 42.7.14.

**Spec:** [`../week1.md`](../week1.md) — §3 decisions, §4 protocol v0, §6 data
model, §8 exit check. Slice A is [`week1.md`](week1.md).

## Global Constraints

- Kotlin 2.0.21, Ktor **3.0.3**, `jvmToolchain(17)`; do not bump the shared
  catalog's Kotlin.
- PostgreSQL **16** (`postgres:16-alpine` in tests), Flyway **11.20.3**,
  HikariCP **6.3.3**, driver **42.7.14**, Testcontainers **1.21.4**.
- Plain SQL over JDBC. No ORM, no query builder.
- Every tenant statement runs inside `Database.tenant(householdId)`; every token
  lookup runs inside `Database.token(hashHex)`. A raw pool connection outside
  those helpers is a review failure.
- RLS is `ENABLE`d **and** `FORCE`d on all ten tables. Tests connect as
  `hopa_app` (`NOSUPERUSER NOBYPASSRLS`); a superuser bypasses RLS and would make
  the isolation test a lie.
- Opaque tokens: 32 random bytes, base64url, no padding; only the SHA-256 hash is
  stored. Access 15 min, refresh 30 days, refresh single use.
- `household_id` never appears on the wire; `from` is always the server-side
  device id.
- Access tokens are checked on every gateway connection and every `/v1` request
  except health, version, claim and refresh.
- Frame cap 64 KiB (slice A); 20 messages/s per device; 5 pairing sessions per
  minute per address; 6 wakes per minute per device, deduplicated per task.
- FCM HTTP v1: data-only, `priority: high`, `ttl: 300s`, **no body content**.
- Trace: a valid `traceparent` is preserved, anything else is replaced; the
  assigned value is echoed. Spans: `accept`, `route`, `deliver`, `ack`, `wake`.
- Logs are JSON on stdout with `trace_id`, `household_id`, `device_id`, `task_id`
  when known. Never a token, never a body.
- Deploy: Render Blueprint, region `frankfurt`, Render Postgres 16, free web
  service for v0; migrations run on boot before the listener starts.
- Docker Desktop must be running (`docker info` succeeds) before `:test`.
- Run everything from the repository root on Windows PowerShell. Tests:
  `apps\android\gradlew.bat -p services/backend :test --rerun-tasks`.

## Review Focus

1. A repository call on a pool connection without `SET LOCAL hopa.household_id`
   returns another household's rows. (`TenantIsolationTest`)
2. A refresh token used twice after rotation leaves the device signed in.
   (`TokenRotationTest`)
3. A queued task for an offline phone produces zero wakes or more than six per
   minute, or the same task wakes twice. (`WakeTest`)
4. The gateway keeps accepting a token after the device is revoked, because the
   5-second cache never expires or is never invalidated. (`PostgresAuthTest`)
5. A second boot re-runs `V1__init.sql`, or the container serves traffic before
   migrations finish. (`DatabaseTest`, `MainTest`)

---

### Task B1: Postgres pool, schema v0, migrations on boot, DB health

**Files:**
- Modify: `apps/android/gradle/libs.versions.toml`
- Modify: `services/backend/build.gradle.kts`
- Create: `services/backend/src/main/resources/db/migration/V1__init.sql`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/store/Database.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/store/DbProbe.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/Main.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/http/HealthRoutes.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/harness/PostgresHarness.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/store/DatabaseTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/http/HealthDbTest.kt`

**Interfaces:**
- Consumes: slice A's `ServerConfig`, `module`, `HealthResponse`.
- Produces:
  ```kotlin
  class Database(dataSource: HikariDataSource) : AutoCloseable {
      internal val dataSource: HikariDataSource
      fun migrate(): Int
      fun <T> tenant(householdId: String, block: (Connection) -> T): T
      fun <T> token(tokenHashHex: String, block: (Connection) -> T): T
      companion object {
          fun connect(jdbcUrl: String, user: String, password: String, maxPoolSize: Int = 10): Database
          fun fromEnvironment(env: Map<String, String> = System.getenv()): Database?
      }
  }
  fun interface DbProbe {
      fun status(): String              // "ok" | "down" | "unconfigured"
      fun queueDepth(householdId: String): Int? = null
  }
  class PostgresProbe(db: Database) : DbProbe
  ```

- [ ] **Step 1: Write the failing database tests**

`PostgresHarness.kt` (test source; one container for the JVM):

```kotlin
object PostgresHarness {
    private val container by lazy {
        PostgreSQLContainer<Nothing>("postgres:16-alpine").apply {
            withDatabaseName("hopa")
            withUsername("postgres")
            withPassword("postgres")
            start()
        }
    }
    private var prepared = false

    fun adminDatabase(): Database {
        val db = Database.connect(container.jdbcUrl, "postgres", "postgres")
        prepare(db)
        return db
    }

    fun appDatabase(): Database {
        adminDatabase()
        return Database.connect(container.jdbcUrl, "hopa_app", "hopa_app")
    }

    private fun prepare(admin: Database) {
        if (prepared) return
        synchronized(this) {
            if (prepared) return
            admin.migrate()
            admin.tenant("00000000-0000-0000-0000-000000000000") { c ->
                c.createStatement().use { s ->
                    s.execute(
                        """
                        DO $$ BEGIN
                          IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hopa_app') THEN
                            CREATE ROLE hopa_app LOGIN PASSWORD 'hopa_app' NOSUPERUSER NOBYPASSRLS;
                          END IF;
                        END $$;
                        GRANT USAGE ON SCHEMA public TO hopa_app;
                        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hopa_app;
                        """.trimIndent(),
                    )
                }
            }
            prepared = true
        }
    }
}
```

`DatabaseTest.kt`:

```kotlin
class DatabaseTest {
    @Test
    fun `migrations apply from empty and a second run is a no-op`() {
        val db = PostgresHarness.adminDatabase()
        db.migrate()
        assertEquals(0, db.migrate())
    }

    @Test
    fun `a connection without a household setting sees no rows`() {
        val db = PostgresHarness.appDatabase()
        val household = UUID.randomUUID().toString()
        val device = UUID.randomUUID().toString()
        seedHousehold(db, household, device, UUID.randomUUID().toString())

        val visible = db.dataSource.connection.use { c ->
            c.createStatement().use { s ->
                s.executeQuery("select count(*) from devices").use { r -> r.next(); r.getInt(1) }
            }
        }

        assertEquals(0, visible)
    }

    @Test
    fun `a tenant transaction sees only its household`() {
        val db = PostgresHarness.appDatabase()
        val home = UUID.randomUUID().toString()
        seedHousehold(db, home, UUID.randomUUID().toString(), UUID.randomUUID().toString())

        val count = db.tenant(home) { c ->
            c.createStatement().use { s ->
                s.executeQuery("select count(*) from devices").use { r -> r.next(); r.getInt(1) }
            }
        }

        assertEquals(1, count)
    }

    @Test
    fun `a postgres url from the environment becomes a jdbc url`() {
        val db = Database.fromEnvironment(
            mapOf("DATABASE_URL" to "postgres://u:p%40ss@db.example:5432/hopa"),
        )
        assertNotNull(db)
        assertEquals("jdbc:postgresql://db.example:5432/hopa", db!!.dataSource.jdbcUrl)
        db.close()
    }
}
```

`seedHousehold` lives in `PostgresHarness.kt`:

```kotlin
fun seedHousehold(db: Database, household: String, device: String, member: String) {
    db.tenant(household) { c ->
        c.prepareStatement("insert into households(id, name) values (?::uuid, 'test')")
            .use { it.setString(1, household); it.executeUpdate() }
        c.prepareStatement(
            "insert into members(id, household_id, role, display_name) values (?::uuid, ?::uuid, 'owner', 'Test')",
        ).use { it.setString(1, member); it.setString(2, household); it.executeUpdate() }
        c.prepareStatement(
            """
            insert into devices(id, household_id, member_id, platform, name)
            values (?::uuid, ?::uuid, ?::uuid, 'android', 'Pixel')
            """.trimIndent(),
        ).use { it.setString(1, device); it.setString(2, household); it.setString(3, member); it.executeUpdate() }
    }
}
```

`HealthDbTest.kt`:

```kotlin
class HealthDbTest {
    @Test
    fun `health reports ok when postgres answers`() = testApplication {
        val db = PostgresHarness.appDatabase()
        application { module(ServerConfig(version = "0.1.0", db = PostgresProbe(db))) }

        val body = Json.parseToJsonElement(client.get("/v1/health").bodyAsText()).jsonObject

        assertEquals("ok", body["db"]!!.jsonPrimitive.content)
        assertNull(body["queueDepth"])
    }
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*DatabaseTest*" --tests "*HealthDbTest*"`

Expected: compile error — unresolved `Database`, `PostgresProbe`, `PostgreSQLContainer`.

- [ ] **Step 3: Add the dependencies, the schema and the helpers**

In `libs.versions.toml` add `flyway = "11.20.3"`, `hikari = "6.3.3"`,
`postgresql = "42.7.14"`, `testcontainers = "1.21.4"` and the aliases
`flyway-core`, `flyway-database-postgresql`, `hikaricp`, `postgresql`,
`testcontainers-postgresql`, `slf4j-simple` (version ref `slf4j`).

`build.gradle.kts` adds those as `implementation` (all but Testcontainers) and
`testImplementation(libs.testcontainers.postgresql)`.

`V1__init.sql` creates exactly these tables. Every tenant table gets
`household_id uuid not null`, and `member_id` where a person owns the row:

| Table | Columns |
|---|---|
| `households` | `id uuid pk`, `name text not null`, `created_at timestamptz not null default now()` |
| `members` | `id uuid pk`, `household_id`, `role text not null check (role in ('owner','member'))`, `display_name text not null`, `created_at` |
| `devices` | `id uuid pk`, `household_id`, `member_id`, `platform text not null check (platform in ('android','windows'))`, `name text not null`, `public_key bytea`, `alg text`, `push_token text`, `capabilities jsonb not null default '{}'::jsonb`, `last_seen_at timestamptz`, `revoked_at timestamptz`, `created_at` |
| `pairing_sessions` | `id uuid pk`, `household_id`, `member_id`, `code_hash bytea not null unique`, `expires_at timestamptz not null`, `claimed_at timestamptz`, `created_at` |
| `refresh_tokens` | `id uuid pk`, `device_id uuid not null`, `household_id`, `token_hash bytea not null unique`, `issued_at`, `expires_at`, `rotated_from uuid`, `revoked_at` |
| `access_tokens` | `id uuid pk`, `device_id uuid not null`, `household_id`, `token_hash bytea not null unique`, `expires_at` |
| `tasks` | `id uuid pk`, `household_id`, `member_id`, `from_device uuid not null`, `to_device uuid not null`, `message_id uuid not null`, `state text not null`, `trace_id text not null`, `body bytea not null`, `deadline_at timestamptz not null`, `created_at`, `updated_at`, `unique (household_id, message_id)` |
| `task_events` | `id bigserial pk`, `task_id uuid not null`, `household_id`, `member_id`, `seq int not null`, `kind text not null`, `body bytea`, `at timestamptz not null`, `unique (task_id, seq)` |
| `idempotency_keys` | `household_id`, `message_id uuid`, `response jsonb not null`, `expires_at timestamptz not null`, `primary key (household_id, message_id)` |
| `trace_spans` | `household_id`, `trace_id text not null`, `span_id text not null`, `operation text not null`, `device_id uuid`, `task_id uuid`, `started_at timestamptz not null`, `duration_ms bigint not null`, `status text not null check (status in ('ok','error'))`, `attributes jsonb not null default '{}'::jsonb`, `primary key (trace_id, span_id)` |

Then, at the end of the migration:

```sql
alter table households          enable row level security;
alter table households          force  row level security;
-- ... the same two lines for the other nine tables ...

create policy households_own on households
  using (id = current_setting('hopa.household_id', true)::uuid);

create policy members_own on members
  using (household_id = current_setting('hopa.household_id', true)::uuid);
-- devices, tasks, task_events, idempotency_keys, trace_spans: same shape, own column

create policy access_tokens_presented on access_tokens for select
  using (token_hash = decode(current_setting('hopa.token_hash', true), 'hex'));
create policy access_tokens_tenant_write on access_tokens for insert
  with check (household_id = current_setting('hopa.household_id', true)::uuid);
create policy access_tokens_tenant_update on access_tokens for update
  using (household_id = current_setting('hopa.household_id', true)::uuid)
  with check (household_id = current_setting('hopa.household_id', true)::uuid);
-- refresh_tokens: the same three policies, with its own token_hash.
-- pairing_sessions: select by code_hash, insert and update by household_id.
```

The split matters: reading a token is allowed only to the caller who already
holds it (`token()`), while issuing, rotating and revoking it happens in a
household transaction (`tenant()`). A single `FOR ALL` policy would make issuing a
token impossible, because no `hopa.token_hash` is set when the row is written.

`Database.tenant` opens a connection, `autoCommit = false`, runs
`select set_config('hopa.household_id', ?, true)`, runs the block, commits,
rolls back on throw. `token` does the same with `hopa.token_hash` and also clears
`hopa.household_id` so the two settings cannot combine. `migrate()` runs
`Flyway.configure().dataSource(dataSource).load().migrate()` and returns
`migrationsExecuted`.

`Database.fromEnvironment` accepts `DATABASE_URL` (`postgres://` or
`postgresql://`) or `JDBC_DATABASE_URL` (`jdbc:postgresql://`), converts to the
JDBC URL, URL-decodes user and password, and returns `null` when neither is set.
`connect` sets `maximumPoolSize`, `connectionTimeout = 10_000`, and
`dataSourceClassName` left to the driver.

`PostgresProbe` reports `ok` when `select 1` succeeds and `down` otherwise; it
never throws. `queueDepth(householdId)` counts `tasks` with
`state in ('queued','delivered')` inside `tenant(householdId)`.

`ServerConfig` gains `val db: DbProbe = DbProbe { "unconfigured" }`; `Main` calls
`Database.fromEnvironment()?.also { it.migrate() }` before `embeddedServer`, and
passes `PostgresProbe(db)` when present. Health emits `queueDepth` only when
`config.auth.deviceFor(bearer)` resolves: the module's JSON uses
`explicitNulls = false`, so an absent depth is omitted rather than sent as `null`.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*DatabaseTest*" --tests "*HealthDbTest*"`

Expected: PASS, 5 tests. Docker must be running; if not, the failure says
`Could not find a valid Docker environment`.

- [ ] **Step 5: Commit**

```powershell
git add apps/android/gradle/libs.versions.toml services/backend
git commit -m "feat(backend): postgres schema v0 behind forced row-level security"
```

---

### Task B2: Tenant isolation, including the 1,000-attempt suite

**Files:**
- Create: `services/backend/src/test/kotlin/com/hopa/backend/store/TenantIsolationTest.kt`
- Modify: `.github/workflows/ci.yml` (backend job env)

**Interfaces:**
- Consumes: `Database.tenant`, `seedHousehold`, the policies from B1.
- Produces: nothing new; this task is the proof B1's policies hold.

- [ ] **Step 1: Write the failing isolation tests**

```kotlin
class TenantIsolationTest {
    private val db = PostgresHarness.appDatabase()

    @Test
    fun `a cross-household select by id returns zero rows`() {
        val (home, other) = twoHouseholds()
        val foreignDevice = deviceOf(other)

        val seen = db.tenant(home) { c ->
            c.prepareStatement("select count(*) from devices where id = ?::uuid").use { s ->
                s.setString(1, foreignDevice)
                s.executeQuery().use { r -> r.next(); r.getInt(1) }
            }
        }

        assertEquals(0, seen)
    }

    @Test
    fun `a token row can only be read by the caller holding it`() {
        val (home, _) = twoHouseholds()
        val hash = ByteArray(32) { 7 }
        db.tenant(home) { c ->
            c.prepareStatement(
                "insert into access_tokens(id, device_id, household_id, token_hash, expires_at) " +
                    "values (gen_random_uuid(), ?::uuid, ?::uuid, ?, now() + interval '15 minutes')",
            ).use {
                it.setString(1, deviceOf(home)); it.setString(2, home); it.setBytes(3, hash)
                it.executeUpdate()
            }
        }

        val byOtherHash = db.token("00".repeat(32)) { c ->
            c.createStatement().use { s ->
                s.executeQuery("select count(*) from access_tokens").use { r -> r.next(); r.getInt(1) }
            }
        }

        assertEquals(0, byOtherHash)
    }

    @Test
    fun `a thousand cross-household reads leak nothing`() {
        val attempts = System.getenv("HOPA_ISOLATION_ATTEMPTS")?.toIntOrNull() ?: 1_000
        val (home, other) = twoHouseholds()
        val foreign = (1..50).map { seedTask(db, other, UUID.randomUUID().toString()) }
        var checked = 0
        repeat(attempts) {
            val target = foreign.random()
            val seen = db.tenant(home) { c ->
                c.prepareStatement("select count(*) from tasks where id = ?::uuid").use { s ->
                    s.setString(1, target)
                    s.executeQuery().use { r -> r.next(); r.getInt(1) }
                }
            }
            assertEquals(0, seen)
            checked++
        }
        assertEquals(attempts, checked)
    }
}
```

Helpers: `twoHouseholds()` returns two fresh UUIDs and seeds a member and device
in each; `seedTask(db, household, messageId)` inserts a `queued` row and returns
its id.

- [ ] **Step 2: Run it to watch it fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*TenantIsolationTest*"`

Expected: FAIL until the policies are right — a missing `FORCE` shows the row, a
missing `tenant` wrapper errors on the GUC cast.

- [ ] **Step 3: Fix the schema or helper, not the test**

Only change `V1__init.sql` (policy shape, `FORCE`) or `Database`. Never weaken an
assertion. Add `HOPA_ISOLATION_ATTEMPTS: "1000"` to the backend job's `env` in
`.github/workflows/ci.yml`.

- [ ] **Step 4: Run it**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*TenantIsolationTest*"`

Expected: PASS, 3 tests (about 10 s for 1,000 reads).

- [ ] **Step 5: Commit**

```powershell
git add services/backend .github/workflows/ci.yml
git commit -m "test(backend): prove tenant isolation with a thousand attempts"
```

---

### Task B3: Pairing sessions, claim, and the first opaque tokens

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/Tokens.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/TokenIssuer.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/PairingApi.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/PairingRoutes.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/http/HttpErrors.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/http/RateLimiter.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/Main.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/pairing/PairingHttpTest.kt`

**Interfaces:**
- Consumes: `Database.tenant`, `Database.token`, `DbProbe`.
- Produces:
  ```kotlin
  object Tokens {
      fun mint(): String                       // 43-char base64url, no padding
      fun hash(token: String): ByteArray       // SHA-256
      fun hex(bytes: ByteArray): String
  }
  data class Issued(val token: String, val expiresAt: String)
  class TokenIssuer(db: Database, clock: () -> Long = System::currentTimeMillis,
                    onRevoke: (deviceId: String) -> Unit = {}) {
      fun issueAccess(deviceId: String, householdId: String, memberId: String): Issued
      fun issueRefresh(deviceId: String, householdId: String, rotatedFrom: String? = null): Issued
  }
  class PairingService(db: Database, clock: () -> Long = System::currentTimeMillis,
                       publicHost: String = "hopa-backend.onrender.com") : PairingApi
  interface PairingApi {
      fun mint(householdName: String, memberName: String, remoteAddress: String): PairingOutcome<Minted>
      fun claim(request: ClaimRequest, remoteAddress: String): PairingOutcome<Claimed>
  }
  sealed interface PairingOutcome<out T> {
      data class Ok<T>(val value: T) : PairingOutcome<T>
      data class Refused(val code: String, val message: String, val retryable: Boolean = false) : PairingOutcome<Nothing>
  }
  data class Minted(val session: String, val qr: String, val expiresAt: String)
  data class ClaimRequest(val session: String, val platform: String, val name: String,
                          val publicKey: String, val alg: String, val pushToken: String?)
  data class Claimed(val deviceId: String, val householdId: String, val accessToken: String,
                     val refreshToken: String, val expiresAt: String)
  class RateLimiter(limit: Int, windowMs: Long, clock: () -> Long = System::currentTimeMillis) {
      fun allow(key: String): Boolean
  }
  ```

- [ ] **Step 1: Write the failing pairing tests**

```kotlin
class PairingHttpTest {
    private val db = PostgresHarness.appDatabase()
    private val clock = AtomicLong(1_763_212_800_000)
    private fun config() = ServerConfig(
        version = "0.1.0",
        bootstrapToken = "boot-secret",
        pairing = PairingService(db, clock = clock::get),
    )

    @Test
    fun `a bootstrap token mints a QR session that expires in five minutes`() = testApplication {
        application { module(config()) }
        val response = client.post("/v1/pair/sessions") {
            header(HttpHeaders.Authorization, "Bearer boot-secret")
            contentType(ContentType.Application.Json)
            setBody("""{"householdName":"Levi","memberName":"Amir"}""")
        }
        assertEquals(HttpStatusCode.Created, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        val qr = body["qr"]!!.jsonPrimitive.content
        assertTrue(qr.startsWith("hopa://pair?v=1&h="))
        assertTrue(qr.contains("&p="))
        assertEquals(clock.get() + 300_000, Instant.parse(body["expiresAt"]!!.jsonPrimitive.content).toEpochMilli())

        val plain = qr.substringAfter("&p=").substringBefore("&")
        val household = qr.substringAfter("h=").substringBefore("&")
        val stored = db.tenant(household) { c ->
            c.createStatement().use { s ->
                s.executeQuery("select encode(code_hash,'hex') from pairing_sessions").use { r -> r.next(); r.getString(1) }
            }
        }
        assertNotEquals(plain, stored)
        assertEquals(Tokens.hex(Tokens.hash(plain)), stored)
    }

    @Test
    fun `a claim creates the device and returns working opaque tokens`() = testApplication {
        application { module(config()) }
        val minted = mint(client, "Levi", "Amir")
        val session = minted.qr.substringAfter("&p=").substringBefore("&")

        val response = claim(client, session)
        assertEquals(HttpStatusCode.Created, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        val access = body["accessToken"]!!.jsonPrimitive.content
        val refresh = body["refreshToken"]!!.jsonPrimitive.content

        assertTrue(access.length >= 43)
        val hashes = db.tenant(body["householdId"]!!.jsonPrimitive.content) { c ->
            c.createStatement().use { s ->
                s.executeQuery("select encode(token_hash,'hex') from access_tokens union all " +
                    "select encode(token_hash,'hex') from refresh_tokens").use { r ->
                    buildList { while (r.next()) add(r.getString(1)) }
                }
            }
        }
        assertFalse(hashes.contains(access))
        assertTrue(hashes.contains(Tokens.hex(Tokens.hash(access))))
    }

    @Test
    fun `a session cannot be claimed twice`() = testApplication {
        application { module(config()) }
        val session = mint(client, "Levi", "Amir").qr.substringAfter("&p=").substringBefore("&")
        assertEquals(HttpStatusCode.Created, claim(client, session).status)
        val again = claim(client, session)
        assertEquals(HttpStatusCode.BadRequest, again.status)
        assertEquals("E_SCHEMA", errorCode(again))
    }

    @Test
    fun `an expired or unknown session is refused`() = testApplication {
        application { module(config()) }
        val session = mint(client, "Levi", "Amir").qr.substringAfter("&p=").substringBefore("&")
        clock.addAndGet(300_001)

        val expired = claim(client, session)
        assertEquals(HttpStatusCode.BadRequest, expired.status)
        assertEquals(HttpStatusCode.BadRequest, claim(client, Tokens.mint()).status)
    }

    @Test
    fun `a missing or wrong bootstrap token is E_AUTH`() = testApplication {
        application { module(config()) }
        val none = client.post("/v1/pair/sessions") { setBody("{}") }
        assertEquals(HttpStatusCode.Unauthorized, none.status)
        assertEquals("E_AUTH", errorCode(none))

        val wrong = client.post("/v1/pair/sessions") {
            header(HttpHeaders.Authorization, "Bearer nope")
            contentType(ContentType.Application.Json)
            setBody("""{"householdName":"Levi","memberName":"Amir"}""")
        }
        assertEquals(HttpStatusCode.Unauthorized, wrong.status)
    }

    @Test
    fun `the sixth session from one address in a minute is E_RATE`() = testApplication {
        application { module(config()) }
        repeat(5) { assertNotEquals(HttpStatusCode.TooManyRequests, mint(client, "L", "A", "203.0.113.7").status) }
        val sixth = mint(client, "L", "A", "203.0.113.7")
        assertEquals(HttpStatusCode.TooManyRequests, sixth.status)
        assertEquals("E_RATE", errorCode(sixth))
    }
}
```

Test helpers `mint`, `claim`, `errorCode` live in the test file.

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*PairingHttpTest*"`

Expected: compile error — unresolved `PairingService`, `ServerConfig.bootstrapToken`.

- [ ] **Step 3: Implement the tokens, the service and the routes**

`TokenIssuer.issueAccess` inserts `(device_id, household_id, token_hash,
expires_at = now + 15 min)` inside `tenant(householdId)` and returns the plain
token. `issueRefresh` does the same with 30 days and optional `rotated_from`.
`Minted.qr` is
`hopa://pair?v=1&h=<householdId>&p=<session>&u=wss://<host>/v1/gateway`; the host
comes from `HOPA_PUBLIC_HOST` (default `hopa-backend.onrender.com`).

`PairingService` is the only `PairingApi` implementation. `mint` generates
household and member UUIDs, then in one `tenant(household)` transaction inserts
the household, the owner member and the pairing session whose `code_hash` is
`Tokens.hash(session)`; TTL is 5 minutes. `claim` looks the session up inside
`token(Tokens.hex(Tokens.hash(session)))`, refuses when `claimed_at` is not null
or `expires_at <= now`, then in `tenant(session.householdId)` inserts the device
(`public_key = Base64.getDecoder().decode(publicKey)`), marks the session
claimed and issues both tokens. The bootstrap token is compared in constant time
in the route; missing `config.bootstrapToken` means the routes are not installed.

`PairingRoutes` maps `Refused` codes: `E_AUTH` → 401, `E_RATE` → 429 with
`Retry-After: 60`, everything else → 400. Error bodies are
`{code, message, retryable, traceId}` with `traceId` from `EnvelopeValidator.traceOf`.

Rate limits are `RateLimiter(5, 60_000)` keyed by the first `X-Forwarded-For`
value, falling back to `call.request.origin.remoteHost`.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*PairingHttpTest*"`

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```powershell
git add services/backend
git commit -m "feat(backend): QR pairing, claim and opaque tokens"
```

---

### Task B4: Refresh rotation, reuse detection, and Postgres-backed auth

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/PgAuth.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/store/PgDevices.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/pairing/TokenRoutes.kt`
- Modify: `TokenIssuer.kt` (add `rotate` and `verify`)
- Modify: `tasks/TaskRouter.kt` (`lookup(to, householdId)`)
- Modify: `auth/AuthPort.kt` (`DeviceDirectory` gains push-token methods)
- Modify: `gateway/GatewayRoutes.kt` (`device.hello` records push token and last seen)
- Test: `services/backend/src/test/kotlin/com/hopa/backend/pairing/TokenRotationTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/pairing/PostgresAuthTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/gateway/HelloPersistenceTest.kt`

**Interfaces:**
- Consumes: B3's `Tokens`, `TokenIssuer`, `PairingService`, `PostgresHarness`.
- Produces:
  ```kotlin
  sealed interface RotateOutcome {
      data class Rotated(val access: Issued, val refresh: Issued) : RotateOutcome
      data object Refused : RotateOutcome
  }
  class TokenIssuer { fun rotate(refreshToken: String): RotateOutcome
                      fun verify(accessToken: String): DeviceIdentity? }
  class PgAuth(db: Database, clock: () -> Long = System::currentTimeMillis,
               cacheTtlMs: Long = 5_000) : AuthPort {
      override fun deviceFor(token: String): DeviceIdentity?
      fun revoke(deviceId: String)
  }
  class PgDevices(db: Database) : DeviceDirectory
  interface DeviceDirectory {
      fun lookup(deviceId: String, householdId: String): DeviceIdentity?
      fun pushToken(deviceId: String, householdId: String): String? = null
      fun touch(deviceId: String, householdId: String, pushToken: String?, at: Long) {}
      fun clearPushToken(deviceId: String, householdId: String) {}
  }
  ```

- [ ] **Step 1: Write the failing tests**

`TokenRotationTest.kt`:

```kotlin
@Test
fun `refresh rotates both tokens and the new pair works`() = testApplication {
    application { module(config()) }
    val first = claimOnce(client)
    val rotated = client.post("/v1/token/refresh") {
        contentType(ContentType.Application.Json)
        setBody("""{"refreshToken":"${first.refresh}"}""")
    }
    assertEquals(HttpStatusCode.OK, rotated.status)
    val body = Json.parseToJsonElement(rotated.bodyAsText()).jsonObject
    val newRefresh = body["refreshToken"]!!.jsonPrimitive.content
    assertNotEquals(first.refresh, newRefresh)

    assertEquals(HttpStatusCode.OK, refresh(client, newRefresh).status)
}

@Test
fun `reusing a rotated refresh token revokes the whole device family`() = testApplication {
    application { module(config()) }
    val first = claimOnce(client)
    val rotated = rotate(client, first.refresh)

    assertEquals(HttpStatusCode.Unauthorized, refresh(client, first.refresh).status)

    // Reuse is treated as theft: the new refresh and the live access token die too.
    assertEquals(HttpStatusCode.Unauthorized, refresh(client, rotated.refresh).status)

    val ws = FakeDevice(first.deviceId, rotated.access)
    ws.connect(http)
    assertEquals("E_AUTH", ws.expect("error").bodyString("code"))
}

@Test
fun `an expired access token is E_AUTH on the socket`() = testApplication {
    application { module(config()) }
    val first = claimOnce(client)
    db.tenant(first.householdId) { c ->
        c.createStatement().use { it.executeUpdate("update access_tokens set expires_at = now() - interval '1 minute'") }
    }
    val ws = FakeDevice(first.deviceId, first.access)
    ws.connect(http)
    assertEquals("E_AUTH", ws.expect("error").bodyString("code"))
}
```

`PostgresAuthTest.kt` (no HTTP): `deviceFor` returns the identity for a live
access token; returns null after `expires_at`; caches for 5 s (a second call does
not hit the DB — assert with a counting `DataSource` wrapper, or by deleting the
row and still resolving); `revoke(deviceId)` clears the cache and the next call
returns null.

`HelloPersistenceTest.kt`: connect a claimed device with `pushToken` in
`device.hello`; assert `devices.push_token` equals it and `last_seen_at` is not
null. Then `device.hello` with a different push token updates the column.

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*TokenRotationTest*" --tests "*PostgresAuthTest*" --tests "*HelloPersistenceTest*"`

Expected: compile error — unresolved `PgAuth`, `PgDevices`, `rotate`.

- [ ] **Step 3: Implement rotation, auth and hello persistence**

`rotate` works inside `token(hash)`:
1. Row missing, or `revoked_at` set **and** a row exists with
   `rotated_from = row.id` → reuse: in `tenant(household_id)` delete every
   `access_tokens` row for the device, set `revoked_at = now()` on its
   `refresh_tokens`, call `onRevoke(deviceId)`, return `Refused`.
2. Row expired → `Refused`.
3. Otherwise mark the row `revoked_at = now()`, issue a new refresh with
   `rotated_from = row.id`, and a new access token, return `Rotated`.

`PgAuth` hashes the presented token, reads the token row inside `token(hash)`,
then reads the device inside `tenant(householdId)` (device must be non-revoked and
the token unexpired), caches `hash → (identity, expiresAt)` for 5 s, and returns
null on any miss. `revoke(deviceId)` removes every cached entry for that device.

`PgDevices.lookup(deviceId, householdId)` runs in `tenant(householdId)` so RLS
answers the tenancy question; a device in another household returns null.
`touch` updates `push_token` (only when non-null) and `last_seen_at`.
`clearPushToken` sets it to null. `TaskRouter` now calls
`devices.lookup(to, identity.householdId)`; `MapDirectory` in tests implements the
new signature.

`gatewayRoutes` calls `devices.touch(identity.deviceId, identity.householdId,
pushTokenFrom(envelope.body), System.currentTimeMillis())` on `device.hello`.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test`

Expected: PASS, every test in the module (slice A included).

- [ ] **Step 5: Commit**

```powershell
git add services/backend
git commit -m "feat(backend): rotating refresh tokens and postgres auth"
```

---

### Task B5: The Postgres task store, idempotency for 24 h, restarts

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/store/PgTaskStore.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/log/EventLog.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskStore.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskRouter.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/tasks/InMemoryTaskStore.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/gateway/GatewayRoutes.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/tasks/PgTaskRoutingTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/tasks/TaskRoutingTest.kt`

**Interfaces:**
- Consumes: `Database`, `PgAuth`, `PgDevices`, `FakeDevice`.
- Produces:
  ```kotlin
  class PgTaskStore(db: Database, clock: () -> Long = System::currentTimeMillis) : TaskStore
  interface TaskStore {
      fun remember(householdId: String, messageId: String, task: TaskRecord)
      fun recall(householdId: String, messageId: String): TaskRecord?
      fun find(taskId: String): TaskRecord?
      fun update(task: TaskRecord)
      fun pendingFor(deviceId: String, now: Long): List<TaskRecord>
      fun markDelivered(taskId: String)
      fun event(taskId: String, householdId: String, kind: String, body: JsonObject, at: Long)
  }
  ```

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test
fun `a round-trip writes the task, the event and the ack`() { /* A -> B over WS with real DB; assert tasks row state, task_events kind, ack */ }

@Test
fun `the same message id three times creates one row and one delivery`() { /* replay; assert count(*) = 1 and B sees one frame */ }

@Test
fun `a cross-household target is refused and leaves no row`() { /* A(hh1) -> C(hh2); E_TENANT, count(*) = 0, log has tenant_refused */ }

@Test
fun `a queued task survives a restart and is delivered on hello`() {
    // phase 1: a router with store A queues while B is offline
    val queued = routeOffline(db, phone, pc)
    // phase 2: a brand-new store and app over the same database
    application { module(config(db)) }
    // B hellos; receives task.create with queued.task
}

@Test
fun `a task past its deadline is never delivered`() { /* insert deadline in the past; hello; expectNothing */ }

@Test
fun `the twenty-first message in one second is E_RATE`() {
    // config with RateLimiter(limit = 1, windowMs = 60_000)
    // first task.create gets an ack, second gets E_RATE
}

@Test
fun `idempotency expires after twenty four hours`() {
    // recall succeeds, then `update idempotency_keys set expires_at = now() - interval '1 second'`,
    // then recall returns null and a resend creates one new task
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*PgTaskRoutingTest*"`

Expected: compile error — unresolved `PgTaskStore`, `TaskStore.event`.

- [ ] **Step 3: Implement the store and wire the router**

`PgTaskStore` maps every method into `tenant(householdId)`:
- `remember` inserts `tasks` (`body = envelope.body.toString().toByteArray()`), then
  `idempotency_keys(response = {"taskId": ..., "state": ...}, expires_at =
  now + 24 h)` in one transaction; a row is read back with
  `Json.parseToJsonElement(String(bytes)).jsonObject`.
- `recall` reads `idempotency_keys` with `expires_at > now()`, then `tasks` by
  id; returns null when either is absent.
- `pendingFor` reads `state in ('queued','delivered')` and `deadline_at > now()`.
- `markDelivered` sets `state = 'delivered'`, `updated_at = now()`. This renames
  slice A's `sent` to the spec's `delivered` on the wire and in the table; update
  `TaskRoutingTest`'s two `"sent"` assertions in the same commit.
- `event` appends `task_events` with `seq = coalesce(max(seq), 0) + 1` for the
  task, inside the same transaction as the state change where there is one.

`ServerConfig` gains `tasks: TaskStore = InMemoryTaskStore()`,
`messageLimit: RateLimiter = RateLimiter(20, 1_000)` and `log: EventLog =
EventLog.None`. `TaskRouter` gains `traces: TraceRecorder = TraceRecorder.None`,
`push: PushPort = PushPort.None` and `log: EventLog = EventLog.None` (B7 and B6
supply the real ones). `gatewayRoutes` builds `TaskRouter(config.tasks, registry,
config.devices, ...)` and, before routing a non-hello frame, refuses with
`E_RATE` when `!config.messageLimit.allow(identity.deviceId)`.

`TaskRouter.create` appends a `create` event; `relay` appends the matching kind;
a refused tenancy logs `tenant_refused` with household and device ids, never the
target's household.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*PgTaskRoutingTest*"`

Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```powershell
git add services/backend
git commit -m "feat(backend): postgres task store with durable idempotency"
```

---

### Task B6: FCM wake for an offline target

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/push/PushPort.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/push/FcmSender.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/push/FcmAuth.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/push/GuardedPush.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskRouter.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/Main.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/harness/FakeFcm.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/push/WakeTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/push/FcmAuthTest.kt`

**Interfaces:**
- Consumes: `PgDevices.pushToken`, `PgDevices.clearPushToken`, `TaskRouter`.
- Produces:
  ```kotlin
  enum class PushOutcome { Delivered, InvalidToken, Retryable, Skipped }
  fun interface PushSender { fun send(token: String, data: Map<String, String>): PushOutcome }
  fun interface PushPort {
      fun wake(deviceId: String, taskId: String, traceId: String, pushToken: String): PushOutcome
      companion object { val None = PushPort { _, _, _, _ -> PushOutcome.Skipped } }
  }
  class FcmSender(projectId: String, baseUrl: String = "https://fcm.googleapis.com",
                  auth: FcmAuth, http: HttpClient = HttpClient.newHttpClient()) : PushSender
  fun interface FcmAuth { fun bearerToken(): String }
  class StaticFcmAuth(token: String) : FcmAuth
  data class JwtClaims(val iss: String, val scope: String, val aud: String, val iat: Long, val exp: Long)
  class ServiceAccountFcmAuth(credentialsJson: String, clock: () -> Long = ...) : FcmAuth {
      fun claims(nowSeconds: Long): JwtClaims
      fun assertion(nowSeconds: Long): String
  }
  class GuardedPush(sender: PushSender, wakesPerMinute: Int = 6,
                    clock: () -> Long = System::currentTimeMillis) : PushPort
  ```

- [ ] **Step 1: Write the failing wake tests**

`FakeFcm.kt` starts a JDK `HttpServer` on port 0 and records every request body,
returning 200, or 404 with `{"error":{"status":"UNREGISTERED"}}` when the token
starts with `dead-`.

```kotlin
@Test
fun `an offline target gets one data-only high-priority wake`() = testApplication {
    val fcm = FakeFcm().start()
    application { module(config(push = fcm.push(projectId = "hopa-test"))) }
    // A and B paired; B never connects
    // A sends task.create to B
    assertEquals(1, fcm.requests.size)
    val message = Json.parseToJsonElement(fcm.requests[0]).jsonObject["message"]!!.jsonObject
    assertEquals("token-b", message["token"]!!.jsonPrimitive.content)
    assertEquals("high", message["android"]!!.jsonObject["priority"]!!.jsonPrimitive.content)
    assertEquals("300s", message["android"]!!.jsonObject["ttl"]!!.jsonPrimitive.content)
    assertTrue(message["data"]!!.jsonObject.keys == setOf("taskId", "traceId"))
    assertFalse(fcm.requests[0].contains("goal"))
}

@Test
fun `an online target gets delivery and no wake`() { /* B connected; fcm.requests is empty */ }

@Test
fun `the seventh wake in a minute is suppressed`() { /* 7 offline tasks; 6 requests */ }

@Test
fun `the same task never wakes twice`() { /* two direct GuardedPush.wake calls with one taskId; 1 request */ }

@Test
fun `an unregistered token is cleared and the next hello restores it`() {
    // push_token = "dead-token"; wake returns InvalidToken; devices.push_token is null
    // hello with a new token; the column holds it again
}
```

`FcmAuthTest`: `ServiceAccountFcmAuth.claims(nowSeconds)` returns `iss =
client_email`, `scope = "https://www.googleapis.com/auth/firebase.messaging"`,
`aud = token_uri`, `iat = now`, `exp = now + 3600`; the signed JWT has three
dot-separated parts and its header is `{"alg":"RS256","typ":"JWT"}`.

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*WakeTest*" --tests "*FcmAuthTest*"`

Expected: compile error — unresolved `FakeFcm`, `GuardedPush`, `FcmSender`.

- [ ] **Step 3: Implement the sender, the guard and the router hook**

`FcmSender.send` posts to `{baseUrl}/v1/projects/{projectId}/messages:send` with
`Authorization: Bearer <token>` and:

```json
{"message":{"token":"<pushToken>","data":{"taskId":"...","traceId":"..."},
 "android":{"priority":"high","ttl":"300s"}}}
```

200/201 → `Delivered`; 404 with `UNREGISTERED` → `InvalidToken`; any other status
or an `IOException` → `Retryable`. It never throws.

`ServiceAccountFcmAuth` parses `client_email`, `private_key`, `token_uri`, signs
an RS256 JWT (`java.security.Signature`), exchanges it at the token URI with the
form grant `urn:ietf:params:oauth:grant-type:jwt-bearer`, and caches the token
until 60 s before expiry.

`GuardedPush.wake` first checks `wakesPerMinute` for the device and a per-task
dedupe window of 60 s, then calls the sender. `TaskRouter.create`, after writing
a `queued` task, calls `push.wake(to, task.id, traceId,
devices.pushToken(to, householdId))` when a token exists; on `InvalidToken` it
calls `devices.clearPushToken(to, householdId)`. `TaskRouter` gains
`push: PushPort = PushPort.None`.

`Main` constructs `GuardedPush(FcmSender(projectId, auth =
ServiceAccountFcmAuth(credentials)), ...[,])` from `HOPA_FCM_PROJECT` and
`HOPA_FCM_CREDENTIALS`; without them, `PushPort.None`.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*WakeTest*" --tests "*FcmAuthTest*"`

Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```powershell
git add services/backend
git commit -m "feat(backend): wake an offline device through fcm http v1"
```

---

### Task B7: Trace spans, trace lookup, and redacted JSON logs

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/trace/Trace.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/trace/PgTraceStore.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/trace/TraceRoutes.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/log/JsonEventLog.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskRouter.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/gateway/GatewayRoutes.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/trace/TraceQueryTest.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/log/JsonLogTest.kt`

**Interfaces:**
- Consumes: `Database.tenant`, `PgAuth`, `EnvelopeValidator.traceOf`.
- Produces:
  ```kotlin
  interface TraceRecorder {
      fun <T> span(householdId: String, traceId: String, operation: String,
                   deviceId: String?, taskId: String?, block: () -> T): T
      companion object { val None = object : TraceRecorder { override fun <T> span(...) = block() } }
  }
  interface TraceQuery { fun spans(householdId: String, traceId: String): List<SpanView> }
  data class SpanView(val operation: String, val startedAt: String, val durationMs: Long,
                      val status: String, val deviceId: String?, val taskId: String?)
  class PgTraceStore(db: Database, clock: () -> Long = ...) : TraceRecorder, TraceQuery
  object TraceIds { fun traceId(traceparent: String): String?; fun newTraceparent(): String }
  fun interface EventLog {
      fun event(name: String, fields: Map<String, String>)
      companion object { val None = EventLog { _, _ -> } }
  }
  class JsonEventLog(out: (String) -> Unit = { println(it) }, clock: () -> Long = ...) : EventLog
  ```

- [ ] **Step 1: Write the failing tests**

`TraceQueryTest.kt`:

```kotlin
@Test
fun `a round-trip records accept, route, deliver and ack under one trace`() = testApplication {
    // two paired devices, one task round-trip with a client-supplied traceparent
    val spans = getJson(client, "/v1/traces/$traceId")["spans"]!!.jsonArray
    assertEquals(setOf("accept", "route", "deliver", "ack"),
        spans.map { it.jsonObject["operation"]!!.jsonPrimitive.content }.toSet())
    assertTrue(spans.all { it.jsonObject["status"]!!.jsonPrimitive.content == "ok" })
}

@Test
fun `another household cannot read the trace`() = testApplication {
    // trace owned by hh-1, caller from hh-2
    assertEquals(HttpStatusCode.NotFound, response.status)
}

@Test
fun `a missing token is E_AUTH`() { /* GET /v1/traces/... -> 401 */ }

@Test
fun `a client traceparent is preserved and echoed`() { /* task.ack.trace contains the same 32 hex */ }
```

`JsonLogTest.kt`:

```kotlin
@Test
fun `a refusal logs identifiers but never the token or the body`() {
    val lines = mutableListOf<String>()
    val log = JsonEventLog(out = { lines += it }, clock = { 1_763_212_800_000 })
    log.event("tenant_refused", mapOf(
        "trace_id" to "a".repeat(32), "household_id" to "hh-1",
        "device_id" to "dev-a", "to" to "dev-b", "token" to "SEMEN",
        "body" to "find the lease",
    ))
    val json = Json.parseToJsonElement(lines.single()).jsonObject
    assertEquals("tenant_refused", json["event"]!!.jsonPrimitive.content)
    assertEquals("a".repeat(32), json["trace_id"]!!.jsonPrimitive.content)
    assertFalse(lines.single().contains("SEMEN"))
    assertFalse(lines.single().contains("find the lease"))
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*TraceQueryTest*" --tests "*JsonLogTest*"`

Expected: compile error — unresolved `TraceRecorder`, `JsonEventLog`, `TraceIds`.

- [ ] **Step 3: Implement the recorder, the query and the log filter**

`PgTraceStore.span` measures `System.nanoTime`, runs the block, and writes one row
inside `tenant(householdId)` with a fresh 8-byte span id, `status = ok` or
`error`, and `attributes = {}`; a write failure is swallowed and never fails the
request. `spans` reads ordered by `started_at`.

`TraceIds.traceId` validates the traceparent shape and returns the 32-hex middle
field; `newTraceparent` reuses `EnvelopeValidator.traceOf` on an envelope without
a trace.

`ServerConfig` gains `traces: TraceRecorder = TraceRecorder.None` and
`traceQuery: TraceQuery? = null`. `GatewayRoutes` wraps decode+validate in
`traces.span(..., "accept", ...)`. `TaskRouter` wraps `create` in `"route"`,
each delivery in `"deliver"`, each relayed `task.ack` in `"ack"`, and each wake in
`"wake"`. `TraceRoutes` authenticates with `config.auth`, returns 401 `E_AUTH`
without a token, and 404 `E_TENANT` when no span matches — the RLS scope means
"no match" also covers another household.

`JsonEventLog` serializes `{"event", "at", "trace_id", "household_id",
"device_id", "task_id", ...}` and drops any key in `setOf("token", "body",
"authorization", "refresh", "access")`. `Main` uses it for stdout.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*TraceQueryTest*" --tests "*JsonLogTest*"`

Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```powershell
git add services/backend
git commit -m "feat(backend): trace spans, trace lookup and redacted json logs"
```

---

### Task B8: Render Blueprint, container, exit run, evidence

**Files:**
- Create: `services/backend/Dockerfile`
- Create: `.dockerignore`
- Modify: `render.yaml`
- Create: `services/docs/guides/backend-deploy.md`
- Create: `services/backend/src/test/kotlin/com/hopa/backend/tools/ExitRun.kt`
- Modify: `services/backend/build.gradle.kts` (`exitRun` task)
- Test: `services/backend/src/test/kotlin/com/hopa/backend/tools/ExitRunTest.kt`
- Create: `docs/project/evidence/B1-gateway.md`
- Modify: `docs/README.md` (evidence row) and `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: everything above.
- Produces: `object ExitRun { fun run(url: String, tokenA: String, tokenB: String, rounds: Int = 20): List<String> }`
  returning one trace id per round-trip; `fun main(args: Array<String>)` parsing
  `--url`, `--token-a`, `--token-b`, `--rounds`.

- [ ] **Step 1: Write the failing exit-run test**

```kotlin
class ExitRunTest {
    @Test
    fun `twenty round-trips over a real socket return twenty trace ids`() {
        val db = PostgresHarness.appDatabase()
        val server = embeddedServer(Netty, port = 0) { module(config(db)) }.start(wait = false)
        val port = server.engine.resolvedConnectors().first().port
        val (a, b) = pairTwoDevices(db)

        val traces = ExitRun.run("ws://127.0.0.1:$port", a.access, b.access, rounds = 20)

        assertEquals(20, traces.size)
        assertEquals(20, traces.toSet().size)
        server.stop(0, 0)
    }
}
```

- [ ] **Step 2: Run it to watch it fail**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*ExitRunTest*"`

Expected: compile error — unresolved `ExitRun`.

- [ ] **Step 3: Implement the runner, the image and the Blueprint**

`ExitRun.run` opens two `FakeDevice`-equivalent clients (same wire calls, in
`src/test`), sends `device.hello` on both, alternates 10 `task.create` each
direction, waits for `task.create` on the target and `task.ack` on the sender,
and returns the ack trace per round. Failures throw with the round number.

The Gradle task:

```kotlin
tasks.register<JavaExec>("exitRun") {
    group = "verification"
    classpath = sourceSets["test"].runtimeClasspath
    mainClass.set("com.hopa.backend.tools.ExitRunKt")
}
```

`Dockerfile` is two stages; context is the repository root because the build
needs `packages/`, `apps/android/gradle` and the wrapper:

```dockerfile
FROM eclipse-temurin:21-jdk AS build
WORKDIR /src
COPY . .
RUN chmod +x apps/android/gradlew && ./apps/android/gradlew -p services/backend installDist --no-daemon

FROM gcr.io/distroless/java21-debian12:nonroot
WORKDIR /app
COPY --from=build /src/services/backend/build/install/hopa-backend/ /app/
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-cp", "/app/lib/*", "com.hopa.backend.MainKt"]
```

`.dockerignore` excludes `.git`, `.venv`, `**/build`, `**/.gradle`, `**/node_modules`,
`.superpowers`.

`render.yaml` gains, keeping the existing relay untouched:

```yaml
databases:
  - name: hopa-backend-db
    databaseName: hopa
    user: hopa_app
    plan: free
    region: frankfurt
    postgresMajorVersion: "16"

services:
  - type: web
    name: hopa-backend
    runtime: docker
    plan: free
    region: frankfurt
    dockerfilePath: ./services/backend/Dockerfile
    dockerContext: .
    healthCheckPath: /v1/health
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: hopa-backend-db
          property: connectionString
      - key: HOPA_BOOTSTRAP_TOKEN
        sync: false
      - key: HOPA_FCM_PROJECT
        sync: false
      - key: HOPA_FCM_CREDENTIALS
        sync: false
      - key: HOPA_PUBLIC_HOST
        value: hopa-backend.onrender.com
```

`services/docs/guides/backend-deploy.md` documents: Blueprint sync, the two
secrets, the free-tier sleep and warm-up, migrations on boot, the `SELECT
rolsuper FROM pg_roles WHERE rolname = current_user` check that must return
`false`, the single-command smoke
(`docker build -t hopa-backend .`, `docker run --rm -p 8080:8080 -e PORT=8080 hopa-backend`,
`curl /v1/health`), and the exit-run command:

```powershell
apps\android\gradlew.bat -p services/backend exitRun --args="--url wss://hopa-backend.onrender.com/v1/gateway --token-a <a> --token-b <b> --rounds 20"
```

- [ ] **Step 4: Verify**

Run: `apps\android\gradlew.bat -p services/backend :test --tests "*ExitRunTest*"`

Expected: PASS, 20 unique trace ids.

Run: `docker build -t hopa-backend:smoke .` then
`docker run -d --rm -p 18080:8080 -e PORT=8080 hopa-backend:smoke`, wait for
`GET http://127.0.0.1:18080/v1/health` to return `200` with
`"db":"unconfigured"`, then stop the container. Record the image size.

- [ ] **Step 5: Write the evidence file and commit**

`docs/project/evidence/B1-gateway.md` carries the eight-row exit table from
§8 with: the command, the date, the result, and for row 1 the 20 trace ids
(placeholders until the Render deploy is run by the account owner). Rows 4, 5 and
8 need the real phone, a deployed instance and the bench, so they are marked
`deferred: needs deploy` rather than claimed. Add it to `docs/README.md` and make
sure `python tools/checks/check-links.py` is 0 broken.

```powershell
git add services/backend .dockerignore render.yaml services/docs docs .github
git commit -m "feat(backend): render blueprint, container and the exit run"
```

---

## Slice boundary

What this slice does **not** build: conversation sync, attachments, approval
routing, end-to-end payload encryption (the key model is decided, not wrapped),
and the Android/Windows gateway clients — those are weeks 2–8 and the client
teams' work. `packages/core` and `packages/data` are still declared in the build
and still unused; that stays a recorded minor.

The free Render service is a v0 demo constraint. Before beta the service moves to
`starter`, and the evidence file records the upgrade as a release gate.

Two week-1 checklist items stay open and are named in the evidence file rather
than silently dropped: `ktlintCheck` (the shared catalog has no ktlint plugin, and
this slice's gate is the test suite) and the 1,000-attempt isolation job has run
locally but not yet on a GitHub runner.
