# ECG Denoising: Part 2 - Code Walkthrough

> **Learning Guide:** This walkthrough dissects the MATLAB implementation line-by-line. We will explain exactly what the MATLAB code does, why we chose it, and how the parameters connect to the DSP concepts (Sampling, FIR/IIR, Nyquist) from Part 1.

---

## Lines 1–14: Header Comments

```matlab
% ECG Signal: fs=360Hz, useful BW=0.5-100Hz, 11-bit/10mV
% Noise: baseline wander (<0.5Hz), 50Hz powerline, EMG (20-150Hz)
% Filter Specs:
%   HP:    cutoff=0.5Hz, PB ripple<=1dB, SB atten>=40dB
%   Notch: 50Hz center, PB ripple<=0.5dB, SB atten>=30dB
%   LP:    cutoff=100Hz, PB ripple<=1dB, SB atten>=40dB
```

These comments summarize the engineering specifications. **PB ripple** = how much the magnitude is allowed to deviate from 0 dB in the passband. **SB atten** = how far below 0 dB the filter must push frequencies in the stopband. These numbers come from clinical ECG standards (AHA guidelines).

---

## Lines 15–22: Setup

```matlab
clc; clear; close all;
fs = 360; T = 10; N_seg = T * fs;
```

- `clc` = clear command window; `clear` = delete all variables; `close all` = close all figures.
- **`fs = 360`**: Sampling rate of the MIT-BIH database. Fixed by the data source.
- `T = 10`: We take 10 seconds of data (enough for ~10 heartbeats at 60 bpm).
- `N_seg = 3600`: Total samples = 10 × 360.

```matlab
scriptDir = fileparts(mfilename('fullpath'));
figDir = fullfile(scriptDir, 'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end
Nfft = 4096;
```

- Builds an absolute path for saving figures regardless of MATLAB's current directory.
- `Nfft = 4096`: Number of frequency points for `freqz`. More points = smoother frequency response plots. 4096 is a power of 2 (efficient for FFT internally).

---

## Lines 24–26: Loading ECG Data

```matlab
[sig100,~,~] = rdsamp('100',[],N_seg);
ecg100 = sig100(:,1);
t100 = (0:length(ecg100)-1)/fs;
```

**`rdsamp`**: A function from the WFDB Toolbox (not built into MATLAB). It reads the binary `.dat` files from the MIT-BIH database.
- `'100'`: Record name (looks for `100.dat` and `100.hea` in the current directory).
- `[]`: Read all channels.
- `N_seg`: Read only the first 3600 samples.
- Returns a matrix where each column is a different ECG lead.

**`sig100(:,1)`**: Extracts column 1, which is the **Modified Lead II (MLII)** — the standard lead for arrhythmia detection.

**`t100 = (0:length(ecg100)-1)/fs`**: Creates a time vector in seconds. Sample 0 → 0 seconds, sample 1 → 1/360 seconds, sample 3599 → 9.997 seconds.

---

## Lines 28–32: FIR Filter Design (Hamming Window)

```matlab
N_hp_fir = 500;
b_fir_hp = fir1(N_hp_fir, 0.5/(fs/2), 'high', hamming(N_hp_fir+1));
a_fir_hp = 1;
```

### What `fir1` does:
1. Designs a **windowed-sinc FIR filter** of order N (which means N+1 = 501 coefficients).
2. `0.5/(fs/2)` = `0.5/180 = 0.00278` — the normalized cutoff frequency.
3. `'high'` = high-pass filter (blocks below cutoff, passes above).
4. `hamming(501)` = apply a 501-point Hamming window to the truncated sinc to suppress Gibbs ringing.

### Why `fir1` and not `firpm` or `fir2`?
- `fir1` uses the **window method** — simplest, most intuitive, and perfectly adequate for our specs.
- `firpm` uses Parks-McClellan (optimal equiripple) — more complex, used when you need the absolute minimum order. Overkill for a course project.
- `fir2` uses frequency sampling — good for arbitrary shapes, not needed here.

