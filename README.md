# ChecklistForProjects

---

## Angular / TypeScript

### Strict compilation

- [ ] `"strict": true` in `tsconfig.json`
- [ ] `"noUnusedLocals": true` and `"noUnusedParameters": true` in `tsconfig.json`
- [ ] Consider `"noUncheckedIndexedAccess": true` — high-value, but expect churn in array-heavy code. Two Angular-specific traps:
  - **`tsc --noEmit` does NOT catch template index-access** — only `ng build` (strictTemplates) compiles templates. Measure and fix via a build, not a type-check, or you'll miss half the violations (`state.map[key].x`, `row.cells[0].color`, etc. in `.html`).
  - **You can't scope it off for specs.** The unit-test builder compiles the production components' _templates_ under `tsconfig.spec.json`, so turning the flag off there makes your template guards (`?? 0`, `?.x`) fire `NG8102` ("unnecessary nullish coalescing"). It's all-or-nothing across app + specs — budget for `!`-asserting fixture access in tests too (they index controlled data, so `!` is idiomatic there). Actual churn is often far smaller than feared.
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
- [ ] Add `eslint-plugin-sonarjs` and extend `sonarjs.configs.recommended` (enables `cognitive-complexity`; the TS analog to PMD's design rules). In flat config it self-registers — don't also add `plugins: { sonarjs }`. The recommended set has **no autofixers** for most rules (`--fix` does nothing), so the first run is all manual triage. Like PMD, some recommended rules are noise and want a decision (the sonarjs analog of the PMD exclusion table):
  - `sonarjs/todo-tag` — **turn off.** It errors on every `TODO`, which directly fights the ratchet philosophy used throughout this checklist (pinned-debt overrides and boundary exemptions all point at a `TODO`). This one bites the moment you add your first ratchet marker.
  - `sonarjs/pseudo-random` — off when there's no security-sensitive randomness (game dice, animation jitter). It's a crypto rule.
  - `sonarjs/cognitive-complexity` — ratchet it per-file like the size caps (`['error', <current>]` with a `TODO`) rather than refactoring a big untested method up front.
  - Per-site suppress (keep the rule on) for legitimate cases: `no-angular-bypass-sanitization` (rendering your own static i18n HTML), `post-message` (an embed handshake to a host whose origin is unknown until it replies), `super-linear-regex` (a regex over trusted, small input like your own CSS in a test), `function-return-type` (a helper that legitimately returns a union — e.g. a value coerced to its declared type).
  - `sonarjs/prefer-specific-assertions` — high-value but noisy in specs (`expect(x.length).toBe(n)` → `expect(x).toHaveLength(n)`); fix them (a `perl -pe` sweep works) rather than disabling — better failure messages.
- [ ] God-object / size caps — stop a class growing one harmless method at a time. `cognitive-complexity` only guards individual _methods_; these guard the file/function/class as a whole:
  - `max-lines: ['error', { max: 400, skipBlankLines: true, skipComments: true }]`
  - `max-lines-per-function: ['error', { max: 80, skipBlankLines: true, skipComments: true }]`
  - `max-classes-per-file: ['error', 1]`
  - Exempt specs (legitimately long: fixtures, provider setup) with a `files: ['**/*.spec.ts']` override turning the size caps off.
  - **Adopt as a ratchet, not a big-bang.** Files that already exceed the cap get a per-file override pinned at their _current_ counted size (run lint once to read the reported number — it differs from `wc -l` because of `skipBlankLines`/`skipComments`). That's a frozen ceiling: they can only shrink, never grow. Add a `TODO` to lower the number as the file is slimmed, and delete the override once it drops under the global cap. Pinning keeps CI green while making the debt explicit and non-growing; a hard global cap on a brownfield repo just leaves the build red and blocks unrelated work.
  - Note the weakness: line-counting can't tell a god object from a long enum/data file (`photo.ts` of pure interfaces is fine at 400+). The layer-boundary rule below is the structural complement.
- [ ] Architectural layer boundaries — `eslint-plugin-boundaries`, the TS analog to ArchUnit (see the Java section). Attacks the _cause_ of god objects rather than the symptom: a UI component that can `inject()` a store/repository directly will accrete data-layer logic until it's a god object. Tag folders as layers (`component` / `service` / `store` / `domain`) in `settings['boundaries/elements']`, then `boundaries/dependencies` (v6; `element-types` in v5) with `default: 'disallow'` and allow only the legal edges — crucially **forbid `component → store`**, forcing that logic into a service. Adopt as `'warn'` first (the first run is the real coupling map of the app), triage, then promote to `'error'`. Put a `domain` pattern above the broad `component` catch-all so pure utils/types aren't misclassified and wrongly denied store access. **Gotchas that will waste an afternoon if you skip them:**
  - **⚠️ The one that actually blocks you: add a TypeScript import resolver.** boundaries resolves every import _to a file_ before classifying it, using the same resolver as `eslint-plugin-import`. The default node resolver can't follow extensionless TS paths (`./storage/review/review-store`), so every dependency resolves to nothing → "unknown" → `element-types` silently skips it. Result: **the rule passes on a codebase full of violations** (the worst failure mode — a green gate that checks nothing). Fix: `npm i -D eslint-import-resolver-typescript` and add to the boundaries config's `settings`: `'import/resolver': { typescript: { project: 'tsconfig.json' } }`. This was _the_ blocker — patterns were a red herring.
  - **Use v6, not v5 — v5 carries a critical CVE.** `eslint-plugin-boundaries@5` depends on `@boundaries/elements` → `handlebars`, which has a **critical** `npm audit` advisory (AST type-confusion / prototype-pollution) with no fix in the 4.x line. v6 dropped that chain — so `npm i -D eslint-plugin-boundaries@^6`. v6 **renamed the rule** `boundaries/element-types` → `boundaries/dependencies` and uses **object-based selectors**: `from: 'component', allow: ['service']` becomes `from: { type: 'component' }, allow: [{ to: { type: 'service' } }]`. A tiny helper keeps it readable: `const to = (...types) => types.map((type) => ({ to: { type } }))`, then `allow: to('service', 'domain')`. (v6 still _runs_ a v5 `element-types` config with deprecation warnings, so the migration is mechanical — rename the rule, wrap the selectors. `settings['boundaries/elements']` is unchanged.)
  - **Element `pattern`s with `mode: 'full'` match the path relative to cwd** — i.e. `src/app/storage/**/*` works (so do `**/`-prefixed globs). Patterns are _not_ the usual cause of "nothing classifies" — the resolver is. Confirm with `boundaries/no-unknown-files: 'error'`, which flags any _file_ that fails to classify (vs `no-unknown`, which is about _dependencies_).
  - **`boundaries/no-unknown` also flags external packages** (`rxjs`, `@angular/*`, etc.), drowning the signal. Set it `'off'` (or scope it) and read `element-types`/`dependencies` for the real violations.
  - **Type-only imports get flagged too,** and they're most of the first-run list: shared _types_ co-located with a component or store (a `Tag` in the DB-schema file, a view-model interface in a component, persisted/API contract types like `FrameSignature`/`PhotoAsset`). Best fix is **relocate the type to `domain`**. If there are too many to relocate up front, a pragmatic shippable compromise is to allow `domain → store/service` (domain may reference contract types that still live there) while keeping `component → store` forbidden — the load-bearing rule — with a TODO to relocate and tighten later.
  - **Except dev-only/tooling screens and test fixtures** via `ignores` (e.g. a `?debug` diagnostic panel that legitimately reaches into stores, `*.fixture.ts`) rather than contorting the rules around them.
  - **Sanity-check before trusting it — non-negotiable:** inject an import you _know_ crosses a layer (a component that imports a store), confirm the rule errors, then revert. A green gate means nothing until you've watched it go red. If a known violation doesn't fire, classification/resolution is broken — don't conclude the codebase is clean. If the plugin keeps fighting you, the triage's _value_ (the bucketed findings) is also obtainable with a direct `grep` for cross-layer imports while you sort the gate out separately.
  - **For an OpenAPI-generated client, split the generated code into two layers**: `generated-api` (the injectable `*Service` classes — the repository/store analog) and `generated-model` (the DTO _types_). Components import DTO types _everywhere_ and legitimately so, so a single `generated` element with `component → generated` forbidden flags every type import and is unusable. The load-bearing rule is **`component → generated-api` forbidden, `component → generated-model` allowed** — data access goes through an app service, types are free. Order the `generated-api` pattern before the `generated-model` catch-all (first match wins). Ratchet existing `component → generated-api` sites with an inline `// eslint-disable-next-line boundaries/dependencies` + `TODO` (which is why `sonarjs/todo-tag` must be off).

### Formatting

- [ ] Add Prettier + `.prettierrc`
- [ ] CI check: `prettier --check .`

### Testing

- [ ] Minimum coverage thresholds (in Vitest / Jest config):
  ```
  branches: 90%, functions: 90%, lines: 90%, statements: 90%
  ```
  - Angular's `@angular/build:unit-test` builder takes coverage options **natively in `angular.json`** (`coverage`, `coverageThresholds`, `coverageExclude`, `coverageReporters`) — no separate vitest config needed. Leave `coverage` off by default (fast local `ng test`) and pass `--coverage` only in CI. Exclude generated code, `main.ts`, `environments/`, and `**/*.spec.ts`, or the numbers are noise.
  - **Ratchet coverage too.** If the repo isn't at 90% yet, a hard 0.90 gate turns CI red on merge. Measure current, set the threshold just below it with a `TODO` to climb — a frozen floor that can only rise. (Same for JaCoCo `<minimum>` on the Java side.)
- [ ] Mock `HTMLMediaElement.play()` in `src/test-setup.ts` to silence jsdom "Not implemented" errors
- [ ] Register it in `angular.json` under `test.options.setupFiles`
- [ ] **`import.meta.url` resolves elsewhere under V8 coverage instrumentation.** A test that reads a source/CSS file via `dirname(fileURLToPath(import.meta.url))` passes normally but fails _only when `--coverage` is on_ (the module URL points at an instrumented location, so relative reads break). Anchor to the project root instead — `join(process.cwd(), 'src/app')` — which is stable in both modes. This surfaces the first time you wire coverage into CI.
- [ ] **Don't depend on `requestAnimationFrame` timing in unit tests.** rAF-driven animation code can stall under load — e.g. a Husky `pre-push` running build + test together — and never resolve, giving intermittent 5 s timeouts that pass in isolation. Make zero-duration animations short-circuit (jump straight to the end, skip rAF); that's both correct behaviour and deterministic tests.

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

| Rule                                            | Category       | Why exclude                                                                                                                                                                                                                                                                 |
| ----------------------------------------------- | -------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AvoidFieldNameMatchingMethodName`              | Error Prone    | Fires on the record-like accessor pattern (`field foo` + method `foo()`) that many codebases use for mutable value objects. If the pattern is consistent and intentional, the warning is noise.                                                                             |
| `AvoidInstantiatingObjectsInLoops`              | Performance    | Unavoidable in factory and builder code that constructs domain objects from configuration. Refactoring away the `new` inside the loop would either duplicate code or introduce unnecessary indirection.                                                                     |
| `AvoidLiteralsInIfCondition`                    | Error Prone    | Domain-specific algorithms often use small numeric literals (minimum counts, thresholds, distances) that have no meaningful name outside their immediate context. Forcing named constants adds ceremony without clarity.                                                    |
| `AvoidBranchingStatementAsLastInLoop`           | Error Prone    | The "return the first match" loop pattern (`for { … return found; }`) is idiomatic Java for search helpers. PMD flags the `return` as a branching statement at the end of the loop body, but the intent is clear and the alternative (a local variable + break) is noisier. |
| `OneDeclarationPerLine`                         | Best Practices | Compact multi-variable declarations (`int i = 0, j = 0`) are common for tightly related loop counters and parallel accumulators. The rule is a style preference; enforce it through Checkstyle or Spotless if you want it.                                                  |
| `UseVarargs`                                    | Best Practices | When a method genuinely accepts a fixed-shape array (not a variadic call site), changing the signature to varargs changes the calling contract and can introduce ambiguity. Suppress or exclude when arrays are passed intentionally.                                       |
| `GuardLogStatement`                             | Best Practices | SLF4J's parameterized logging (`log.debug("val={}", x)`) is a no-op when the level is disabled; an `isDebugEnabled()` guard is redundant and adds noise.                                                                                                                    |
| `LooseCoupling`                                 | Best Practices | Spring APIs (`RestClient`, `ResponseEntity`, `HttpHeaders`) use concrete types by design; no meaningful interface exists to substitute.                                                                                                                                     |
| `UnitTestShouldIncludeAssert`                   | Best Practices | MockMvc's `andExpect()` chains are assertions; PMD does not recognise them and incorrectly flags the test as having no assertions.                                                                                                                                          |
| `UnitTestContainsTooManyAsserts`                | Best Practices | Multiple `andExpect()` calls on a single MockMvc request are idiomatic; splitting them into separate tests would multiply boilerplate without improving signal.                                                                                                             |
| `AtLeastOneConstructor`                         | Code Style     | Spring beans and `@ConfigurationProperties` classes rely on the implicit no-arg constructor; an explicit one adds noise with no value.                                                                                                                                      |
| `LocalVariableCouldBeFinal`                     | Code Style     | Marking every local variable `final` generates widespread noise without meaningful safety gain in a NullAway-checked codebase.                                                                                                                                              |
| `MethodArgumentCouldBeFinal`                    | Code Style     | Same rationale as `LocalVariableCouldBeFinal`.                                                                                                                                                                                                                              |
| `OnlyOneReturn`                                 | Code Style     | The guard-clause early-return pattern (`if (x == null) return …`) is idiomatic and more readable than a single-return with nested conditionals.                                                                                                                             |
| `ShortVariable`                                 | Code Style     | `e` is the universal catch-block variable; PMD's minimum-length rule has no carve-out for this convention.                                                                                                                                                                  |
| `TooManyStaticImports`                          | Code Style     | Static imports for JUnit 5, Mockito, and MockMvc matchers are standard practice in test classes and aid readability.                                                                                                                                                        |
| `LinguisticNaming`                              | Code Style     | `setUp` and `tearDown` are JUnit 4/5 conventions; PMD incorrectly classifies them as setters because of the `set` prefix.                                                                                                                                                   |
| `ClassWithOnlyPrivateConstructorsShouldBeFinal` | Design         | `@SpringBootApplication` classes must not be `final` — Spring creates a CGLIB subclass. This rule also fires on utility classes that are intentionally non-extendable via a private constructor.                                                                            |
| `DataClass`                                     | Design         | `@ConfigurationProperties` is intentionally a data holder; the rule fires by design on DTOs and config beans.                                                                                                                                                               |
| `LawOfDemeter`                                  | Design         | Spring's fluent builders (`RestClient`, `UriComponentsBuilder`) and MockMvc's DSL chain calls across multiple objects by design.                                                                                                                                            |
| `UseObjectForClearerAPI`                        | Design         | Service methods that require several tightly coupled parameters (e.g. `accessToken`, `catalogId`, `assetId`, `size`) have those parameters out of necessity; a wrapper class would be over-engineering for a small, focused API.                                            |
| `AvoidCatchingGenericException`                 | Design         | A broad `catch (Exception e)` at the `@RestControllerAdvice` boundary is the correct pattern for translating unexpected errors into HTTP 500 responses.                                                                                                                     |
| `SingularField`                                 | Design         | Test-class fields (`mockMvc`, shared `tokenData`) are used across multiple `@Test` methods via `@BeforeEach`; PMD incorrectly suggests moving them to local variables.                                                                                                      |
| `TooManyMethods`                                | Design         | Test classes intentionally have many small, focused `@Test` methods; splitting the class adds navigation overhead without improving test quality.                                                                                                                           |
| `AvoidDuplicateLiterals`                        | Error Prone    | Package-name and endpoint-path strings in ArchUnit rules and integration tests are clearer as inline literals than as extracted constants in small, focused test classes.                                                                                                   |

**Rules to suppress per site** (use `@SuppressWarnings("PMD.<RuleName>")` on the smallest enclosing element)

| Rule                                  | When to suppress                                                                                                                                                                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `LooseCoupling`                       | When the concrete collection type carries a meaningful contract (e.g. `ConcurrentHashMap` guarantees thread safety; switching the declared type to `Map` would hide that guarantee and allow accidental substitution with a non-thread-safe implementation). |
| `ReturnEmptyCollectionRatherThanNull` | When `null` and an empty collection have distinct semantics — e.g. `null` means "this field does not apply" and an empty collection means "the field applies but has no entries". Returning empty in that case would silently change the API contract.       |
| `NullAssignment`                      | When `null` is used as a local sentinel in a compact chain of if-else branches and the scope is narrow enough that an `Optional` wrapper would add more ceremony than clarity.                                                                               |
| `CompareObjectsWithEquals`            | When object identity (`!=`) is intentionally compared — e.g. checking whether a mutation algorithm produced a new object rather than returned the original. Value equality would not detect that distinction.                                                |
| `SystemPrintln`                       | In standalone training, benchmarking, or development utilities whose primary output channel is stdout by design. Replace with a logger in application code.                                                                                                  |

### Spring Boot caveats

These adjustments are needed when using Spring Boot with strict static analysis. Each item was discovered in practice; ignoring it will cause a build failure that is not obviously Spring-related.

#### NullAway

- `@ConfigurationProperties` fields are initialized by Spring's property binding, not by a constructor or field initializer. NullAway cannot see this and reports uninitialized `@NonNull` fields. Suppress with `@SuppressWarnings("NullAway.Init")` on the class.
- Use `jakarta.annotation.Nullable` for `@Nullable` — consistent with the Jakarta namespace used throughout Spring Boot 3.x. Do not mix with `org.jspecify` or `org.springframework.lang` annotations in the same module.
- **Grow `AnnotatedPackages` one package at a time as a ratchet, but the end-state is the _root_ package (`AnnotatedPackages=com.example`), not a curated per-package list.** NullAway treats code in _unannotated_ packages optimistically: it assumes their method returns are `@NonNull` and lets you pass anything to their params. So an explicit allowlist silently _hides_ nullability gaps at every boundary with a package you haven't added yet — e.g. a nullable request-DTO field flowing into a value-object/record constructor in an unlisted `action`/`model` package is accepted with no error, even though it's a latent NPE. Collapsing to the root package once the ratchet is complete both closes those gaps (it found a real one for us the moment we switched) and makes null-safety the _default_ for any package added later, so no one has to remember to extend the list.
- **`AnnotatedPackages` (what NullAway checks) and `XepExcludedPaths` (what Error Prone analyzes at all) are independent knobs — use both.** Set `AnnotatedPackages` to the root package for full coverage, and keep generated code / dev-only tooling / test sources out via `XepExcludedPaths=.*(/generated-sources/|/testapp/|/src/test/).*`. Excluded files are never _analyzed_, but their annotations are still _honored_ at call sites — which is exactly what you want for generated DTOs: enforce their nullability contract on your code without trying to fix the generated code itself.
- **Make the generated API DTOs' nullability honest, or NullAway enforces a wrong contract.** Once the generated model package is in `AnnotatedPackages`, its annotations bind your call sites. Two common mismatches with the OpenAPI (openapi-generator) Spring generator: (1) a genuinely-optional response field left in the schema's `required` list generates as a `@NonNull` constructor arg, so you can't pass the `null` you return at runtime — remove it from `required` and it becomes a clean `@Nullable` wither. (2) Optional _container_ fields (maps/arrays) default to `@NonNull` empty collections; set `<containerDefaultToNull>true</containerDefaultToNull>` in `configOptions` so non-required containers are `@Nullable` — this both matches reality and keeps the wire format omitting them (rather than emitting `{}`/`[]`). A shared spec regenerates the client too, so re-run the client's type-check after either change.

#### SpotBugs

- Spring's constructor-injected beans store references to mutable objects, triggering `EI_EXPOSE_REP2`. The injected objects are Spring-managed singletons, so this is safe by design. Create a `spotbugs-exclude.xml` and exclude `EI_EXPOSE_REP2` for your `@Component`, `@Service`, and `@RestController` classes rather than suppressing it per site.
- **SpotBugs reads `jakarta.annotation.Nullable` _globally_, unlike NullAway's package scoping — so making one shared getter `@Nullable` can cascade `NP_*` findings across every caller, including packages outside `AnnotatedPackages`.** The recurring trap is the _call-twice_ pattern: `if (x.getFoo() != null) use(x.getFoo())` re-invokes the getter, and SpotBugs won't assume the second call is still non-null (`NP_NULL_ON_SOME_PATH_FROM_RETURN_VALUE`). Hoist the value into a local (`var foo = x.getFoo(); if (foo != null) use(foo);`). This surfaces the moment you annotate a getter used in a guard, and again whenever a generated DTO getter turns `@Nullable`.
- Do not throw bare `RuntimeException` — SpotBugs flags it as `THROWS_METHOD_THROWS_RUNTIMEEXCEPTION`. Create a specific exception subclass for each module boundary. Add `@java.io.Serial private static final long serialVersionUID = 1L` to every custom exception.

#### ArchUnit

- When constructing `ClassFileImporter`, always add `.withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)`. Without it, test classes that live in the same package as production classes (e.g. `controller`) will appear as production-code dependencies and cause false cross-package violation failures.
- Also exclude generated code and any dev-only tooling package via a custom `ImportOption` (`location -> !location.contains("/generated/") && !location.contains("/testapp/")`), so the rules describe only hand-written code — same rationale as excluding them from PMD/JaCoCo.
- **Sanity-check with a real bytecode dependency, not an unused `import`.** ArchUnit reads bytecode, where an unused import leaves no trace — inject an actual _usage_ (a field or parameter of the forbidden type), confirm the rule goes red, then revert. (A bonus signal: a genuine cross-layer usage often trips _two_ rules — the direct one and a new cycle — which confirms both fire.)
- **Adopt a cycle rule (`slices()...should().beFreeOfCycles()`) on an existing codebase with `FreezingArchRule`** — the ArchUnit-native ratchet. `FreezingArchRule.freeze(rule)` baselines the current violations to a store and fails only on _new_ ones; the default matcher ignores line numbers, so it's robust to code shifts. It's the right tool because untangling long-standing package cycles (e.g. `game ↔ state` via a marker interface referenced downward) is a real refactoring project, not a gate you can flip green in one pass. Mechanics:
  - `src/test/resources/archunit.properties`: `freeze.store.default.allowStoreCreation=true` for the **first** run (creates the baseline), then flip it to **`false`** so a missing store fails loudly instead of silently re-baselining and accepting whatever exists.
  - **Commit the `archunit_store/` directory — do NOT gitignore it.** It _is_ the baseline. Gitignoring it plus `allowStoreCreation=true` means CI recreates a fresh baseline every run and the guard checks nothing (the same vacuous-green failure mode as the boundaries resolver).
- **Checkstyle `ConstantName` collides with ArchUnit's field-naming convention.** `@ArchTest` rules are `static final` fields named in camelCase so each reads as a sentence (and reports as a readable test name); `ConstantName` demands `UPPER_SNAKE`. Suppress `ConstantName` for the arch-test class rather than uglifying the rule names.

#### JaCoCo coverage

- Exclude the `@SpringBootApplication` bootstrap class and `@Configuration`/`@ConfigurationProperties` classes from coverage enforcement. They contain only Spring lifecycle glue that cannot be meaningfully unit-tested. Use the `<excludes>` block in the JaCoCo check execution:
  ```xml
  <exclude>com/example/YourApplication.class</exclude>
  <exclude>com/example/config/YourConfig.class</exclude>
  ```

#### `@RestControllerAdvice` exception ordering

- A catch-all `@ExceptionHandler(Exception.class)` will also match `ResponseStatusException` (which is a subclass of `RuntimeException`). This causes Spring MVC's own error responses (404, 405, etc.) to be swallowed and returned as 500. Register a more specific `@ExceptionHandler(ResponseStatusException.class)` _before_ the catch-all to preserve the intended status code.

#### `@MockBean` deprecation (Spring Boot 3.5+)

- `@MockBean` is deprecated in Spring Boot 3.5. Use `@MockitoBean` from `org.springframework.test.context.bean.override.mockito` instead.

#### Error Prone `.mvn/jvm.config` location

- Error Prone requires `--add-exports` JVM flags. These must be placed in `.mvn/jvm.config` **relative to the directory from which Maven is invoked**. If your project layout is a monorepo (`repo/backend/pom.xml`) and CI runs `mvn` from `backend/`, create `backend/.mvn/jvm.config` — the file at the repo root will not be picked up.

#### JDK compatibility (non-LTS versions)

- Many Maven plugins lag behind the JDK release cycle. When targeting a non-LTS JDK (e.g. JDK 25), add explicit `<version>` overrides in the pom for JaCoCo, SpotBugs, PMD, ArchUnit, and Error Prone even if the Spring Boot BOM already manages them — the BOM version may be too old to support the new class-file version.
- Spring Boot 3.3.x bundles ASM 9.6, which cannot parse class files compiled by JDK 25. Upgrade to Spring Boot 3.4.x or later (ASM 9.8+) before running `@WebMvcTest` or any test that loads the Spring context on JDK 25.

### Context-load smoke test

- [ ] Add a `@SpringBootTest` test that loads the full context and asserts a bean wires (e.g. `context.getBean(X.class)`). Unit tests construct beans by hand and ArchUnit is static, so neither exercises real DI — without this, broken wiring (e.g. a `@Component` with two constructors and no `@Autowired`, or a missing bean) only fails when the app actually starts, not in the build. Inject the context as a test-method parameter to avoid a NullAway-flagged `@Autowired` field.
  - **`webEnvironment = NONE` only for a non-web app.** For a web app (`@RestController`, SSE, filters) NONE strips the servlet context and those beans fail to wire, so the context won't load at all. Use the default **`MOCK`** — it loads the _full_ context, web beans included, without binding a real port, which is exactly what you want. (The "don't bind a port" goal is already satisfied by MOCK; only `RANDOM_PORT`/`DEFINED_PORT` bind one.)

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
  - a media-type typo (`appplication/json`) — accepted as a valid _custom_ media type, so the response body binds to **nothing**
  - `nullable: true` in an **OpenAPI 3.1** spec — 3.1 removed the keyword, so it's **silently ignored** and the field generates as plain non-null. `struct` catches it; the fix is the union type `type: [string, 'null']`. **But** with openapi-generator's **Spring** generator that union produces `JsonNullable<T>`, which changes the field's Java type and breaks hand-written call sites — so for a field that's merely optional (not explicitly nullable), prefer just `type: string` and leave it out of `required` rather than the union.
- [ ] Use **Redocly**, not Spectral, as the structural gate. Redocly's `recommended` config enables the `struct` rule, which validates schema objects against the OpenAPI meta-schema and catches the invalid-keyword and malformed-inline-schema cases above. Spectral's default `spectral:oas` ruleset does **not** catch them (unknown keywords are valid JSON-Schema annotations, so they pass; it only flagged the missing `operationId` and the unused component). They're complementary — Spectral uniquely catches `oas3-unused-component` — but if you run one structural gate, run Redocly.
- [ ] Redocly exits non-zero only on **errors**, not warnings — so `struct`/keyword violations fail CI while style nits (missing 4xx response, license, `localhost`/example server URL) stay visible but non-blocking. Good default; don't promote warnings to errors without triage.
- [ ] Turn off `security-defined` for APIs with **no auth by design** — its recommended severity is `error`, so it fails the build with one finding _per operation_. Important: OpenAPI security schemes are **declarative only** — they document the API and hint codegen, they do **not** enforce anything. If you add a scheme you must also add server-side enforcement (Spring Security / a filter); the spec half is the easy half.
- [ ] Pin the linter version (`@redocly/cli@2`, not `@latest`) so a new major's rule changes can't turn CI red on an untouched spec.
- [ ] Tune the remaining warnings honestly — don't blanket-disable, and don't fabricate:
  - `operation-4xx-response` is high-value (it surfaced real undocumented error responses — e.g. a GET returning 400/404/500 that the spec omitted), but it false-positives on no-input list endpoints that only ever return 200. **Fix the real gaps; scope the genuine exceptions to a `.redocly.lint-ignore.yaml` (with a comment) rather than turning the rule off** — a global off would have hidden the real bugs it found.
  - `info-license` — turn **off** for an unlicensed hobby/internal project; don't add a `license` block claiming terms the repo doesn't have.
  - `no-server-example.com` (fires on `localhost` too) — fix by using a **relative server URL** (`url: /`, same origin — also the right `basePath` for a generated SPA client) and document the dev URL in prose, instead of hard-coding `http://localhost:...`.

