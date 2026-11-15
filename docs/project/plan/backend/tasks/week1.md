# Backend week 1, slice A: contract, skeleton, codec, mock clients

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or
> superpowers:subagent-driven-development) to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze protocol v0 as executable contracts, stand up the Kotlin/Ktor
service, and prove the envelope and the handshake with two simulated devices that
speak the real wire protocol over a real socket.

**Architecture:** `services/backend` is a single-module Gradle project that
includes `:core` and `:data` from `packages/` (precedent:
`apps/windows/sidecar`). Protocol types and their validation live in
`com.hopa.backend.protocol` and are driven by fixtures in `contracts/`. The
gateway is a Ktor WebSocket route; the phone and the PC are simulated by
`FakeDevice`, a Ktor WebSocket **client** in test sources — not a mock of our own
code, so every assertion travels a real socket.

**Tech Stack:** Kotlin 2.0.21, JDK 17 toolchain (JDK 21 runs Gradle), Ktor 3.0.3
(Netty, WebSockets, content negotiation), kotlinx.serialization 1.7.3, JUnit 4.
Postgres, Flyway, FCM and deployment are **out of this slice** (slice B).

**Spec:** [`../week1.md`](../week1.md) — §4 protocol v0, §5 shape, §7 work plan.

## Global Constraints

- Kotlin 2.0.21 and `jvmToolchain(17)`; do not bump the shared catalog's Kotlin.
- Ktor **3.0.3** only (it is compiled with Kotlin 2.0.21; newer Ktor needs 2.1+).
- `household_id` never appears on the wire; identity comes from the token.
- A frame over **65,536 bytes** is refused with `E_SCHEMA`, never buffered.
- Error codes are exactly `E_AUTH`, `E_TENANT`, `E_VERSION`, `E_RATE`,
  `E_QUEUE`, `E_SCHEMA`, `E_UNSUPPORTED`.
- Gateway heartbeat 25 s, dead after 90 s; envelope `v` is `1`.
- No `hmac`, `adb`, `hdc`, device command or screen content in any type here.
- Every command below runs from the repository root on Windows PowerShell.
- Tests use `apps/android/gradlew.bat -p services/backend`; there is no second
  wrapper.

## Review Focus

- A replayed `task.create` after a reconnect creates a second task.
- A `to` device in another household is delivered instead of refused.
- A 65,537-byte frame is accepted or crashes the gateway.
- A non-`traceparent` trace value is rejected instead of replaced and echoed.
- A device that drops between ack and delivery loses the queued task.

Each line has a test in Task 4 or Task 6.

---

### Task 1: Freeze protocol v0 as executable contracts

**Files:**
- Create: `contracts/schemas/gateway.v1.schema.json`
- Create: `contracts/fixtures/gateway-v0.json`
- Create: `contracts/openapi/backend.v1.yaml`
- Create: `docs/design/decisions/0022-backend-kotlin-and-shape.md`
- Create: `tools/checks/check-gateway-fixtures.py`
- Create: `tools/scripts/test_gateway_fixtures.py`
- Modify: `docs/design/decisions/README.md`, `docs/reference/protocols.md`,
  `contracts/openapi/README.md`, `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: nothing.
- Produces: fixture file `/fixtures/gateway-v0.json` (test classpath) with
  `{"version":1,"cases":[{"name":str,"ok":bool,"error":str?,"message":obj}]}`;
  schema file `/schemas/gateway.v1.schema.json`; `backend.v1.yaml` with the six
  `/v1` paths.

- [ ] **Step 1: Write the failing fixture test**

Create `tools/scripts/test_gateway_fixtures.py`:

```python
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "contracts" / "fixtures" / "gateway-v0.json"
SCHEMA = ROOT / "contracts" / "schemas" / "gateway.v1.schema.json"


def load():
    return json.loads(FIXTURES.read_text(encoding="utf-8"))


def test_at_least_fourteen_unique_cases():
    names = [c["name"] for c in load()["cases"]]
    assert len(names) >= 14
    assert len(names) == len(set(names))


def test_every_case_matches_its_expectation():
    from jsonschema import Draft202012Validator

    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    validator = Draft202012Validator(schema)
    for case in load()["cases"]:
        errors = list(validator.iter_errors(case["message"]))
        if case["ok"]:
            assert not errors, (case["name"], errors)
        else:
            assert errors, f"{case['name']} must be refused by the schema"


