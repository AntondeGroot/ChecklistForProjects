# Android apps (Capacitor / web-in-a-webview)

Companion to the main [README](README.md). Everything here is a failure that was actually hit,
not a generic list — each item names the quiet way it goes wrong, because the expensive ones on
Android are the ones that fail *silently on a real phone* while passing everywhere else.

The recurring theme: **a phone is not a browser tab.** It sleeps, it has a keyboard that covers
half the screen, it is in a timezone that is not UTC, and it kills your background work without
telling you.

---

## Dates and local time

Get this wrong and the app is wrong for a few hours *every single day*, in a way nobody notices
until someone is up at midnight.

- [ ] **Never derive "today" from `toISOString()`.** `new Date().toISOString().slice(0, 10)` is
      the **UTC** date. East of Greenwich it is *yesterday's* date until your offset has passed —
      in Amsterdam in summer the day rolls over at 02:00, so anything logged at 00:30 lands on the
      day before. Read local calendar parts instead:
      ```ts
      export function localDate(at: Date): string {
        return `${at.getFullYear()}-${two(at.getMonth() + 1)}-${two(at.getDate())}`;
      }
      ```
- [ ] **Make "today" a signal/observable, not a function call.** A `computed()` only re-runs when a
      *signal* it read changes, so a plain `today()` inside one freezes on the day it first ran.
      The symptom is not a crash: the app just keeps serving yesterday, and an app left open
      overnight is still on yesterday in the morning. Something has to **own the tick**.
- [ ] **Schedule the rollover for the next _local_ midnight, built as `day + 1`** — not by adding
      24 hours:
      ```ts
      const midnight = new Date(at.getFullYear(), at.getMonth(), at.getDate() + 1);
      ```
      The constructor normalises a month or year end, and lands on real midnight on the two nights
      a year that are **not 24 hours long**. A fixed `+24h` ticks an hour early on the DST night and
      then drifts.
- [ ] **Give the tick a second of grace.** A timer asked to fire on the stroke can arrive a hair
      early and read the day it was meant to end.
- [ ] **Resync on resume — the timer alone is not enough.** A sleeping phone does not run timers, and
      the common case (backgrounded overnight, opened at breakfast) is caught on the way *back in*,
      never by the timer. Listen for `visibilitychange`, and/or Capacitor's `App` `resume` event.
- [ ] **Keep date-only _arithmetic_ anchored at UTC.** "Add 7 days to `2026-08-10`" should parse as
      `2026-08-10T00:00:00Z`. That is what makes the arithmetic timezone-independent. Local-time is
      for answering *what day is it now*; UTC anchoring is for *calendar maths on date strings*.
      Mixing them up in the other direction is the second-most-common bug here.
- [ ] **Decide, once, what a stored timestamp means** — a local calendar day (`YYYY-MM-DD`) or an
      instant (ISO with offset). Write it down. Half a codebase treating `2026-08-10` as an instant
      and half as a day is unfixable later.
- [ ] **Test under a timezone that is not UTC.** CI runs in UTC, where local == UTC and the bug is
      invisible — a green suite that classifies nothing. Pin the zone in the test:
      ```ts
      vi.stubEnv("TZ", "Europe/Amsterdam");
      const at = new Date("2026-08-10T22:30:00Z");        // 00:30 local on the 11th
      expect(localDate(at)).toBe("2026-08-11");
      expect(at.toISOString().slice(0, 10)).toBe("2026-08-10");   // the bug, pinned
      ```
      That second assertion is the point: it proves the test can go red. Consider running the whole
      suite under `TZ=Europe/Amsterdam` so this class of bug cannot land at all.
- [ ] **Check the device, not just the emulator.** Set the phone to a different timezone, and to
      "24-hour time" off/on, before believing a date feature works.

---

## Notifications

Two different things, and picking the wrong one costs you a backend:

|  | **Local notifications** | **Push (FCM)** |
|---|---|---|
| Needs a server | no | yes — plus Firebase |
| Fires when | a time you scheduled | whenever the server says |
| Works offline | yes | no |
| Good for | reminders, streaks, deadlines | news, chat, anything server-driven |

If every notification your app sends is *about the user's own data on the device*, local
notifications are the whole answer and a backend is not justified. Decide this deliberately —
it is an architecture decision wearing a feature's clothes.

### Local notifications

- [ ] **Android 13+ (API 33) needs the runtime `POST_NOTIFICATIONS` permission.** Without it,
      scheduling *succeeds* and nothing ever appears. Request it, and handle refusal.
- [ ] **Scheduling is fire-and-forget.** A reminder that cannot be set — permission declined,
      notifications off at system level, plugin missing — must never block the thing the user
      actually came to do. Wrap it and swallow, or the first denied permission takes the app down.
- [ ] **A notification cannot ask a question when it fires.** It is set ahead of time and goes off
      regardless. So "only remind me if I haven't done X" is *not* a property of the notification —
      it is decided **when scheduling**, while the answer is known. Reschedule whenever the answer
      changes. A conditional reminder that lies is worse than no reminder.
- [ ] **Prefer a single dated notification over a repeating one** when the condition can change.
      Repeats keep firing on the old assumption; a dated one is recomputed each time state moves.
- [ ] **Notification channels are required from API 26.** Create them at startup. The user owns a
      channel's importance and sound once it exists — **you cannot raise it later in code**, and
      recreating the same channel id keeps the user's settings. Getting the id/importance right on
      the first ship matters more than it looks.
