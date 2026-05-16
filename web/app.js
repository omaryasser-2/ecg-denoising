/* ===== ECG Denoising Showcase — App Logic ===== */
(function () {
    'use strict';

    const figures = [
        { file: 'fig01_raw_ecg.png', caption: 'Raw ECG signals — Record 100 (Normal Sinus Rhythm) and Record 106 (Ventricular Ectopic Beats)' },
        { file: 'fig02_fir_mag_phase.png', caption: 'FIR Hamming filter — Magnitude and Phase response for HP, Notch, and LP stages' },
        { file: 'fig03_butter_mag_phase.png', caption: 'Butterworth IIR filter — Magnitude and Phase response for all 3 stages' },
        { file: 'fig04_cheby2_mag_phase.png', caption: 'Chebyshev Type II filter — Magnitude and Phase response for all 3 stages' },
        { file: 'fig05_fir_impulse_step.png', caption: 'FIR filter — Impulse and Step response for HP, Notch, and LP' },
        { file: 'fig06_butter_impulse_step.png', caption: 'Butterworth filter — Impulse and Step response' },
        { file: 'fig07_cheby2_impulse_step.png', caption: 'Chebyshev II filter — Impulse and Step response' },
        { file: 'fig08_fir_polezero.png', caption: 'FIR filter — Pole-Zero plots for HP, Notch, LP (all zeros on unit circle)' },
        { file: 'fig09_butter_polezero.png', caption: 'Butterworth filter — Pole-Zero plots (poles inside unit circle = stable)' },
        { file: 'fig10_cheby2_polezero.png', caption: 'Chebyshev II filter — Pole-Zero plots showing zeros in stopband' },
        { file: 'fig11_filtered_vs_raw.png', caption: 'Filtered vs Raw ECG — comparing all 3 filter outputs against original' },
        { file: 'fig12_qrs_zoom.png', caption: 'QRS Complex preservation — zoomed view showing morphology retention after filtering' },
        { file: 'fig13_psd_comparison.png', caption: 'Power Spectral Density (Welch) — noise reduction in frequency domain' },
        { file: 'fig14_spectrogram.png', caption: 'Spectrogram — time-frequency analysis showing noise removal across all filters' },
        { file: 'fig15_snr_comparison.png', caption: 'SNR comparison — quantitative improvement: Raw vs FIR vs Butterworth vs Chebyshev II' },
        { file: 'fig16_record106.png', caption: 'Record 106 — Raw vs Butterworth filtered, preserving PVC morphology' }
    ];

    let currentFig = 0;
    const img = document.getElementById('figure-img');
    const caption = document.getElementById('figure-caption');
    const counter = document.getElementById('fig-counter');
    const tabs = document.querySelectorAll('.tab');

    function showFigure(index) {
        currentFig = ((index % figures.length) + figures.length) % figures.length;
        img.classList.add('loading');
        img.onload = () => img.classList.remove('loading');
        img.src = '../figures/' + figures[currentFig].file;
        img.alt = figures[currentFig].caption;
        caption.textContent = figures[currentFig].caption;
        counter.textContent = (currentFig + 1) + ' / ' + figures.length;

        tabs.forEach(t => t.classList.remove('active'));
        tabs[currentFig].classList.add('active');
        tabs[currentFig].scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }

    tabs.forEach(tab => {
        tab.addEventListener('click', () => showFigure(parseInt(tab.dataset.tab)));
    });

    document.getElementById('prev-fig').addEventListener('click', () => showFigure(currentFig - 1));
    document.getElementById('next-fig').addEventListener('click', () => showFigure(currentFig + 1));

    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowLeft') showFigure(currentFig - 1);
        if (e.key === 'ArrowRight') showFigure(currentFig + 1);
    });

    // Load MATLAB code — XMLHttpRequest works from file:// protocol
    function loadMatlabCode() {
        try {
            const xhr = new XMLHttpRequest();
            xhr.open('GET', '../ecg_denoising.m', true);
            xhr.onload = function () {
                if (xhr.status === 200 || xhr.status === 0) {
                    document.getElementById('matlab-code').textContent = xhr.responseText;
                } else {
                    showCodeFallback();
                }
            };
            xhr.onerror = function () { showCodeFallback(); };
            xhr.send();
        } catch (e) {
            showCodeFallback();
        }
    }
    function showCodeFallback() {
        document.getElementById('matlab-code').textContent =
            '% To view the full code here, open via local server:\n' +
            '% cd web && python -m http.server 8080\n' +
            '% Then open http://localhost:8080\n\n' +
            '% Or open ecg_denoising.m directly in MATLAB / VS Code.';
    }
    loadMatlabCode();

    // Copy button
    const copyBtn = document.getElementById('copy-code');
    copyBtn.addEventListener('click', () => {
        const code = document.getElementById('matlab-code').textContent;
        navigator.clipboard.writeText(code).then(() => {
            copyBtn.innerHTML = '<i class="fas fa-check"></i> Copied!';
            copyBtn.classList.add('copied');
            setTimeout(() => {
                copyBtn.innerHTML = '<i class="fas fa-copy"></i> Copy';
                copyBtn.classList.remove('copied');
            }, 2000);
        });
    });

    // Scroll animation
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.style.opacity = '1';
                entry.target.style.transform = 'translateY(0)';
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('.section').forEach(sec => {
        sec.style.opacity = '0';
        sec.style.transform = 'translateY(30px)';
        sec.style.transition = 'opacity 0.6s ease, transform 0.6s ease';
        observer.observe(sec);
    });

    showFigure(0);
})();
