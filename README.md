# ChecklistForProjects

---

## Angular / TypeScript

### Strict compilation
- [ ] `"strict": true` in `tsconfig.json`
- [ ] `"noUnusedLocals": true` and `"noUnusedParameters": true` in `tsconfig.json`
- [ ] Consider `"noUncheckedIndexedAccess": true` — high-value, but expect churn in array-heavy code
- [ ] `"strictTemplates": true` and `"extendedDiagnostics": { "defaultCategory": "error" }` in `angularCompilerOptions`
- [ ] Use standalone components
- [ ] Avoid `any`; use `unknown` if the type is genuinely unknown
- [ ] Enable strict form typing (`FormGroup<{...}>` instead of untyped `FormGroup`)
- [ ] Add `src/test-setup.ts` to `include` in `tsconfig.spec.json`

### ESLint
- [ ] `ng add @angular-eslint/schematics`
- [ ] Enable type-aware linting: `parserOptions: { projectService: true, tsconfigRootDir: __dirname }`
- [ ] Treat all warnings as errors: `ng lint -- --max-warnings=0`
- [ ] Rules to enable:
  - `no-console`
  - `@typescript-eslint/no-explicit-any`
  - `@typescript-eslint/no-unused-vars`
  - `@typescript-eslint/prefer-readonly`
  - `@typescript-eslint/no-floating-promises`
  - `@typescript-eslint/no-deprecated: 'error'`
  - `eqeqeq`
