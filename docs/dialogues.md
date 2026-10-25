# Dialogue catalogue

Each authored encounter is stored as its own `StoryText` resource under `resources/dialogues/`. `DialogueCatalog` indexes the resources by stable `act.beat` IDs. Use `get_story(id)` when a caller needs the editable resource, or `get_messages(id)` when it needs typed dialogue lines. Unknown IDs return `null` or an empty typed array.

## Catalogue

| Group | ID | Resource | Lines |
| --- | --- | --- | ---: |
| Cutscene | `cutscene.opening` | `resources/dialogues/cutscene/opening.tres` | 1 |
| Act 1 | `act1.intro` | `resources/dialogues/act1/intro.tres` | 1 |
| Act 1 | `act1.call` | `resources/dialogues/act1/call.tres` | 1 |
| Act 1 | `act1.no_response` | `resources/dialogues/act1/no_response.tres` | 3 |
| Act 1 | `act1.camera` | `resources/dialogues/act1/camera.tres` | 1 |
| Act 1 | `act1.locked` | `resources/dialogues/act1/locked.tres` | 1 |
| Act 1 | `act1.sleep` | `resources/dialogues/act1/sleep.tres` | 8 |
| Act 2 | `act2.wake` | `resources/dialogues/act2/wake.tres` | 3 |
| Act 2 | `act2.silhouette_scare` | `resources/dialogues/act2/silhouette_scare.tres` | 2 |
| Act 2 | `act2.coat_rack_reveal` | `resources/dialogues/act2/coat_rack_reveal.tres` | 2 |
| Act 2 | `act2.coat_rack_repeat` | `resources/dialogues/act2/coat_rack_repeat.tres` | 1 |
| Act 2 | `act2.cellar_approach` | `resources/dialogues/act2/cellar_approach.tres` | 3 |
| Act 2 | `act2.washing_machine` | `resources/dialogues/act2/washing_machine.tres` | 8 |
| Act 2 | `act2.leaving_cellar` | `resources/dialogues/act2/leaving_cellar.tres` | 3 |
| Act 3 | `act3.wake` | `resources/dialogues/act3/wake.tres` | 6 |
| Act 3 | `act3.attic_unreachable` | `resources/dialogues/act3/attic_unreachable.tres` | 1 |
| Act 3 | `act3.freezer_ladder` | `resources/dialogues/act3/freezer_ladder.tres` | 1 |
| Act 3 | `act3.attic_entry` | `resources/dialogues/act3/attic_entry.tres` | 2 |
| Act 3 | `act3.documents` | `resources/dialogues/act3/documents.tres` | 2 |
| Act 3 | `act3.diagnosis` | `resources/dialogues/act3/diagnosis.tres` | 1 |
| Act 3 | `act3.mirror_clue` | `resources/dialogues/act3/mirror_clue.tres` | 1 |
| Act 3 | `act3.code` | `resources/dialogues/act3/code.tres` | 1 |
| Act 3 | `act3.id_reveal` | `resources/dialogues/act3/id_reveal.tres` | 1 |

The catalogue contains 23 resources and 54 spoken lines. Text, capitalization, spelling, vulgarity, ellipses, and the authored `<ziiv>` marker are retained as supplied. Punctuation-only spoken entries remain entries in their original order.

## Author clarification

The Act 3 wake line `Proč by TETA bydlela se mnou? Kde  Ale byl tam ten klíč na půdu` is preserved verbatim, including the double space. Its intended punctuation or wording needs author clarification; this import does not infer a correction.

## Non-spoken direction and narrative notes

After `act2.leaving_cellar`, the supplied direction is `audio pádu a fadeout`. It is not a dialogue resource line.

### Original story outline

The supplied outline says that after the Act 1 sleep, the protagonist wakes around 3:15; dark silhouettes are revealed as mundane objects when the lights turn on; a washing machine in the cellar contains a key and the protagonist then faints; and Act 3 begins around 14:00. It proposes a folding ladder in the freezer leading to the attic, a diagnosis in the documents, a locked cabinet with a combination related to a photographed mirror code, and an ID revealing that the aunt is the protagonist. This is the original narrative outline, not a description of the current implemented route.

### Current attic ending decisions and implementation

The attic room scene and attic art exist. The staircase is temporarily unrestricted, including before day two and before the diagnosis; the hall exit no longer consumes story flags, though the progression helper may retain them for a future story gate. The combination lock remains in the attic by the cabinet, not in the bedroom. Entering the existing code `1234` immediately shows the supplied identity-card art with `act3.id_reveal`; closing that reveal completes the game and opens the final credits, whose return action leads to the menu. The combination code is not an attic-access prerequisite.

The diagnosis and night entity placements remain undecided. The cellar and freezer-ladder sequence is not implemented. The attic and cellar statements in the original outline should not be read as claims that those outline sequences are already in the game.

## Catalogue verification

Run the regular test scene with `Godot --headless --path . res://scenes/testing/dialogue_catalog_verification.tscn`. It checks the catalogue count, typed accessors, unknown IDs, total line count, and the preserved ambiguous line, then exits with a failure code if any check fails.
