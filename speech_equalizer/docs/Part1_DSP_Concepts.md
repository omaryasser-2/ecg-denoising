# Part 1: The Foundational DSP & Audio Concepts

Before we touch a single line of MATLAB code, we need to build up every concept from absolute zero. By the end of this section, you will understand what an equalizer is mathematically, how filters work, what "dB" means, and what happens when you change the speed at which audio is recorded. Let's begin.

---

## 1.1 What is Sound, Physically?

Sound is vibration. When someone speaks, their vocal cords vibrate, pushing air molecules back and forth. These vibrations travel through the air as a **pressure wave**. When this pressure wave reaches your ear, your eardrum vibrates, and your brain interprets that vibration as sound.

A **microphone** does the same thing as your eardrum: it converts the air pressure fluctuations into an **electrical voltage** that goes up and down over time. If you plot that voltage on a graph with time on the x-axis and voltage on the y-axis, you get a **waveform** — a squiggly line that represents the sound.

### Key properties of a sound wave:

- **Frequency**: How fast the vibration repeats, measured in **Hertz (Hz)**. 1 Hz means one complete back-and-forth cycle per second. A deep bass note might be 80 Hz. A high-pitched whistle might be 8000 Hz. Human hearing ranges from roughly 20 Hz to 20,000 Hz (20 kHz).

- **Amplitude**: How large the vibration is — how far the pressure deviates from its resting state. Bigger amplitude = louder sound.

- **A real sound is never a single frequency.** When someone speaks, the resulting waveform is a complex mixture of hundreds or thousands of different frequencies all happening simultaneously. The *specific mix* of frequencies is what makes a voice sound different from a piano or a drum.

---

## 1.2 What is "Digital" Audio?

The electrical voltage from a microphone is a **continuous** signal — it changes smoothly and has a value at every instant in time. But computers can't store continuous things. They store discrete numbers.

### Sampling: Turning Continuous into Discrete

To record audio digitally, we use an **Analog-to-Digital Converter (ADC)**. It does two things:

1. **Sampling**: It measures the voltage at regular intervals. If we sample at **44,100 times per second**, the sampling rate is **fs = 44,100 Hz**. This is the standard for CD-quality audio. Each measurement is called a **sample**.

2. **Quantization**: Each measured voltage is rounded to the nearest number that the system can represent (e.g., a 16-bit system has 65,536 possible levels).

After this process, your audio is just a **long list of numbers** (an array). For example, 3 seconds of audio at 44,100 Hz produces 3 × 44,100 = **132,300 numbers** in an array. That array is what your MATLAB code manipulates.

### What does the array look like?

```
x = [0.00, 0.02, 0.05, 0.09, 0.12, 0.14, 0.12, 0.09, ...]
```

Each number represents the air pressure (normalized to between -1 and +1) at one instant in time. The spacing between samples is `1/fs` seconds. At 44,100 Hz, each sample is `1/44100 ≈ 0.0000227 seconds` apart.

---

## 1.3 The Nyquist Theorem — The Most Important Rule in Digital Audio

Here is the single most critical concept in all of digital signal processing:

> **The Nyquist-Shannon Sampling Theorem**: To perfectly capture a frequency `f` in a digital recording, you must sample at **at least 2× that frequency**. That is, `fs ≥ 2f`.

The **Nyquist frequency** is defined as exactly half the sampling rate:

```
f_Nyquist = fs / 2
```

For our audio at fs = 44,100 Hz:

```
f_Nyquist = 44,100 / 2 = 22,050 Hz
```

### What does this mean practically?

- Our digital audio can represent frequencies up to **22,050 Hz**. Since human hearing maxes out at ~20,000 Hz, this is more than enough.
- Any frequency **above** 22,050 Hz simply **cannot exist** in our digital audio. If we tried to record a 23,000 Hz tone at 44,100 Hz sampling, something terrible would happen: it would appear as a **fake, lower frequency** in our recording. This distortion is called **aliasing** — the high frequency masquerades as (takes the alias of) a lower one.

### Why does this matter for equalizers?

When we design filters in MATLAB, we don't specify frequencies in raw Hz. Instead, we express them as a **fraction of the Nyquist frequency**. This is called **normalized frequency**:

```
Wn = f_desired / f_Nyquist = f_desired / (fs/2)
```

For example, if we want to filter at 5,000 Hz with fs = 44,100:

```
Wn = 5000 / 22050 = 0.2268
```

This normalized frequency always falls between 0 (DC, meaning 0 Hz) and 1 (the Nyquist frequency). You will see this calculation on nearly every line of the filter design code.

