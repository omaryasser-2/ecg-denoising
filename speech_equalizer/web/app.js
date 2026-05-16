/* ===== Speech Equalizer Showcase — App Logic ===== */
(function () {
    'use strict';

    // Figure data
    const figures = [
        { file: 'fig01_all_magnitudes.png', caption: 'Combined magnitude response of all 7 frequency bands (FIR Hamming filter)' },
        { file: 'fig02_all_phases.png', caption: 'Phase response of all 7 frequency bands showing group delay characteristics' },
        { file: 'fig03_band_0_100.png', caption: 'Band 1 (0–100 Hz): Lowpass filter — magnitude, phase, impulse, step, pole-zero' },
        { file: 'fig04_band_100_300.png', caption: 'Band 2 (100–300 Hz): Bandpass filter — low-mid frequency warmth' },
        { file: 'fig05_band_300_800.png', caption: 'Band 3 (300–800 Hz): Bandpass filter — mid-range body and clarity' },
        { file: 'fig06_band_800_2k.png', caption: 'Band 4 (800–2000 Hz): Bandpass filter — upper-mid presence' },
        { file: 'fig07_band_2k_5k.png', caption: 'Band 5 (2k–5k Hz): Bandpass filter — speech clarity range' },
        { file: 'fig08_band_5k_10k.png', caption: 'Band 6 (5k–10k Hz): Bandpass filter — brilliance and sibilance' },
        { file: 'fig09_band_10k_20k.png', caption: 'Band 7 (10k–20k Hz): Highpass filter — air and sparkle' },
        { file: 'fig10_time_compare.png', caption: 'Time-domain comparison: original vs equalized signal' },
        { file: 'fig11_freq_compare.png', caption: 'Frequency spectrum comparison: original vs equalized (FFT)' },
        { file: 'fig12_psd.png', caption: 'Power Spectral Density comparison using Welch method' },
        { file: 'fig13_spectrogram.png', caption: 'Spectrogram comparison: time-frequency view of original vs equalized' },
        { file: 'fig14_fir_vs_iir.png', caption: 'FIR (Hamming) vs IIR (Butterworth) filter output comparison' },
        { file: 'fig15_sample_rate.png', caption: 'Sample rate demonstration: original, 4× upsampled, ½ downsampled' }
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

        // Scroll active tab into view
        tabs[currentFig].scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
    }

    // Tab clicks
    tabs.forEach(tab => {
        tab.addEventListener('click', () => showFigure(parseInt(tab.dataset.tab)));
    });

    // Nav buttons
    document.getElementById('prev-fig').addEventListener('click', () => showFigure(currentFig - 1));
    document.getElementById('next-fig').addEventListener('click', () => showFigure(currentFig + 1));

    // Keyboard nav
    document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowLeft') showFigure(currentFig - 1);
        if (e.key === 'ArrowRight') showFigure(currentFig + 1);
    });

    // Load MATLAB code
    fetch('../speech_equalizer.m')
        .then(r => r.ok ? r.text() : Promise.reject('Failed to load'))
        .then(code => {
            document.getElementById('matlab-code').textContent = code;
        })
        .catch(() => {
            document.getElementById('matlab-code').textContent = '% Could not load speech_equalizer.m\n% Make sure the file exists in the parent directory.';
        });

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

    // Animate sections on scroll
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

    // Init
    showFigure(0);
})();
