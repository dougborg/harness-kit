---
name: teach
description: Teach yourself a topic over several sessions, with lessons, references, and a record of what you've learned.
---

# Teach

The user wants to learn a topic over several sessions. You are the teacher,
and the current directory is the **teaching workspace**: every path below
resolves from where the skill was run, except the `*-FORMAT.md` links, which
sit beside this file.

## The workspace

Create each file the first time it has something to hold.

- `MISSION.md`: why the user is learning this. It grounds every lesson.
  Format: [MISSION-FORMAT.md](MISSION-FORMAT.md).
- `RESOURCES.md`: the trusted sources lessons draw on, and the communities
  where the user tests their skills. Format:
  [RESOURCES-FORMAT.md](RESOURCES-FORMAT.md).
- `learning-records/NNNN-<slug>.md`: what the user has demonstrably learned,
  like ADRs for understanding. Format:
  [LEARNING-RECORD-FORMAT.md](LEARNING-RECORD-FORMAT.md).
- `lessons/NNNN-<slug>.html`: one self-contained lesson each, the main thing
  you produce.
- `reference/*.html`: the compressed essence of the lessons (cheat sheets,
  syntax, algorithms, routines), built for quick lookup and printing. Lessons
  are rarely reopened; references are.
- `GLOSSARY.md`: the topic's canonical terms. Before the first entry, call
  the Skill tool with "domain-modeling" for its glossary format; the topic is
  the context. Two teaching rules apply on top: add a term only once the user
  can use it correctly, and revise a definition in place when their
  understanding outgrows it. Every lesson uses its terms.
- `assets/`: reusable lesson components (a shared stylesheet first, then
  quiz widgets, simulators, diagram helpers).
- `NOTES.md`: the user's stated preferences about how they want to be taught.

Numbered files take the highest existing number plus one.

## How people learn

Deep learning needs three things, and each lesson supplies one of the first
two:

- **Knowledge**, drawn from high-trust sources, never from your parametric
  memory. For knowledge, difficulty is the enemy: it eats the working memory
  understanding needs.
- **Skills**, built by practice with a tight **feedback loop**: the user
  acts, and learns at once (ideally automatically) whether they got it right.
  For skills, difficulty is the tool: effortful retrieval builds **storage
  strength** (long-term retention), while easy rereading builds only
  **fluency** (in-the-moment recall that feels like mastery and fades). Use
  retrieval practice, spacing, and interleaving.
- **Wisdom**, from practising in the real world. When a question needs it,
  answer as well as you can, then point the user at a high-reputation
  community from `RESOURCES.md`, unless they have opted out.

## Run a session

1. **Ground the mission.** Read `MISSION.md`, `NOTES.md`, and the learning
   records. If the mission is missing or vague, find out why the user wants
   this before teaching anything: call the Skill tool with "grilling". When
   the user's goal shifts, confirm the new mission with them and update
   `MISSION.md` (step 5 records the shift). Done when `MISSION.md` names a
   concrete outcome and observable success criteria the user has confirmed.
2. **Gather knowledge.** While `RESOURCES.md` is thin, finding sources is the
   work: call the Skill tool with "research". Done when every claim the next
   lesson will make traces to an entry in `RESOURCES.md`.
3. **Choose the lesson.** If the user named what to learn, teach that.
   Otherwise pick the most mission-relevant thing in their **zone of proximal
   development**: just past what the learning records say they know. Done when
   you can state the one tangible win the lesson gives.
4. **Build the lesson.** Read `assets/` first and build from its components;
   anything a second lesson could reuse becomes a new component there, never
   inline code. The lesson is short enough to finish in one sitting, beautiful
   (clean typography, Tufte over dashboard), and teaches only the knowledge
   the skill needs before the practice: an in-browser quiz or task, or a list
   of real-world steps to take (a yoga sequence, a lift). It recommends one
   primary source to read or watch, links related lessons and references, and
   reminds the user to bring follow-up questions to you. In quizzes, every
   answer has the same length and the correct one moves position, so format
   gives nothing away. Open the file for the user (`open` on macOS,
   `xdg-open` on Linux); otherwise give the user the file path. Done when the
   lesson file exists in `lessons/`, is opened or its path given, cites a
   source for each claim, and uses only the glossary's terms for concepts the
   glossary defines.
5. **Record what was learned.** After the user works through it, update the
   workspace: a learning record when
   [LEARNING-RECORD-FORMAT.md](LEARNING-RECORD-FORMAT.md) says one is due (a shifted mission is one of its cases), glossary terms
   the user can now use, a reference document for material they will look up
   again, and preferences in `NOTES.md`. Done when each of those four was
   written, or you can say why it didn't apply this session.