def test_refusals_name_a_gateway_error():
    allowed = {"E_AUTH", "E_TENANT", "E_VERSION", "E_RATE", "E_QUEUE",
               "E_SCHEMA", "E_UNSUPPORTED"}
    for case in load()["cases"]:
        if case.get("error"):
            assert case["error"] in allowed, case["name"]
```

- [ ] **Step 2: Run it to watch it fail**

Run: `.venv\Scripts\python.exe -m pytest tools/scripts/test_gateway_fixtures.py -v`
Expected: FAIL — `FileNotFoundError` for `contracts/fixtures/gateway-v0.json`.
If `pytest` or `jsonschema` is missing: `.venv\Scripts\python.exe -m pip install pytest jsonschema`,
then re-run and confirm the same failure.

- [ ] **Step 3: Write the schema, the fixtures, the checker and the spec**

`contracts/schemas/gateway.v1.schema.json`: Draft 2020-12, `required`
`["v","id","type","ts"]`, `v` const `1`, `id` UUID, `type` enum of the 12 types
in `week1.md` §4.3, `trace` matching `^00-[0-9a-f]{32}-[0-9a-f]{16}-01$`,
`body` an object, `additionalProperties: false`.

`ok:false` means the JSON Schema refuses the message. A schema-valid message can
still be refused by the server, so those cases carry `"ok": true` and an `error`
code, and the fixture test reads the code independently of `ok`.

`contracts/fixtures/gateway-v0.json`: the 14 vectors in `week1.md` §4.5. Keep at
least four schema-invalid cases (missing `id`, unknown `type`, `v: 2`, a
`task.create` without `to`) and at least three schema-valid refusals
(`E_TENANT`, the 65,537-byte body as `E_SCHEMA`, `E_UNSUPPORTED`).

`contracts/openapi/backend.v1.yaml`: OpenAPI 3.0.3 for `/v1/health`,
`/v1/version`, `/v1/pair/sessions`, `/v1/pair/claim`, `/v1/token/refresh`,
`/v1/traces/{traceId}`; bearer auth everywhere except health and version;
request and response schemas inline.

`tools/checks/check-gateway-fixtures.py`: same assertions as the test, printing
`ok N case(s)` on success, for CI and for humans.

`docs/design/decisions/0022-backend-kotlin-and-shape.md`: status proposed,
recording Kotlin 2.0.21 + Ktor 3.0.3, one Gradle build including `packages/`,
Postgres queue, RLS, opaque tokens, and the two rejected alternatives (Go,
Python). Add the row to `docs/design/decisions/README.md`.

`docs/reference/protocols.md` gains a gateway row; `contracts/openapi/README.md`
gains `backend.v1.yaml`. `.github/workflows/ci.yml` adds `jsonschema` to the
python job's install line and a `Gateway fixtures` step.

- [ ] **Step 4: Run the test and the checker**

Run: `.venv\Scripts\python.exe -m pytest tools/scripts/test_gateway_fixtures.py -v`
Expected: PASS, 3 tests.

Run: `py -3 tools/checks/check-gateway-fixtures.py`
Expected: `ok 14 case(s)`.

Run: `py -3 tools/checks/check-links.py`
Expected: `0 broken link(s)`.

- [ ] **Step 5: Commit**

```powershell
git add contracts docs/design/decisions docs/reference/protocols.md tools/checks/check-gateway-fixtures.py tools/scripts/test_gateway_fixtures.py .github/workflows/ci.yml
git commit -m "feat(backend): freeze protocol v0 as contracts and fixtures"
```

---

### Task 2: Kotlin service skeleton with health and version

**Files:**
- Create: `services/backend/settings.gradle.kts`, `services/backend/build.gradle.kts`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/Main.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/http/HealthRoutes.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/ServerConfig.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/http/HealthTest.kt`
- Modify: `apps/android/gradle/libs.versions.toml` (add Ktor 3.0.3 entries)

**Interfaces:**
- Consumes: nothing.
- Produces: `fun Application.module(config: ServerConfig)`;
  `data class ServerConfig(val version: String, val auth: AuthPort = AuthPort.DenyAll)`;
  `fun main()` reading `PORT` (default 8080) and `HOPA_VERSION` (default `0.1.0`).
  `GET /v1/health` → `{"ok":true,"version":"<v>","db":"unconfigured"}`;
  `GET /v1/version` → `{"version":"<v>","protocol":1}`.

- [ ] **Step 1: Write the failing test**

`HealthTest.kt`:

