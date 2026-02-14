# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Project: JiriSewa

Three-sided agricultural marketplace connecting farmers, consumers, and crowdsourced riders in Nepal. See `spec.md` for full specification and `ui.md` for the design system.

### Tech Stack
- **Web**: Next.js 15, App Router, TypeScript, Tailwind CSS
- **Mobile**: Flutter, Dart
- **Backend**: Self-hosted Supabase (PostgreSQL 16 + PostGIS)
- **Maps**: OpenStreetMap + Leaflet (web) + flutter_map (mobile)

### Quality Rules — MANDATORY

**NO MOCKS. NO STUBS. NO PLACEHOLDERS.**

Every piece of code you write must be real, working, production-quality code:

1. **CI must pass.** Before pushing, run:
   - Web: `pnpm tsc --noEmit && pnpm lint && pnpm build && pnpm test`
   - Mobile: `flutter analyze --fatal-infos && flutter test`
   - If CI fails, fix it. Do not push broken code.

2. **No mock data in production code.** If a component needs data, wire it to Supabase. If the API doesn't exist yet, build it or create a bead for it — do not fake it.

3. **No placeholder UI.** Every component must follow `ui.md` exactly:
   - Zero box shadows
   - Outfit font
   - Correct color tokens (primary=#3B82F6, secondary=#10B981, accent=#F59E0B)
   - Scale transforms for hover, not shadow effects
   - Read `ui.md` before writing any UI code

4. **No TODO comments that skip functionality.** If something is out of scope, don't half-implement it. Either build it fully or don't include it.

5. **Tests must test real behavior.** Integration tests over unit tests. Test actual API calls with Supabase test client, not mock responses.

6. **Type safety.** TypeScript strict mode. No `any` types. No `@ts-ignore`.

7. **Supabase migrations must be valid SQL.** Test them locally before committing.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

