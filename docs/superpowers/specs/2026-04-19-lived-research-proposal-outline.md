# Lived Research Proposal — Outline (v1)

**Author:** Mike Subelsky
**Program:** Experience Design Certificate — Lived Research component
**Research window:** June–July 2026 (approx. 65 hrs)
**Proposal due:** 2026-04-24
**Deliverable format:** 3–5 double-spaced pages
**Required components:** line of inquiry, description, bibliography (5+), calendar/timeline, site/sites/itinerary

---

## 1. Line of Inquiry

Exploring the creative possibilities of LLMs as ambient storykeepers and guides for **emergent, audience-driven storytelling** — the kind of collaborative, unscripted narrative that tabletop role-playing games, improv theater, and actual-play podcasts already do at small human scale, and that conventional immersive theater has largely failed to achieve. Can LLM-mediated worldkeeping help this form of story — with its proven capacity for personal and transformative meaning — reach audiences beyond the 4–8 people who can fit around a table? How can such a system preserve coherence and prevent hallucination while still supporting the genuine emergence that makes the form powerful? Context engineering, memory architecture, and agentic orchestration are treated as research fronts.

---

## 2. Description — bullets to write from

### 2a. Opening — the problem with most "immersive" (1–2 paragraphs)
- Most immersive theater is spectacle with atmosphere, not transformation. A well-staged proscenium show can be more moving.
- The gap between "cool" and "meaningful" in immersive isn't a production-value problem; it's a structural one. The story is still *told at* you. Your choices don't actually matter.
- Thesis: what's missing is genuine **emergent authorship by the audience.**

### 2b. Where emergent audience storytelling already works (1 paragraph)
- **Improv theater** — at its best, a scene or show is authored entirely by the people in it, with nothing pre-planned. Improv is often associated with comedy, but gifted long-form improvisers build sustained story worlds; forms like the Harold, Armando, and TJ & Dave–style two-person longform can carry narrative for 30–90+ minutes in ways that fully satisfy an audience. (Your own background as an improv director and actor is lived evidence of this.)
- **Tabletop RPGs** — the GM shapes a world and its rules; players make the story by acting in it. Stakes are real to the participants because they chose them. Entire design lineages (Apocalypse World, Blades in the Dark, Ironsworn, Fiasco) exist to tune this emergent quality.
- **Actual-play podcasts** — proof the form scales to audiences of millions *as listeners* because emergent quality translates even secondhand (Critical Role, Dimension 20, The Adventure Zone, Friends at the Table).
- These forms routinely produce moments of personal and transformative meaning that scripted theater can't reliably deliver. But they all require skilled humans (GMs, improvisers) at a high ratio to participants, which caps audience size.

### 2c. The research bet (1 paragraph)
- LLMs are the first technology plausibly capable of playing part of the skilled GM / improv partner role at scale. Not as an author of plot — but as a **storykeeper:** maintaining a world's state, answering oracular questions about it, shaping its structure, responding to audience action with continuity and surprise.
- If this works, the form can scale beyond the table — not by becoming another kind of scripted immersive theater, but by preserving emergent authorship while growing the group.

### 2d. The central craft problem (1 paragraph)
- Emergence requires the model to be **creative and surprising.** Coherence requires it to be **bounded and faithful to established world-truth.** These two pulls oppose each other — this is where most current LLM-fiction efforts fail.
- Practitioner observation ("I spent weeks building an interactive fiction GPT," r/interactivefictions): *"the player must, to some degree, be complicit with the AI."* The storykeeper framing — where the audience is the primary author — reduces what the model must carry alone.

### 2e. Research fronts (bulleted cluster, not a paragraph)
- **Memory architecture** — what must the storykeeper remember, and in what shape? Episodic vs. semantic vs. temporal knowledge graphs; document-based meta-memory; reference-frame theory.
- **Context engineering** — what's loaded into a given response; how recency, relevance, and world-truth are balanced; retrieval patterns.
- **Agentic orchestration** — narrow-scope agents (moderator / state-keeper / responder) to contain hallucination.
- **Oracle-style response design** — answering from world-state rather than inventing whole cloth. Pattern borrowed from solo RPGs.