```kotlin
class HealthTest {
    @Test
    fun `health reports ok and the build version`() = testApplication {
        application { module(ServerConfig(version = "0.1.0")) }
        val response = client.get("/v1/health")
        assertEquals(HttpStatusCode.OK, response.status)
        val body = Json.parseToJsonElement(response.bodyAsText()).jsonObject
        assertEquals(true, body["ok"]!!.jsonPrimitive.boolean)
        assertEquals("0.1.0", body["version"]!!.jsonPrimitive.content)
        assertEquals("unconfigured", body["db"]!!.jsonPrimitive.content)
    }

    @Test
    fun `version reports protocol 1`() = testApplication {
        application { module(ServerConfig(version = "9.9.9")) }
        val body = Json.parseToJsonElement(
            client.get("/v1/version").bodyAsText()
        ).jsonObject
        assertEquals(1, body["protocol"]!!.jsonPrimitive.int)
        assertEquals("9.9.9", body["version"]!!.jsonPrimitive.content)
    }
}
```

- [ ] **Step 2: Run it to watch it fail**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*HealthTest*"`
Expected: compile error — unresolved `module`, `ServerConfig`; `services/backend`
has no build file.

- [ ] **Step 3: Add the build files and the minimal module**

`settings.gradle.kts`: mirror `apps/windows/sidecar/settings.gradle.kts` —
`rootProject.name = "hopa-backend"`, version catalog from
`apps/android/gradle/libs.versions.toml`, include `:core` (`../../packages/core`)
and `:data` (`../../packages/data`).

`build.gradle.kts`: `kotlin-jvm` + `kotlin-serialization` + `application`;
`jvmToolchain(17)`; `mainClass = "com.hopa.backend.MainKt"`; dependencies
`:core`, `:data`, `ktor-server-core`, `ktor-server-netty`,
`ktor-server-content-negotiation`, `ktor-serialization-kotlinx-json`,
`ktor-server-test-host`, `kotlin-test-junit`; test resources
`resources.srcDir(file("../../contracts"))`.

Add to `libs.versions.toml`: `ktor = "3.0.3"` and the five library aliases above.

`Main.kt`: embedded server on `PORT`, `application { module(config) }`.

`HealthRoutes.kt`: two `get` routes returning `call.respond(mapOf(...))`; content
negotiation with `Json`.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*HealthTest*"`
Expected: `BUILD SUCCESSFUL`, 2 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/android/gradle/libs.versions.toml services/backend
git commit -m "feat(backend): Ktor skeleton with health and version"
```

---

### Task 3: Gateway envelope codec driven by the fixtures

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/protocol/Envelope.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/protocol/GatewayCodec.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/protocol/GatewayError.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/protocol/GatewayCodecTest.kt`

**Interfaces:**
- Consumes: `contracts/fixtures/gateway-v0.json` on the test classpath as
  `/fixtures/gateway-v0.json`.
- Produces: `data class Envelope(val v: Int, val id: String, val type: String,
  val ts: Long, val trace: String? = null, val from: String? = null,
  val to: String? = null, val task: String? = null, val body: JsonObject = JsonObject(emptyMap()))`;
  `object GatewayCodec { fun decode(raw: String): DecodeResult; fun encode(e: Envelope): String }`;
  `sealed interface DecodeResult { data class Ok(val envelope: Envelope): DecodeResult; data class Failed(val error: GatewayError): DecodeResult }`;
  `data class GatewayError(val code: String, val message: String, val retryable: Boolean = false)`.

- [ ] **Step 1: Write the failing test**

`GatewayCodecTest.kt` opens `/fixtures/gateway-v0.json` from the classpath, and
for every case whose message is schema-valid:

```kotlin
@Test
fun `every valid fixture decodes and re-decodes identically`() {
    val cases = fixtureCases().filter { it.ok }
    assertTrue(cases.size >= 10)
    for (case in cases) {
        val first = GatewayCodec.decode(case.message.toString())
        assertTrue("${case.name}: ${first}", first is DecodeResult.Ok)
        val e = (first as DecodeResult.Ok).envelope
        assertEquals(case.name.length > 0, e.id.isNotEmpty())
        val again = GatewayCodec.decode(GatewayCodec.encode(e))
        assertEquals(e, (again as DecodeResult.Ok).envelope, case.name)
    }
}

@Test
fun `a message with unknown fields keeps only the contract fields`() {
    val raw = """{"v":1,"id":"018f3a5e-6b1c-7c3a-9d2e-4f5a6b7c8d9e",
        "type":"task.create","ts":1,"household":"hh_evil","body":{}}"""
    val e = (GatewayCodec.decode(raw) as DecodeResult.Ok).envelope
    assertFalse(GatewayCodec.encode(e).contains("household"))
}
```

