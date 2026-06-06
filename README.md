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