---

## 1.4 What is an Equalizer?

You have seen equalizer sliders on music apps — those vertical bars labeled "Bass", "Mid", "Treble", etc. Each slider controls the volume of a specific range of frequencies. Slide one up, and those frequencies get louder. Slide one down, and they get quieter.

### The Mathematical Definition

An equalizer is a system that **decomposes** an audio signal into multiple **frequency bands** (sub-ranges of frequency), applies a separate **gain** (volume multiplier) to each band, and then **adds them all back together** to produce the output.

Here is the process, step by step:

```
Input Signal x(t)
    │
    ├──▶ [Band 1 Filter: 0-100 Hz]     ──▶ × Gain₁ ──▶ y₁(t)
    ├──▶ [Band 2 Filter: 100-300 Hz]   ──▶ × Gain₂ ──▶ y₂(t)
    ├──▶ [Band 3 Filter: 300-800 Hz]   ──▶ × Gain₃ ──▶ y₃(t)
    ├──▶ [Band 4 Filter: 800-2000 Hz]  ──▶ × Gain₄ ──▶ y₄(t)
    ├──▶ [Band 5 Filter: 2000-5000 Hz] ──▶ × Gain₅ ──▶ y₅(t)
    ├──▶ [Band 6 Filter: 5000-10kHz]   ──▶ × Gain₆ ──▶ y₆(t)
    ├──▶ [Band 7 Filter: 10k-20kHz]    ──▶ × Gain₇ ──▶ y₇(t)
    │
    └──▶ Output = y₁ + y₂ + y₃ + y₄ + y₅ + y₆ + y₇
```

Each "Band Filter" is a **bandpass filter** — a filter that only allows frequencies within a specific range to pass through and blocks everything outside that range. The output of each bandpass filter is a version of the original audio that contains *only* the frequencies in that band.

Then each band is multiplied by its gain. If the gain is > 1, that band gets louder (**boosted**). If the gain is < 1, that band gets quieter (**cut**). If the gain is exactly 1, the band is unchanged.

Finally, all seven modified bands are summed together. Since the bands cover the entire audible spectrum without gaps, the sum reconstructs a complete audio signal — but now with the frequency balance adjusted according to the gains.

### Why not just boost the whole signal?

Because different frequency ranges carry different information:

| Frequency Range | What it Contains (in Speech) |
|---|---|
| 0–100 Hz | Rumble, room hum, low vibrations. Not much useful speech. |
| 100–300 Hz | The "body" or warmth of a voice. The fundamental pitch of most male speakers. |
| 300–800 Hz | Lower formants. Makes speech sound full or "boxy." |
| 800–2000 Hz | Upper formants. Critical for speech intelligibility — this is where vowel sounds are distinguished. |
| 2000–5000 Hz | "Presence" range. Consonants like "t", "s", "k" live here. Boosting this makes speech clearer and "closer." |
| 5000–10,000 Hz | "Brilliance" and sibilance. The "ssss" and "shhhh" sounds. |
| 10,000–20,000 Hz | "Air." Very high harmonics. Gives a sense of spaciousness. |

An equalizer lets you selectively boost the 2k–5k range to make speech clearer on a podcast, while cutting the 0–100 Hz range to remove background rumble — without affecting the rest.

---

## 1.5 What is a Digital Filter?

A digital filter is a mathematical formula that takes your audio array (a list of numbers) as input and produces a new array as output, where certain frequencies have been amplified or suppressed.

Every digital filter is defined by a **difference equation**:

```
y[n] = b₀·x[n] + b₁·x[n-1] + b₂·x[n-2] + ...
       - a₁·y[n-1] - a₂·y[n-2] - ...
```

Where:
- `x[n]` = the current input sample (the n-th number in your input array)
- `x[n-1]` = the previous input sample
- `y[n]` = the current output sample (what the filter produces)
- `y[n-1]` = the previous output sample
- `b₀, b₁, b₂, ...` = **feedforward coefficients** (they weigh the current and past *inputs*)
- `a₁, a₂, ...` = **feedback coefficients** (they weigh the past *outputs*)

The filter processes the signal **one sample at a time**, marching through the array from the first sample to the last. At each step, it computes one output sample by taking a weighted combination of recent inputs and recent outputs.

The specific values of the `b` and `a` coefficients determine which frequencies are passed and which are blocked. Designing a filter means computing these coefficients.

---

## 1.6 FIR vs IIR Filters — The Two Families

There are two fundamentally different types of digital filters, and your MATLAB code lets the user choose between them.

