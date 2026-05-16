# Part 2: Line-by-Line Code Logic & Algorithm

Now that you understand the foundational concepts, let's walk through every line of the MATLAB code and explain exactly what it does to the audio data.

---

## 2.1 Initialization (Lines 1–8)

```matlab
%% Multi-Band Speech Equalizer for Podcast Enhancement
% DSP Project - FIR & IIR filter-based equalizer
% Supports Preset (7-band) and Custom (5-10 band) modes
clc; clear; close all;

scriptDir = fileparts(mfilename('fullpath'));
figDir = fullfile(scriptDir, 'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end
```

- `clc` — Clears the MATLAB Command Window (removes old text output).
- `clear` — Deletes all variables from the workspace (memory), so we start fresh.
- `close all` — Closes all open figure windows.
- `fileparts(mfilename('fullpath'))` — Gets the directory where this `.m` file lives. `mfilename('fullpath')` returns the full path like `C:\...\speech_equalizer.m`, and `fileparts` strips the filename, leaving just the folder path.
- `figDir = fullfile(scriptDir, 'figures')` — Creates the path `...\speech_equalizer\figures`.
- `if ~exist(figDir,'dir'), mkdir(figDir); end` — If the `figures` folder doesn't exist yet, create it. This is where all generated plot images will be saved.

---

## 2.2 Audio Input (Lines 10–30)

```matlab
fname = input('Audio file path (Enter for test signal): ','s');
```

This prompts the user to type a file path. The `'s'` argument tells MATLAB to read the input as a **string** (text), not as a number.

### If the user presses Enter (empty input) — Test Signal Generation (Lines 17–25):

```matlab
fs_orig = 44100; dur = 3;
tt = (0:round(fs_orig*dur)-1)'/fs_orig;
x_orig = 0.3*sin(2*pi*120*tt) + 0.5*sin(2*pi*400*tt) + ...
    0.6*sin(2*pi*1200*tt) + 0.4*sin(2*pi*3000*tt) + ...
    0.2*sin(2*pi*7000*tt) + 0.1*sin(2*pi*14000*tt) + ...
    0.05*randn(size(tt));
x_orig = x_orig / max(abs(x_orig));
```

This creates a **synthetic test signal** — a mix of pure sine waves at specific frequencies plus a small amount of random noise:

- `fs_orig = 44100` — Sets sampling rate to CD quality.
- `dur = 3` — 3 seconds of audio.
- `tt = (0:round(fs_orig*dur)-1)'/fs_orig` — Creates a **time vector**. This is an array of evenly spaced time values from 0 to ~3 seconds, with spacing `1/44100`. The `'` transposes it into a column vector.
- The sine waves are at 120 Hz (in band 2), 400 Hz (band 3), 1200 Hz (band 4), 3000 Hz (band 5), 7000 Hz (band 6), and 14000 Hz (band 7). Each has a different amplitude (0.3, 0.5, 0.6, 0.4, 0.2, 0.1). This lets you see each band's filter working.
- `0.05*randn(size(tt))` — Adds small Gaussian random noise to simulate real-world conditions.
- `x_orig = x_orig / max(abs(x_orig))` — **Normalization**: divides the entire signal by its largest absolute value, so the signal fits within the range [-1, +1]. This prevents clipping (distortion from exceeding the maximum value).

### If the user provides a filename (Lines 27–29):

```matlab
[x_orig, fs_orig] = audioread(fname);
if size(x_orig,2) > 1, x_orig = mean(x_orig,2); end
```

