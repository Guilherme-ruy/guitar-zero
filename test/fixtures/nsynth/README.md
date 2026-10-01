# Gravações reais de referência (NSynth)

Seis notas de guitarra/violão nas alturas das cordas soltas, usadas como
teste de regressão com áudio real (`test/core/real_audio_test.dart`).

- Origem: **The NSynth Dataset** (Google Inc.), conjunto `nsynth-test`,
  https://magenta.tensorflow.org/datasets/nsynth
- Licença: **Creative Commons Attribution 4.0 International (CC BY 4.0)**,
  https://creativecommons.org/licenses/by/4.0/
- Alterações: reamostradas de 16 kHz para 44.1 kHz (ffmpeg) e cortadas nos
  primeiros 3.5 s. O nome do arquivo é o identificador original da nota
  (`instrumento-pitchMIDI-velocidade`).

| Arquivo | Nota | Por que foi escolhida |
| --- | --- | --- |
| `guitar_acoustic_015-040-050` | E2 | inarmonicidade alta (B ≈ 3.5e-4), pitch que cai após o ataque, cauda ×3 |
| `guitar_acoustic_014-045-050` | A2 | inarmonicidade moderada (B ≈ 5e-5) |
| `guitar_acoustic_010-050-050` | D3 | quase harmônica |
| `guitar_electronic_028-055-050` | G3 | guitarra elétrica |
| `guitar_electronic_022-059-075` | B3 | guitarra elétrica com variação de pitch |
| `guitar_acoustic_021-064-127` | E4 | ataque forte |