- [ ] **Step 2: Run it to watch it fail**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*GatewayCodecTest*"`
Expected: compile error — unresolved `GatewayCodec`.

- [ ] **Step 3: Implement the envelope and the codec**

`Envelope.kt` is the data class above with `@Serializable` and
`@SerialName("from")` on `from`. `GatewayCodec` uses one `Json` instance with
`ignoreUnknownKeys = true`, `encodeDefaults = false`, `explicitNulls = false`;
`decode` maps `SerializationException` to
`DecodeResult.Failed(GatewayError("E_SCHEMA", "invalid envelope"))`; `encode`
uses the same instance. No validation here — that is Task 4.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*GatewayCodecTest*"`
Expected: `BUILD SUCCESSFUL`, 2 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services/backend/src
git commit -m "feat(backend): gateway envelope codec with fixtures"
```

---

### Task 4: Envelope validation, the frame cap and the error mapping

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/protocol/EnvelopeValidator.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/protocol/EnvelopeValidatorTest.kt`

**Interfaces:**
- Consumes: `Envelope`, `GatewayCodec`, `GatewayError` (Task 3).
- Produces: `object EnvelopeValidator { const val MAX_FRAME_BYTES = 65_536;
  val TYPES: Set<String>; fun validate(raw: String, envelope: Envelope): GatewayError?;
  fun traceOf(envelope: Envelope): String }` — `traceOf` returns the incoming
  `trace` when it matches `^00-[0-9a-f]{32}-[0-9a-f]{16}-01$`, else a fresh
  `00-<32 hex>-<16 hex>-01`.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `a frame over the cap is refused`() {
    val raw = """{"v":1,"id":"${UUID.randomUUID()}","type":"task.create","ts":1,"body":{"x":"${"a".repeat(70_000)}"}}"""
    assertEquals("E_SCHEMA", EnvelopeValidator.validate(raw, okEnvelope(raw)).code)
}

@Test fun `an unknown major version is refused`() {
    val e = okEnvelope().copy(v = 2)
    assertEquals("E_VERSION", EnvelopeValidator.validate(GatewayCodec.encode(e), e)!!.code)
}

@Test fun `an unknown type is refused`() {
    val e = okEnvelope().copy(type = "device.reboot")
    assertEquals("E_UNSUPPORTED", EnvelopeValidator.validate(GatewayCodec.encode(e), e)!!.code)
}

@Test fun `an invalid trace is replaced, not rejected`() {
    val e = okEnvelope().copy(trace = "not-a-traceparent")
    assertNull(EnvelopeValidator.validate(GatewayCodec.encode(e), e))
    assertTrue(EnvelopeValidator.traceOf(e).matches(Regex("^00-[0-9a-f]{32}-[0-9a-f]{16}-01$")))
}

@Test fun `a valid trace is preserved`() {
    val trace = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    assertEquals(trace, EnvelopeValidator.traceOf(okEnvelope().copy(trace = trace)))
}

@Test fun `a task message without a target is refused`() {
    val e = okEnvelope().copy(to = null)
    assertEquals("E_SCHEMA", EnvelopeValidator.validate(GatewayCodec.encode(e), e)!!.code)
}
```

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*EnvelopeValidatorTest*"`
Expected: compile error — unresolved `EnvelopeValidator`.

- [ ] **Step 3: Implement the validator**

Check in this order and return the first error: byte cap (`raw.toByteArray().size > MAX_FRAME_BYTES` → `E_SCHEMA`), `v != 1` (`E_VERSION`), `type !in TYPES` (`E_UNSUPPORTED`), blank `id` (`E_SCHEMA`), `type.startsWith("task.") && to == null` (`E_SCHEMA`). `TYPES` is the 12 names from `week1.md` §4.3. `traceOf` uses `SecureRandom` for the 16-byte trace id and 8-byte span id, hex-encoded lowercase.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*EnvelopeValidatorTest*"`
Expected: `BUILD SUCCESSFUL`, 6 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services/backend/src
git commit -m "feat(backend): envelope validation, frame cap, trace assignment"
```

---

### Task 5: FakeDevice client and the gateway handshake with presence

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/auth/AuthPort.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/gateway/DeviceRegistry.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/gateway/GatewayRoutes.kt`
- Create: `services/backend/src/test/kotlin/com/hopa/backend/harness/FakeDevice.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/gateway/GatewayHandshakeTest.kt`
- Modify: `services/backend/build.gradle.kts` (add `ktor-client-websockets`,
  `ktor-client-cio`, `ktor-client-content-negotiation`)

