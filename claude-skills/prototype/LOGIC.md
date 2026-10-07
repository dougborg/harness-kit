# Logic Prototype

One self-contained HTML file, a **shareable demo**, that lets anyone drive a
state model by clicking buttons. Use it when the question is about business
logic, state transitions, or data shape: things that look reasonable on paper
and only feel wrong once pushed through real cases.

It's one file with nothing to install, so a designer, a PM, or a domain
expert can open it and feel the model for themselves. It speaks their
language, not the code's.

## When this is the right shape

- "I'm not sure this state machine handles X followed by Y."
- "Can this data model represent the case where…"
- "I want to feel out the API before writing it."
- Anything where someone wants to press buttons and watch state change.

If the question is what something should look like, this is the wrong
branch: go back to the skill and take the UI branch.

## 1. State the question

Write the state model and the question in one paragraph, in a visible intro
at the top of the demo (not just a comment), so it can be checked later.
Done when the intro states what the demo explores.

## 2. Isolate the logic in a portable module

Put the logic that answers the question in one `<script>` block, written as a
small pure module that could be lifted into the real codebase. The page
around it is throwaway; the module isn't. Pick the shape that fits the
question, not the one easiest to wire to a page:

- **A pure reducer**, `(state, action) => state`: discrete events, one state
  value.
- **A state machine** with explicit states and transitions: when which
  actions are legal right now is part of the question.
- **A few pure functions** over a plain data type: no implicit current
  state, just transformations.
- **A class or module with a clear method surface**: when the logic really
  owns ongoing internal state.

Keep it pure: no DOM, no `document`, no button handlers reaching in. The page
calls the module; nothing flows the other way. Done when the module would
run unchanged outside the page.

## 3. Build the shareable HTML file

Plain HTML, CSS, and JavaScript, all inline: no framework, bundler, or
server, so it opens by double-click and survives being emailed. Every label
is in domain language: buttons and state read like the business, not the
reducer. Top to bottom:

1. **Title and a one-line explanation** of what the demo explores.
2. **Current state**, as a readable panel of labelled fields (not a raw JSON
   dump), re-rendered after every click. Where it helps, call out what just
   changed.
3. **Free-play buttons**, one per action and always available, so anyone can
   poke at the model in any order.
4. **Guided walkthroughs**, one scenario per tab. Each tab has a short
   plain-language description of the situation and what to watch for, then
   the ordered buttons to press, each a real button that performs its action
   and moves to the next step. Starting a walkthrough resets to a known
   state, so it runs the same way every time.

Pick scenarios that show the awkward cases: the happy path, a tricky edge
case, and an attempt at something that should be illegal. Keep the styling
restrained: clean type, generous spacing, one accent colour, no animation.

Done when every action has a free-play button, every scenario runs from a
reset, and the state panel updates on each click.

## 4. Hand it over

Send the file, or open it for the user. The useful moments are "wait, that
shouldn't be possible" and "huh, I assumed X": bugs in the idea, which is the
point. Add actions or scenarios when asked. Done when the user has the file
and knows how to open it.

## 5. Capture the answer and the prototype

Once the question is answered, capture the verdict and the prototype as the
skill's rules describe. For logic, the validated reducer, machine, or
functions lift into the real module; the HTML file goes to the throwaway
branch, where, being one file, it stays trivial to re-run. Done when the
module is in the real code and the file is on its branch.

## Anti-patterns

- **Adding tests.** A prototype that needs tests is no longer a prototype.
- **Wiring it to the real database.** Use in-memory state unless the
  question is about persistence.
- **Generalising.** No "what if we later need X". It answers one question.
- **Blurring logic and page.** If the module touches the DOM, `document`, or
  button handlers, it can't be lifted. Keep the page a thin shell.
- **Reaching for a framework, bundler, or server.** One file the recipient
  double-clicks; a dev server defeats "shareable".
- **Shipping the HTML shell.** The page is built for clicking through by
  hand. The module behind it is what's worth keeping.
