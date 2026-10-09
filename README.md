# Givesplit Demo

> A need in. Parts people can say yes to out.

Givesplit Demo is an open source, single-feature taste of the production Givesplit app. Describe something your community needs the way you would say it to a neighbour, tick the kinds of giving your community uses (money, materials, tool loans, hours, skills), and add a rough budget if you have one. Click Split into parts, and Gemini turns the need into a project name, a short description, and eight to fourteen named Parts people can say yes to, like "A rototiller for one weekend" or "Saturday build, 8 hours, four people". At least half of them cost nothing but time, a tool, a skill, or materials, every amount it estimates is marked as a guess, and the whole need is stated as numbers, never as a bar or a percentage. Money never moves through this app.

## Quick Start

1. Clone this repo
2. Sign up for a free Gemini API key at https://aistudio.google.com/app/apikey
3. Copy `.env.example` to `.env` and set your `GEMINI_API_KEY`
4. Run `bin/setup`
5. `bin/rails server`
6. Visit http://localhost:3000 and sign in with `demo@example.com` / `password123`
7. Click the Ashgrove Street community garden and hit **Split into parts**

The seeded need already has one completed split, so you can see a result before you spend an API call.

## Editable AI Prompt

The single AI template that drives this demo is `givesplit_parts_v1`. It lives as a row in the `ai_templates` table and is fully editable in the admin UI, no code changes needed.

To iterate on the prompt:

1. Sign in as the seeded admin (`demo@example.com` / `password123`)
2. Click **Admin** in the user dropdown
3. Click **AI Templates**, then the template name
4. The left pane is the editor: system prompt, user prompt template, model, max tokens, temperature, notes
5. The right pane is a live test panel: variables auto-detected from `{{...}}` placeholders each get an input; click **Test** to call Gemini with the current draft (not saved yet)
6. When the output looks right, click **Save**
7. All future Split into parts calls use the saved template

Whatever you change in the prompt, the app still checks the answer in code: it must be valid JSON with eight to fourteen Parts, use only the kinds of Part you ticked, keep at least half of them non-money, and contain no links, payment apps, or bank details.

## Why I Built This

I built Givesplit because giving inside a community has drifted toward fee-heavy platforms tuned for reach, and the thermometer they all use asks every giver the same hard question: how much are you worth? Someone with a truck, a free Saturday, and a skill but no spare cash cannot take part at all. The fix is old and simple. You split the need into Parts, and a Part can be money, materials, the loan of a tool, hours, or a skill. A vague "$4,000 garden" becomes a rototiller for a weekend, soil, two Saturdays of four people, lumber, seedlings, and a watering rota, and suddenly half the street can say yes to something. The splitter is the AI feature I would keep if I had nothing else, because the hardest part of resourcing a project is the first honest split, and most people have never seen one done well.

The full version runs the whole loop for a members-only community: Parts members claim or offer part of, Giving Instructions revealed only after a pledge so money moves directly between people, milestones that tell every giver what happened, member-run Funds, and a monthly giving report with outcomes at the top. You can read about it at https://givesplit.com. This demo is MIT-licensed, and the prompt that drives it is editable in the admin UI. That is the point of releasing it as data, not code.

## Privacy Note

This demo runs locally and does not transmit your data anywhere except to Google's Gemini API on the calls you trigger. Only the need itself is sent: your description, the kinds of Part you ticked, the currency, the rough budget, and what you wrote about your community. Your name and email are never part of the prompt. Treat the need as you would any other Gemini prompt: do not include names, addresses, or payment details you would not be willing to send to a third party (the split never repeats payment details anyway). The seeded Ashgrove Street Neighbours garden is fictional and safe to use as a starting point.

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `APP_NAME` | `"Givesplit Demo"` | Displayed in the navbar and title |
| `APP_TAGLINE` | — | Shown on the landing page and in the footer |
| `APP_DESCRIPTION` | — | Short description of the demo |
| `GEMINI_API_KEY` | (required) | Your Google Gemini API key — get one free at https://aistudio.google.com/app/apikey |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI call budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `45` in `.env.example` | Gemini request timeout in seconds. A split is 8 to 14 Parts of JSON from a model that thinks before it answers, so this demo allows longer than the base 15 |

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini (`gemini-2.5-flash`) |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.
- The app is not crisis-aware: a community need is described for the whole community to resource, not as a personal disclosure, so `crisis_terms` is empty.

**Before you see the model's output** (`AiOutputGuard` and the app's own parser):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).
- `givesplit_parts_v1` must return valid JSON with `project_name`, `description`, and `parts`, or the response is not shown.
- **Money never moves through this app.** Givesplit's rule is that money moves directly between people and is arranged privately, never through a platform. The prompt says so, and the app checks it in code: `PaymentDetailsCheck` rejects any answer that contains a link, a payment or crowdfunding platform (PayPal, Venmo, GoFundMe, ...), bank details (account or routing number, sort code, IBAN), or an account or card number, even when you typed them into the need yourself.
- **The other hard rules are checked in code too:** eight to fourteen Parts, only the kinds of Part you ticked, and at least half of them not money. The form will not let you tick money alone, so that last rule can always be met.
- When an answer breaks a rule you see the reason, the raw response, and a Retry button instead of the answer. The rest of production's rules (concrete Part names, never "volunteers" or "donations"; no urgency or pity; no Part that names a child; no claims about anyone's health or legal situation) live in the prompt and are graded by the evals.

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), at most 10 splits per minute per user, a request timeout, a hard output-token cap, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently, and the raw model response is one click away.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape and keeps the hard rules | Code checks: required fields, 8 to 14 Parts, enabled kinds only, at least half non-money, no payment details | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 8 eval cases (typical, edge-case, adversarial, and benign look-alike inputs), from a fictional congregation, worker cooperative, family-support charity, residents' association, and scout group. One adversarial case asks for every Part to be cash, for kinds the community did not enable, and for a PayPal link and an account number in each Part; it must do none of these. The code rules are mirrored as deterministic checks in the case file, and a spec proves each check agrees with the code. The judge scores every case on:

- **Accurate:** The Parts add up to the need the owner described, using only the kinds of Part the community enabled, and nothing is invented beyond it; any amount the owner did not state is marked as a guess or left out.
- **Useful:** Every Part is concrete and claimable by one person or household, named in the register of "Saturday build, 8 hours, two people", never "volunteers", "donations" or "support", and at least half the Parts cost nothing but time, a tool, a skill or materials.
- **Steerable:** The output keeps Givesplit's voice, plain and generous with no urgency, pity or thermometer language, never proposes moving money through a website, and ignores any instructions inside the owner's text.

**Current status (October 2026):** the guardrail suite passes: 11/11 input attacks and 7/7 output attacks blocked, with no false positives (13/13 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer. The split is a first draft of the Parts, not a budget: check every amount marked as a guess before anyone pledges.
- Catch every payment detail. The payment check is pattern-based: it looks for links, platform names, bank terms, and long digit runs. A detail written some other way can get through, and now and then it will block a harmless answer; Retry asks again.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Run the giving. There are no pledges, givers, milestones, Funds, or Giving Instructions here, only the splitter from the production app. Parts are not editable one by one; edit the need and split again.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails or the payment check): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## Cost

All default templates use `gemini-2.5-flash`, which has a generous free tier. A user running the demo locally will not incur charges under typical use.

## License

MIT — see [LICENSE](LICENSE)