### Why order 500?
The HP filter must transition from blocking at 0 Hz to passing at 0.5 Hz. That's a tiny normalized frequency (0.00278). The rule of thumb for `fir1` with Hamming is: `N ≈ 3.3 / (transition_width / fs)`. For a 0.5 Hz transition: `N ≈ 3.3 / (0.5/360) ≈ 2376`. We use 500 as a practical compromise — it won't get a razor-sharp cutoff, but it's enough to significantly reduce baseline wander.

### Why `a_fir_hp = 1`?
FIR filters have no denominator (no feedback). The difference equation is purely feedforward. Setting `a = 1` tells MATLAB there's no recursive part.

```matlab
N_notch_fir = 500;
b_fir_notch = fir1(N_notch_fir, [48 52]/(fs/2), 'stop', hamming(N_notch_fir+1));
```

- `[48 52]/(fs/2)`: Two cutoff frequencies → bandstop (notch). Blocks 48–52 Hz, passes everything else.
- `'stop'`: Bandstop filter type.
- Order 500 because the notch must be narrow (only 4 Hz wide) — FIR needs many taps for narrow transitions.

```matlab
N_lp_fir = 100;
b_fir_lp = fir1(N_lp_fir, 100/(fs/2), 'low', hamming(N_lp_fir+1));
```

- `100/(fs/2) = 0.556`: Normalized cutoff at 100 Hz.
- `'low'`: Low-pass filter.
- **Only order 100** because 100 Hz is a relatively high frequency (0.556 normalized) — the transition band is wide in absolute terms, so fewer taps suffice.

---

## Lines 34–37: IIR Butterworth Design

```matlab
[b_but_hp, a_but_hp] = butter(4, 0.5/(fs/2), 'high');
```

### What `butter` does:
1. Designs an analog Butterworth prototype (maximally flat).
2. Converts it to digital using the **bilinear transform** (maps the analog s-plane to the digital z-plane, preserving stability).
3. Returns both `b` (numerator) and `a` (denominator) coefficients.

### Why order 4?
- Butterworth at order 4 gives ~80 dB/decade rolloff (the slope of the magnitude curve). This is steep enough for ECG.
- Compare: our FIR needed order 500 for the same cutoff. IIR's feedback makes it exponentially more efficient.
- Going higher (6, 8) would be sharper but risks numerical instability in MATLAB's direct-form implementation.

### Why `butter` and not `cheby1` here?
Butterworth is our "clean" reference — maximally flat passband, no ripple. We use Chebyshev separately as a comparison.

```matlab
w0 = 50/(fs/2);
bw = w0/30;
[b_but_notch, a_but_notch] = iirnotch(w0, bw);
```

### What `iirnotch` does:
Creates a 2nd-order IIR notch filter that places a deep null at exactly `w0`.

- `w0 = 50/180 = 0.2778`: Normalized center frequency.
- `bw = w0/30`: The 3-dB bandwidth. This determines the **Q-factor** (Quality factor = w0/bw = 30). Higher Q = narrower notch.
- Q=30 means the notch is only about **50 ± 0.83 Hz** — surgically precise.

### Why `iirnotch` instead of a bandstop `butter`?
A Butterworth bandstop would need a higher order to achieve the same narrow notch. `iirnotch` is purpose-built for removing a single frequency — it's the cleanest, most efficient solution.

---

## Lines 39–42: IIR Chebyshev Type II Design

```matlab
[b_ch2_hp, a_ch2_hp] = cheby2(4, 40, 0.5/(fs/2), 'high');
```

### What `cheby2` does:
Same process as `butter` (analog prototype → bilinear transform → digital), but with a Chebyshev Type II characteristic.

- `4`: Filter order.
- `40`: **Rs = 40 dB** — the minimum stopband attenuation. Noise in the stopband will be at least 40 dB (100×) below the passband.
- `0.5/(fs/2)`: This is the **stopband edge** frequency (not the passband edge like Butterworth). For Cheby2, the cutoff specification has a slightly different meaning.

### Why use Chebyshev II as our third filter set?
- It gives us a **sharper transition** than Butterworth at the same order.
- Its passband is monotonically flat (no ripple where ECG lives).
- The equiripple behavior is in the stopband, where we don't care about ripple.
- It's the ideal comparison: Butterworth = smoothest, Chebyshev II = sharpest.

---

## Lines 44–49: Organizing Filters into Cell Arrays

