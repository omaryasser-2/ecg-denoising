%% Multi-Band Speech Equalizer for Podcast Enhancement
% DSP Project - FIR & IIR filter-based equalizer
% Supports Preset (7-band) and Custom (5-10 band) modes
clc; clear; close all;

scriptDir = fileparts(mfilename('fullpath'));
figDir = fullfile(scriptDir, 'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end

%% ===================== USER INPUT =====================
fprintf('\n========================================\n');
fprintf('  Multi-Band Speech Equalizer\n');
fprintf('========================================\n\n');

% --- Audio file ---
fname = input('Audio file path (Enter for test signal): ','s');
if isempty(fname)
    fs_orig = 44100; dur = 3;
    tt = (0:round(fs_orig*dur)-1)'/fs_orig;
    x_orig = 0.3*sin(2*pi*120*tt) + 0.5*sin(2*pi*400*tt) + ...
        0.6*sin(2*pi*1200*tt) + 0.4*sin(2*pi*3000*tt) + ...
        0.2*sin(2*pi*7000*tt) + 0.1*sin(2*pi*14000*tt) + ...
        0.05*randn(size(tt));
    x_orig = x_orig / max(abs(x_orig));
    fprintf('Test signal: fs=%d Hz, %.1f s\n\n', fs_orig, dur);
else
    [x_orig, fs_orig] = audioread(fname);
    if size(x_orig,2) > 1, x_orig = mean(x_orig,2); end
    fprintf('Loaded: fs=%d Hz, %.2f s\n\n', fs_orig, length(x_orig)/fs_orig);
end

% --- Mode ---
mode = input('Mode (1=Preset, 2=Custom) [1]: ');
if isempty(mode), mode = 1; end

if mode == 1
    bands = [0 100; 100 300; 300 800; 800 2000; 2000 5000; 5000 10000; 10000 20000];
    bnames = {'0-100','100-300','300-800','800-2k','2k-5k','5k-10k','10k-20k'};
else
    nb = input('Number of bands (5-10): ');
    nb = max(5, min(10, nb));
    edges = input(sprintf('Enter %d edges [0 ... 20000]: ', nb+1));
    bands = [edges(1:end-1)', edges(2:end)'];
    bnames = cell(1,size(bands,1));
    for i = 1:size(bands,1)
        bnames{i} = sprintf('%g-%g', bands(i,1), bands(i,2));
    end
end
nbands = size(bands,1);

% --- Filter type ---
ftype = input('Filter (1=FIR, 2=IIR) [1]: ');
if isempty(ftype), ftype = 1; end

if ftype == 1
    wtype = input('Window (1=Hamming, 2=Hanning, 3=Blackman) [1]: ');
    if isempty(wtype), wtype = 1; end
    def_ord = 100;
    wnames = {'Hamming','Hanning','Blackman'};
    ftype_name = ['FIR (' wnames{wtype} ')'];
else
    iir_m = input('IIR (1=Butterworth, 2=ChebyI, 3=ChebyII) [1]: ');
    if isempty(iir_m), iir_m = 1; end
    def_ord = 4;
    mnames = {'Butterworth','Chebyshev I','Chebyshev II'};
    ftype_name = ['IIR ' mnames{iir_m}];
end

filt_order = input(sprintf('Filter order [%d]: ', def_ord));
if isempty(filt_order), filt_order = def_ord; end

% --- Gains ---
fprintf('Enter %d gains in dB (e.g. [0 3 6 3 0 -3 -6]):\n', nbands);
gains_db = input('Gains: ');
if isempty(gains_db), gains_db = zeros(1,nbands); end

% --- Output sample rate ---
fs_out = input(sprintf('Output sample rate [%d]: ', fs_orig));
if isempty(fs_out), fs_out = fs_orig; end

%% ===================== FILTER DESIGN =====================
nyq = fs_orig / 2;
b_all = cell(1,nbands);
a_all = cell(1,nbands);

for i = 1:nbands
    fl = bands(i,1); fh = min(bands(i,2), nyq-1);
    if fl >= nyq, b_all{i}=0; a_all{i}=1; continue; end

    if fl == 0
        Wn = fh/nyq; ft = 'low';
    elseif fh >= nyq-1
        Wn = max(fl/nyq, 0.001); ft = 'high';
    else
        Wn = [max(fl/nyq,0.001) fh/nyq]; ft = 'bandpass';
    end

    if ftype == 1
        switch wtype
            case 1, w = hamming(filt_order+1);
            case 2, w = hanning(filt_order+1);
            case 3, w = blackman(filt_order+1);
        end
        b_all{i} = fir1(filt_order, Wn, ft, w);
        a_all{i} = 1;
    else
        switch iir_m
            case 1, [b_all{i},a_all{i}] = butter(filt_order, Wn, ft);
            case 2, [b_all{i},a_all{i}] = cheby1(filt_order, 0.5, Wn, ft);
            case 3, [b_all{i},a_all{i}] = cheby2(filt_order, 40, Wn, ft);
        end
    end
end

%% ===================== SIGNAL PROCESSING =====================
x = x_orig;
y_bands = zeros(length(x), nbands);

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

y_eq = sum(y_bands, 2);
y_eq = y_eq / max(abs(y_eq)+eps);

% Resample if needed
if fs_out ~= fs_orig
    y_out = resample(y_eq, fs_out, fs_orig);
else
    y_out = y_eq;
end

%% ===================== ALSO RUN OTHER FILTER TYPE =====================
% For demonstration: run the opposite filter type with same bands/gains
if ftype == 1
    alt_name = 'IIR Butterworth';
else
    alt_name = 'FIR Hamming';
end
y_alt_bands = zeros(length(x), nbands);
for i = 1:nbands
    fl = bands(i,1); fh = min(bands(i,2), nyq-1);
    if fl >= nyq, continue; end
    if fl == 0
        Wn = fh/nyq; ft = 'low';
    elseif fh >= nyq-1
        Wn = max(fl/nyq, 0.001); ft = 'high';
    else
        Wn = [max(fl/nyq,0.001) fh/nyq]; ft = 'bandpass';
    end
    if ftype == 1
        [ba,aa] = butter(4, Wn, ft);
        y_alt_bands(:,i) = filtfilt(ba,aa,x) * 10^(gains_db(i)/20);
    else
        ba = fir1(100, Wn, ft, hamming(101));
        y_alt_bands(:,i) = filter(ba,1,x) * 10^(gains_db(i)/20);
    end
end
y_alt = sum(y_alt_bands,2);
y_alt = y_alt / max(abs(y_alt)+eps);

%% ===================== SAMPLE RATE DEMOS =====================
y_4x = resample(y_eq, 4, 1);
y_half = resample(y_eq, 1, 2);
fs_4x = fs_orig * 4;
fs_half = fs_orig / 2;

%% ===================== PSD & SPECTROGRAMS =====================
nw = min(1024, floor(length(x)/4));
[pxx_orig, f_psd] = pwelch(x, hamming(nw), nw/2, nw, fs_orig);
[pxx_eq, ~] = pwelch(y_eq, hamming(nw), nw/2, nw, fs_orig);

%% ===================== TABBED FIGURE VIEWER =====================
fig = figure('Name','Speech Equalizer Results','Position',[30 30 1500 900],...
    'NumberTitle','off','Color','w');
tg = uitabgroup(fig);
Nfft = 4096;
cmap = lines(nbands);

% ---- Tab: Combined Magnitude Response ----
tab = uitab(tg,'Title','All Magnitudes');
ax = axes('Parent',tab,'Position',[0.07 0.1 0.88 0.82]);
hold(ax,'on');
for i = 1:nbands
    if isequal(b_all{i},0), continue; end
    [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
    plot(ax, f, 20*log10(abs(H)+eps), 'Color', cmap(i,:), 'LineWidth', 1.3);
end
legend(ax, bnames, 'Location','best'); grid(ax,'on');
title(ax,['Magnitude Response - All Bands (' ftype_name ')']);
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'Magnitude (dB)');
xlim(ax,[0 nyq]);

% ---- Tab: Combined Phase Response ----
tab = uitab(tg,'Title','All Phases');
ax = axes('Parent',tab,'Position',[0.07 0.1 0.88 0.82]);
hold(ax,'on');
for i = 1:nbands
    if isequal(b_all{i},0), continue; end
    [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
    plot(ax, f, unwrap(angle(H))*180/pi, 'Color', cmap(i,:), 'LineWidth', 1.3);
end
legend(ax, bnames, 'Location','best'); grid(ax,'on');
title(ax,'Phase Response - All Bands');
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'Phase (degrees)');
xlim(ax,[0 nyq]);

% ---- Tabs: Per-band analysis (impulse, step, pole-zero) ----
imp_len = 300; imp = [1; zeros(imp_len-1,1)]; stp = ones(imp_len,1);
t_imp = (0:imp_len-1)/fs_orig;

for i = 1:nbands
    if isequal(b_all{i},0), continue; end
    tab = uitab(tg,'Title',['Band ' bnames{i}]);

    % Magnitude
    ax = tsubplot(tab,3,2,1);
    [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
    plot(ax,f,20*log10(abs(H)+eps),'Color',cmap(i,:),'LineWidth',1.2); grid(ax,'on');
    title(ax,[bnames{i} ' Hz - Magnitude']); xlabel(ax,'Hz'); ylabel(ax,'dB');

    % Phase
    ax = tsubplot(tab,3,2,2);
    plot(ax,f,unwrap(angle(H))*180/pi,'Color',cmap(i,:),'LineWidth',1.2); grid(ax,'on');
    title(ax,'Phase'); xlabel(ax,'Hz'); ylabel(ax,'Deg');

    % Impulse
    ax = tsubplot(tab,3,2,3);
    h_i = filter(b_all{i}, a_all{i}, imp);
    stem(ax,t_imp,h_i,'Color',cmap(i,:),'MarkerSize',2); grid(ax,'on');
    title(ax,'Impulse Response'); xlabel(ax,'Time (s)');

    % Step
    ax = tsubplot(tab,3,2,4);
    h_s = filter(b_all{i}, a_all{i}, stp);
    plot(ax,t_imp,h_s,'Color',cmap(i,:),'LineWidth',1.2); grid(ax,'on');
    title(ax,'Step Response'); xlabel(ax,'Time (s)');

    % Pole-Zero
    ax = tsubplot(tab,3,2,5);
    axes(ax); %#ok<LAXES>
    zplane(b_all{i}, a_all{i});
    title(ax,'Pole-Zero'); grid(ax,'on');

    % Info
    ax = tsubplot(tab,3,2,6);
    axis(ax,'off');
    info_str = {sprintf('Band: %s Hz', bnames{i}), ...
        sprintf('Type: %s', ftype_name), ...
        sprintf('Order: %d', filt_order), ...
        sprintf('Gain: %.1f dB', gains_db(i)), ...
        sprintf('Num coeffs: %d', length(b_all{i})), ...
        sprintf('Den coeffs: %d', length(a_all{i}))};
    text(ax, 0.1, 0.7, info_str, 'FontSize', 12, 'VerticalAlignment', 'top');
    title(ax, 'Filter Info');
end

% ---- Tab: Time Domain Comparison ----
tab = uitab(tg,'Title','Time Compare');
t_sig = (0:length(x)-1)/fs_orig;
ax = tsubplot(tab,2,1,1);
plot(ax, t_sig, x, 'k'); grid(ax,'on');
title(ax,'Original Signal'); xlabel(ax,'Time (s)'); ylabel(ax,'Amplitude');
ax = tsubplot(tab,2,1,2);
plot(ax, t_sig, y_eq, 'b'); grid(ax,'on');
title(ax,['Equalized (' ftype_name ')']); xlabel(ax,'Time (s)'); ylabel(ax,'Amplitude');

% ---- Tab: Frequency Domain Comparison ----
tab = uitab(tg,'Title','Freq Compare');
X_fft = abs(fft(x)); Y_fft = abs(fft(y_eq));
f_axis = (0:length(x)-1)*fs_orig/length(x);
half = floor(length(x)/2);
ax = tsubplot(tab,1,1,1);
plot(ax, f_axis(1:half), 20*log10(X_fft(1:half)+eps), 'k', 'LineWidth', 0.8); hold(ax,'on');
plot(ax, f_axis(1:half), 20*log10(Y_fft(1:half)+eps), 'b', 'LineWidth', 0.8);
legend(ax,'Original','Equalized'); grid(ax,'on');
title(ax,'Frequency Spectrum Comparison');
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'Magnitude (dB)');
xlim(ax,[0 nyq]);

% ---- Tab: PSD ----
tab = uitab(tg,'Title','PSD');
ax = tsubplot(tab,1,1,1);
plot(ax, f_psd, 10*log10(pxx_orig), 'k', 'LineWidth', 1.2); hold(ax,'on');
plot(ax, f_psd, 10*log10(pxx_eq), 'b', 'LineWidth', 1.2);
legend(ax,'Original','Equalized'); grid(ax,'on');
title(ax,'Power Spectral Density (Welch)');
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'PSD (dB/Hz)');