- [ ] **Exact vs inexact alarms.** From API 31 exact alarms need `SCHEDULE_EXACT_ALARM`
      (`USE_EXACT_ALARM` from 33 for alarm-clock-like apps), and on newer versions it is not granted
      by default. Inexact alarms are batched by Doze and can drift by minutes to hours. A 20:00
      nudge does not care; an alarm clock does. Do not ask for the exact-alarm permission unless the
      feature genuinely fails without it — Play reviews it.
- [ ] **Alarms do not survive a reboot** unless something reschedules them
      (`RECEIVE_BOOT_COMPLETED`). Verify your plugin does this rather than assuming — test it by
      actually rebooting the phone.
- [ ] **OEM battery managers silently kill scheduled work.** Xiaomi, Huawei, Samsung and others
      will stop notifications firing with no error anywhere. If reminders are core to the app, test
      on one of those brands, not only a Pixel or an emulator.
- [ ] **Recompute reminders whenever the state they depend on changes** — config loaded, task
      completed, app resumed. A reminder is a cached decision, and every cache needs an
      invalidation rule.
- [ ] **Test the denied path.** "Permission refused" is a normal state, not an error case.

### Push (FCM), if you genuinely need it

- [ ] `google-services.json` per environment; check whether yours belongs in the repo.
- [ ] Handle **token refresh** — tokens rotate, and a stale token is a silently undelivered
      notification. Re-register on every app start, not only on first install.
- [ ] Decide **topics vs per-device tokens** early; migrating later means a data migration.
- [ ] Payload: **`notification` vs `data`** messages behave differently when the app is backgrounded
      (one is drawn by the system, one wakes your handler). Test both app states — foreground,
      background, and swiped-away.
- [ ] **Deep link from the tap.** A notification that opens the home screen wastes the tap; route to
      the thing it was about.
- [ ] From Android 12, **notification trampolines are banned** — you cannot start an activity from a
      broadcast receiver/service in response to a tap. Point the `PendingIntent` at the activity.

---

## Toolchain and build

- [ ] **Pin the JDK; do not take the newest.** Gradle 8.14.x cannot read class file major version
      69+, so a default `JAVA_HOME` of JDK 25/26 fails at *settings evaluation* with "Unsupported
      class file major version" — which reads as a broken project rather than a wrong toolchain.
      Set `org.gradle.java.home` in `~/.gradle/gradle.properties` (user-level, so no
      machine-specific path is committed) or run with
      `JAVA_HOME=$(/usr/libexec/java_home -v 21)`.
- [ ] **Always `cap sync` before building.** Skipping it packages the *previous* web bundle, so your
      fix appears not to work and you go debugging code that was never installed. Put it in a script
      (`npm run android:install`) rather than in your head.
- [ ] **Check for a usable device _before_ building**, so a missing phone costs a second instead of a
      full Gradle run. `adb` is often not on `PATH`, and an attached phone can still be
      `unauthorized`.
- [ ] **`android/` and `ios/` are generated** and contain a copy of the built web bundle — exclude
      both from lint, formatting and coverage.
- [ ] **Adding Kotlin** means `ext.kotlin_version` in `android/build.gradle` and
      `apply plugin: 'kotlin-android'` in `android/app/build.gradle`. Match the version the Capacitor
      plugins already build against so the build does not pull two toolchains.
- [ ] **Register custom plugins _before_ `super.onCreate`** — that is when the bridge builds its
      registry. After is too late, and it fails at runtime, not at build.
- [ ] Test a **release** build, not only debug: minification and resource shrinking break things
      debug never does.

---

## Storage and file access

- [ ] **Shared storage is not readable by default since Android 11.** `Directory.Documents` maps to
      real shared storage, but without a grant a read just returns nothing — no error, no prompt.
- [ ] **Prefer the Storage Access Framework folder picker over `MANAGE_EXTERNAL_STORAGE`.** All-files
      access is restricted to file managers on Play, and asks for the whole device to read one
      folder. The picker costs a small native plugin (Capacitor cannot read tree URIs) and is the
      difference between shippable and not.
- [ ] **Persist the URI grant** (`takePersistableUriPermission`) so the folder is chosen once, not
      daily.
- [ ] **Walk with a `DocumentsContract` cursor, not `DocumentFile.listFiles()`** — the latter issues
      a query per entry and turns a real folder into a long wait.
- [ ] **Batch across the JS↔native bridge.** Every hop costs; a listing followed by one read per file
      pays it hundreds of times. Return the batch, or emit events in chunks (~25), never one per
      item.
- [ ] **`content://` URIs cannot be handed to the webview via `convertFileSrc`.** Either return
      bytes as a data URL (simple; costs memory, so read on demand and cache) or serve them through a
      `WebViewAssetLoader` route (streams; more machinery).
- [ ] **Stream long reads to the UI.** On a phone a large folder takes long enough that a screen
      showing nothing reads as a hang — the app looks broken while it is working perfectly.

---

## Webview and UX

- [ ] **Native dropdowns land on top of the keyboard.** A `<datalist>` or long native picker opens
      over the very field being typed into. Render suggestion lists **inline, in the panel's own
      flow**, so they push content down and scroll with it.
- [ ] **Respect safe areas** (notch, gesture bar) with `env(safe-area-inset-*)`.
- [ ] **Handle the hardware back button** — by default it can close the app from a sub-screen.
- [ ] **Give dialogs a real focus target and an Escape/back path**, or they are unreachable from a
      keyboard and read to a screen reader as though you never left the previous screen.
- [ ] **Test on a small screen in landscape**, where a dialog is taller than the viewport: the panel
      must scroll, or the buttons are unreachable.