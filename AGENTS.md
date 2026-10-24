For version control, use `C:\Users\vdolansky\Downloads\PortableGit-2.56.0.3-64-bit.7z\cmd\git.exe`. The `PortableGit` folder does not contain a Git executable.

No script should be longer than 300 lines.
No scene file except level scenes should be longer than 15 nodes directly (compounding scenes within scenes is fine).

For WAV-to-OGG conversion, use `scripts/convert_wav_to_ogg.cmd` (requires FFmpeg with `libvorbis`). It writes to `assets/audio` by default; assign the OGG in the AudioManager and enable looping there when needed.