**Interfaces:**
- Consumes: `Envelope`, `GatewayCodec`, `EnvelopeValidator`.
- Produces: `interface AuthPort { fun deviceFor(token: String): DeviceIdentity? }`
  with `AuthPort.DenyAll`; `data class DeviceIdentity(val deviceId: String,
  val householdId: String, val memberId: String)`;
  `class DeviceRegistry { fun online(identity: DeviceIdentity, sessionId: String);
  fun offline(deviceId: String); fun peers(householdId: String): List<String>;
  fun isOnline(deviceId: String): Boolean }`;
  `fun Application.gatewayRoutes(config: ServerConfig)`;
  test helper `class MapAuth(private val byToken: Map<String, DeviceIdentity>) :
  AuthPort`; test helper `class FakeDevice(val deviceId: String, val token: String)` with
  `suspend fun connect(client: HttpClient, baseUrl: String)`,
  `suspend fun send(envelope: Envelope)`,
  `suspend fun expect(type: String, timeoutMs: Long = 2_000): Envelope`,
  `suspend fun close()`.

- [ ] **Step 1: Write the failing test**

```kotlin
@Test
fun `two devices of one household handshake and see each other, a third does not`() = testApplication {
    val auth = MapAuth(
        "tok-a" to DeviceIdentity("dev-a", "hh-1", "mem-1"),
        "tok-b" to DeviceIdentity("dev-b", "hh-1", "mem-1"),
        "tok-c" to DeviceIdentity("dev-c", "hh-2", "mem-2"),
    )
    application { module(ServerConfig(version = "0.1.0", auth = auth)) }
    val http = createClient { install(WebSockets) }
    val a = FakeDevice("dev-a", "tok-a"); val b = FakeDevice("dev-b", "tok-b")
    val c = FakeDevice("dev-c", "tok-c")
    a.connect(http, "/v1/gateway"); b.connect(http, "/v1/gateway"); c.connect(http, "/v1/gateway")

    a.send(hello("dev-a")); b.send(hello("dev-b")); c.send(hello("dev-c"))
    assertEquals("dev-a", a.expect("device.hello.ack").to)
    assertEquals("dev-b", b.expect("device.hello.ack").to)

    assertEquals(listOf("dev-b"), a.expect("presence").body["peers"]!!.jsonArray.map { it.jsonPrimitive.content })
    assertEquals(listOf("dev-a"), b.expect("presence").body["peers"]!!.jsonArray.map { it.jsonPrimitive.content })
}

@Test
fun `a connection with an unknown token is closed with E_AUTH`() = testApplication {
    application { module(ServerConfig(version = "0.1.0", auth = MapAuth(emptyMap()))) }
    val http = createClient { install(WebSockets) }
    val d = FakeDevice("dev-x", "nope")
    d.connect(http, "/v1/gateway")
    assertEquals("E_AUTH", d.expect("error").body["code"]!!.jsonPrimitive.content)
}
```

`hello(deviceId)` is a test helper returning
`Envelope(v=1, id=UUID.randomUUID().toString(), type="device.hello", ts=0, from=deviceId,
body=buildJsonObject { put("platform", "android"); put("name", "Pixel"); put("appVersion", "0.1.0") })`.

- [ ] **Step 2: Run it to watch it fail**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*GatewayHandshakeTest*"`
Expected: compile error — unresolved `MapAuth`, `FakeDevice`, `gatewayRoutes`.

- [ ] **Step 3: Implement auth, registry and the route**

`AuthPort.kt` holds the interface, `DeviceIdentity` and `AuthPort.DenyAll`.
`DeviceRegistry` is a thread-safe in-memory map of `deviceId -> (session,
householdId)`; `peers` filters the same household and excludes the caller.
`gatewayRoutes` installs `WebSockets`, reads `Authorization: Bearer <token>`,
resolves `AuthPort`; on failure sends `error{E_AUTH}` and closes with
`CloseReason(VIOLATED_POLICY, "auth")`. On the first frame it decodes and
validates, requires `device.hello`, registers the session, sends
`device.hello.ack {session, serverTime, heartbeatSec:25, queued:0}` to the caller
and `presence {device, online, peers:[...]}` to every peer. It records presence
in the registry and removes the device in the `finally` block.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*GatewayHandshakeTest*"`
Expected: `BUILD SUCCESSFUL`, 2 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add services/backend/src services/backend/build.gradle.kts
git commit -m "feat(backend): gateway handshake, presence, fake device client"
```

---

### Task 6: Task routing, idempotency, cross-household refusal and the queue

**Files:**
- Create: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskStore.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/tasks/TaskRouter.kt`
- Create: `services/backend/src/main/kotlin/com/hopa/backend/gateway/GatewaySession.kt`
- Modify: `services/backend/src/main/kotlin/com/hopa/backend/gateway/GatewayRoutes.kt`
- Test: `services/backend/src/test/kotlin/com/hopa/backend/gateway/TaskRoutingTest.kt`

