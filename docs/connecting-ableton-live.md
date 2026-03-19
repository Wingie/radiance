# Connecting Radiance with Ableton Live

Radiance generates music-reactive visuals by analyzing audio input in real-time. It performs beat detection, spectral analysis, and exposes audio levels (low/mid/high) to every shader effect. To connect it with Ableton Live, you route Ableton's audio output into Radiance's audio input.

## What You Need

- **Radiance** (built with `cargo run`)
- **Ableton Live**
- **BlackHole 2ch** — virtual audio device (already installed via `brew install blackhole-2ch`)
- **BH+USB** — Multi-Output Device (already configured in Audio MIDI Setup, combines BlackHole 2ch + USB output)

## Setup Overview

```
Ableton Live ──audio──> BH+USB (Multi-Output Device)
                            ├──audio──> BlackHole 2ch ──audio──> Radiance
                            └──audio──> USB output (speakers/headphones)
```

## Step 1: Configure Ableton Live

1. Open Ableton Live
2. Go to **Preferences** > **Audio**
3. Set **Audio Output Device** to **BH+USB**
   - This sends Ableton's audio to both your speakers (via USB) AND BlackHole simultaneously
4. Alternatively, if you don't need monitoring, set output directly to **BlackHole 2ch**

> **Sample rate note**: BlackHole 2ch runs at 48kHz. Radiance uses CPAL for audio capture, which handles sample rate conversion automatically — no manual adjustment needed.

## Step 2: Configure Radiance

1. Launch Radiance (`cargo run`)
2. In the Radiance UI, find the **audio input device selector** (top area of the interface)
3. Select **BlackHole 2ch** as the input device
4. You should immediately see the spectrum analyzer and beat detection responding to Ableton's audio

> **Don't have this setup?** If you need to create the Multi-Output Device from scratch:
> 1. Install BlackHole: `brew install blackhole-2ch`
> 2. Open **Audio MIDI Setup** (`/Applications/Utilities/`)
> 3. Click **+** > **Create Multi-Output Device**
> 4. Check **BlackHole 2ch** and your output device (speakers/interface)
> 5. Set your output device as **Master**
> 6. Rename it (e.g., "BH+USB")

## Step 3: Verify the Connection

- Play music in Ableton Live
- In Radiance, watch for:
  - **Spectrum widget** showing frequency activity
  - **Beat widget** flashing on detected beats
  - **Waveform widget** showing audio levels
  - Shader effects responding to the music (any effect with intensity > 0 will react)

## How Radiance Uses the Audio

Every shader effect in Radiance automatically receives these audio-reactive uniforms:

| Uniform | Description |
|---------|-------------|
| `iAudioLow` | Low frequency energy (bass), 0.0–1.0 |
| `iAudioMid` | Mid frequency energy, 0.0–1.0 |
| `iAudioHi` | High frequency energy (treble), 0.0–1.0 |
| `iAudioLevel` | Overall audio level, 0.0–1.0 |
| `iTime` | Time in beats (0–16, wrapping), synced to detected BPM |

The beat tracker detects BPM (range 55–215) and all effects automatically sync to the beat. The `iTime` uniform advances in beat-time, so effects stay rhythmically locked to Ableton's tempo.

## Tips for Best Results

- **Send a clean mix**: Radiance's beat tracker works best with a clear kick drum / rhythmic signal
- **Adjust effect intensity**: Use the intensity slider on each effect to control how much it reacts to audio
- **Use the frequency knob**: The frequency parameter on effects controls the rate of animation relative to the beat
- **Low-latency**: Radiance has ~0.1s latency compensation built in for beat tracking. For tighter sync, keep Ableton's audio buffer size small (128–256 samples)
- **No audio?** If Radiance falls back to a constant 120 BPM, it means no audio input is detected — check your device selection

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No audio input devices shown | Check that BlackHole is installed (`brew list blackhole-2ch`) |
| Radiance shows no audio activity | Verify Ableton's output is set to **BH+USB** |
| Audio is choppy or glitchy | Increase Ableton's buffer size, or reduce system audio load |
| Beat detection is erratic | Send a cleaner signal — solo the drum track or use a sidechain send |
| Can't hear audio from speakers | Make sure your speakers are checked in the Multi-Output Device |

## Alternative: Using an Audio Interface with Multiple Outputs

If you have an audio interface with multiple outputs, you can skip BlackHole entirely:

1. In Ableton, route a **Send** track to a spare output pair on your interface
2. Use a physical cable (or internal loopback if your interface supports it) to route that output back to an input
3. Select that input in Radiance

This gives you independent volume control over what Radiance "hears" without affecting your main mix.
