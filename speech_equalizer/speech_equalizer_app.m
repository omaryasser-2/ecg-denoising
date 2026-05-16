function speech_equalizer_app()
%SPEECH_EQUALIZER_APP  Visual GUI for the multi-band speech equalizer.
%   Launch with:  speech_equalizer_app
%
%   Features:
%     - Browse for audio file or use built-in test signal
%     - Preset & custom band modes
%     - Visual gain sliders per band
%     - Filter type / window / order controls
%     - One-click presets (Voice, Bass Boost, etc.)
%     - Run history — reload last config instantly
%     - Runs processing and opens HTML results page

    scriptDir = fileparts(mfilename('fullpath'));
    histFile  = fullfile(scriptDir, 'run_history.mat');

    % Default preset bands
    presetBands  = [0 100; 100 300; 300 800; 800 2000; 2000 5000; 5000 10000; 10000 20000];
    presetNames  = {'0-100','100-300','300-800','800-2k','2k-5k','5k-10k','10k-20k'};

    % ===== CREATE MAIN WINDOW =====
    fig = uifigure('Name', 'Speech Equalizer', ...
        'Position', [150 80 920 720], ...
        'Color', [0.08 0.08 0.12], ...
        'Resize', 'on');

    % ===== TITLE =====
    uilabel(fig, 'Text', '🎛️  Multi-Band Speech Equalizer', ...
        'Position', [30 670 500 35], ...
        'FontSize', 20, 'FontWeight', 'bold', ...
        'FontColor', [0.9 0.9 0.95]);

    uilabel(fig, 'Text', 'Configure parameters below, then press RUN to process.', ...
        'Position', [30 648 500 22], ...
        'FontSize', 12, 'FontColor', [0.5 0.5 0.65]);

    % ===== AUDIO FILE PANEL =====
    pnlAudio = uipanel(fig, 'Title', '📁 Audio Input', ...
        'Position', [20 560 880 80], ...
        'BackgroundColor', [0.1 0.1 0.15], ...
        'ForegroundColor', [0.7 0.7 0.8], ...
        'FontWeight', 'bold');

    lblFile = uilabel(pnlAudio, 'Text', 'No file selected — will use test signal', ...
        'Position', [15 10 580 28], ...
        'FontSize', 12, 'FontColor', [0.6 0.6 0.7]);

    uibutton(pnlAudio, 'Text', '📂 Browse...', ...
        'Position', [620 10 110 32], ...
        'BackgroundColor', [0.18 0.18 0.28], ...
        'FontColor', [0.85 0.85 0.95], ...
        'ButtonPushedFcn', @browseFile);

    uibutton(pnlAudio, 'Text', '✕ Clear', ...
        'Position', [740 10 110 32], ...
        'BackgroundColor', [0.18 0.18 0.28], ...
        'FontColor', [0.85 0.85 0.95], ...
        'ButtonPushedFcn', @clearFile);

    % ===== FILTER SETTINGS PANEL =====
    pnlFilter = uipanel(fig, 'Title', '⚙️ Filter Settings', ...
        'Position', [20 430 430 120], ...
        'BackgroundColor', [0.1 0.1 0.15], ...
        'ForegroundColor', [0.7 0.7 0.8], ...
        'FontWeight', 'bold');

    uilabel(pnlFilter, 'Text', 'Filter Type', ...
        'Position', [15 60 80 22], 'FontColor', [0.6 0.6 0.7]);
    ddFilter = uidropdown(pnlFilter, ...
        'Items', {'FIR', 'IIR'}, 'Value', 'FIR', ...
        'Position', [100 58 120 28], ...
        'BackgroundColor', [0.15 0.15 0.22], ...
        'FontColor', [0.9 0.9 0.95], ...
        'ValueChangedFcn', @filterTypeChanged);

    uilabel(pnlFilter, 'Text', 'Window / Method', ...
        'Position', [230 60 110 22], 'FontColor', [0.6 0.6 0.7]);
    ddWindow = uidropdown(pnlFilter, ...
        'Items', {'Hamming', 'Hanning', 'Blackman'}, 'Value', 'Hamming', ...
        'Position', [340 58 80 28], ...
        'BackgroundColor', [0.15 0.15 0.22], ...
        'FontColor', [0.9 0.9 0.95]);

    uilabel(pnlFilter, 'Text', 'Filter Order', ...
        'Position', [15 20 80 22], 'FontColor', [0.6 0.6 0.7]);
    spnOrder = uispinner(pnlFilter, 'Value', 100, ...
        'Limits', [2 500], 'Step', 2, ...
        'Position', [100 18 120 28], ...
        'BackgroundColor', [0.15 0.15 0.22], ...
        'FontColor', [0.9 0.9 0.95]);

    uilabel(pnlFilter, 'Text', 'Output Fs', ...
        'Position', [230 20 110 22], 'FontColor', [0.6 0.6 0.7]);
    ddFs = uidropdown(pnlFilter, ...
        'Items', {'Same as input','22050','44100','48000','96000'}, ...
        'Value', 'Same as input', ...
        'Position', [340 18 80 28], ...
        'BackgroundColor', [0.15 0.15 0.22], ...
        'FontColor', [0.9 0.9 0.95]);

    % ===== PRESETS PANEL =====
    pnlPreset = uipanel(fig, 'Title', '🎨 Quick Presets', ...
        'Position', [470 430 430 120], ...
        'BackgroundColor', [0.1 0.1 0.15], ...
        'ForegroundColor', [0.7 0.7 0.8], ...
        'FontWeight', 'bold');

    presetDefs = {
        'Flat',            [0 0 0 0 0 0 0];
        'Voice Enhance',   [-3 0 3 6 6 3 -3];
        'Bass Boost',      [8 6 3 0 0 -2 -4];
        'Treble Boost',    [-4 -2 0 0 3 6 8];
        'Podcast',         [-6 -2 4 6 4 2 -2];
        'De-Noise',        [-8 -4 0 2 2 -2 -6];
    };

    for p = 1:size(presetDefs,1)
        row = ceil(p/3); col = mod(p-1,3)+1;
        x = 10 + (col-1)*140;
        y = 65 - (row-1)*42;
        uibutton(pnlPreset, 'Text', presetDefs{p,1}, ...
            'Position', [x y 130 34], ...
            'BackgroundColor', [0.2 0.15 0.35], ...
            'FontColor', [0.9 0.85 1.0], ...
            'FontWeight', 'bold', ...
            'ButtonPushedFcn', @(~,~) applyPreset(presetDefs{p,2}));
    end

    % ===== EQUALIZER SLIDERS PANEL =====
    pnlEQ = uipanel(fig, 'Title', '🎚️ Band Gains (dB) — drag sliders to adjust', ...
        'Position', [20 140 880 280], ...
        'BackgroundColor', [0.1 0.1 0.15], ...
        'ForegroundColor', [0.7 0.7 0.8], ...
        'FontWeight', 'bold');

    sliders = gobjects(1,7);
    sliderLabels = gobjects(1,7);
    sliderValues = gobjects(1,7);
    sliderW = 100;
    startX = 30;

    for i = 1:7
        cx = startX + (i-1) * (sliderW + 18);

        % Band name
        uilabel(pnlEQ, 'Text', presetNames{i}, ...
            'Position', [cx 220 sliderW 20], ...
            'FontSize', 11, 'FontWeight', 'bold', ...
            'FontColor', [0.75 0.7 0.9], ...
            'HorizontalAlignment', 'center');

        % Slider
        sliders(i) = uislider(pnlEQ, ...
            'Orientation', 'vertical', ...
            'Limits', [-12 12], 'Value', 0, ...
            'Position', [cx+40 30 3 180], ...
            'MajorTicks', [-12 -6 0 6 12], ...
            'MinorTicks', -12:2:12, ...
            'FontColor', [0.6 0.6 0.7], ...
            'ValueChangedFcn', @(s,~) updateSliderLabel(i, s.Value));

        % dB value display
        sliderValues(i) = uilabel(pnlEQ, 'Text', '0 dB', ...
            'Position', [cx 5 sliderW 20], ...
            'FontSize', 12, 'FontWeight', 'bold', ...
            'FontColor', [0.4 0.85 0.5], ...
            'HorizontalAlignment', 'center');
    end

    % ===== BOTTOM ACTION BAR =====
    pnlActions = uipanel(fig, 'Title', '', ...
        'Position', [20 15 880 115], ...
        'BackgroundColor', [0.1 0.1 0.15], ...
        'BorderType', 'none');

    % Run button
    btnRun = uibutton(pnlActions, 'Text', '▶  RUN EQUALIZER', ...
        'Position', [20 55 250 45], ...
        'BackgroundColor', [0.35 0.2 0.75], ...
        'FontColor', [1 1 1], ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @runEqualizer);

    % View results
    uibutton(pnlActions, 'Text', '🌐 View Results', ...
        'Position', [290 55 160 45], ...
        'BackgroundColor', [0.12 0.35 0.25], ...
        'FontColor', [0.7 1.0 0.8], ...
        'FontSize', 14, 'FontWeight', 'bold', ...
        'ButtonPushedFcn', @openResults);

    % Load history
    uibutton(pnlActions, 'Text', '🕐 Load Last Run', ...
        'Position', [470 55 160 45], ...
        'BackgroundColor', [0.18 0.18 0.28], ...
        'FontColor', [0.8 0.8 0.9], ...
        'FontSize', 13, ...
        'ButtonPushedFcn', @loadHistory);

    % Save history label
    uibutton(pnlActions, 'Text', '💾 Save Config', ...
        'Position', [650 55 100 45], ...
        'BackgroundColor', [0.18 0.18 0.28], ...
        'FontColor', [0.8 0.8 0.9], ...
        'FontSize', 13, ...
        'ButtonPushedFcn', @saveHistory);

    % Status
    lblStatus = uilabel(pnlActions, 'Text', 'Ready. Configure settings and press RUN.', ...
        'Position', [20 15 700 28], ...
        'FontSize', 12, 'FontColor', [0.5 0.5 0.65]);

    % Store selected file path
    selectedFile = '';

    % ===== AUTO-CONFIGURE RECOMMENDED DEFAULTS =====
    % Auto-select test_speech.wav
    defaultAudio = fullfile(scriptDir, 'test_speech.wav');
    if isfile(defaultAudio)
        selectedFile = defaultAudio;
        lblFile.Text = ['✅ ' selectedFile];
        lblFile.FontColor = [0.4 0.85 0.5];
    end

    % Auto-apply Podcast preset: [-6 -2 4 6 4 2 -2]
    podcastGains = [-6 -2 4 6 4 2 -2];
    for k = 1:7
        sliders(k).Value = podcastGains(k);
        updateSliderLabel(k, podcastGains(k));
    end

    lblStatus.Text = '✅ Ready! Podcast preset + test_speech.wav loaded. Press RUN or tweak settings first.';
    lblStatus.FontColor = [0.4 0.85 0.5];

    % ========== CALLBACKS ==========

    function browseFile(~, ~)
        [f, p] = uigetfile({'*.wav;*.mp3;*.flac;*.m4a','Audio Files'; '*.*','All Files'}, ...
            'Select Audio File', scriptDir);
        if f ~= 0
            selectedFile = fullfile(p, f);
            lblFile.Text = ['✅ ' selectedFile];
            lblFile.FontColor = [0.4 0.85 0.5];
        end
    end

    function clearFile(~, ~)
        selectedFile = '';
        lblFile.Text = 'No file selected — will use test signal';
        lblFile.FontColor = [0.6 0.6 0.7];
    end

    function filterTypeChanged(~, ~)
        if strcmp(ddFilter.Value, 'FIR')
            ddWindow.Items = {'Hamming', 'Hanning', 'Blackman'};
            ddWindow.Value = 'Hamming';
            spnOrder.Value = 100;
        else
            ddWindow.Items = {'Butterworth', 'Chebyshev I', 'Chebyshev II'};
            ddWindow.Value = 'Butterworth';
            spnOrder.Value = 4;
        end
    end

    function applyPreset(gains)
        for k = 1:min(7, length(gains))
            sliders(k).Value = gains(k);
            updateSliderLabel(k, gains(k));
        end
    end

    function updateSliderLabel(idx, val)
        if val > 0
            sliderValues(idx).Text = sprintf('+%.0f dB', val);
            sliderValues(idx).FontColor = [0.4 0.85 0.5];
        elseif val < 0
            sliderValues(idx).Text = sprintf('%.0f dB', val);
            sliderValues(idx).FontColor = [0.95 0.4 0.4];
        else
            sliderValues(idx).Text = '0 dB';
            sliderValues(idx).FontColor = [0.6 0.6 0.7];
        end
    end

    function cfg = buildConfig()
        cfg.audioFile   = selectedFile;
        cfg.mode        = 1;
        cfg.bands       = presetBands;
        cfg.bnames      = presetNames;
        cfg.gains_db    = arrayfun(@(s) round(s.Value), sliders);

        if strcmp(ddFilter.Value, 'FIR')
            cfg.filterType  = 1;
            winMap = containers.Map({'Hamming','Hanning','Blackman'}, {1,2,3});
            cfg.windowType  = winMap(ddWindow.Value);
            cfg.iirMethod   = 1;
        else
            cfg.filterType  = 2;
            cfg.windowType  = 1;
            iirMap = containers.Map({'Butterworth','Chebyshev I','Chebyshev II'}, {1,2,3});
            cfg.iirMethod   = iirMap(ddWindow.Value);
        end

        cfg.filterOrder = spnOrder.Value;

        fsVal = ddFs.Value;
        if strcmp(fsVal, 'Same as input')
            cfg.fs_out = 0;
        else
            cfg.fs_out = str2double(fsVal);
        end
    end

    function applyConfig(cfg)
        % Apply a saved config to the UI
        if ~isempty(cfg.audioFile) && isfile(cfg.audioFile)
            selectedFile = cfg.audioFile;
            lblFile.Text = ['✅ ' selectedFile];
            lblFile.FontColor = [0.4 0.85 0.5];
        else
            clearFile();
        end

        if cfg.filterType == 1
            ddFilter.Value = 'FIR';
            filterTypeChanged();
            wnames = {'Hamming','Hanning','Blackman'};
            ddWindow.Value = wnames{cfg.windowType};
        else
            ddFilter.Value = 'IIR';
            filterTypeChanged();
            mnames = {'Butterworth','Chebyshev I','Chebyshev II'};
            ddWindow.Value = mnames{cfg.iirMethod};
        end

        spnOrder.Value = cfg.filterOrder;

        if cfg.fs_out == 0
            ddFs.Value = 'Same as input';
        else
            ddFs.Value = num2str(cfg.fs_out);
        end

        for k = 1:min(7, length(cfg.gains_db))
            sliders(k).Value = cfg.gains_db(k);
            updateSliderLabel(k, cfg.gains_db(k));
        end
    end

    function runEqualizer(~, ~)
        cfg = buildConfig();
        lblStatus.Text = '⏳ Processing... please wait.';
        lblStatus.FontColor = [1 0.8 0.2];
        drawnow;

        try
            run_equalizer(cfg);

            % Auto-save history
            save(histFile, 'cfg');

            lblStatus.Text = '✅ Done! Figures and audio saved. Click "View Results" to see them.';
            lblStatus.FontColor = [0.4 0.85 0.5];

            % Ask to open results
            answer = uiconfirm(fig, 'Processing complete! Open results page?', ...
                'Success', 'Options', {'Open Results','Close'}, ...
                'DefaultOption', 'Open Results', ...
                'Icon', 'success');
            if strcmp(answer, 'Open Results')
                openResults();
            end
        catch ME
            lblStatus.Text = ['❌ Error: ' ME.message];
            lblStatus.FontColor = [0.95 0.35 0.35];
        end
    end

    function openResults(~, ~)
        htmlPath = fullfile(scriptDir, 'web', 'index.html');
        if isfile(htmlPath)
            web(['file:///' strrep(htmlPath, '\', '/')], '-browser');
        else
            uialert(fig, 'web/index.html not found!', 'Error');
        end
    end

    function saveHistory(~, ~)
        cfg = buildConfig();
        save(histFile, 'cfg');
        lblStatus.Text = '💾 Config saved to run_history.mat';
        lblStatus.FontColor = [0.5 0.7 1.0];
    end

    function loadHistory(~, ~)
        if isfile(histFile)
            data = load(histFile, 'cfg');
            applyConfig(data.cfg);
            lblStatus.Text = '🕐 Loaded last run config — sliders updated!';
            lblStatus.FontColor = [0.5 0.7 1.0];
        else
            lblStatus.Text = '⚠️ No history found. Run the equalizer at least once first.';
            lblStatus.FontColor = [1 0.8 0.2];
        end
    end

end