% ---- Tab: Spectrogram ----
tab = uitab(tg,'Title','Spectrogram');
wsp = hamming(256); nov = 200; nsp = 512;
ax = tsubplot(tab,2,1,1); axes(ax);
spectrogram(x, wsp, nov, nsp, fs_orig, 'yaxis');
title('Original'); colorbar;
ax = tsubplot(tab,2,1,2); axes(ax);
spectrogram(y_eq, wsp, nov, nsp, fs_orig, 'yaxis');
title('Equalized'); colorbar;

% ---- Tab: FIR vs IIR ----
tab = uitab(tg,'Title','FIR vs IIR');
ax = tsubplot(tab,2,1,1);
plot(ax, t_sig, y_eq, 'b'); grid(ax,'on');
title(ax,['Primary: ' ftype_name]); ylabel(ax,'Amplitude');
ax = tsubplot(tab,2,1,2);
plot(ax, t_sig, y_alt, 'r'); grid(ax,'on');
title(ax,['Alternate: ' alt_name]); xlabel(ax,'Time (s)'); ylabel(ax,'Amplitude');

% ---- Tab: Sample Rate Demo ----
tab = uitab(tg,'Title','Sample Rate');
ax = tsubplot(tab,3,1,1);
t_orig = (0:length(y_eq)-1)/fs_orig;
plot(ax, t_orig(1:min(500,end)), y_eq(1:min(500,end)), 'b'); grid(ax,'on');
title(ax,sprintf('Original (fs=%d Hz)', fs_orig)); ylabel(ax,'Amp');
ax = tsubplot(tab,3,1,2);
t4 = (0:length(y_4x)-1)/fs_4x;
plot(ax, t4(1:min(2000,end)), y_4x(1:min(2000,end)), 'r'); grid(ax,'on');
title(ax,sprintf('4x Sample Rate (fs=%d Hz)', fs_4x)); ylabel(ax,'Amp');
ax = tsubplot(tab,3,1,3);
th = (0:length(y_half)-1)/fs_half;
plot(ax, th(1:min(250,end)), y_half(1:min(250,end)), 'Color',[0.1 0.7 0.3]); grid(ax,'on');
title(ax,sprintf('Half Sample Rate (fs=%d Hz)', round(fs_half))); ylabel(ax,'Amp');
xlabel(ax,'Time (s)');

