# Givesplit Demo - Build Tracker

**Spec:** [`givesplit-demo-spec.md`](givesplit-demo-spec.md)
**Process:** `OPEN-SOURCE-PLAYBOOK.md` steps 4-12
**Boilerplate:** open-base (scaffolded with `new-open-app.sh givesplit "Givesplit" "..."`)

| # | Phase | Status |
|---|---|---|
| 1 | Branding and config: `.env(.example)` (timeout 45s), layout and mailer fallback name, teal/amber accent CSS, landing page; base dashboard removed; `db/schema.rb` rebuilt without open-base's orphan tables | `[x]` |
| 2 | Models: `Need`, `PartsPlan`, `Part` migrations, validations, constants, associations | `[x]` |
| 3 | Routes and controllers: `NeedsController` CRUD, `PartsPlansController` (index redirect, rate limit, rescues) | `[x]` |
| 4 | Views and Stimulus: dashboard, form with kind checkboxes, need page, result page with Part tiles, `generating`, `form_submit`, `download_markdown` | `[x]` |
| 5 | AI integration: `givesplit_parts_v1` prompt, parser (8-14 parts, enabled kinds, half non-money), `PaymentDetailsCheck` | `[x]` |
| 6 | Seeds: template, Ashgrove Street garden need with a completed split, `demo_placeholder_v1` removed (seeds and DB) | `[x]` |
| 7 | Guardrails and evals: `config/ai_guards.yml`, `evals/cases/givesplit_parts_v1.yml` (8 cases, code rules mirrored), placeholder case removed | `[x]` |
| 8 | Specs: models, `PaymentDetailsCheck`, eval mirror, requests; `bundle exec rspec` green; `bin/rails evals:guardrails` PASS | `[x]` |
| 9 | README rewrite, UI journey manifest (port 3126), pre-publish check, local commit | `[x]` |

## Quick reference

```
needs_path                         GET  /needs   (also /dashboard)
new_need_path                      GET  /needs/new
need_path(n)                       GET  /needs/:id
edit_need_path(n)                  GET  /needs/:id/edit
need_parts_plans_path(n)           POST /needs/:id/splits   (GET redirects to the need)
need_parts_plan_path(n, p)         GET  /needs/:id/splits/:id
```

```
Template:   givesplit_parts_v1   (gemini-2.5-flash, 8192 max tokens, temperature 0.5)
Variables:  need_text, enabled_kinds, currency, rough_budget, community_context
JSON:       project_name, description, parts[8-14]{kind, name, amount, price_is_guess,
            quantity, unit, why_it_matters}, questions_for_owner[0-2]
Code rules: 8-14 parts, enabled kinds only, at least half non-money, no payment details
```

## Not done here (needs the owner)

- Live runs: `bin/rails evals:run` and `./ui-journey-fleet.sh --yes open-givesplit` (real Gemini calls). The free
  journeys (`--free`) were not run either: the build agent was not allowed to boot the server.
- `Open/README.md` app count and `git open repos.md` remote line (shared files, updated by the coordinator).
- GitHub repo creation and push.
