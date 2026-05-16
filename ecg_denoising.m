%% ECG Signal Denoising for Telemedicine Applications
% DSP Project - MIT-BIH Arrhythmia Database (Records 100 & 106)
% Filters: FIR Hamming, IIR Butterworth, IIR Chebyshev Type II
%
% ECG Signal: fs=360Hz, useful BW=0.5-100Hz, 11-bit/10mV
% Noise: baseline wander (<0.5Hz), 50Hz powerline, EMG (20-150Hz)
%
% Filter Specs:
%   HP:    cutoff=0.5Hz, PB ripple<=1dB, SB atten>=40dB
%   Notch: 50Hz center, PB ripple<=0.5dB, SB atten>=30dB
%   LP:    cutoff=100Hz, PB ripple<=1dB, SB atten>=40dB
%
% Constraints: FIR ~500 taps max, IIR ~6th order max
%   FIR = linear phase | IIR = use filtfilt for zero-phase
clc; clear; close all;

%% Configuration
fs = 360; T = 10; N_seg = T * fs;
scriptDir = fileparts(mfilename('fullpath'));
figDir = fullfile(scriptDir, 'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end
Nfft = 4096;

%% Load ECG Data
[sig100,~,~] = rdsamp('100',[],N_seg); ecg100=sig100(:,1); t100=(0:length(ecg100)-1)/fs;
[sig106,~,~] = rdsamp('106',[],N_seg); ecg106=sig106(:,1); t106=(0:length(ecg106)-1)/fs;

%% Filter Design
% --- FIR (Hamming Window) ---
N_hp_fir=500; b_fir_hp=fir1(N_hp_fir,0.5/(fs/2),'high',hamming(N_hp_fir+1)); a_fir_hp=1;
N_notch_fir=500; b_fir_notch=fir1(N_notch_fir,[48 52]/(fs/2),'stop',hamming(N_notch_fir+1)); a_fir_notch=1;
N_lp_fir=100; b_fir_lp=fir1(N_lp_fir,100/(fs/2),'low',hamming(N_lp_fir+1)); a_fir_lp=1;

% --- IIR Butterworth ---
[b_but_hp,a_but_hp]=butter(4,0.5/(fs/2),'high');
w0=50/(fs/2); bw=w0/30; [b_but_notch,a_but_notch]=iirnotch(w0,bw);
[b_but_lp,a_but_lp]=butter(4,100/(fs/2),'low');

% --- IIR Chebyshev Type II ---
[b_ch2_hp,a_ch2_hp]=cheby2(4,40,0.5/(fs/2),'high');
[b_ch2_notch,a_ch2_notch]=iirnotch(w0,bw);
[b_ch2_lp,a_ch2_lp]=cheby2(4,40,100/(fs/2),'low');

% Cell arrays for looping
b_fir_all={b_fir_hp,b_fir_notch,b_fir_lp}; a_fir_all={a_fir_hp,a_fir_notch,a_fir_lp};
b_but_all={b_but_hp,b_but_notch,b_but_lp}; a_but_all={a_but_hp,a_but_notch,a_but_lp};
b_ch2_all={b_ch2_hp,b_ch2_notch,b_ch2_lp}; a_ch2_all={a_ch2_hp,a_ch2_notch,a_ch2_lp};
fnames={'HP (Baseline)','Notch (50Hz)','LP (EMG)'};
xlims={[0 5],[30 70],[0 fs/2]};

%% Apply Filters to Record 100
ecg=ecg100; t=t100;

% FIR cascade
ecg_fir=filter(b_fir_hp,1,ecg);
ecg_fir=filter(b_fir_notch,1,ecg_fir);
ecg_fir=filter(b_fir_lp,1,ecg_fir);
total_delay=(N_hp_fir+N_notch_fir+N_lp_fir)/2;

% Butterworth cascade (zero-phase)
ecg_but=filtfilt(b_but_hp,a_but_hp,ecg);
ecg_but=filtfilt(b_but_notch,a_but_notch,ecg_but);
ecg_but=filtfilt(b_but_lp,a_but_lp,ecg_but);

% Chebyshev II cascade (zero-phase)
ecg_ch2=filtfilt(b_ch2_hp,a_ch2_hp,ecg);
ecg_ch2=filtfilt(b_ch2_notch,a_ch2_notch,ecg_ch2);
ecg_ch2=filtfilt(b_ch2_lp,a_ch2_lp,ecg_ch2);

% PSD (Welch) & SNR
nw=1024;
[pxx_raw,f_psd]=pwelch(ecg,hamming(nw),nw/2,nw,fs);
[pxx_fir,~]=pwelch(ecg_fir,hamming(nw),nw/2,nw,fs);
[pxx_but,~]=pwelch(ecg_but,hamming(nw),nw/2,nw,fs);
[pxx_ch2,~]=pwelch(ecg_ch2,hamming(nw),nw/2,nw,fs);

sb=f_psd>=0.5&f_psd<=40; nb=(f_psd<0.5)|(f_psd>=49&f_psd<=51)|(f_psd>100);
snr_raw=10*log10(sum(pxx_raw(sb))/(sum(pxx_raw(nb))+eps));
snr_fir=10*log10(sum(pxx_fir(sb))/(sum(pxx_fir(nb))+eps));
snr_but=10*log10(sum(pxx_but(sb))/(sum(pxx_but(nb))+eps));
snr_ch2=10*log10(sum(pxx_ch2(sb))/(sum(pxx_ch2(nb))+eps));

% Record 106 filtering
ecg106_but=filtfilt(b_but_hp,a_but_hp,ecg106);
ecg106_but=filtfilt(b_but_notch,a_but_notch,ecg106_but);
ecg106_but=filtfilt(b_but_lp,a_but_lp,ecg106_but);

%% ==================== TABBED FIGURE VIEWER ====================
fig = figure('Name','ECG Denoising Results','Position',[50 50 1400 850],...
    'NumberTitle','off','Color','w');
tg = uitabgroup(fig);

% ---- Tab 1: Raw ECG ----
tab=uitab(tg,'Title','Raw ECG');
ax=tsubplot(tab,2,1,1); plot(ax,t100,ecg100,'b'); grid(ax,'on');
title(ax,'Record 100 - Normal Sinus Rhythm'); xlabel(ax,'Time(s)'); ylabel(ax,'mV');
ax=tsubplot(tab,2,1,2); plot(ax,t106,ecg106,'r'); grid(ax,'on');
title(ax,'Record 106 - Ventricular Ectopic Beats'); xlabel(ax,'Time(s)'); ylabel(ax,'mV');

% ---- Tabs 2-4: Magnitude & Phase ----
colors = {'b','r',[0.1 0.7 0.3]};
setnames = {'FIR (Hamming)','Butterworth','Chebyshev II'};
ball={b_fir_all,b_but_all,b_ch2_all}; aall={a_fir_all,a_but_all,a_ch2_all};
for s=1:3
    tab=uitab(tg,'Title',[setnames{s},' Freq']);
    for k=1:3
        [H,f]=freqz(ball{s}{k},aall{s}{k},Nfft,fs);
        ax=tsubplot(tab,3,2,2*k-1);
        plot(ax,f,20*log10(abs(H)+eps),'Color',colors{s},'LineWidth',1.2); grid(ax,'on');
        title(ax,[fnames{k},' - Magnitude']); xlabel(ax,'Hz'); ylabel(ax,'dB'); xlim(ax,xlims{k});
        ax=tsubplot(tab,3,2,2*k);
        plot(ax,f,unwrap(angle(H))*180/pi,'Color',colors{s},'LineWidth',1.2); grid(ax,'on');
        title(ax,[fnames{k},' - Phase']); xlabel(ax,'Hz'); ylabel(ax,'Deg'); xlim(ax,xlims{k});
    end
end

% ---- Tabs 5-7: Impulse & Step ----
imp_len=300; imp=[1;zeros(imp_len-1,1)]; stp=ones(imp_len,1); t_imp=(0:imp_len-1)/fs;
for s=1:3
    tab=uitab(tg,'Title',[setnames{s},' Imp/Step']);
    for k=1:3
        h_i=filter(ball{s}{k},aall{s}{k},imp);
        h_s=filter(ball{s}{k},aall{s}{k},stp);
        ax=tsubplot(tab,3,2,2*k-1);
        stem(ax,t_imp,h_i,'Color',colors{s},'MarkerSize',2); grid(ax,'on');
        title(ax,[fnames{k},' - Impulse']); xlabel(ax,'Time(s)');
        ax=tsubplot(tab,3,2,2*k);
        plot(ax,t_imp,h_s,'Color',colors{s},'LineWidth',1.2); grid(ax,'on');
        title(ax,[fnames{k},' - Step']); xlabel(ax,'Time(s)');
    end
end

% ---- Tabs 8-10: Pole-Zero ----
for s=1:3
    tab=uitab(tg,'Title',[setnames{s},' P/Z']);
    for k=1:3
        ax=tsubplot(tab,1,3,k);
        axes(ax); %#ok<LAXES>
        zplane(ball{s}{k},aall{s}{k});
        title(ax,fnames{k}); grid(ax,'on');
    end
end

% ---- Tab 11: Filtered vs Raw ----
tab=uitab(tg,'Title','Filtered vs Raw');
win=1*fs:5*fs;
ax=tsubplot(tab,4,1,1); plot(ax,t(win),ecg(win),'k'); grid(ax,'on');
title(ax,'Original'); ylabel(ax,'mV');
ax=tsubplot(tab,4,1,2); plot(ax,t(win),ecg_fir(win),'b'); grid(ax,'on');
title(ax,'FIR'); ylabel(ax,'mV');
ax=tsubplot(tab,4,1,3); plot(ax,t(win),ecg_but(win),'r'); grid(ax,'on');
title(ax,'Butterworth'); ylabel(ax,'mV');
ax=tsubplot(tab,4,1,4); plot(ax,t(win),ecg_ch2(win),'Color',[0.1 0.7 0.3]); grid(ax,'on');
title(ax,'Chebyshev II'); ylabel(ax,'mV'); xlabel(ax,'Time(s)');

% ---- Tab 12: QRS Zoom ----
tab=uitab(tg,'Title','QRS Zoom');
qw=round(1.5*fs):round(3.5*fs);
ax=tsubplot(tab,2,1,1);
plot(ax,t(qw),ecg(qw),'k','LineWidth',1.2); hold(ax,'on');
plot(ax,t(qw),ecg_but(qw),'r--','LineWidth',1.2);
plot(ax,t(qw),ecg_ch2(qw),'g-.','LineWidth',1.2);
legend(ax,'Original','Butterworth','Chebyshev II'); grid(ax,'on');
title(ax,'QRS Preservation (IIR)'); ylabel(ax,'mV');
ax=tsubplot(tab,2,1,2);
plot(ax,t(qw),ecg(qw),'k','LineWidth',1.2); hold(ax,'on');
plot(ax,t(qw),ecg_fir(qw),'b--','LineWidth',1.2);
legend(ax,'Original','FIR'); grid(ax,'on');
title(ax,'QRS - FIR (note delay)'); xlabel(ax,'Time(s)'); ylabel(ax,'mV');

% ---- Tab 13: PSD ----
tab=uitab(tg,'Title','PSD (Welch)');
ax=tsubplot(tab,1,2,1);
plot(ax,f_psd,10*log10(pxx_raw),'k','LineWidth',1.2); hold(ax,'on');
plot(ax,f_psd,10*log10(pxx_but),'r','LineWidth',1.2);
plot(ax,f_psd,10*log10(pxx_ch2),'g','LineWidth',1.2);
legend(ax,'Raw','Butterworth','Chebyshev II'); grid(ax,'on');
title(ax,'PSD - IIR vs Raw'); xlabel(ax,'Hz'); ylabel(ax,'dB/Hz');
ax=tsubplot(tab,1,2,2);
plot(ax,f_psd,10*log10(pxx_raw),'k','LineWidth',1.2); hold(ax,'on');
plot(ax,f_psd,10*log10(pxx_fir),'b','LineWidth',1.2);
legend(ax,'Raw','FIR'); grid(ax,'on');
title(ax,'PSD - FIR vs Raw'); xlabel(ax,'Hz'); ylabel(ax,'dB/Hz');

% ---- Tab 14: Spectrogram ----
tab=uitab(tg,'Title','Spectrogram');
wsp=hamming(256); nov=200; nsp=512;
ax=tsubplot(tab,2,2,1); axes(ax); spectrogram(ecg,wsp,nov,nsp,fs,'yaxis');
title('Raw'); colorbar; ylim([0 100]);
ax=tsubplot(tab,2,2,2); axes(ax); spectrogram(ecg_but,wsp,nov,nsp,fs,'yaxis');
title('Butterworth'); colorbar; ylim([0 100]);
ax=tsubplot(tab,2,2,3); axes(ax); spectrogram(ecg_fir,wsp,nov,nsp,fs,'yaxis');
title('FIR'); colorbar; ylim([0 100]);
ax=tsubplot(tab,2,2,4); axes(ax); spectrogram(ecg_ch2,wsp,nov,nsp,fs,'yaxis');
title('Chebyshev II'); colorbar; ylim([0 100]);

% ---- Tab 15: SNR ----
tab=uitab(tg,'Title','SNR');
ax=tsubplot(tab,1,1,1);
bh=bar(ax,[snr_raw,snr_fir,snr_but,snr_ch2]);
bh.FaceColor='flat';
bh.CData=[0.5 0.5 0.5;0 0 1;1 0 0;0.1 0.7 0.3];
set(ax,'XTickLabel',{'Raw','FIR','Butterworth','Chebyshev II'});
ylabel(ax,'SNR (dB)'); title(ax,'SNR Comparison'); grid(ax,'on');

% ---- Tab 16: Record 106 ----
tab=uitab(tg,'Title','Record 106');
w6=1*fs:6*fs;
ax=tsubplot(tab,2,1,1); plot(ax,t106(w6),ecg106(w6),'k'); grid(ax,'on');
title(ax,'Record 106 - Raw (PVCs)'); ylabel(ax,'mV');
ax=tsubplot(tab,2,1,2); plot(ax,t106(w6),ecg106_but(w6),'r'); grid(ax,'on');
title(ax,'After Butterworth Filtering'); ylabel(ax,'mV'); xlabel(ax,'Time(s)');

%% Save each tab as individual PNG
tabnames = {'fig01_raw_ecg','fig02_fir_mag_phase','fig03_butter_mag_phase',...
    'fig04_cheby2_mag_phase','fig05_fir_impulse_step','fig06_butter_impulse_step',...
    'fig07_cheby2_impulse_step','fig08_fir_polezero','fig09_butter_polezero',...
    'fig10_cheby2_polezero','fig11_filtered_vs_raw','fig12_qrs_zoom',...
    'fig13_psd_comparison','fig14_spectrogram','fig15_snr_comparison','fig16_record106'};
tabs = tg.Children;
for i = 1:length(tabs)
    tg.SelectedTab = tabs(i);
    drawnow;
    exportgraphics(tabs(i), fullfile(figDir,[tabnames{i},'.png']), 'Resolution',150, 'BackgroundColor','none');
end

%% Helper: subplot inside a uitab
function ax = tsubplot(parent, m, n, p)
    col = mod(p-1, n) + 1;
    row = ceil(p / n);
    gap_x = 0.08; gap_y = 0.08;
    margin_l = 0.06; margin_b = 0.06;
    w = (1 - margin_l - gap_x*(n-1) - 0.02) / n;
    h = (1 - margin_b - gap_y*(m-1) - 0.04) / m;
    left = margin_l + (col-1)*(w + gap_x);
    bot = 1 - 0.03 - row*h - (row-1)*gap_y;
    ax = axes('Parent', parent, 'Position', [left bot w h]);
end