%% ===================== SAVE FIGURES =====================
tabnames = {};
tabs_all = tg.Children;
for i = 1:length(tabs_all)
    tg.SelectedTab = tabs_all(i);
    drawnow;
    safe = regexprep(tabs_all(i).Title, '[^a-zA-Z0-9]', '_');
    fname_fig = sprintf('fig%02d_%s.png', i, lower(safe));
    tabnames{end+1} = fname_fig; %#ok<SAGROW>
    exportgraphics(tabs_all(i), fullfile(figDir, fname_fig), 'Resolution', 150, 'BackgroundColor', 'none');
end

%% ===================== PLAY & SAVE OUTPUT =====================
% Save equalized audio
out_file = fullfile(scriptDir, 'output_equalized.wav');
audiowrite(out_file, y_out, fs_out);

% Save alternate filter type
out_alt = fullfile(scriptDir, 'output_alternate.wav');
audiowrite(out_alt, y_alt/max(abs(y_alt)+eps), fs_orig);

% Save resampled versions
audiowrite(fullfile(scriptDir, 'output_4x.wav'), y_4x/max(abs(y_4x)+eps), fs_4x);
audiowrite(fullfile(scriptDir, 'output_half.wav'), y_half/max(abs(y_half)+eps), round(fs_half));

fprintf('\n--- Output Files ---\n');
fprintf('Equalized: %s (fs=%d Hz)\n', out_file, fs_out);
fprintf('Alternate: %s\n', out_alt);
fprintf('4x rate:   output_4x.wav (fs=%d Hz)\n', fs_4x);
fprintf('Half rate: output_half.wav (fs=%d Hz)\n', round(fs_half));
fprintf('\nPlaying original...\n');
sound(x, fs_orig); pause(length(x)/fs_orig + 0.5);
fprintf('Playing equalized...\n');
sound(y_out, fs_out); pause(length(y_out)/fs_out + 0.5);
fprintf('Done.\n');

%% ===================== HELPER =====================
function ax = tsubplot(parent, m, n, p)
    col = mod(p-1, n) + 1;
    row = ceil(p / n);
    gx = 0.08; gy = 0.08;
    ml = 0.06; mb = 0.06;
    w = (1 - ml - gx*(n-1) - 0.02) / n;
    h = (1 - mb - gy*(m-1) - 0.04) / m;
    left = ml + (col-1)*(w + gx);
    bot = 1 - 0.03 - row*h - (row-1)*gy;
    ax = axes('Parent', parent, 'Position', [left bot w h]);
end