- [ ] Enforce barrel imports for generated code via `no-restricted-imports`
- [ ] Add `eslint-plugin-sonarjs` and extend `sonarjs.configs.recommended` (enables `cognitive-complexity`; the TS analog to PMD's design rules). In flat config it self-registers — don't also add `plugins: { sonarjs }`.
- [ ] God-object / size caps — stop a class growing one harmless method at a time. `cognitive-complexity` only guards individual *methods*; these guard the file/function/class as a whole:
  - `max-lines: ['error', { max: 400, skipBlankLines: true, skipComments: true }]`
  - `max-lines-per-function: ['error', { max: 80, skipBlankLines: true, skipComments: true }]`
  - `max-classes-per-file: ['error', 1]`
  - Exempt specs (legitimately long: fixtures, provider setup) with a `files: ['**/*.spec.ts']` override turning the size caps off.
  - **Adopt as a ratchet, not a big-bang.** Files that already exceed the cap get a per-file override pinned at their *current* counted size (run lint once to read the reported number — it differs from `wc -l` because of `skipBlankLines`/`skipComments`). That's a frozen ceiling: they can only shrink, never grow. Add a `TODO` to lower the number as the file is slimmed, and delete the override once it drops under the global cap. Pinning keeps CI green while making the debt explicit and non-growing; a hard global cap on a brownfield repo just leaves the build red and blocks unrelated work.
  - Note the weakness: line-counting can't tell a god object from a long enum/data file (`photo.ts` of pure interfaces is fine at 400+). The layer-boundary rule below is the structural complement.
- [ ] Architectural layer boundaries — `eslint-plugin-boundaries`, the TS analog to ArchUnit (see the Java section). Attacks the *cause* of god objects rather than the symptom: a UI component that can `inject()` a store/repository directly will accrete data-layer logic until it's a god object. Tag folders as layers (`component` / `service` / `store` / `domain`) in `settings['boundaries/elements']`, then `boundaries/dependencies` (v6; `element-types` in v5) with `default: 'disallow'` and allow only the legal edges — crucially **forbid `component → store`**, forcing that logic into a service. Adopt as `'warn'` first (the first run is the real coupling map of the app), triage, then promote to `'error'`. Put a `domain` pattern above the broad `component` catch-all so pure utils/types aren't misclassified and wrongly denied store access. **Gotchas that will waste an afternoon if you skip them:**
  - **⚠️ The one that actually blocks you: add a TypeScript import resolver.** boundaries resolves every import *to a file* before classifying it, using the same resolver as `eslint-plugin-import`. The default node resolver can't follow extensionless TS paths (`./storage/review/review-store`), so every dependency resolves to nothing → "unknown" → `element-types` silently skips it. Result: **the rule passes on a codebase full of violations** (the worst failure mode — a green gate that checks nothing). Fix: `npm i -D eslint-import-resolver-typescript` and add to the boundaries config's `settings`: `'import/resolver': { typescript: { project: 'tsconfig.json' } }`. This was *the* blocker — patterns were a red herring.
  - **Use v6, not v5 — v5 carries a critical CVE.** `eslint-plugin-boundaries@5` depends on `@boundaries/elements` → `handlebars`, which has a **critical** `npm audit` advisory (AST type-confusion / prototype-pollution) with no fix in the 4.x line. v6 dropped that chain — so `npm i -D eslint-plugin-boundaries@^6`. v6 **renamed the rule** `boundaries/element-types` → `boundaries/dependencies` and uses **object-based selectors**: `from: 'component', allow: ['service']` becomes `from: { type: 'component' }, allow: [{ to: { type: 'service' } }]`. A tiny helper keeps it readable: `const to = (...types) => types.map((type) => ({ to: { type } }))`, then `allow: to('service', 'domain')`. (v6 still *runs* a v5 `element-types` config with deprecation warnings, so the migration is mechanical — rename the rule, wrap the selectors. `settings['boundaries/elements']` is unchanged.)
  - **Element `pattern`s with `mode: 'full'` match the path relative to cwd** — i.e. `src/app/storage/**/*` works (so do `**/`-prefixed globs). Patterns are *not* the usual cause of "nothing classifies" — the resolver is. Confirm with `boundaries/no-unknown-files: 'error'`, which flags any *file* that fails to classify (vs `no-unknown`, which is about *dependencies*).
  - **`boundaries/no-unknown` also flags external packages** (`rxjs`, `@angular/*`, etc.), drowning the signal. Set it `'off'` (or scope it) and read `element-types`/`dependencies` for the real violations.
  - **Type-only imports get flagged too,** and they're most of the first-run list: shared *types* co-located with a component or store (a `Tag` in the DB-schema file, a view-model interface in a component, persisted/API contract types like `FrameSignature`/`PhotoAsset`). Best fix is **relocate the type to `domain`**. If there are too many to relocate up front, a pragmatic shippable compromise is to allow `domain → store/service` (domain may reference contract types that still live there) while keeping `component → store` forbidden — the load-bearing rule — with a TODO to relocate and tighten later.
  - **Except dev-only/tooling screens and test fixtures** via `ignores` (e.g. a `?debug` diagnostic panel that legitimately reaches into stores, `*.fixture.ts`) rather than contorting the rules around them.
  - **Sanity-check before trusting it — non-negotiable:** inject an import you *know* crosses a layer (a component that imports a store), confirm the rule errors, then revert. A green gate means nothing until you've watched it go red. If a known violation doesn't fire, classification/resolution is broken — don't conclude the codebase is clean. If the plugin keeps fighting you, the triage's *value* (the bucketed findings) is also obtainable with a direct `grep` for cross-layer imports while you sort the gate out separately.

### Formatting
- [ ] Add Prettier + `.prettierrc`
- [ ] CI check: `prettier --check .`

### Testing
- [ ] Minimum coverage thresholds (in Vitest / Jest config):
  ```
  branches: 90%, functions: 90%, lines: 90%, statements: 90%
  ```
- [ ] Mock `HTMLMediaElement.play()` in `src/test-setup.ts` to silence jsdom "Not implemented" errors
- [ ] Register it in `angular.json` under `test.options.setupFiles`

### i18n
- [ ] Cache-bust translation JSON files: append `?v=${Date.now()}` in `HttpLoaderFactory.getTranslation()`

### Security
- [ ] `npm audit` (and fail CI on critical/high findings)
- [ ] Add Dependabot or Renovate for dependency updates
- [ ] Group lockstep packages in `dependabot.yml` via `groups:`. Without it, Dependabot opens **one PR per package** — a framework bump (Angular, Spring) becomes a dozen PRs, and they each **fail CI individually** because the packages are peer-versioned (e.g. `@angular/core` ahead of `@angular/common` won't install). One PR per group keeps them coherent so CI passes. Order matters — a package joins the first group it matches, so put specific groups (`@angular*`, `org.springframework*`) before broad `minor`/`patch` catch-alls; leave majors ungrouped so each gets its own PR to review.
- [ ] Auto-merge minor/patch Dependabot PRs via a workflow using `dependabot/fetch-metadata` + `gh pr merge --auto` (gate on `update-type == semver-minor|semver-patch`). Prerequisites: enable **Settings → General → Allow auto-merge**, and configure **branch protection with required status checks** — `--auto` only completes once required checks pass, so without a required check it can't gate (and grouping is what lets those checks pass in the first place).
- [ ] Never use `[innerHTML]` with unsanitized input; use Angular's `DomSanitizer` if binding HTML is unavoidable
- [ ] Add CSP headers
- [ ] Ensure HTTPS is enforced end-to-end — verify no proxy or load balancer silently strips the `X-Forwarded-Proto` header and downgrades to HTTP

---

## Java / Spring / Maven

### Strict compilation
- [ ] `-Xlint:all -Xlint:-processing -Werror` in `maven-compiler-plugin`
- [ ] `@java.io.Serial private static final long serialVersionUID = 1L;` on every exception class

### Static analysis
- [ ] Checkstyle
- [ ] SpotBugs
- [ ] PMD
- [ ] Error Prone
- [ ] NullAway
- [ ] ArchUnit for architecture rules
- [ ] Spotless Maven Plugin for formatting

#### PMD configuration notes

**Java version compatibility**
- PMD lags behind the Java release cycle. Set `<targetJdk>` explicitly to the latest PMD-supported LTS version (e.g. `21`) when your compiler targets a newer preview or non-LTS version. PMD will still find all the same issues; it just will not parse language-version-specific syntax it does not know yet.

**Exclude debug/tooling packages from analysis**
- Internal packages used only for development tooling (e.g. a `testapp` package with a manual test harness) tend to violate rules that are valid in production code. Exclude them via `<excludes><exclude>**/testapp/**</exclude></excludes>` so they do not pollute the report.

**Rules to exclude globally** (add `<exclude name="..."/>` in the appropriate category block of your ruleset XML)

| Rule | Category | Why exclude |
|------|----------|-------------|
| `AvoidFieldNameMatchingMethodName` | Error Prone | Fires on the record-like accessor pattern (`field foo` + method `foo()`) that many codebases use for mutable value objects. If the pattern is consistent and intentional, the warning is noise. |
| `AvoidInstantiatingObjectsInLoops` | Performance | Unavoidable in factory and builder code that constructs domain objects from configuration. Refactoring away the `new` inside the loop would either duplicate code or introduce unnecessary indirection. |
| `AvoidLiteralsInIfCondition` | Error Prone | Domain-specific algorithms often use small numeric literals (minimum counts, thresholds, distances) that have no meaningful name outside their immediate context. Forcing named constants adds ceremony without clarity. |
| `AvoidBranchingStatementAsLastInLoop` | Error Prone | The "return the first match" loop pattern (`for { … return found; }`) is idiomatic Java for search helpers. PMD flags the `return` as a branching statement at the end of the loop body, but the intent is clear and the alternative (a local variable + break) is noisier. |
| `OneDeclarationPerLine` | Best Practices | Compact multi-variable declarations (`int i = 0, j = 0`) are common for tightly related loop counters and parallel accumulators. The rule is a style preference; enforce it through Checkstyle or Spotless if you want it. |
| `UseVarargs` | Best Practices | When a method genuinely accepts a fixed-shape array (not a variadic call site), changing the signature to varargs changes the calling contract and can introduce ambiguity. Suppress or exclude when arrays are passed intentionally. |
| `GuardLogStatement` | Best Practices | SLF4J's parameterized logging (`log.debug("val={}", x)`) is a no-op when the level is disabled; an `isDebugEnabled()` guard is redundant and adds noise. |
| `LooseCoupling` | Best Practices | Spring APIs (`RestClient`, `ResponseEntity`, `HttpHeaders`) use concrete types by design; no meaningful interface exists to substitute. |
| `UnitTestShouldIncludeAssert` | Best Practices | MockMvc's `andExpect()` chains are assertions; PMD does not recognise them and incorrectly flags the test as having no assertions. |
| `UnitTestContainsTooManyAsserts` | Best Practices | Multiple `andExpect()` calls on a single MockMvc request are idiomatic; splitting them into separate tests would multiply boilerplate without improving signal. |
| `AtLeastOneConstructor` | Code Style | Spring beans and `@ConfigurationProperties` classes rely on the implicit no-arg constructor; an explicit one adds noise with no value. |
| `LocalVariableCouldBeFinal` | Code Style | Marking every local variable `final` generates widespread noise without meaningful safety gain in a NullAway-checked codebase. |
| `MethodArgumentCouldBeFinal` | Code Style | Same rationale as `LocalVariableCouldBeFinal`. |
| `OnlyOneReturn` | Code Style | The guard-clause early-return pattern (`if (x == null) return …`) is idiomatic and more readable than a single-return with nested conditionals. |
| `ShortVariable` | Code Style | `e` is the universal catch-block variable; PMD's minimum-length rule has no carve-out for this convention. |
| `TooManyStaticImports` | Code Style | Static imports for JUnit 5, Mockito, and MockMvc matchers are standard practice in test classes and aid readability. |
| `LinguisticNaming` | Code Style | `setUp` and `tearDown` are JUnit 4/5 conventions; PMD incorrectly classifies them as setters because of the `set` prefix. |
| `ClassWithOnlyPrivateConstructorsShouldBeFinal` | Design | `@SpringBootApplication` classes must not be `final` — Spring creates a CGLIB subclass. This rule also fires on utility classes that are intentionally non-extendable via a private constructor. |
| `DataClass` | Design | `@ConfigurationProperties` is intentionally a data holder; the rule fires by design on DTOs and config beans. |
| `LawOfDemeter` | Design | Spring's fluent builders (`RestClient`, `UriComponentsBuilder`) and MockMvc's DSL chain calls across multiple objects by design. |
| `UseObjectForClearerAPI` | Design | Service methods that require several tightly coupled parameters (e.g. `accessToken`, `catalogId`, `assetId`, `size`) have those parameters out of necessity; a wrapper class would be over-engineering for a small, focused API. |
| `AvoidCatchingGenericException` | Design | A broad `catch (Exception e)` at the `@RestControllerAdvice` boundary is the correct pattern for translating unexpected errors into HTTP 500 responses. |
| `SingularField` | Design | Test-class fields (`mockMvc`, shared `tokenData`) are used across multiple `@Test` methods via `@BeforeEach`; PMD incorrectly suggests moving them to local variables. |
| `TooManyMethods` | Design | Test classes intentionally have many small, focused `@Test` methods; splitting the class adds navigation overhead without improving test quality. |
| `AvoidDuplicateLiterals` | Error Prone | Package-name and endpoint-path strings in ArchUnit rules and integration tests are clearer as inline literals than as extracted constants in small, focused test classes. |

**Rules to suppress per site** (use `@SuppressWarnings("PMD.<RuleName>")` on the smallest enclosing element)

| Rule | When to suppress |
|------|-----------------|
| `LooseCoupling` | When the concrete collection type carries a meaningful contract (e.g. `ConcurrentHashMap` guarantees thread safety; switching the declared type to `Map` would hide that guarantee and allow accidental substitution with a non-thread-safe implementation). |
| `ReturnEmptyCollectionRatherThanNull` | When `null` and an empty collection have distinct semantics — e.g. `null` means "this field does not apply" and an empty collection means "the field applies but has no entries". Returning empty in that case would silently change the API contract. |
| `NullAssignment` | When `null` is used as a local sentinel in a compact chain of if-else branches and the scope is narrow enough that an `Optional` wrapper would add more ceremony than clarity. |
| `CompareObjectsWithEquals` | When object identity (`!=`) is intentionally compared — e.g. checking whether a mutation algorithm produced a new object rather than returned the original. Value equality would not detect that distinction. |
| `SystemPrintln` | In standalone training, benchmarking, or development utilities whose primary output channel is stdout by design. Replace with a logger in application code. |

### Spring Boot caveats

These adjustments are needed when using Spring Boot with strict static analysis. Each item was discovered in practice; ignoring it will cause a build failure that is not obviously Spring-related.

#### NullAway
- `@ConfigurationProperties` fields are initialized by Spring's property binding, not by a constructor or field initializer. NullAway cannot see this and reports uninitialized `@NonNull` fields. Suppress with `@SuppressWarnings("NullAway.Init")` on the class.
- Use `jakarta.annotation.Nullable` for `@Nullable` — consistent with the Jakarta namespace used throughout Spring Boot 3.x. Do not mix with `org.jspecify` or `org.springframework.lang` annotations in the same module.

#### SpotBugs
- Spring's constructor-injected beans store references to mutable objects, triggering `EI_EXPOSE_REP2`. The injected objects are Spring-managed singletons, so this is safe by design. Create a `spotbugs-exclude.xml` and exclude `EI_EXPOSE_REP2` for your `@Component`, `@Service`, and `@RestController` classes rather than suppressing it per site.
- Do not throw bare `RuntimeException` — SpotBugs flags it as `THROWS_METHOD_THROWS_RUNTIMEEXCEPTION`. Create a specific exception subclass for each module boundary. Add `@java.io.Serial private static final long serialVersionUID = 1L` to every custom exception.

#### ArchUnit
- When constructing `ClassFileImporter`, always add `.withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)`. Without it, test classes that live in the same package as production classes (e.g. `controller`) will appear as production-code dependencies and cause false cross-package violation failures.

#### JaCoCo coverage
- Exclude the `@SpringBootApplication` bootstrap class and `@Configuration`/`@ConfigurationProperties` classes from coverage enforcement. They contain only Spring lifecycle glue that cannot be meaningfully unit-tested. Use the `<excludes>` block in the JaCoCo check execution:
  ```xml
  <exclude>com/example/YourApplication.class</exclude>
  <exclude>com/example/config/YourConfig.class</exclude>
  ```

#### `@RestControllerAdvice` exception ordering
- A catch-all `@ExceptionHandler(Exception.class)` will also match `ResponseStatusException` (which is a subclass of `RuntimeException`). This causes Spring MVC's own error responses (404, 405, etc.) to be swallowed and returned as 500. Register a more specific `@ExceptionHandler(ResponseStatusException.class)` *before* the catch-all to preserve the intended status code.

#### `@MockBean` deprecation (Spring Boot 3.5+)
- `@MockBean` is deprecated in Spring Boot 3.5. Use `@MockitoBean` from `org.springframework.test.context.bean.override.mockito` instead.

#### Error Prone `.mvn/jvm.config` location
- Error Prone requires `--add-exports` JVM flags. These must be placed in `.mvn/jvm.config` **relative to the directory from which Maven is invoked**. If your project layout is a monorepo (`repo/backend/pom.xml`) and CI runs `mvn` from `backend/`, create `backend/.mvn/jvm.config` — the file at the repo root will not be picked up.

#### JDK compatibility (non-LTS versions)
- Many Maven plugins lag behind the JDK release cycle. When targeting a non-LTS JDK (e.g. JDK 25), add explicit `<version>` overrides in the pom for JaCoCo, SpotBugs, PMD, ArchUnit, and Error Prone even if the Spring Boot BOM already manages them — the BOM version may be too old to support the new class-file version.
- Spring Boot 3.3.x bundles ASM 9.6, which cannot parse class files compiled by JDK 25. Upgrade to Spring Boot 3.4.x or later (ASM 9.8+) before running `@WebMvcTest` or any test that loads the Spring context on JDK 25.

### Context-load smoke test
- [ ] Add a `@SpringBootTest(webEnvironment = NONE)` test that loads the full context and asserts a bean wires (e.g. `context.getBean(X.class)`). Unit tests construct beans by hand and ArchUnit is static, so neither exercises real DI — without this, broken wiring (e.g. a `@Component` with two constructors and no `@Autowired`, or a missing bean) only fails when the app actually starts, not in the build. Use `webEnvironment = NONE` so it doesn't bind a port, and inject the context as a test-method parameter to avoid a NullAway-flagged `@Autowired` field.

### Coverage
- [ ] JaCoCo with `<minimum>0.90</minimum>` for line and branch coverage

### Mutation testing
- [ ] PIT (Pitest) — catches weak tests; target 70–80% mutation score

### Dependency management
- [ ] `maven-enforcer-plugin` — enforce minimum Maven/Java versions, ban duplicate dependencies

---

## OpenAPI / API contract

### Lint the spec in CI — the codegen build will NOT catch malformations
- [ ] Add `redocly lint` as a CI gate, run **before** the codegen build. `openapi-generator` (and swagger-parser) are lenient by design — they pass structurally broken specs and emit silently-wrong output, so a green build is **not** evidence of a valid contract. Failure modes observed in practice, all of which built green:
  - invalid schema keywords (`min`/`max` instead of `minLength`/`minimum`) — **ignored**, so no validation annotation is generated
  - a malformed inline response schema (a bare `sessionId:` directly under `schema:`, with no `type`/`$ref`) — generates an **empty model**
  - a media-type typo (`appplication/json`) — accepted as a valid *custom* media type, so the response body binds to **nothing**
- [ ] Use **Redocly**, not Spectral, as the structural gate. Redocly's `recommended` config enables the `struct` rule, which validates schema objects against the OpenAPI meta-schema and catches the invalid-keyword and malformed-inline-schema cases above. Spectral's default `spectral:oas` ruleset does **not** catch them (unknown keywords are valid JSON-Schema annotations, so they pass; it only flagged the missing `operationId` and the unused component). They're complementary — Spectral uniquely catches `oas3-unused-component` — but if you run one structural gate, run Redocly.
- [ ] Redocly exits non-zero only on **errors**, not warnings — so `struct`/keyword violations fail CI while style nits (missing 4xx response, license, `localhost`/example server URL) stay visible but non-blocking. Good default; don't promote warnings to errors without triage.
- [ ] Turn off `security-defined` for APIs with **no auth by design** — its recommended severity is `error`, so it fails the build with one finding *per operation*. Important: OpenAPI security schemes are **declarative only** — they document the API and hint codegen, they do **not** enforce anything. If you add a scheme you must also add server-side enforcement (Spring Security / a filter); the spec half is the easy half.
- [ ] Pin the linter version (`@redocly/cli@2`, not `@latest`) so a new major's rule changes can't turn CI red on an untouched spec.
- [ ] Tune the remaining warnings honestly — don't blanket-disable, and don't fabricate:
  - `operation-4xx-response` is high-value (it surfaced real undocumented error responses — e.g. a GET returning 400/404/500 that the spec omitted), but it false-positives on no-input list endpoints that only ever return 200. **Fix the real gaps; scope the genuine exceptions to a `.redocly.lint-ignore.yaml` (with a comment) rather than turning the rule off** — a global off would have hidden the real bugs it found.
  - `info-license` — turn **off** for an unlicensed hobby/internal project; don't add a `license` block claiming terms the repo doesn't have.
  - `no-server-example.com` (fires on `localhost` too) — fix by using a **relative server URL** (`url: /`, same origin — also the right `basePath` for a generated SPA client) and document the dev URL in prose, instead of hard-coding `http://localhost:...`.

### The gap a linter cannot close
- [ ] A linter proves the spec is **well-formed**; it cannot prove the spec **matches the running server**. The media-type typo above slipped past *both* linters because a media-type key is free-form text. Close this with **codegen + a contract test**: generate models from the spec, compile the server against the generated interfaces, and assert real endpoint responses (status code + body shape) in an integration test. This is what actually catches "spec says X, server returns Y".
- [ ] Treat the spec as the single source of truth — **delete hand-written DTOs that duplicate generated models** (they drift apart). Re-run the generator in CI and fail on any diff vs committed output (see the generated-code item in the CI section).

---

## CI / GitHub

### Branch protection (Settings → Branches → main)
- [ ] Require a pull request before merging (no direct pushes to main)
- [ ] Require status checks to pass before merging — select the CI job(s)
- [ ] Require branches to be up to date before merging
- [ ] Do not allow bypassing the above settings (disables admin override)
- [ ] Disallow force pushes
- [ ] Disallow branch deletion

### Every pull request pipeline must run
- [ ] `npm ci`
- [ ] `npm run lint`
- [ ] `npm run test -- --coverage`
- [ ] `npm run build`
- [ ] `mvn clean verify`

### CI must fail on
- [ ] TypeScript compiler warnings or errors
- [ ] ESLint warnings (`--max-warnings=0`)
- [ ] Prettier formatting violations
- [ ] Failed tests
- [ ] Coverage below threshold
- [ ] Java compiler warnings (`-Werror`)
- [ ] Static analysis violations (Checkstyle, SpotBugs, PMD)
- [ ] Architectural violations (ArchUnit for Java; `eslint-plugin-boundaries` for Angular/TS)
- [ ] Vulnerable dependencies (`npm audit`, OWASP Dependency-Check) — **do not run OWASP on pull requests**. Move it to a dedicated `security.yml` workflow that triggers on push to `main` and on a weekly schedule (e.g. every Monday at 06:00 UTC: `cron: '0 6 * * 1'`). Running it on PRs causes a red cross whenever a CVE exists for which no patched version is yet available, blocking unrelated work. The weekly run keeps findings visible without polluting the PR pipeline. Supply an NVD API key via `${env.NVD_API_KEY}` (free at nvd.nist.gov/developers/request-an-api-key); without it the NVD database update takes 20–30 minutes per run.
- [ ] OpenAPI spec lint errors (Redocly `struct`/keyword rules, run before the codegen build — see the OpenAPI section)
- [ ] Generated-code diffs (re-run generator in CI and fail if output differs from committed files)

### Quality gates

| Area                        | Target  |
|-----------------------------|---------|
| Angular line coverage       | 90%     |
| Angular branch coverage     | 90%     |
| Java line coverage          | 90%     |
| Java branch coverage        | 90%     |
| Mutation score              | 70–80%  |
| ESLint warnings             | 0       |
| Java compiler warnings      | 0       |
| Security critical/high      | 0       |
| Formatting violations       | 0       |

### Pre-commit hooks
- [ ] `npm install --save-dev husky` and `npx husky init`
- [ ] `pre-commit`: run lint and format check on the entire codebase
- [ ] `pre-push`: run build and tests