### FIR = Finite Impulse Response

An FIR filter **only has `b` coefficients**. The `a` side is simply `a₀ = 1` (no feedback). The equation becomes:

```
y[n] = b₀·x[n] + b₁·x[n-1] + b₂·x[n-2] + ... + bₙ·x[n-N]
```

It only looks at the current and past **N input values**. It never feeds its own output back into the equation.

**Why "Finite Impulse Response"?** Imagine feeding a single spike (value 1 at time 0, value 0 everywhere else) into the filter. The output will be the `b` coefficients themselves, one by one: `b₀, b₁, b₂, ..., bₙ`. After N+1 samples, the output becomes zero forever. The "impulse response" (the output when you feed in a spike) is **finite** in length.

**Properties of FIR filters:**

1. **Always Stable**: Since there is no feedback loop, the output can never grow uncontrollably. No matter what input you give it, the output stays bounded. This is a huge safety advantage.

2. **Linear Phase** (when designed with symmetric coefficients): This is the most important advantage for audio. "Linear phase" means that **all frequencies are delayed by exactly the same amount of time**. The waveform shape is perfectly preserved — it is just shifted to the right in time. There is no distortion of the signal's shape.

3. **Needs Many Coefficients**: To get a sharp frequency cutoff (a steep wall between "pass" and "block"), you need a large number of `b` coefficients. For example, to sharply isolate a band like 100–300 Hz from a 44,100 Hz signal, you might need an FIR filter of order 100 or more (meaning 101 coefficients). The code defaults to order 100.

### IIR = Infinite Impulse Response

An IIR filter **has both `b` and `a` coefficients**. The equation includes feedback:

```
y[n] = b₀·x[n] + b₁·x[n-1] + ... - a₁·y[n-1] - a₂·y[n-2] - ...
```

It uses its own past outputs in the computation. This feedback loop is what gives IIR filters their power — and their risks.

**Why "Infinite Impulse Response"?** Feed in a single spike. The feedback causes the output to decay exponentially, but it theoretically never reaches exactly zero. The impulse response is **infinite** in duration (though it gets vanishingly small very quickly for a well-designed, stable filter).

**Properties of IIR filters:**

1. **Very Efficient**: A 4th-order IIR filter (with only ~5 `b` coefficients and ~5 `a` coefficients) can achieve a frequency cutoff sharpness that would require an FIR filter with hundreds of coefficients. This means less computation.

2. **Can Be Unstable**: If the feedback coefficients are poorly chosen, the output can grow without bound — the filter "blows up." MATLAB's design functions (`butter`, `cheby1`, `cheby2`) guarantee stability for the orders they produce, so this is usually handled for you.

3. **Non-Linear Phase**: This is the critical disadvantage for audio. Different frequencies get delayed by different amounts. This means that the *shape* of the waveform changes as it passes through the filter. Components that were aligned in time before the filter may come out slightly misaligned after.

### How Does Phase Distortion from IIR Affect Speech?

Phase distortion is subtle. Here is what happens:

Imagine a spoken word like "tap." It consists of a sudden burst ("t"), a vowel ("a"), and another burst ("p"), all happening in rapid succession. Each of these sounds occupies different frequency ranges.

With a **linear-phase FIR filter**, all of these frequency components are delayed by the same amount. The "t", "a", and "p" remain aligned. The word still sounds like "tap" — just played back a tiny fraction of a second later.

With a **non-linear-phase IIR filter**, the low-frequency components of the vowel might be delayed more than the high-frequency components of the consonants. The "t" burst might arrive slightly earlier relative to the "a" than it should. This causes a subtle **smearing** or **pre-ringing** effect. For most listeners, this is nearly imperceptible on speech — the human auditory system is remarkably insensitive to phase changes. However, in careful A/B testing, some people report that IIR-filtered speech sounds slightly "different" or "less crisp."

**The fix: `filtfilt`**. Your code uses a MATLAB trick: when IIR is selected, it calls `filtfilt` instead of `filter`. This function filters the signal forward, then flips it and filters it backward. The forward phase shift and backward phase shift cancel perfectly, resulting in **zero phase distortion**. The output is not shifted in time at all, and the waveform shape is perfectly preserved. The catch is that `filtfilt` doubles the effective filter order (a 4th-order filter acts like an 8th-order one) and requires the entire signal upfront (no real-time processing).

---

## 1.7 The Three IIR Filter Designs in This Project

When you choose IIR mode, the code offers three sub-types. They differ in their mathematical philosophy:

### Butterworth