**Interfaces:**
- Consumes: `DeviceRegistry`, `AuthPort`, `Envelope`, `GatewayCodec`, `FakeDevice`.
- Produces: `data class TaskRecord(val id: String, val householdId: String,
  val from: String, val to: String, val state: String, val trace: String,
  val deadlineAt: Long)`; `interface TaskStore { fun remember(householdId: String,
  messageId: String, task: TaskRecord); fun recall(householdId: String,
  messageId: String): TaskRecord?; fun queue(task: TaskRecord);
  fun queuedFor(deviceId: String): List<TaskRecord>; fun markDelivered(taskId: String) }`;
  `class InMemoryTaskStore : TaskStore`; `class TaskRouter(store: TaskStore,
  registry: DeviceRegistry) { suspend fun route(identity: DeviceIdentity,
  envelope: Envelope): RouteResult }` where
  `sealed interface RouteResult { data class Accepted(val task: TaskRecord, val duplicate: Boolean): RouteResult;
  data class Refused(val error: GatewayError): RouteResult }`.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun `a task travels from the phone to the pc and is acked`() { /* A sends task.create to B; assert B receives it with the same id and body, A receives task.ack with task id, task state delivered */ }

@Test fun `the same message id sent three times creates one task and one delivery`() { /* send twice with the same id; B sees exactly one; second answer is ack with duplicate=true */ }

@Test fun `a target in another household is refused and never delivered`() { /* A(hh-1) -> dev-c(hh-2): E_TENANT to A, nothing arrives at C, store has zero rows for hh-1 */ }

@Test fun `a task for an offline device is queued and delivered on hello`() { /* B is closed; A creates; A gets ack queued=true; B reconnects and hellos; B receives task.create */ }
```

Each test uses the `FakeDevice` harness from Task 5, `MapAuth` with two
households, and asserts on real frames. The offline test asserts the queue
drained exactly once.

- [ ] **Step 2: Run them to watch them fail**

Run: `apps\android\gradlew.bat -p services/backend test --tests "*TaskRoutingTest*"`
Expected: compile error — unresolved `TaskRouter`, `TaskStore`.

- [ ] **Step 3: Implement the store and the router**

`InMemoryTaskStore` uses `ConcurrentHashMap` for idempotency keyed
`"$householdId/$messageId"` and tasks keyed by id; `queuedFor` filters
`state == "queued"` by target. `TaskRouter.route`:

1. `store.recall(household, envelope.id)` → `Accepted(task, duplicate = true)`.
2. `task.*` other than `task.create` → `E_UNSUPPORTED` (v0 routes only creates).
3. Resolve `to` in the registry/identity table; unknown or different household →
   `Refused(E_TENANT)`.
4. Build `TaskRecord` (state `delivered` when online, `queued` when not,
   `deadlineAt = now + 10 min`), `remember`, `queue` or deliver, ack the sender
   with `{task: id, state, duplicate:false}`.
5. Delivery sends the **original** envelope with `task` set and `from` replaced
   by the server-side device id.

Wire `router.route` into `gatewayRoutes` for `task.create`; on
`device.hello` drain `queuedFor(deviceId)` after the ack.

- [ ] **Step 4: Run the tests**

Run: `apps\android\gradlew.bat -p services/backend test`
Expected: `BUILD SUCCESSFUL`, every test in the module passes (Tasks 2–6).

- [ ] **Step 5: Commit**

```powershell
git add services/backend/src
git commit -m "feat(backend): task routing, idempotency, tenancy refusal, queue"
```

---

## Slice boundary

Slice B (next plan) replaces `InMemoryTaskStore` and `MapAuth` with Postgres and
adds pairing, tokens, FCM, tracing and deployment. Nothing in this slice is
thrown away: `TaskStore` and `AuthPort` are the seams those implementations plug
into.
