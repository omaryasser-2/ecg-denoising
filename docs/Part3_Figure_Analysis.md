# Part 3: Visual Translation (The Figures)

Let's go through each generated figure as if we're looking at them together during your discussion.

---

## Tab 1: Raw ECG

**X-axis**: Time in seconds (0 to 10 s)
**Y-axis**: Voltage in millivolts (mV)

### Record 100 (top, blue)
You see ~10 sharp spikes evenly spaced — these are QRS complexes of a **normal sinus rhythm** (healthy heartbeat at ~72 bpm). The baseline sits around -0.3 mV and you can see slight drift — that's the baseline wander we need to remove.

### Record 106 (bottom, red)
This patient has **PVCs (Premature Ventricular Contractions)**. Some beats look normal, others are taller/wider with a different shape — those are the abnormal beats. The morphology is noticeably different. **Our filter must preserve these differences** — if it smooths them away, a doctor could miss the arrhythmia.

### What proves success to the TA:
You can visually see baseline drift and high-frequency fuzz on both records — confirming the noise is present and needs removal.

---

## Tabs 2–4: Magnitude & Phase Responses

Each tab shows a 3×2 grid: **magnitude** (left column) and **phase** (right column) for the HP, Notch, and LP sub-filters.

### Magnitude Response (left column)
**X-axis**: Frequency in Hz
**Y-axis**: Gain in decibels (dB). 0 dB = unchanged, -40 dB = signal reduced by 100×.

**HP (Baseline) — Magnitude**:
- Below 0.5 Hz: the curve dips down (attenuation). For FIR it reaches about -10 dB. For Butterworth/Cheby2 it drops much more steeply (to -300 dB or more) because IIR is more efficient.
- Above ~1 Hz: the curve is at 0 dB (signal passes through unchanged).
- **What proves it works**: The low-frequency region is attenuated. The ECG band (1+ Hz) is at 0 dB.

**Notch (50 Hz) — Magnitude**:
- You see a sharp V-shaped dip centered exactly at 50 Hz, reaching down to -60 to -80 dB.
- On either side (e.g., 40 Hz and 60 Hz) the magnitude is at 0 dB.
- **What proves it works**: The notch is very narrow and deep — it kills 50 Hz without touching nearby ECG content.

