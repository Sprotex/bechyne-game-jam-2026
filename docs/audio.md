# Zvuky

Zálohy, přesné ořezy nahrávek a výměna hudby jsou popsané v `docs/audio-editing.md`.

Dodané nahrávky M4A jsou převedené do mono WAV (PCM 16 bitů, 44 100 Hz):

| Původní nahrávka | Asset | Použití |
| --- | --- | --- |
| dveře.m4a | `assets/audio/door.wav` | Průchod dveřmi mezi místnostmi |
| kroky.m4a | `assets/audio/footsteps.wav` | Smyčka při drženém pohybovém vstupu |
| zámek.m4a | `assets/audio/lock.wav` | Změna cifry otočného zámku |
| pračka.m4a | `assets/audio/washing_machine.wav` | Globální smyčka ve druhém aktu |

Převod používá FFmpeg: `ffmpeg -i vstup.m4a -vn -ac 1 -ar 44100 -c:a pcm_s16le vystup.wav`.
Soubory WAV jsou přímo přiřazené v `scenes/audio/audio_manager.tscn`.
Pokud se později převádějí WAV na OGG, použije se `scripts/convert_wav_to_ogg.cmd`.

`AudioManager.set_loop_active()` spouští pojmenované smyčky bez opakovaného restartování.
Změna režimu smyčky upravuje kopii streamu, nikoli sdílený importovaný asset.
Rychlé protáčení zámku znovu spouští jeden přehrávač, aby se dlouhé nahrávky nehromadily.
Kroky zatím nejsou synchronizované s animací; hrají i při chůzi proti překážce.
Zastaví se po uvolnění pohybu, při blokování ovládání nebo opuštění herní scény.

## Pračka

Bus `WashingMachine` posílá výstup do `Sound`, takže reaguje na hlasitost efektů.
Má samostatnou hlasitost a prostor pro budoucí efekty; není závislý na aktuální místnosti.
`StoryAudio` v herním levelu zapíná smyčku po nastavení `story.day_two`.
Přechody mezi místnostmi přehrávání nerestartují.

Pračka se vypne při `story.washing_machine_stopped`, `story.act_three`,
`story.identity_read`, dokončení hry nebo opuštění levelu.
Budoucí sekvence sklepa má při vypnutí pračky nastavit `story.washing_machine_stopped`;
při začátku třetího aktu nastaví `story.act_three`. Samotná sekvence zatím neexistuje.
