# Acceptance criteria

A spec moves from `draft` to `accepted` when every criterion below holds, and a review says which hold and which do not. Each criterion is a yes or a no with evidence beside it: a spec sentence, a case, or a line an implementation printed. A criterion nobody checked is a no. Where `spec-series lint` checks a criterion, its passing is the evidence.

The same criteria judge a change to accepted specs (`change` mode) and the live set (`series` mode). There a no is a finding against what is already accepted.

## A. It is frames's to do

A no that shows the work is not this specification's rejects the spec, whatever else holds: the work belongs to frames's users or a neighbour. A no the text answers in place, a Motivation not yet written or a general rule not yet stated where the spec already does the work, is revised like any other.

- **A1. It could not be done without this.** For each thing the spec adds, its Motivation names what could not be done with the live set alone. A thing its users could build out of what exists fails.
- **A2. It is general.** One rule covers the feature. A rule that adds a branch for one shape, where a general rule would cover it, fails until the general rule is found.

- **A3. It is a tool, not a purpose.** A new form or purpose is added without changing it. A rule that serves one form or purpose fails, and belongs in a pack, a guide or a tool.
- **A4. It composites and does not generate.** Anything beyond titles and shapes arrives as media.
- **A5. It is the editing model's or a role's.** Behaviour above pixels is decided once, in resolve or evaluation. A rule that a role must carry out itself, beyond drawing, mixing, decoding or encoding what it is given, fails.

## B. What it says is right

- **B0. It has its template's shape.** Every section of its series' template, in order, and every rule under Rules.
- **B1. Every answer is decided.** No input exists for which two people doing the work could answer differently: an order, a spelling, a message, a rounding, a winner between two writes, a stage. A reviewer who finds one shows the input and the two answers.
- **B2. It agrees with the live set.** No sentence contradicts a live spec, and no rule is stated in two places. Every link resolves, and the spec it reaches says what the linking sentence claims.
- **B3. Each thing is said one way.** The spec adds no second spelling for something that already has one.
- **B4. Each refusal is where it is first decidable.** A refusal or failure happens at the earliest stage that has what it needs.
- **B5. The words are standard and single.** The field's term, one sense per word across the specification. No history, and no rule hidden in a **Note.**
- **B6. Another could follow it.** Someone doing the work without the reference implementation, in another language or another team, could do it from the text alone.
- **B7. A form is given whole and stated as what it is.** Every name, spelling, field and layout the spec adds or touches is a grammar or a table, not prose alone. No rule is phrased against the input that raised it where the form it belongs to can be stated instead.
- **B8. A number says what it is.** Each number is exact by definition or mathematics, chosen by frames, or estimated from a measurement, and the text shows which. An estimate names what it was measured on and reads as one that may differ elsewhere. No rule is a count of observations, and no measurement stands as a rule.

## C. The cases are enough

For a spec of a series that is measured. A spec of a series judged by its text alone is not asked them.

- **C1. Every rule sentence is held by a case.** Each refusal has a case at its stage. Each answer has a case that reads it. A sentence no case can hold says why, in a **Note.**
- **C2. Each case breaks one rule.** A refusing case refuses with the message and place of the rule it names, checked by running it rather than by reading its name.
- **C3. The edges are held.** Where a rule draws a line, there is a case just inside it and a case just outside it.
- **C4. It is held against what it meets.** For each accepted spec the feature reaches, there is a case where the two meet.
- **C5. The reference implementation passes them.** Every case passes on the reference implementation pinned at this commit. Accepted means implemented.

## D. The specification stays straight

- **D1. What it changes is made and classed.** Every accepted spec whose text must change is changed in the diff under review: each place `spec-series impact` prints that restates or relies on what changes, and each link `spec-series lint --as` prints. A change made in place is a supplement, and a spec whose decision moves is superseded. A supplement is shown by running the whole suite with the change and seeing no answer move.
- **D2. Supersession is whole.** A superseding spec restates everything it keeps, `Supersedes` names exactly the specs it replaces, and no live spec links to a superseded one.

## E. Nothing is left open

- **E1.** No critical or major finding is open.
- **E2.** Nothing in the spec is marked **Open.**
- **E3.** Every question it raised for the owner has an answer, and the answer is in the text.

## Verdict

- **accept**: every criterion holds.
- **revise**: A holds, or each no in A is one the text answers in place, and something else does not. The review lists each no with what would turn it into a yes.
- **reject**: a no in A shows the work is not this specification's. The review says where the work belongs instead.