### The gap a linter cannot close

- [ ] A linter proves the spec is **well-formed**; it cannot prove the spec **matches the running server**. The media-type typo above slipped past _both_ linters because a media-type key is free-form text. Close this with **codegen + a contract test**: generate models from the spec, compile the server against the generated interfaces, and assert real endpoint responses (status code + body shape) in an integration test. This is what actually catches "spec says X, server returns Y".
- [ ] Treat the spec as the single source of truth — **delete hand-written DTOs that duplicate generated models** (they drift apart). Re-run the generator in CI and fail on any diff vs committed output (see the generated-code item in the CI section).
  - **If you instead gitignore the generated code** (a valid choice — the spec is then the only source of truth and drift is impossible by construction), the `git diff --exit-code` drift gate becomes a **no-op that silently protects nothing** (a gitignored path never shows in the diff). Delete that CI step rather than leave it implying a guarantee it doesn't provide; the real gate in this model is spec-lint + regenerate-before-build. Pick one model — commit-and-diff, _or_ ignore-and-regenerate — and make the CI match it.

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

| Area                    | Target |
| ----------------------- | ------ |
| Angular line coverage   | 90%    |
| Angular branch coverage | 90%    |
| Java line coverage      | 90%    |
| Java branch coverage    | 90%    |
| Mutation score          | 70–80% |
| ESLint warnings         | 0      |
| Java compiler warnings  | 0      |
| Security critical/high  | 0      |
| Formatting violations   | 0      |

