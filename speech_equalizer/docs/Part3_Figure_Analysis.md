# Speech Equalizer: Part 3 - Visual Translation — The Figures

> **Learning Guide:** Now let's go through each generated figure and understand exactly what you're seeing and what it proves to your TA.

---

## 3.1 Tab: "All Magnitudes" — Combined Magnitude Response

### What you're looking at:
A single plot with **7 colored curves**, one per frequency band. The x-axis is **Frequency (Hz)** from 0 to 22,050 Hz (the Nyquist frequency). The y-axis is **Magnitude (dB)**.

### How to read it:
- Each curve shows **how much** of each frequency the corresponding band filter lets through.
- Where a curve is near **0 dB** (the top), the filter is fully passing that frequency — it lets it through unchanged.
- Where a curve drops sharply to **-40 dB, -60 dB, or lower**, the filter is blocking that frequency. At -60 dB, the signal is attenuated to 1/1000th of its original amplitude — effectively silenced.

### What proves correct band isolation:
- The **red curve** (0–100 Hz band) should be flat near 0 dB from 0 to 100 Hz, then drop steeply after 100 Hz.
- The **next curve** (100–300 Hz) should be flat near 0 dB between 100 and 300 Hz, then drop on both sides.
- Each subsequent curve should be a "hill" centered on its frequency range.
- **The hills should not overlap significantly.** If two adjacent band curves overlap a lot in the transition region, that means some frequencies are being counted in two bands, which would make them louder than intended when the bands are summed.

### What the TA might ask:
> "Why aren't the transitions perfectly vertical (like a brick wall)?"

Because that's physically impossible with finite-order filters. The steepness of the transition depends on the filter order. Higher order = steeper. With FIR order 100, you'll see reasonably steep slopes. With IIR order 4, the slopes are gentler but still functional.

---

## 3.2 Tab: "All Phases" — Combined Phase Response

### What you're looking at:
7 curves plotting **Phase (degrees)** vs **Frequency (Hz)**.

### For FIR filters:
The phase curves should be **straight lines** (linear). This is the hallmark of linear-phase FIR filters — the phase is a linear function of frequency, meaning all frequencies are delayed by the same amount of time. The slope of each line equals `-filter_order / 2` samples of delay.

### For IIR filters (without filtfilt):
The curves would be **non-linear** — curved, with different slopes at different frequencies. This represents the phase distortion discussed in Part 1.

