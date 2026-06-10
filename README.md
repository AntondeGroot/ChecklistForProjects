# ChecklistForProjects

---

## Angular / TypeScript

### Strict compilation
- [ ] `"strict": true` in `tsconfig.json`
- [ ] `"noUnusedLocals": true` and `"noUnusedParameters": true` in `tsconfig.json`
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

### Coverage
- [ ] JaCoCo with `<minimum>0.90</minimum>` for line and branch coverage

### Mutation testing
- [ ] PIT (Pitest) — catches weak tests; target 70–80% mutation score

### Dependency management
- [ ] `maven-enforcer-plugin` — enforce minimum Maven/Java versions, ban duplicate dependencies

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
- [ ] Architectural violations (ArchUnit)
- [ ] Vulnerable dependencies (`npm audit`, OWASP Dependency-Check) — **do not run OWASP on pull requests**. Move it to a dedicated `security.yml` workflow that triggers on push to `main` and on a weekly schedule (e.g. every Monday at 06:00 UTC: `cron: '0 6 * * 1'`). Running it on PRs causes a red cross whenever a CVE exists for which no patched version is yet available, blocking unrelated work. The weekly run keeps findings visible without polluting the PR pipeline. Supply an NVD API key via `${env.NVD_API_KEY}` (free at nvd.nist.gov/developers/request-an-api-key); without it the NVD database update takes 20–30 minutes per run.
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