```matlab
b_fir_all = {b_fir_hp, b_fir_notch, b_fir_lp};
a_fir_all = {a_fir_hp, a_fir_notch, a_fir_lp};
```

Cell arrays let us store filters of different sizes in one container. This enables looping through all 9 filters (3 types × 3 sub-filters) with `for` loops instead of copy-pasting code 9 times.

---

## Lines 51–68: Applying the Filter Cascades

### FIR Cascade (Lines 54–58)

```matlab
ecg_fir = filter(b_fir_hp, 1, ecg);
ecg_fir = filter(b_fir_notch, 1, ecg_fir);
ecg_fir = filter(b_fir_lp, 1, ecg_fir);
total_delay = (N_hp_fir + N_notch_fir + N_lp_fir) / 2;
```

### What `filter` does:
Implements the difference equation directly: processes the signal sample by sample, left to right. This is **causal** filtering — each output sample only depends on current and past inputs.

### Why `filter` for FIR and not `filtfilt`?
- FIR with symmetric coefficients already has **linear phase**. The waveform shape is preserved — it's just delayed.
- Using `filtfilt` on FIR would double the order unnecessarily and waste computation.
- The delay is predictable: (N)/2 samples per filter. Total = (500+500+100)/2 = **550 samples ≈ 1.53 seconds**.

### IIR Cascades (Lines 60–68)

```matlab
ecg_but = filtfilt(b_but_hp, a_but_hp, ecg);
ecg_but = filtfilt(b_but_notch, a_but_notch, ecg_but);
ecg_but = filtfilt(b_but_lp, a_but_lp, ecg_but);
```

### What `filtfilt` does:
1. Filters the signal **forward** (left to right) using the difference equation.
2. **Reverses** the output signal.
3. Filters it **again** (which is effectively filtering backward).
4. Reverses the result back to the original direction.

The forward pass introduces phase shift φ(ω). The backward pass introduces -φ(ω). They cancel: **zero total phase shift**.

### Why `filtfilt` for IIR and not `filter`?
- IIR filters have **non-linear phase** — different frequencies get different delays. Using `filter` alone would distort the QRS waveform shape (peaks would be asymmetric, shifted, skewed).
- `filtfilt` eliminates this phase distortion completely.
- **Trade-off**: It doubles the effective order (4th order → 8th order effective) and it's **offline only** (you need the whole signal before you start).

### Why cascade (HP → Notch → LP) instead of one big filter?
- Each sub-filter targets one specific noise type. This is modular and easier to tune.
- Designing a single filter that does HP + Notch + LP simultaneously would require very high order and be harder to analyze.
- Cascading is standard practice in biomedical signal processing.

---

## Lines 70–81: PSD and SNR Computation

```matlab
nw = 1024;
[pxx_raw, f_psd] = pwelch(ecg, hamming(nw), nw/2, nw, fs);
```

### What `pwelch` does:
1. Divides the signal into segments of `nw = 1024` samples.
2. Each segment overlaps the previous by `nw/2 = 512` samples (50% overlap).
3. Multiplies each segment by a `hamming(1024)` window.
4. Computes the FFT of each windowed segment.
5. Takes `|FFT|²` to get power.
6. Averages all segments.
7. Returns `pxx` (power at each frequency) and `f_psd` (frequency vector in Hz).

### Why `pwelch` and not just `fft`?
A raw FFT of the full signal is very noisy — lots of random spikes. Welch's method averages many FFTs of overlapping segments, producing a **smooth, statistically reliable** PSD estimate.

### SNR Calculation (Lines 77–81)

```matlab
sb = f_psd>=0.5 & f_psd<=40;    % signal band
nb = (f_psd<0.5) | (f_psd>=49 & f_psd<=51) | (f_psd>100);  % noise bands

snr_raw = 10*log10(sum(pxx_raw(sb)) / (sum(pxx_raw(nb)) + eps));
```

- `sb`: Boolean mask selecting frequencies where real ECG content lives (0.5–40 Hz).
- `nb`: Boolean mask selecting known noise frequencies.
- `sum(pxx(sb))`: Total power in the signal band.
- `sum(pxx(nb))`: Total power in the noise bands.
- `10*log10(ratio)`: Converts power ratio to decibels.
- `eps` (≈ 2.2 × 10⁻¹⁶): Prevents division by zero.