**LP (EMG) — Magnitude**:
- Below 100 Hz: 0 dB (passes through).
- Above 100 Hz: drops sharply. For FIR it oscillates between -60 and -120 dB in the stopband (this is the windowed FIR's characteristic ripple). For Butterworth it drops smoothly. For Cheby2 it drops with a controlled equiripple pattern.
- **What proves it works**: Everything above 100 Hz is heavily suppressed.

### Phase Response (right column)
**X-axis**: Frequency in Hz
**Y-axis**: Phase shift in degrees

**FIR phase**: A **straight line** (linear phase). This is the signature of FIR filters. Every frequency gets the same time delay. The slope of the line equals the group delay.

**IIR phase (Butterworth/Cheby2)**: A **curved line**, especially near the cutoff frequency. This curvature IS the non-linear phase that would distort the waveform — and that's exactly why we use `filtfilt` to cancel it out.

### What the TA wants to see:
- FIR: straight phase line → proves linear phase
- Butterworth: smooth magnitude rolloff → proves maximally flat
- Chebyshev II: steeper rolloff than Butterworth at same order → proves sharper transition

---

## Tabs 5–7: Impulse & Step Responses

Each tab shows a 3×2 grid: **impulse** (left) and **step** (right) for HP, Notch, LP.

### Impulse Response
**X-axis**: Time in seconds
**Y-axis**: Filter output amplitude (unitless)

**FIR HP impulse**: Almost zero for a long time, then a tall spike near the middle (around 0.7 seconds = 250th sample out of 500). This delayed spike IS the group delay. The response is **symmetric** around this center point — that's what gives FIR its linear phase.

**FIR LP impulse**: A sinc-like shape (tall peak at center with small oscillations on both sides). The peak occurs earlier (around 0.14 s = 50th sample) because the LP filter is only order 100.

**IIR impulse**: A sharp spike at time 0 that quickly decays. IIR filters respond immediately (no group delay) but have an exponentially decaying tail.

### Step Response
**X-axis**: Time in seconds
**Y-axis**: Filter output amplitude

Feed in a constant "1" and see how the filter settles:

**HP step**: Starts at 0, may spike, then settles back toward 0. This makes sense — a HP filter blocks DC (constant values). A step signal IS DC, so the output must eventually go to zero.

**Notch step**: Quickly settles to ~1.0 with small oscillations. This makes sense — a step signal has no 50 Hz component, so the notch filter passes it almost unchanged.

**LP step**: Rises from 0 to 1.0 and stays there. A constant signal has zero frequency (DC), and a low-pass filter passes DC.

### What proves success to the TA:
- FIR impulse is symmetric → confirms linear phase property.
- IIR impulse decays to zero → confirms stability (it doesn't blow up).
- Step responses settle to physically expected values (HP→0, Notch→1, LP→1).

---

## Tabs 8–10: Pole-Zero Diagrams

**X-axis**: Real part of z
**Y-axis**: Imaginary part of z
**The dotted circle**: The unit circle (|z| = 1)
**○ symbols**: Zeros
**× symbols**: Poles

### FIR Pole-Zero (Tab 8):
- **Zeros**: Hundreds of small circles distributed around the unit circle. Their angular positions correspond to the frequencies being blocked.
- **Poles**: A cluster labeled "500" at the origin (z = 0). FIR filters always have all poles at the origin. This guarantees stability.
- **What proves success**: ALL poles are at origin → system is always stable, period.

### Butterworth Pole-Zero (Tab 9):
- **HP**: A few poles (×) clustered near z = 1 on the real axis, still inside the unit circle. A few zeros (○) also visible.
- **Notch**: Two zeros ON the unit circle at the angle corresponding to 50 Hz. These zeros force the gain to exactly zero at 50 Hz — that's how the notch works.
- **LP**: Poles inside the unit circle near the angle corresponding to 100 Hz. The "4" label means 4 poles at z = -1.
- **What proves success**: ALL poles (×) are INSIDE the dotted circle → filter is stable.

### Chebyshev II Pole-Zero (Tab 10):
Similar to Butterworth, but the zero positions differ. Chebyshev II places zeros in the stopband to create the equiripple pattern.

### What the TA wants to see:
**Every single × (pole) must be inside the unit circle.** This is THE stability test. If you can point at the plot and say "all poles are inside the unit circle, therefore the system is BIBO stable," you've nailed it.

---

## Tab 11: Filtered vs Raw

**X-axis**: Time in seconds (1 to 5 s window)
**Y-axis**: Voltage in mV

Four panels stacked vertically:
1. **Original (black)**: QRS spikes visible, but the baseline wanders and there's visible high-frequency fuzz.
2. **FIR (blue)**: Cleaner, but the signal appears **shifted to the right** compared to the original. This is the 550-sample group delay.
3. **Butterworth (red)**: Clean, and the peaks line up perfectly with the original (zero phase from `filtfilt`). Baseline is flat near 0 mV.
4. **Chebyshev II (green)**: Very similar to Butterworth. Possibly slightly cleaner due to sharper cutoff.

### What proves success:
- Baseline is now flat (no more drift) → HP worked.
- No visible 50 Hz ripple → Notch worked.
- Less high-frequency fuzz → LP worked.
- QRS peaks are preserved in shape and timing (for IIR).

---

## Tab 12: QRS Zoom

**X-axis**: Time (1.5 to 3.5 s)
**Y-axis**: Voltage (mV)

Zoomed view of 2-3 heartbeats overlaying original and filtered signals:

**Top panel (IIR filters)**:
The original (black), Butterworth (red dashed), and Chebyshev II (green dash-dot) traces overlap almost perfectly. The QRS peaks, P-waves, and T-waves maintain their shape and timing. This proves `filtfilt` achieved zero-phase filtering.

**Bottom panel (FIR)**:
The FIR trace (blue dashed) has the same shape as the original, but it's **shifted to the right** by about 1.5 seconds. This is the group delay. The waveform itself is not distorted — just delayed.

### What proves success:
- IIR signals overlap with original → zero phase distortion confirmed.
- FIR signal has same shape but is shifted → linear phase (constant delay) confirmed.
- QRS amplitude is preserved → no diagnostic information is lost.

---

## Tab 13: PSD (Welch Method)

**X-axis**: Frequency in Hz (0 to 180 Hz)
**Y-axis**: Power Spectral Density in dB/Hz

**Left panel (IIR vs Raw)**:
- Black line (Raw): Shows the full power spectrum. You can see energy across the entire range.
- Red/Green lines (Butterworth/Cheby2): Energy drops sharply above ~100 Hz (LP effect). The drop is 20-40 dB below the raw signal in the 100-180 Hz region. Near 0 Hz, the filtered signals have less energy (HP effect).

**Right panel (FIR vs Raw)**:
- The blue line (FIR) shows a sharp cutoff at 100 Hz — a near-vertical drop. This is the FIR LP filter's sharp transition (500 taps gives a steep wall). Near 50 Hz, there's a dip where the notch filter removed power.

### What proves success:
- Energy above 100 Hz is significantly reduced → EMG noise removed.
- Energy below ~0.5 Hz is reduced → baseline wander removed.
- A dip near 50 Hz → power-line noise removed.
- Energy between 1-40 Hz is **unchanged** → ECG content preserved.

---

## Tab 14: Spectrogram (STFT)

**X-axis**: Time in seconds
**Y-axis**: Frequency in Hz (0 to 100 Hz)
**Color**: Power in dB (yellow = high, blue = low)

Four panels: Raw, Butterworth, FIR, Chebyshev II.

### Raw spectrogram:
- Vertical bright bands at each heartbeat (QRS complexes are broadband energy bursts — they light up across all frequencies simultaneously).
- A faint horizontal band around 50 Hz (constant powerline interference throughout the recording).
- Fairly uniform energy across the frequency range.

### Filtered spectrograms:
- The 50 Hz horizontal band **disappears** (most visible in FIR, where you can see a clear dark horizontal line at 50 Hz).
- Energy above ~80-100 Hz becomes much weaker (more blue/dark).
- The vertical heartbeat bands are still clearly visible — the filter preserved the QRS transients.

### What proves success:
- The 50 Hz horizontal line vanishes → notch filter worked.
- High-frequency region becomes darker → LP filter worked.
- QRS vertical bands survive → signal content preserved.
- The spectrogram shows filtering effect **over time** (not just averaged like PSD), proving the filter works consistently throughout the recording.

---

## Tab 15: SNR Bar Chart

**X-axis**: Filter type (Raw, FIR, Butterworth, Chebyshev II)
**Y-axis**: SNR in dB

- **Raw (gray)**: About -5 dB. Noise is actually stronger than signal.
- **FIR (blue)**: About 3.5 dB. Modest improvement (~8.5 dB gain).
- **Butterworth (red)**: About 30 dB. Massive improvement (~35 dB gain).
- **Chebyshev II (green)**: About 37 dB. Best result (~42 dB gain).

### Why is FIR so much lower?
The FIR HP filter at order 500 can't achieve a sharp enough cutoff at 0.5 Hz (the normalized frequency is extremely low: 0.00278). It doesn't block baseline wander as aggressively as the IIR filters. Also, `filter` (causal) vs `filtfilt` (zero-phase, doubled order) makes a huge difference in effective stopband attenuation.

### What proves success:
All three filters improve SNR over the raw signal. IIR filters show dramatically better performance because of their efficient low-frequency selectivity and the `filtfilt` order-doubling effect.

---

## Tab 16: Record 106 (PVC Morphology)

**X-axis**: Time (1 to 6 s)
**Y-axis**: Voltage (mV)

**Top (black)**: Raw Record 106 showing normal beats interspersed with PVCs (wider, taller, differently shaped beats).

**Bottom (red)**: After Butterworth filtering. The PVCs are still clearly distinguishable from normal beats — their unique morphology is preserved. The baseline is now flat, and noise is reduced.

### What proves success:
The filter cleaned the signal without making PVCs look like normal beats. A cardiologist could still identify the arrhythmia from the filtered signal. This is the ultimate test: **noise removal without diagnostic information loss**.
