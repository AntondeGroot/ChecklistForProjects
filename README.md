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

**Rules to suppress per site** (use `@SuppressWarnings("PMD.<RuleName>")` on the smallest enclosing element)

| Rule | When to suppress |
|------|-----------------|
| `LooseCoupling` | When the concrete collection type carries a meaningful contract (e.g. `ConcurrentHashMap` guarantees thread safety; switching the declared type to `Map` would hide that guarantee and allow accidental substitution with a non-thread-safe implementation). |
| `ReturnEmptyCollectionRatherThanNull` | When `null` and an empty collection have distinct semantics — e.g. `null` means "this field does not apply" and an empty collection means "the field applies but has no entries". Returning empty in that case would silently change the API contract. |
| `NullAssignment` | When `null` is used as a local sentinel in a compact chain of if-else branches and the scope is narrow enough that an `Optional` wrapper would add more ceremony than clarity. |
| `CompareObjectsWithEquals` | When object identity (`!=`) is intentionally compared — e.g. checking whether a mutation algorithm produced a new object rather than returned the original. Value equality would not detect that distinction. |
| `SystemPrintln` | In standalone training, benchmarking, or development utilities whose primary output channel is stdout by design. Replace with a logger in application code. |

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
- [ ] Vulnerable dependencies (`npm audit`, OWASP Dependency-Check)
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