### For IIR with filtfilt:
The phase plot of the filter design itself will still look non-linear (because it shows the filter's inherent response), but remember that `filtfilt` cancels this distortion when applied to the signal. The filter's phase response and the actual processing are two different things.

### What proves correct behavior:
- **FIR**: Straight lines = linear phase = no waveform distortion. ✓
- **IIR**: Curved lines = non-linear phase, but `filtfilt` fixes this during processing. ✓

---

## 3.3 Per-Band Tabs: "Band 0-100", "Band 100-300", etc.

Each tab has 6 sub-plots. Let's go through each:

### Sub-plot 1: Magnitude Response (this band only)
Same as the combined view but zoomed to one band. Easier to see the exact passband ripple (if any) and transition width.

### Sub-plot 2: Phase Response (this band only)
Same as combined but for one band.

### Sub-plot 3: Impulse Response

**What it is**: The output of the filter when you feed in a single spike `[1, 0, 0, 0, ...]`.

**What you see for FIR**: A symmetric sequence of coefficients, centered in the middle, tapering to zero at both ends (shaped by the window function). The length equals `filter_order + 1` samples, after which it's exactly zero.

**What you see for IIR**: A few large oscillations that decay exponentially toward zero. It never reaches exactly zero (theoretically), but it gets negligibly small very quickly. The response is much shorter-looking than FIR despite achieving similar frequency selectivity.

**What it proves**: 
- FIR has a **finite**, well-defined impulse response.
- IIR has a **decaying** impulse response — if it decays to negligible values quickly, the filter is stable.

### Sub-plot 4: Step Response

**What it is**: The output when you feed in a constant `[1, 1, 1, 1, ...]`.

**What you see for lowpass bands** (0–100 Hz): The output gradually rises to a steady-state value near 1.0. The rise time depends on the filter order and bandwidth.

**What you see for bandpass bands** (e.g., 100–300 Hz): The output initially rises, then settles to zero. Why? Because a constant signal has frequency = 0 Hz, which is outside the 100–300 Hz passband. The filter correctly blocks it.

**What you see for highpass bands** (10k–20k Hz): Similar to bandpass — the output goes to zero because DC (0 Hz) is blocked.

### Sub-plot 5: Pole-Zero Diagram

**What it is**: A plot on the **complex z-plane** showing:
- **Zeros** (○ circles): Values of z where the filter's transfer function equals zero (complete blocking).
- **Poles** (× crosses): Values of z where the transfer function goes to infinity.
- The **unit circle**: A circle of radius 1 centered at the origin.

**What you see for FIR**: Only zeros (on or near the unit circle), with poles only at the origin (z = 0). FIR filters have all their poles at z = 0, which is always inside the unit circle → always stable.

**What you see for IIR**: Both poles and zeros. The critical thing is that **all poles must be inside the unit circle**. If any pole were on or outside the circle, the filter would be unstable (output would grow unbounded).

**What it proves**: 
- All poles are inside the unit circle → the filter is **stable**. ✓
- Zeros near the unit circle at specific angles correspond to frequencies being blocked.

### Sub-plot 6: Filter Info
Displays the band name, filter type, order, applied dB gain, and the number of numerator/denominator coefficients.

---

## 3.4 Tab: "Time Compare" — Original vs Equalized Waveforms

### What you're looking at:
Two time-domain waveform plots, stacked vertically:
- **Top**: The original signal amplitude vs time.
- **Bottom**: The equalized signal amplitude vs time.

### What to look for:
- **Shape changes**: If you boosted the bass (0–100 Hz, +6 dB), the equalized waveform should show larger low-frequency oscillations — the slow, broad undulations become more prominent.
- **If you cut the treble** (10k–20k Hz, -6 dB), the equalized waveform should look slightly smoother — the fast, tiny wiggles riding on top of the waveform are reduced.
- **Overall amplitude**: The equalized signal is normalized, so its maximum is always 1.0 regardless of the gains applied.

### For speech:
The waveform of speech looks like bursts of activity (when the person is speaking) separated by silence (gaps between words). The equalized version should have the same burst pattern — equalization changes the *frequency content* within the bursts, not their timing.

---

## 3.5 Tab: "Freq Compare" — Frequency Domain Comparison

### What you're looking at:
A single plot with two overlaid curves:
- **Black**: The FFT magnitude of the original signal (in dB).
- **Blue**: The FFT magnitude of the equalized signal (in dB).

### What proves the equalizer worked:
This is your **strongest evidence**. Look at specific frequency ranges:

- **If you set the 0–100 Hz band to +6 dB**: The blue line should be about **6 dB higher** than the black line in the 0–100 Hz region.
- **If you set the 10k–20k Hz band to -6 dB**: The blue line should be about **6 dB lower** than the black line in the 10k–20k Hz region.
- **If a band has 0 dB gain**: The blue and black lines should overlap in that frequency range.

This plot directly shows the equalizer's effect on the frequency content. Each band's gain should be visible as a vertical shift of the blue curve relative to the black curve in that band's frequency range.

---

## 3.6 Tab: "PSD" — Power Spectral Density (Welch)

### What you're looking at:
Similar to the Freq Compare tab, but using the **Welch PSD estimate** instead of a raw FFT. Two curves:
- **Black**: Original signal PSD.
- **Blue**: Equalized signal PSD.

### How it differs from the FFT plot:
The PSD is **smoother** and less noisy. The Welch method averages many overlapping FFT segments, producing a cleaner estimate of the signal's frequency content. The raw FFT (Freq Compare tab) is spiky and volatile; the PSD gives a more reliable, averaged view.

### What proves the equalizer worked:
Exactly the same logic as the Freq Compare tab, but easier to see because the curves are smoother:
- Boosted bands → Blue curve shifts **up** relative to black.
- Cut bands → Blue curve shifts **down** relative to black.
- Unchanged bands → Curves overlap.

### What does the PSD of speech look like?
Speech PSD typically shows:
- **High energy between 100–4000 Hz** — this is where most speech information lives.
- **A peak around 200–500 Hz** — the fundamental frequency of the voice and first formants.
- **Gradual rolloff above 4000 Hz** — less energy at higher frequencies.
- **Very low energy below 80 Hz** — not much useful speech content down there.

### What does noise look like on PSD?
- **White noise** (hiss) has a **flat** PSD — equal energy at all frequencies. It looks like a horizontal line.
- **Pink noise** (more natural) has a PSD that decreases at 3 dB per octave.
- **A hum** (like power line interference) shows a **spike** at one specific frequency.

---

## 3.7 Tab: "Spectrogram" — Time-Frequency Analysis

### What you're looking at:
Two **spectrograms** stacked vertically:
- **Top**: Original signal.
- **Bottom**: Equalized signal.

A spectrogram is a **2D heatmap** where:
- **X-axis** = Time (seconds)
- **Y-axis** = Frequency (Hz)
- **Color** = Intensity/power at that frequency at that time. Bright/warm colors (yellow/red) = high energy. Dark/cool colors (blue/black) = low energy.

### What does a spectrogram of human speech look like?

Speech spectrograms have a very distinctive appearance:

1. **Horizontal bands (formants)**: Vowel sounds produce bright horizontal bands at specific frequencies. These are called **formants** — resonant frequencies of the vocal tract. You'll typically see 2–4 prominent bands, usually between 300 Hz and 4000 Hz.

2. **Vertical lines (plosives)**: Consonants like "p", "t", "k" create brief vertical bars spanning many frequencies simultaneously — they're essentially short bursts of broadband energy.

3. **Gaps**: Pauses between words show as dark vertical columns (silence).

4. **Structure**: Overall, speech has a **structured, patterned** appearance — bands, gaps, transitions. It looks organized.

### What does noise look like on a spectrogram?

- **White noise**: A uniform, speckled pattern with no structure — every frequency at every time has roughly equal energy. It looks like television static.
- **Background hum**: A bright horizontal line at one specific frequency (e.g., 50 Hz or 60 Hz) running across the entire time axis.

### Visual evidence that equalization worked:

Compare the top and bottom spectrograms:

- **Boosted bands**: The corresponding frequency region in the bottom spectrogram should appear **brighter/warmer** (shifted toward yellow/red) compared to the top.
- **Cut bands**: The corresponding frequency region should appear **darker/cooler** (shifted toward blue/black).
- **For example**, if you boosted the 2k–5k Hz band by +6 dB: Look at the horizontal strip between 2000 Hz and 5000 Hz on the y-axis. In the bottom (equalized) spectrogram, that strip should be noticeably brighter than in the top (original) spectrogram.

This is extremely compelling visual evidence because you can literally **see** the frequency bands changing color.

---

## 3.8 Tab: "FIR vs IIR" — Filter Type Comparison

### What you're looking at:
Two time-domain waveforms:
- **Top (Blue)**: The result from your primary filter type choice.
- **Bottom (Red)**: The result from the alternate filter type.

### What to notice:
- With `filtfilt` on the IIR side, both should look very similar because both achieve near-zero-phase filtering.
- Without `filtfilt` (if you used `filter` for IIR), the IIR result might show a **time shift** relative to FIR — peaks appear at slightly different positions because of non-linear phase delay.
- The overall shape should be similar since both are applying the same frequency-domain gains.

---

## 3.9 Tab: "Sample Rate" — Multirate Demonstration

### What you're looking at:
Three time-domain waveforms showing the first ~500 samples of:
- **Top (Blue)**: Original sample rate (e.g., 44,100 Hz).
- **Middle (Red)**: 4× upsampled (e.g., 176,400 Hz).
- **Bottom (Green)**: Half sample rate (e.g., 22,050 Hz).

### What to notice:

**4× upsampled**: The waveform looks **smoother** and more densely sampled. The time axis shows the same duration but with 4× more data points. The shape is identical — you haven't changed the sound, just increased the resolution of the recording.

**Half rate**: The waveform looks **coarser** with fewer data points. It covers the same time duration but with half the samples. You might notice that very fast oscillations (high frequencies) are absent — they were removed by the anti-aliasing filter before downsampling.

**What this proves**: The `resample` function correctly changes the sample rate while preserving the signal's integrity. The anti-aliasing filter prevents aliasing artifacts during downsampling.

---

## 3.10 What to Tell Your TA — Summary of Visual Evidence

When defending your project, point to these specific pieces of evidence:

| Claim | Evidence | Where to Look |
|---|---|---|
| "The 7 bands are correctly isolated" | Each band's magnitude response is a hill centered on the correct frequency range with steep dropoffs | **All Magnitudes** tab |
| "FIR filters have linear phase" | Phase response curves are straight lines | **All Phases** tab |
| "The filters are stable" | All poles are inside the unit circle in every pole-zero diagram | **Per-band** tabs, sub-plot 5 |
| "Gain adjustments work" | Blue curve is shifted up/down relative to black by the exact dB amount in the correct frequency ranges | **Freq Compare** and **PSD** tabs |
| "The spectrogram confirms equalization" | Specific frequency bands are visibly brighter or darker in the equalized spectrogram | **Spectrogram** tab |
| "Sample rate conversion works" | 4× version is smoother, half version is coarser but alias-free | **Sample Rate** tab |
| "FIR and IIR produce comparable results" | Both waveforms have similar shape when filtfilt is used for IIR | **FIR vs IIR** tab |
