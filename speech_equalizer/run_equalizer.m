function run_equalizer(cfg)
%RUN_EQUALIZER  Core processing engine for the speech equalizer.
%   run_equalizer(cfg) runs the full equalizer pipeline using the config
%   struct cfg with fields:
%       .audioFile   - path to wav/mp3 or '' for test signal
%       .mode        - 1 (preset 7-band) or 2 (custom)
%       .bands       - Nx2 matrix of [low high] Hz per band
%       .bnames      - cell array of band name strings
%       .filterType  - 1 (FIR) or 2 (IIR)
%       .windowType  - 1 (Hamming) 2 (Hanning) 3 (Blackman)  [FIR only]
%       .iirMethod   - 1 (Butter) 2 (ChebyI) 3 (ChebyII)    [IIR only]
%       .filterOrder - filter order
%       .gains_db    - 1xN gain vector in dB
%       .fs_out      - output sample rate (0 = same as input)

    scriptDir = fileparts(mfilename('fullpath'));
    figDir    = fullfile(scriptDir, 'figures');
    if ~exist(figDir,'dir'), mkdir(figDir); end

    %% Load audio
    if isempty(cfg.audioFile)
        fs_orig = 44100; dur = 3;
        tt = (0:round(fs_orig*dur)-1)'/fs_orig;
        x_orig = 0.3*sin(2*pi*120*tt) + 0.5*sin(2*pi*400*tt) + ...
            0.6*sin(2*pi*1200*tt) + 0.4*sin(2*pi*3000*tt) + ...
            0.2*sin(2*pi*7000*tt) + 0.1*sin(2*pi*14000*tt) + ...
            0.05*randn(size(tt));
        x_orig = x_orig / max(abs(x_orig));
        fprintf('Using test signal: fs=%d Hz, %.1f s\n', fs_orig, dur);
    else
        [x_orig, fs_orig] = audioread(cfg.audioFile);
        if size(x_orig,2) > 1, x_orig = mean(x_orig,2); end
        fprintf('Loaded: %s (fs=%d Hz, %.2f s)\n', cfg.audioFile, fs_orig, length(x_orig)/fs_orig);
    end

    bands   = cfg.bands;
    bnames  = cfg.bnames;
    nbands  = size(bands,1);
    gains_db = cfg.gains_db;
    ftype   = cfg.filterType;
    filt_order = cfg.filterOrder;
    fs_out  = cfg.fs_out;
    if fs_out == 0, fs_out = fs_orig; end

    % Filter type name
    if ftype == 1
        wtype = cfg.windowType;
        wnames = {'Hamming','Hanning','Blackman'};
        ftype_name = ['FIR (' wnames{wtype} ')'];
    else
        iir_m = cfg.iirMethod;
        mnames = {'Butterworth','Chebyshev I','Chebyshev II'};
        ftype_name = ['IIR ' mnames{iir_m}];
    end

    %% Filter design
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

    %% Signal processing
    x = x_orig;
    y_bands = zeros(length(x), nbands);
    for i = 1:nbands
        if isequal(b_all{i}, 0), continue; end
        if ftype == 1
            yi = filter(b_all{i}, a_all{i}, x);
        else
            yi = filtfilt(b_all{i}, a_all{i}, x);
        end
        y_bands(:,i) = yi * 10^(gains_db(i)/20);
    end
    y_eq = sum(y_bands, 2);
    y_eq = y_eq / max(abs(y_eq)+eps);

    if fs_out ~= fs_orig
        y_out = resample(y_eq, fs_out, fs_orig);
    else
        y_out = y_eq;
    end

    %% Alternate filter type
    if ftype == 1, alt_name = 'IIR Butterworth';
    else,          alt_name = 'FIR Hamming'; end
    y_alt_bands = zeros(length(x), nbands);
    for i = 1:nbands
        fl = bands(i,1); fh = min(bands(i,2), nyq-1);
        if fl >= nyq, continue; end
        if fl == 0,        Wn = fh/nyq; ft = 'low';
        elseif fh >= nyq-1, Wn = max(fl/nyq,0.001); ft = 'high';
        else,              Wn = [max(fl/nyq,0.001) fh/nyq]; ft = 'bandpass'; end
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

    %% Sample rate demos
    y_4x   = resample(y_eq, 4, 1);
    y_half = resample(y_eq, 1, 2);
    fs_4x  = fs_orig * 4;
    fs_half = fs_orig / 2;

    %% PSD
    nw = min(1024, floor(length(x)/4));
    [pxx_orig, f_psd] = pwelch(x, hamming(nw), nw/2, nw, fs_orig);
    [pxx_eq, ~]       = pwelch(y_eq, hamming(nw), nw/2, nw, fs_orig);

    %% ========== Generate all 15 figures ==========
    Nfft = 4096;
    cmap = lines(nbands);
    t_sig = (0:length(x)-1)/fs_orig;

    % --- Fig 1: All Magnitudes ---
    f1 = figure('Visible','off','Position',[30 30 1200 600]);
    hold on;
    for i = 1:nbands
        if isequal(b_all{i},0), continue; end
        [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
        plot(f, 20*log10(abs(H)+eps), 'Color', cmap(i,:), 'LineWidth', 1.3);
    end
    legend(bnames,'Location','best'); grid on;
    title(['Magnitude Response - All Bands (' ftype_name ')']);
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)'); xlim([0 nyq]);
    exportgraphics(f1, fullfile(figDir,'fig01_all_magnitudes.png'),'Resolution',150);
    close(f1);

    % --- Fig 2: All Phases ---
    f2 = figure('Visible','off','Position',[30 30 1200 600]);
    hold on;
    for i = 1:nbands
        if isequal(b_all{i},0), continue; end
        [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
        plot(f, unwrap(angle(H))*180/pi, 'Color', cmap(i,:), 'LineWidth', 1.3);
    end
    legend(bnames,'Location','best'); grid on;
    title('Phase Response - All Bands');
    xlabel('Frequency (Hz)'); ylabel('Phase (degrees)'); xlim([0 nyq]);
    exportgraphics(f2, fullfile(figDir,'fig02_all_phases.png'),'Resolution',150);
    close(f2);

    % --- Figs 3-9: Per-band ---
    imp_len = 300; imp = [1; zeros(imp_len-1,1)]; stp = ones(imp_len,1);
    t_imp = (0:imp_len-1)/fs_orig;
    for i = 1:nbands
        if isequal(b_all{i},0), continue; end
        fg = figure('Visible','off','Position',[30 30 1400 800]);
        subplot(3,2,1);
        [H,f] = freqz(b_all{i}, a_all{i}, Nfft, fs_orig);
        plot(f,20*log10(abs(H)+eps),'Color',cmap(i,:),'LineWidth',1.2); grid on;
        title([bnames{i} ' Hz - Magnitude']); xlabel('Hz'); ylabel('dB');
        subplot(3,2,2);
        plot(f,unwrap(angle(H))*180/pi,'Color',cmap(i,:),'LineWidth',1.2); grid on;
        title('Phase'); xlabel('Hz'); ylabel('Deg');
        subplot(3,2,3);
        stem(t_imp,filter(b_all{i},a_all{i},imp),'Color',cmap(i,:),'MarkerSize',2); grid on;
        title('Impulse Response'); xlabel('Time (s)');
        subplot(3,2,4);
        plot(t_imp,filter(b_all{i},a_all{i},stp),'Color',cmap(i,:),'LineWidth',1.2); grid on;
        title('Step Response'); xlabel('Time (s)');
        subplot(3,2,5);
        zplane(b_all{i},a_all{i}); title('Pole-Zero'); grid on;
        subplot(3,2,6); axis off;
        text(0.1,0.7,{sprintf('Band: %s Hz',bnames{i}), sprintf('Type: %s',ftype_name), ...
            sprintf('Order: %d',filt_order), sprintf('Gain: %.1f dB',gains_db(i))},...
            'FontSize',12,'VerticalAlignment','top');
        title('Filter Info');
        safe = regexprep(bnames{i},'[^a-zA-Z0-9]','_');
        exportgraphics(fg, fullfile(figDir,sprintf('fig%02d_band_%s.png',i+2,lower(safe))),'Resolution',150);
        close(fg);
    end

    % --- Fig 10: Time Compare ---
    fg = figure('Visible','off','Position',[30 30 1200 600]);
    subplot(2,1,1); plot(t_sig,x,'k'); grid on; title('Original Signal'); ylabel('Amplitude');
    subplot(2,1,2); plot(t_sig,y_eq,'b'); grid on; title(['Equalized (' ftype_name ')']); xlabel('Time (s)'); ylabel('Amplitude');
    exportgraphics(fg, fullfile(figDir,'fig10_time_compare.png'),'Resolution',150); close(fg);

    % --- Fig 11: Freq Compare ---
    fg = figure('Visible','off','Position',[30 30 1200 600]);
    X_fft = abs(fft(x)); Y_fft = abs(fft(y_eq));
    f_axis = (0:length(x)-1)*fs_orig/length(x); half = floor(length(x)/2);
    plot(f_axis(1:half),20*log10(X_fft(1:half)+eps),'k','LineWidth',0.8); hold on;
    plot(f_axis(1:half),20*log10(Y_fft(1:half)+eps),'b','LineWidth',0.8);
    legend('Original','Equalized'); grid on; title('Frequency Spectrum'); xlabel('Hz'); ylabel('dB'); xlim([0 nyq]);
    exportgraphics(fg, fullfile(figDir,'fig11_freq_compare.png'),'Resolution',150); close(fg);

    % --- Fig 12: PSD ---
    fg = figure('Visible','off','Position',[30 30 1200 600]);
    plot(f_psd,10*log10(pxx_orig),'k','LineWidth',1.2); hold on;
    plot(f_psd,10*log10(pxx_eq),'b','LineWidth',1.2);
    legend('Original','Equalized'); grid on; title('Power Spectral Density (Welch)'); xlabel('Hz'); ylabel('dB/Hz');
    exportgraphics(fg, fullfile(figDir,'fig12_psd.png'),'Resolution',150); close(fg);

    % --- Fig 13: Spectrogram ---
    fg = figure('Visible','off','Position',[30 30 1200 800]);
    wsp = hamming(256); nov = 200; nsp = 512;
    subplot(2,1,1); spectrogram(x,wsp,nov,nsp,fs_orig,'yaxis'); title('Original'); colorbar;
    subplot(2,1,2); spectrogram(y_eq,wsp,nov,nsp,fs_orig,'yaxis'); title('Equalized'); colorbar;
    exportgraphics(fg, fullfile(figDir,'fig13_spectrogram.png'),'Resolution',150); close(fg);

    % --- Fig 14: FIR vs IIR ---
    fg = figure('Visible','off','Position',[30 30 1200 600]);
    subplot(2,1,1); plot(t_sig,y_eq,'b'); grid on; title(['Primary: ' ftype_name]); ylabel('Amplitude');
    subplot(2,1,2); plot(t_sig,y_alt,'r'); grid on; title(['Alternate: ' alt_name]); xlabel('Time (s)'); ylabel('Amplitude');
    exportgraphics(fg, fullfile(figDir,'fig14_fir_vs_iir.png'),'Resolution',150); close(fg);

    % --- Fig 15: Sample Rate ---
    fg = figure('Visible','off','Position',[30 30 1200 800]);
    t_orig_sr = (0:length(y_eq)-1)/fs_orig;
    subplot(3,1,1); plot(t_orig_sr(1:min(500,end)),y_eq(1:min(500,end)),'b'); grid on;
    title(sprintf('Original (fs=%d Hz)',fs_orig)); ylabel('Amp');
    t4 = (0:length(y_4x)-1)/fs_4x;
    subplot(3,1,2); plot(t4(1:min(2000,end)),y_4x(1:min(2000,end)),'r'); grid on;
    title(sprintf('4x Rate (fs=%d Hz)',fs_4x)); ylabel('Amp');
    th = (0:length(y_half)-1)/fs_half;
    subplot(3,1,3); plot(th(1:min(250,end)),y_half(1:min(250,end)),'Color',[0.1 0.7 0.3]); grid on;
    title(sprintf('Half Rate (fs=%d Hz)',round(fs_half))); ylabel('Amp'); xlabel('Time (s)');
    exportgraphics(fg, fullfile(figDir,'fig15_sample_rate.png'),'Resolution',150); close(fg);

    %% Save audio
    audiowrite(fullfile(scriptDir,'output_equalized.wav'), y_out, fs_out);
    audiowrite(fullfile(scriptDir,'output_alternate.wav'), y_alt/max(abs(y_alt)+eps), fs_orig);
    audiowrite(fullfile(scriptDir,'output_4x.wav'), y_4x/max(abs(y_4x)+eps), fs_4x);
    audiowrite(fullfile(scriptDir,'output_half.wav'), y_half/max(abs(y_half)+eps), round(fs_half));

    fprintf('\n=== Done! ===\n');
    fprintf('Figures saved to: %s\n', figDir);
    fprintf('Audio saved to: %s\n', scriptDir);
end
