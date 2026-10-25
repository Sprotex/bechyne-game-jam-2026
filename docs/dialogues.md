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

Sequence context supplied for documentation only: after the Act 1 sleep, the protagonist wakes around 3:15. Dark silhouettes are revealed as mundane objects when the lights turn on. A washing machine in the cellar contains a key and the protagonist then faints. Act 3 begins around 14:00. A folding ladder in the freezer provides access to the attic. The documents reveal a diagnosis; a locked cabinet has a combination related to a photographed mirror code; an ID reveals that the aunt is the protagonist. This context is not implemented as state logic.

The current project does not yet contain attic or cellar room art/scenes. Importing these resources does not place interactors or change existing scene text.

## Catalogue verification

Run the regular test scene with `Godot --headless --path . res://scenes/testing/dialogue_catalog_verification.tscn`. It checks the catalogue count, typed accessors, unknown IDs, total line count, and the preserved ambiguous line, then exits with a failure code if any check fails.