- **Philosophy**: "Maximally flat magnitude response." The passband (the range of frequencies you want to keep) has absolutely no ripples — the magnitude response is as smooth and flat as possible.
- **Trade-off**: Because it refuses to ripple, the transition from passband to stopband is relatively **gradual** (gentle slope). It takes more frequency space to go from "fully passing" to "fully blocking."
- **MATLAB function**: `butter(order, Wn, type)`

### Chebyshev Type I

- **Philosophy**: Allow some controlled **ripple in the passband** to get a **steeper** transition than Butterworth at the same filter order.
- **Parameter**: Ripple depth in the passband (your code uses 0.5 dB, meaning the passband magnitude oscillates by up to 0.5 dB).
- **Trade-off**: The passband is not perfectly flat — there are small waves. For an equalizer, this means the frequencies you *want* to keep will have their volume oscillate slightly.
- **MATLAB function**: `cheby1(order, ripple_dB, Wn, type)`

### Chebyshev Type II

- **Philosophy**: Allow controlled **ripple in the stopband** (the range you're blocking) to get a steeper transition, while keeping the **passband perfectly flat**.
- **Parameter**: Minimum stopband attenuation (your code uses 40 dB, meaning blocked frequencies are reduced to at least 1/100th of their original amplitude).
- **Trade-off**: The stopband has small oscillations, but the passband is monotonically flat. This is often preferred for audio because the frequencies you *keep* are undistorted.
- **MATLAB function**: `cheby2(order, stopband_attenuation_dB, Wn, type)`

---

## 1.8 Gain in Decibels (dB)

Your equalizer asks the user to input gains in **dB** (decibels). This is not a simple multiplier — it's a **logarithmic scale**.

### Why use dB instead of just "multiply by 2"?

Because the human ear perceives loudness **logarithmically**, not linearly. Doubling the sound pressure does not make it sound "twice as loud" to you — it sounds just a little bit louder. To sound "twice as loud," you need about 10× more power. The dB scale matches this perception.

### The Formula

For **amplitude** (voltage, sound pressure), the conversion from dB to a linear multiplier is:

```
linear_gain = 10^(gain_dB / 20)
```

Examples:

| Gain in dB | Linear Multiplier | What it means |
|---|---|---|
| 0 dB | 10^(0/20) = 1.0 | No change |
| +6 dB | 10^(6/20) ≈ 2.0 | Double the amplitude (noticeably louder) |
| +20 dB | 10^(20/20) = 10.0 | 10× the amplitude (much louder) |
| -6 dB | 10^(-6/20) ≈ 0.5 | Half the amplitude (noticeably quieter) |
| -20 dB | 10^(-20/20) = 0.1 | 1/10th the amplitude (much quieter) |
| +3 dB | 10^(3/20) ≈ 1.41 | √2 × amplitude (about 1.4× louder) |

**In the code**, the line `gain_lin = 10^(gains_db(i)/20)` converts the user's dB value into this linear multiplier, and then the filtered band signal is multiplied by it: `y_bands(:,i) = yi * gain_lin`.

So if the user enters a gain of +6 dB for the 100–300 Hz band, every sample in that band's filtered signal gets multiplied by ~2.0, effectively doubling the volume of those frequencies.

---

## 1.9 Multirate DSP: Changing the Sample Rate

Your code includes a feature to change the output sample rate. This brings us to **multirate digital signal processing** — the science of changing the number of samples per second in a digital signal.

### Why would you change the sample rate?

- **Upsampling** (increasing the sample rate): If you need to play the audio on a system that requires a higher sample rate, or if you want to reduce quantization effects in further processing. Your code demonstrates **4× upsampling** (e.g., 44,100 Hz → 176,400 Hz).

- **Downsampling** (decreasing the sample rate): If you want to reduce the file size, or the target playback system uses a lower rate. Your code demonstrates **halving** (e.g., 44,100 Hz → 22,050 Hz).

### Upsampling by 4×

This means going from 44,100 samples per second to 176,400 samples per second. Conceptually:

1. **Insert zeros**: Between every original sample, insert 3 zeros. This makes the array 4× longer but introduces high-frequency artifacts (images of the original spectrum that repeat at multiples of the original sampling rate).

2. **Low-pass filter**: Apply a filter that removes those artifacts, keeping only the original frequencies (0 to 22,050 Hz). The filter smoothly interpolates between the original samples, filling in the zeros with mathematically estimated values.

The result is an audio signal with 4× as many samples that sounds identical — the extra samples just provide finer time resolution.

### Downsampling by 2×

This means going from 44,100 samples per second to 22,050 samples per second. Conceptually:

1. **Low-pass filter first**: Before throwing away any samples, you must filter the signal to remove all frequencies above the **new Nyquist frequency**: 22,050 / 2 = 11,025 Hz. If you skip this step, frequencies between 11,025 Hz and 22,050 Hz will **alias** down into the 0–11,025 Hz range, creating audible distortion.

2. **Discard every other sample**: Keep only every 2nd sample, cutting the array length in half.

The result is an audio signal with half as many samples. It sounds almost the same, but all frequencies above 11,025 Hz have been removed. For speech, this is often acceptable because most speech energy is below 8,000 Hz.

### The Nyquist Connection

The Nyquist theorem is the reason you **must** filter before downsampling. If the original signal contains any frequency above the new Nyquist limit, those frequencies will fold back (alias) and corrupt your audio irreversibly. The anti-aliasing low-pass filter prevents this.

MATLAB's `resample(x, P, Q)` function handles all of this automatically — it designs and applies the necessary anti-aliasing filter, then changes the sample rate by the ratio P/Q.

---

## 1.10 Window Functions: Hamming, Hanning, and Blackman

When designing FIR filters, we need to use **window functions**. Here's why:

### The Problem: You Can't Have a Perfect Filter

The mathematically "ideal" bandpass filter would be a perfect rectangular brick wall: magnitude = 1 inside the passband, magnitude = 0 outside. But the impulse response of this ideal filter is a **sinc function** (`sin(x)/x`), which extends infinitely in both directions. We can't store an infinite number of coefficients.

### The Solution: Truncate and Window

We truncate the ideal impulse response to N+1 samples. But abruptly cutting it off introduces ringing artifacts in the frequency response — ripples that appear near the cutoff frequency. This is called the **Gibbs phenomenon**.

To reduce these ripples, we multiply the truncated impulse response by a **window function** — a smooth curve that tapers the coefficients to zero at the edges. This reduces the abruptness of the truncation.

### The Three Windows in Your Code

| Window | Main Lobe Width | Sidelobe Level | Best For |
|---|---|---|---|
| **Hamming** | Medium | -53 dB (very good) | General-purpose. Most popular default. Good balance between sharp cutoff and sidelobe suppression. |
| **Hanning** (Hann) | Medium | -44 dB (good) | Slightly wider main lobe than Hamming, but the sidelobes roll off faster. Better when you care more about distant sidelobes than the first few. |
| **Blackman** | Wide | -74 dB (excellent) | When you need maximum sidelobe suppression and can tolerate a wider transition band. Great for situations where even small leakage from adjacent bands is unacceptable. |

**Main lobe width** = how gradual the transition is from pass to stop. Wider = less sharp cutoff.

**Sidelobe level** = how much the filter "leaks" frequencies it's supposed to block. Lower (more negative dB) = better blocking.

**The trade-off is always the same**: better sidelobe suppression comes at the cost of a wider transition band. You cannot have both a razor-sharp cutoff and perfect blocking — this is a fundamental limitation of FIR design.

### How does this affect the equalizer?

With a **Hamming window**, the borders between your 7 frequency bands will be reasonably sharp with good out-of-band rejection. With a **Blackman window**, the borders will be less sharp, but each band will have even less contamination from adjacent bands. The choice depends on whether you prioritize sharpness or purity.

---

## 1.11 Summary of Concepts

Before reading the code, make sure you're comfortable with these ideas:

| Concept | One-Sentence Summary |
|---|---|
| **Sound** | Pressure vibrations converted to an array of numbers by a microphone + ADC. |
| **Sampling Rate (fs)** | How many numbers per second are in the array. |
| **Nyquist Frequency** | fs/2 — the highest frequency the digital audio can represent. |
| **Aliasing** | Fake frequencies created when you violate the Nyquist theorem. |
| **Filter** | A math formula that selectively amplifies or suppresses certain frequencies. |
| **FIR Filter** | No feedback, always stable, linear phase, needs many coefficients. |
| **IIR Filter** | Uses feedback, efficient, can be unstable, has phase distortion (fixed by filtfilt). |
| **Equalizer** | Splits audio into bands, applies gain to each, sums them back. |
| **Gain in dB** | A logarithmic scale: +6 dB ≈ 2× amplitude, -6 dB ≈ 0.5× amplitude. |
| **Upsampling** | Insert zeros + filter to increase sample rate without aliasing. |
| **Downsampling** | Filter + discard samples to decrease sample rate without aliasing. |
| **Window Function** | Smoothly tapers FIR coefficients to reduce spectral ripple. |
