# Úpravy nahrávek z 25. října 2026

## Záloha před ořezem

Původní soubory jsou uložené beze změny v `audio_sources/untrimmed/2026-10-25/`.
Před ořezem byly porovnané kontrolní součty SHA256 kopií s původními soubory.
Záloha obsahuje `door.wav`, `footsteps.wav`, `lock.wav`, `washing_machine.wav`,
`voice_message.wav` a předchozí verzi `creepy.ogg`.
Soubor `.gdignore` brání importování záložních nahrávek do hry.

Pro vrácení jednotlivého zvuku spusť z kořene projektu například:

```powershell
Copy-Item -LiteralPath audio_sources/untrimmed/2026-10-25/lock.wav -Destination assets/audio/lock.wav -Force
```

Potom nech Godot soubor znovu importovat. Obdobně lze obnovit předchozí `creepy.ogg`.

## Ořezy

`scripts/trim_audio_leading_silence.ps1` má explicitní rozsahy po jednotlivých samplech.
Používá FFmpeg `atrim`, nepřeskládává zvuk, nezesiluje ho a nemaže pauzy uvnitř nahrávek.
Formát zůstává PCM16 se zachovanými kanály a původním sample rate.

| Zvuk | Vybraný začátek v původní nahrávce | Výsledná délka |
| --- | ---: | ---: |
| Dveře | 0,693 s | 3,138 s |
| Kroky | 0,639 s | 6,954 s |
| Zámek | 3,344 s | 0,156 s |
| Pračka | 0,347 s | 7,733 s |
| Původní hlasová zpráva | 0,143 s | 8,140 s |

Zámek obsahuje pouze jedno izolované cvaknutí z posledního plného pokusu;
další pokusy v původní nahrávce se při změně číslice nepřehrávají.
Ostatní nahrávky zachovávají vše za vybraným začátkem.

Pro zopakování úpravy z již existující zálohy:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/trim_audio_leading_silence.ps1 -BackupName 2026-10-25 -FromBackup
```

Bez `-FromBackup` skript nejprve vytvoří a ověří zálohu a odmítne přepsat jinou existující zálohu.
Rozsahy patří k těmto konkrétním nahrávkám; pro nové soubory je nutné vybrat nové rozsahy.
`audio_trim_verification.tscn` ověřuje hashe originálů, shodu zachovaných samplů,
jediný take zámku a přítomnost zvuku během prvních 20 ms.

## Nová creepy hudba

Dodané `crepy.wav` nahrazuje `assets/audio/creepy.ogg`.
Převod provedl `scripts/convert_wav_to_ogg.cmd`; nová stopa má délku 54 sekund.
Přehrává se ve stávajícím AudioManageru přes bus `Music`, s `loop_music = true`.
Smyčku zajišťuje `AudioStreamOggVorbis.loop`, nikoli jen opakované spouštění po konci.
Alternativní hudba `not_creepy.ogg` zůstává beze změny.
