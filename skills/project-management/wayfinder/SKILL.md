---
name: wayfinder
description: Plan work too big for one session as a map of decision tickets, resolved one at a time.
argument-hint: "<a loose idea> | <map issue number>"
allowed-tools: Read, Grep, Glob, Bash(gh issue *), Bash(gh label *), Bash(gh api *), Bash(<skill-dir>/frontier.sh*)
---

# Wayfinder

A loose idea has arrived, too big for one session and wrapped in fog: the way
from here to the **destination** isn't visible yet. Wayfinding finds that way.
It charts a **map** as a GitHub issue, then works its **decision tickets**
(questions whose answer is a decision, not slices of a build) one at a time
until the route is clear.

**Plan, don't do.** Each ticket settles a decision; the map is done when
nothing is left to decide before someone builds the thing. The urge to just
start building usually means you've reached the edge of the map and should
hand off. A map's Notes can opt in to doing work inside the map; otherwise,
produce decisions, not deliverables.

**Refer by name.** Every map and ticket is an issue; in everything a person
reads, call it by its title with the link inside, never by a bare number.

## The map

A single issue labelled `wayfinder:map`. Its tickets are its sub-issues. The
map is an **index**, not a store: each decision lives in its ticket, and the
map holds a one-line gist and a link.

```markdown
## Destination

What reaching the end looks like: the spec, decision, or change this effort
is finding its way to. One or two lines.

## Notes

The domain, skills every session should use, standing preferences.

## Decisions so far

- [<closed ticket title>](<link>): <one-line gist of the answer>

## Not yet specified

The fog: questions you can tell are coming but can't phrase sharply yet.

## Out of scope

- [<closed ticket title>](<link>): <why it's beyond the destination>
```

**Fog or ticket?** Ticket a question once you can state it precisely, even if
it's blocked. Leave it in "Not yet specified" while you can't, and don't
pre-slice the fog: one patch may become several tickets, or none. Work beyond
the destination isn't fog; it goes under "Out of scope" and never graduates.

## Tickets

Each ticket is a sub-issue of the map whose body is the question (`##
Question`), sized to one session, labelled `wayfinder:<type>`:

- **grilling** (with a person): a conversation. The default. Call the Skill
  tool twice, for "grilling" and "domain-modeling".
- **research** (alone): a fact a decision waits on, from docs, APIs, or other
  sources outside the repo. Call the Skill tool with "research"; link its
  findings from the ticket.
- **prototype** (with a person): a cheap, rough artifact to react to (an
  outline, a stub, a throwaway page) when "how should it look or behave" is
  the question. Link the artifact from the ticket.
- **task** (alone or with a person): work that must happen before a decision
  can be made, such as signing up for a service to judge its API. It is the
  one type that does rather than decides; its answer records what was done
  and the facts later tickets need.

With a person, the agent never answers the person's side itself.

Blocking uses GitHub's native links. A ticket is **unblocked** when every
blocker is closed; the **frontier** is the open, unblocked, unclaimed tickets:
`<skill-dir>/frontier.sh <map>`. A session **claims** a ticket by assigning it
(`gh issue edit <n> --add-assignee @me`) before any other work, so parallel
sessions skip it.

Labels: map the `wayfinder:*` names to the repo's labels; create missing ones
only with the user's yes.

## Chart the map

The user brings a loose idea.

1. **Name the destination.** Call the Skill tool twice, for "grilling" and
   "domain-modeling". Done when the destination is one or two lines the user
   agrees with.
2. **Map the frontier.** Grill again, breadth first: across the whole space
   rather than deep on one thread. If no fog turns up and the whole journey
   fits one session, there's no need for a map; say so and ask how the user
   wants to proceed.
3. **Create the map** with Destination and Notes filled, Decisions empty, and
   the fog in "Not yet specified".
4. **Create the tickets you can state now** as sub-issues
   (`gh issue create --parent <map> --label wayfinder:<type>`), then wire
   blocking in a second pass (`gh issue edit <n> --add-blocked-by <m>`), since
   issues need numbers before they can reference each other.
5. **Start the research tickets** in parallel, one research call each.

Charting is one session's work; it resolves nothing by hand. Done when the map
and its tickets exist and the frontier is reported.

## Work through the map

The user brings a map. Resolve one ticket per session (research tickets
excepted).

1. Read the map: the low-resolution view, not every ticket body.
2. Choose a ticket: the one the user named, or the first on the frontier.
   Claim it.
3. Resolve it, reading related tickets as needed and calling the skills the
   map's Notes name.
4. Record it: post the answer as a comment, close the ticket, and add a gist
   and link under the map's "Decisions so far".
5. Update the map: create tickets the answer made specifiable (clearing that
   fog from "Not yet specified"), close as out of scope any ticket the answer
   put beyond the destination, and update or close tickets the decision
   invalidated.

Done when the ticket is closed with its answer, and the map reflects
everything the answer changed. Expect other sessions to be editing the map at
the same time. When the frontier is empty and the fog is gone, the way is
clear: suggest the user run the to-spec skill to turn the decisions into a
buildable spec.