### Pre-commit hooks

- [ ] `npm install --save-dev husky` and `npx husky init`
- [ ] `pre-commit`: run lint and format check on the entire codebase
- [ ] `pre-push`: run build and tests

---

## Refactoring & code design

Applies whenever you touch existing code, not just greenfield. The three that matter most:

- [ ] **Cohesion over god classes.** Group logically-related behaviour together and split large classes along _concept_ boundaries — each class (and file) should be one clear responsibility. When a class accretes unrelated concerns, extract a cohesive collaborator it delegates to (e.g. a 900-line `GameState` → a `TradeManager`, `PlayerRoster`, `TileReachability`; a controller doing routing + seeding + HTML → three classes). Keep the extracted unit's interface narrow — if it needs 6+ collaborators injected, it isn't a clean seam; leave it.
- [ ] **Single level of abstraction per method (SLAP).** Within a method keep every statement at the _same_ level: it should read either as a sequence of named operations _or_ as low-level detail — never a mix. If a method both orchestrates and fiddles with details, push the details into a named helper so the caller reads as a story. (A thin controller endpoint that builds HTML with a `StringBuilder` inline is the classic violation.)
- [ ] **Intention-revealing, human-readable names.** Methods and variables name _what_ they do in domain terms, so the code reads intuitively without comments. Replace magic numbers/strings with named constants (`LAST_TILE`/`SECTION_SIZE`, not bare `15`/`16`). Collapse near-duplicate blocks into one well-named helper (pass the varying part as a parameter) rather than repeating the pattern.

**Do it under a safety net.** Before changing code, confirm it's covered by tests (and read the class it lives in). If coverage is thin, pin the current behaviour with characterization tests _first_, then refactor and re-run the full suite — plus mutation testing if set up — to confirm the change is genuinely behaviour-preserving. A "behaviour-preserving" refactor without that net can silently alter behaviour.