### 2f. Prior personal engagement — Mythic Engine (1 paragraph)
- Over roughly 12 months under the working name **Mythic Engine,** I explored this space: architecture notes, a multi-player steel-thread prototype spec, a product-thesis document, and early practitioner interviews with Matt Terry (Southport Marketing) and Glenn Ricci / Ursula Bethell (Bricolage Pittsburgh). The work lapsed as other projects took priority. This Lived Research resumes the inquiry with a sharper framing and a firm horizon: a research report that seeds a small-scale fall portfolio project.

### 2g. Method (1 paragraph)
- ~30 hrs inquiry (structured reading; 8–12 interviews; one field observation).
- ~35 hrs prototyping probes — small, disposable experiments, each aimed at one tension.
- ~10 hrs synthesis, field-note coding, and report outline.

### 2h. Expected output (short close)
- A research report that documents what I found in the literature, what practitioners told me, what each probe revealed, and a design program for the fall creative project.

---

## 3. Bibliography — 15 core sources, grouped

### Foundations of interactive & emergent narrative
1. Murray, J. *Hamlet on the Holodeck: The Future of Narrative in Cyberspace.* 1997 / updated ed.
2. Jenkins, H. *Game Design as Narrative Architecture.* In *First Person: New Media as Story, Performance, and Game,* 2004.
3. Mateas, M. & Stern, A. *Integrating Plot, Character and Natural Language Processing in the Interactive Drama Façade.* AAAI AIIDE Symposium, 2002.

### Improv & live emergent performance
4. Johnstone, K. *Impro: Improvisation and the Theatre.* 1979.
5. Close, D., Halpern, C., Johnson, K. *Truth in Comedy: The Manual for Improvisation.* 1994.

### Tabletop RPG design — the analog prior art for emergent storytelling
6. Baker, V. *Apocalypse World.* Lumpley Games, 2010.
7. Harper, J. *Blades in the Dark.* Evil Hat, 2017.
8. Pigeon, T. *Mythic Game Master Emulator.* Word Mill Games.
9. Tomkin, S. *Ironsworn* (2018) and *Ironsworn: Starforged* (2022).

### LLM-driven interactive narrative (current research)
10. Peng, X., Quaye, J., Rao, S. et al. *Player-Driven Emergence in LLM-Driven Game Narrative.* Microsoft Research, arXiv:2404.17027 (2024).
11. Pan, Z., Andronis, A., Hayek, E. et al. *Guiding Generative Storytelling with Knowledge Graphs.* Charismatic.ai / University of the Arts London (2024).

### Memory & infrastructure
12. Ghosh, B. *Agents That Remember: Temporal Knowledge Graphs as Long-Term Memory.* Medium, April 2025.
13. Hawkins, J. *A Thousand Brains: A New Theory of Intelligence.* Basic Books, 2021.

### Practitioner essays / immersive context
14. Vondle, D. *Integrating AI into Immersive Interactive Fiction* (TAC-2112). Duct Tape AI / Medium, 2023.
15. Ricci, G. *Bricolage's Project Amelia Envisions A Software-Enabled Future.* No Proscenium, 2019.

**Floater sources** — to be added if probes or interviews open those directions:
- Morningstar, J. *Fiasco* (2009).
- Kabashkin, I. et al. *AI Narrative Modeling: Jungian Archetypes,* *Information* 16(4), 2025.
- Salen, K. & Zimmerman, E. *Rules of Play,* 2003.
- Fox, J. *Acts of Service: Spontaneity, Commitment, Tradition in the Nonscripted Theatre of Playback,* 1994.
- Fizel, J. *Squeezing Creativity From an LLM.* Duct Tape AI.
- Hwang, A. et al. *DrawTalking.*
- Barrett, S. / Turner, N. on Herringbone Wang Tiles (procedural environments).

---

## 4. Interviews — target pool (aim for 8–12 completed)

### Researchers
- **Michael Mateas** (UC Santa Cruz, Expressive Intelligence Studio). In-person if possible; sole candidate for travel.
- **Sudha Rao or co-authors,** Microsoft Research — Peng et al. arxiv 2024 paper (cold outreach).
- **Pan et al. authors,** Charismatic.ai / UAL London (virtual; leverage London contacts).