- `audioread(fname)` — Reads a .wav or .mp3 file. Returns two things: `x_orig` (the audio data as a matrix of numbers, values between -1 and +1) and `fs_orig` (the file's sampling rate, e.g., 44100).
- `if size(x_orig,2) > 1` — Checks if the audio is **stereo** (2 columns: left and right channels). If so, `mean(x_orig,2)` averages the two channels into one **mono** signal. We do this because our equalizer processes one channel at a time.

---

## 2.3 Mode Selection & Band Definition (Lines 32–49)

```matlab
mode = input('Mode (1=Preset, 2=Custom) [1]: ');
if isempty(mode), mode = 1; end
```

The user picks Preset (7 fixed bands) or Custom (choose your own bands).

### Preset Mode (Lines 36–38):

```matlab
bands = [0 100; 100 300; 300 800; 800 2000; 2000 5000; 5000 10000; 10000 20000];
bnames = {'0-100','100-300','300-800','800-2k','2k-5k','5k-10k','10k-20k'};
```

- `bands` is a **7×2 matrix**. Each row defines one frequency band: `[low_edge, high_edge]` in Hz.
- `bnames` is a cell array of human-readable labels for each band, used in plots.

### Custom Mode (Lines 40–48):

```matlab
nb = input('Number of bands (5-10): ');
nb = max(5, min(10, nb));
edges = input(sprintf('Enter %d edges [0 ... 20000]: ', nb+1));
bands = [edges(1:end-1)', edges(2:end)'];
```

- The user specifies how many bands (clamped between 5 and 10).
- Then enters the **edge frequencies**. For example, 6 bands need 7 edges: `[0 200 500 1000 3000 8000 20000]`.
- `bands = [edges(1:end-1)', edges(2:end)']` — Turns the edge list into a matrix of `[low, high]` pairs. Edge 1-2 becomes band 1, edge 2-3 becomes band 2, etc.

---

## 2.4 Filter Type & Parameters (Lines 51–70)

```matlab
ftype = input('Filter (1=FIR, 2=IIR) [1]: ');
```

### FIR Path (Lines 55–60):

```matlab
wtype = input('Window (1=Hamming, 2=Hanning, 3=Blackman) [1]: ');
def_ord = 100;
```

- The user selects the window function. Default order is 100 (meaning 101 coefficients).

### IIR Path (Lines 62–66):

```matlab
iir_m = input('IIR (1=Butterworth, 2=ChebyI, 3=ChebyII) [1]: ');
def_ord = 4;
```

- The user selects the IIR design method. Default order is 4 (just 5 `b` and 5 `a` coefficients — vastly fewer than FIR).

### Gain Input (Lines 72–75):

```matlab
fprintf('Enter %d gains in dB (e.g. [0 3 6 3 0 -3 -6]):\n', nbands);
gains_db = input('Gains: ');
if isempty(gains_db), gains_db = zeros(1,nbands); end
```

The user enters an array of gains in dB, one per band. If they press Enter, all gains default to 0 dB (no change).

### Output Sample Rate (Lines 77–79):

```matlab
fs_out = input(sprintf('Output sample rate [%d]: ', fs_orig));
if isempty(fs_out), fs_out = fs_orig; end
```

The user can choose a different output sample rate. Default is the same as the input.

---

## 2.5 Filter Design Loop (Lines 81–113) — THE CORE

This is where the math happens. We design one filter for each frequency band.

```matlab
nyq = fs_orig / 2;
b_all = cell(1,nbands);
a_all = cell(1,nbands);
```

- `nyq = fs_orig / 2` — The Nyquist frequency. For 44100 Hz, this is 22050 Hz.
- `b_all` and `a_all` — Cell arrays to store each band's filter coefficients.

### The Loop (Lines 86–113):

```matlab
for i = 1:nbands
    fl = bands(i,1); fh = min(bands(i,2), nyq-1);
    if fl >= nyq, b_all{i}=0; a_all{i}=1; continue; end
```

- `fl` = low edge of band `i`, `fh` = high edge (capped at `nyq-1` to stay below Nyquist).
- If the low edge is already above Nyquist, the band is impossible — skip it.

### Determining Filter Type (Lines 90–96):

```matlab
    if fl == 0
        Wn = fh/nyq; ft = 'low';
    elseif fh >= nyq-1
        Wn = max(fl/nyq, 0.001); ft = 'high';
    else
        Wn = [max(fl/nyq,0.001) fh/nyq]; ft = 'bandpass';
    end
```

This converts Hz to **normalized frequency** and decides the filter type:

- **Band starts at 0 Hz** → Use a **lowpass** filter. `Wn` is a single number (the upper cutoff as a fraction of Nyquist).
- **Band ends at/near Nyquist** → Use a **highpass** filter. `Wn` is the lower cutoff.
- **Band is in the middle** → Use a **bandpass** filter. `Wn` is a two-element vector `[low, high]`.

The `max(fl/nyq, 0.001)` ensures the normalized frequency is never zero (which would be invalid).

### FIR Design (Lines 98–105):

```matlab
        switch wtype
            case 1, w = hamming(filt_order+1);
            case 2, w = hanning(filt_order+1);
            case 3, w = blackman(filt_order+1);
        end
        b_all{i} = fir1(filt_order, Wn, ft, w);
        a_all{i} = 1;
```

- `hamming(filt_order+1)` / `hanning(...)` / `blackman(...)` — Creates a window vector of length `filt_order+1`. This is the tapering function described in Part 1.
- `fir1(filt_order, Wn, ft, w)` — This is MATLAB's **FIR filter design function**. It:
  1. Computes the ideal filter's impulse response (a sinc function) for the given `Wn` and type `ft`.
  2. Truncates it to `filt_order+1` samples.
  3. Multiplies by the window `w` to smooth the truncation.
  4. Returns the `b` coefficients (an array of `filt_order+1` numbers).
- `a_all{i} = 1` — FIR filters have no denominator/feedback, so `a` is just 1.

### IIR Design (Lines 107–111):

```matlab
        switch iir_m
            case 1, [b_all{i},a_all{i}] = butter(filt_order, Wn, ft);
            case 2, [b_all{i},a_all{i}] = cheby1(filt_order, 0.5, Wn, ft);
            case 3, [b_all{i},a_all{i}] = cheby2(filt_order, 40, Wn, ft);
        end
```

- `butter(order, Wn, type)` — Designs a Butterworth IIR filter. Returns both `b` (numerator) and `a` (denominator) coefficient arrays.
- `cheby1(order, Rp, Wn, type)` — Chebyshev Type I. `Rp = 0.5` means 0.5 dB passband ripple.
- `cheby2(order, Rs, Wn, type)` — Chebyshev Type II. `Rs = 40` means 40 dB minimum stopband attenuation.

---

## 2.6 Signal Processing — Filtering & Gain (Lines 115–131)

```matlab
x = x_orig;
y_bands = zeros(length(x), nbands);
```

- `y_bands` — A matrix where each column will hold the filtered+gained signal for one band.

### The Filtering Loop (Lines 119–128):

```matlab
for i = 1:nbands
    if isequal(b_all{i}, 0), continue; end
    if ftype == 1
        yi = filter(b_all{i}, a_all{i}, x);
    else
        yi = filtfilt(b_all{i}, a_all{i}, x);
    end
    gain_lin = 10^(gains_db(i)/20);
    y_bands(:,i) = yi * gain_lin;
end
```

- `filter(b, a, x)` — Applies the difference equation `y[n] = b₀x[n] + b₁x[n-1] + ... - a₁y[n-1] - ...` sample-by-sample through the entire signal `x`. Used for FIR because FIR has linear phase and no need for `filtfilt`.
- `filtfilt(b, a, x)` — Applies the filter **forward**, then **backward**, canceling phase distortion. Used for IIR to achieve zero-phase filtering.
- `gain_lin = 10^(gains_db(i)/20)` — Converts the user's dB gain to a linear multiplier (e.g., +6 dB → 2.0).
- `y_bands(:,i) = yi * gain_lin` — Every sample in this band's filtered signal is multiplied by the gain.

### Recombination (Lines 130–131):

```matlab
y_eq = sum(y_bands, 2);
y_eq = y_eq / max(abs(y_eq)+eps);
```

- `sum(y_bands, 2)` — Sums across all columns (bands) for each row (time sample). This adds all the gained band signals back together into one complete audio signal.
- `y_eq / max(abs(y_eq)+eps)` — Normalizes the output to [-1, +1] to prevent clipping. The `+eps` prevents division by zero (`eps` is ~2.2×10⁻¹⁶).

**This is how the equalizer works**: split → gain → sum. The bands are designed to cover the entire spectrum, so summing them reconstructs the full signal. The only change is that each band has been amplified or attenuated according to the user's dB settings.

---

## 2.7 Alternate Filter Type Comparison (Lines 140–167)

```matlab
if ftype == 1
    alt_name = 'IIR Butterworth';
else
    alt_name = 'FIR Hamming';
end
```

This section runs the **opposite** filter type with the same bands and gains, so you can visually compare FIR vs IIR results in the plots. If you chose FIR, it runs a Butterworth IIR as the alternate. If you chose IIR, it runs an FIR Hamming as the alternate.

The logic is identical to the main processing loop — design filters, apply them, multiply by gain, sum. The result is stored in `y_alt`.

---

## 2.8 Sample Rate Demonstrations (Lines 169–173)

```matlab
y_4x = resample(y_eq, 4, 1);
y_half = resample(y_eq, 1, 2);
fs_4x = fs_orig * 4;
fs_half = fs_orig / 2;
```

- `resample(y_eq, 4, 1)` — **Upsamples by 4×**. The arguments are `resample(signal, P, Q)` which changes the rate by the factor P/Q. So `P=4, Q=1` means multiply the sample rate by 4/1 = 4. Internally, MATLAB inserts zeros, applies an anti-imaging lowpass filter, and interpolates.
- `resample(y_eq, 1, 2)` — **Downsamples by 2×** (factor 1/2). MATLAB first applies an anti-aliasing lowpass filter to remove frequencies above the new Nyquist, then keeps every 2nd sample.
- `fs_4x = fs_orig * 4` — Records the new sample rate (e.g., 176,400 Hz).
- `fs_half = fs_orig / 2` — Records the new sample rate (e.g., 22,050 Hz).

---

## 2.9 PSD Computation (Lines 175–178)

```matlab
nw = min(1024, floor(length(x)/4));
[pxx_orig, f_psd] = pwelch(x, hamming(nw), nw/2, nw, fs_orig);
[pxx_eq, ~] = pwelch(y_eq, hamming(nw), nw/2, nw, fs_orig);
```

- `pwelch` implements the **Welch method** for Power Spectral Density estimation:
  - `x` — the signal to analyze.
  - `hamming(nw)` — window of length `nw` samples.
  - `nw/2` — overlap of 50% between segments.
  - `nw` — FFT length.
  - `fs_orig` — sampling rate (so frequencies are in Hz, not normalized).
- Returns `pxx` (power at each frequency) and `f_psd` (the frequency axis).
- We compute PSD for both original and equalized signals to compare them.

---

## 2.10 Visualization Tabs (Lines 180–330)

The code creates a **tabbed figure window** with multiple analysis tabs. Here's a summary of each:

### Tab: "All Magnitudes" (Lines 187–199)
For each band, computes `freqz(b, a, Nfft, fs)` — the frequency response — and plots `20*log10(abs(H))`, which is the magnitude response in dB.

### Tab: "All Phases" (Lines 201–213)
Plots `unwrap(angle(H))*180/pi` — the phase response in degrees. `unwrap` corrects for the discontinuities that happen when the angle wraps from +180° to -180°.

### Tab: Per-Band Analysis (Lines 215–263)
For each of the 7 bands, creates 6 sub-plots:
1. **Magnitude Response** — Same as above but for one band only.
2. **Phase Response** — Same as above.
3. **Impulse Response** — Filters a single spike `[1; 0; 0; ...]` through the filter. Shows the filter's `b` coefficients essentially.
4. **Step Response** — Filters a constant-1 signal through the filter. Shows how the filter responds to a sudden "step" change.
5. **Pole-Zero Diagram** — `zplane(b, a)` plots the filter's poles (×) and zeros (○) on the complex unit circle. Poles inside the unit circle = stable filter.
6. **Info Panel** — Displays band name, filter type, order, gain, and coefficient counts.

### Tab: "Time Compare" (Lines 265–273)
Plots the original and equalized waveforms side by side in the time domain.

### Tab: "Freq Compare" (Lines 275–286)
Computes the FFT of both signals, converts to dB, and overlays them. Shows exactly which frequencies were boosted or cut.

### Tab: "PSD" (Lines 288–295)
Plots the Welch PSD for original vs equalized. This is a smoother version of the frequency comparison.

### Tab: "Spectrogram" (Lines 297–305)
Uses `spectrogram(x, window, overlap, nfft, fs, 'yaxis')` to create time-frequency plots. Shows how the frequency content of the signal changes over time.

### Tab: "FIR vs IIR" (Lines 307–314)
Overlays the primary and alternate filter type results in the time domain.

### Tab: "Sample Rate" (Lines 316–330)
Shows three versions of the equalized signal: original rate, 4× rate, and half rate. Zoomed in to the first ~500 samples to show the difference in sample density.

---

## 2.11 Saving Outputs (Lines 332–366)

```matlab
exportgraphics(tabs_all(i), fullfile(figDir, fname_fig), 'Resolution', 150);
```

Saves each tab as a PNG image at 150 DPI resolution into the `figures` folder.

```matlab
audiowrite(out_file, y_out, fs_out);
```

- `audiowrite(filename, data, sampleRate)` — Writes the audio array to a `.wav` file. The data must be in [-1, +1] range. The sample rate tells the WAV header how fast to play back.

The code saves four audio files:
1. `output_equalized.wav` — The main equalized output (at the chosen output sample rate).
2. `output_alternate.wav` — The alternate filter type result.
3. `output_4x.wav` — The 4× upsampled version.
4. `output_half.wav` — The half-rate downsampled version.

Finally, `sound(x, fs_orig)` plays the audio through your speakers.

---

## 2.12 The Helper Function `tsubplot` (Lines 368–380)

```matlab
function ax = tsubplot(parent, m, n, p)
```

This is a custom function that creates positioned axes within a tab. MATLAB's built-in `subplot` doesn't work cleanly inside `uitab` panels, so this helper manually calculates the position of each sub-plot using row/column arithmetic and creates the axes with explicit `[left bottom width height]` coordinates.