---

## Lines 88–91: Tabbed Figure Setup

```matlab
fig = figure('Name','ECG Denoising Results','Position',[50 50 1400 850],...
    'NumberTitle','off','Color','w');
tg = uitabgroup(fig);
```

- Creates one figure window with a **tab group** (like browser tabs).
- All 16 analysis plots are organized as tabs in this single window — no pop-up storm.

---

## Lines 107–113: Frequency Response Plots

```matlab
[H, f] = freqz(ball{s}{k}, aall{s}{k}, Nfft, fs);
plot(ax, f, 20*log10(abs(H)+eps), ...);    % Magnitude
plot(ax, f, unwrap(angle(H))*180/pi, ...); % Phase
```

### What `freqz` does:
Evaluates the filter's **transfer function** H(e^jω) at `Nfft` equally-spaced frequencies from 0 to fs/2.

- `H`: Complex-valued frequency response at each frequency point.
- `f`: Corresponding frequencies in Hz.

### Breaking down the magnitude plot:
- `abs(H)`: Magnitude of the complex response (how much each frequency is amplified or attenuated).
- `20*log10(...)`: Converts to decibels. In dB: 0 dB = unchanged, -20 dB = 10× weaker, -40 dB = 100× weaker.
- `+eps`: Prevents `log10(0)` which would be -∞.

### Breaking down the phase plot:
- `angle(H)`: Phase shift in radians at each frequency.
- `unwrap(...)`: Removes artificial ±π jumps (without this, the phase plot would have discontinuous vertical jumps).
- `*180/pi`: Converts radians to degrees.

---

## Lines 118–131: Impulse and Step Response

```matlab
imp = [1; zeros(imp_len-1,1)];  % δ[n]: a single spike
stp = ones(imp_len,1);           % u[n]: a constant "on" signal
h_i = filter(b, a, imp);         % impulse response
h_s = filter(b, a, stp);         % step response
```

### Impulse response:
Feed the filter a single spike at n=0, then silence. The output IS the filter — it shows how the filter "rings" and decays. For FIR, the impulse response is literally the `b` coefficients themselves.

### Step response:
Feed the filter a constant value of 1 forever. Shows how fast the filter reaches steady state. A good filter should settle quickly without excessive ringing.

### Why use `filter` here and not `filtfilt`?
We want to see the filter's **true** causal behavior — how it responds to an input in real time. `filtfilt` would mask the settling behavior.

---

## Lines 133–141: Pole-Zero Diagrams

```matlab
zplane(b, a);
```

### What `zplane` does:
Plots the **zeros** (○) and **poles** (×) of the filter's transfer function in the complex z-plane.

- **Zeros**: Values of z where the numerator B(z) = 0 → the filter has zero gain at these frequencies.
- **Poles**: Values of z where the denominator A(z) = 0 → the filter has infinite gain at these frequencies (theoretically).

### The unit circle (the dotted circle of radius 1):
- Points on the unit circle correspond to real frequencies (from 0 Hz at angle=0 to fs/2 at angle=π).
- **Stability rule**: ALL poles must be strictly INSIDE the unit circle. If any pole touches or crosses the unit circle, the filter is unstable (output grows to infinity).
- For FIR: all poles are at z=0 (the origin) → always stable.
- For IIR: poles are inside but not at the origin → stable but could theoretically become unstable if order is too high.

---

## Lines 214–225: Saving Figures

```matlab
exportgraphics(tabs(i), fullfile(figDir,[tabnames{i},'.png']), 'Resolution',150, 'BackgroundColor','none');
```

- Iterates through all 16 tabs, makes each one active, and exports it as a PNG.
- `'Resolution',150`: 150 DPI (decent quality for reports).
- `'BackgroundColor','none'`: Transparent background.

---

## Lines 227–238: Helper Function

```matlab
function ax = tsubplot(parent, m, n, p)
```

A custom function that creates axes inside a `uitab` (since MATLAB's built-in `subplot` doesn't work directly with tabs). It calculates the position `[left, bottom, width, height]` for a grid of m rows × n columns, at position p.