### Immersive practitioners
- **Glenn Ricci & Ursula Bethell** — Bricolage, Pittsburgh (follow-up from prior interview).
- **Nancy Proctor.**
- **Albert Hwang** — DrawTalking.

### LLM-storytelling builders
- **Dave Vondle** — Duct Tape AI / TAC-2112.
- **Jenna Fizel** — Duct Tape AI.
- **AdventureLab** contact (Denmark).

### Emergent-story form carriers
- An experienced **long-form improv director or teacher** (Baltimore / DC / NYC / remote).
- A **tabletop RPG designer** in the emergent/story-games space — someone in the Baker / Harper / Morningstar orbit, via cold outreach.
- An **actual-play GM or producer** from a smaller or mid-tier show where access is realistic.

---

## 5. Calendar / Timeline — ~65 hrs across June–July

| Wk | Dates | Hrs | Focus |
|----|-------|-----|-------|
| 1 | Jun 1–7 | 6 | Foundational reading: Murray, Jenkins, Mateas, Johnstone. Draft interview protocol. Outreach begins. |
| 2 | Jun 8–14 | 8 | Reading continues (Baker, Harper, Pigeon, Tomkin). Interviews #1–#2. Set up prototype harness. |
| 3 | Jun 15–21 | 10 | Interviews #3–#5. Begin **Probe 1: Oracle Responder.** |
| 4 | Jun 22–28 | 10 | Interviews #6–#8. Finish Probe 1, writeup. Begin **Probe 2: Moderated Shared Worldstate.** |
| 5 | Jun 29–Jul 5 | 8 | *Contingent:* West Coast trip if Mateas confirms. Otherwise additional interviews + reading + one field observation. |
| 6 | Jul 6–12 | 10 | Probe 2 main work. Mid-point reflection memo. |
| 7 | Jul 13–19 | 8 | **Probe 3: GM Emulator at Group Scale** (optional). Remaining interviews. |
| 8 | Jul 20–26 | 5 | Interview coding, field-note review, report outline. |
| 9 | Jul 27–31 | — | Buffer. |
| — | Aug 1–8 | — | Report drafting (outside the 65 hrs). |

### Prototype probes — reoriented around emergent storytelling
- **Probe 1 — Oracle Responder.** Given a structured world-state, can the model answer audience queries in-world without inventing contradictory facts? The solo-RPG oracle mechanic, implemented at LLM resolution.
- **Probe 2 — Moderated Shared Worldstate.** Multi-user shared world. A moderator agent gates input; a storykeeper agent updates state; a presenter agent renders state back per user. Probe coherence/surprise tradeoffs as moderator strictness varies.
- **Probe 3 — GM Emulator at Group Scale.** The harder research question: can the system play part of the role a skilled GM plays — setting up stakes, pacing beats, knowing when to yield to player invention — for a group larger than a table?

---

## 6. Sites / Itinerary

- **Primary site:** home studio, Baltimore (Roland Park). All reading, prototyping, and most interviews via Google Meet / phone.
- **Contingent West Coast trip:** ~3 days, conditional on Mateas accepting in-person. Cluster additional West Coast interviews into the same trip (candidates: Hwang; Microsoft Research authors if Seattle-based).
- **Field observation:** one emergent-storytelling experience attended as research during the window. Candidates, in order of relevance:
  - A live actual-play recording (check tour schedules for Dimension 20, Critical Role, Worlds Beyond Number, etc.).
  - A long-form improv show in Baltimore, DC, or NYC.
  - A Bricolage touring piece (if calendar aligns).
  - An immersive theater piece for contrast — what spectacle-dominant immersive feels like next to the emergent forms above.

---

## Notes to self while writing

- The opening should earn the "transformative" claim quickly — concrete personal example from improv or RPG play hits harder than abstract framing.
- The Mythic Engine paragraph (2f) should be matter-of-fact — prior work lapsed, resuming with sharper question. Don't apologize for the gap.
- Keep the research-fronts list (2e) tight. Expand only the one or two you most expect to explore.
- The calendar table is a commitment device, not a prediction. Note that explicitly in the prose.
- The contingent West Coast trip is worth mentioning early in the itinerary section — frame as "research opportunity conditional on Mateas's availability."
