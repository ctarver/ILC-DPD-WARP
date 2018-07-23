clear; clc; close all;
% Add the submodules to path
%addpath(genpath(OFDM-Matlab))
%addpath(genpath(WARPLab-Matlab-Wrapper))

nIterations =200;
Fs = 40e6;
type = 'instantaneous_gain';
type = 'linear';

% Create OFDM Signal
ofdm_params.nSubcarriers = 300;
ofdm_params.subcarrier_spacing = 15e3; % 15kHz subcarrier spacing
ofdm_params.constellation = 'QPSK';
ofdm_params.cp_length = 144; % Number of samples in cyclic prefix.
ofdm_params.nSymbols = 2;
modulator = OFDM(ofdm_params);
tx_data = modulator.use;
upsampled_tx_data = up_sample(tx_data, modulator.sampling_rate);

% Desired PA Output
y_d = normalize_for_pa(upsampled_tx_data, 0.2);

% Set up WARP
warp_params.nBoards = 1;         % Number of boards
warp_params.RF_port  = 'A2B';    % Broadcast from RF A to RF B. Can also do 'B2A'
board = WARP(warp_params);

u_k = y_d; % Initial guess at tx signal.
plot_results('psd', 'Original', u_k, Fs);

for i = 1:nIterations
    y_k = board.transmit(u_k);
    if i == 1
        plot_results('psd', 'No DPD', y_k, Fs);
    end
    
    e_k = y_d - y_k;
    switch type
        case 'instantaneous_gain'
            learning_matrix = diag(y_k./u_k);
            u_k = u_k + learning_matrix \ e_k;
        case 'linear'
            learning_matrix = 0.1 * eye(length(e_k));
            u_k = u_k + learning_matrix * e_k;
    end
end

plot_results('psd', 'ILC Final', y_k, Fs);

function out = up_sample(in, sampling_rate)
upsample_rate = floor(40e6/sampling_rate);
beta = 0.25;
upsample_span = 60;
sps = upsample_rate;
upsample_rrcFilter = rcosdesign(beta, upsample_span, sps);
out = upfirdn(in, upsample_rrcFilter, upsample_rate);
end

function [out, scale_factor] = normalize_for_pa(in, RMS_power)
scale_factor = RMS_power/rms(in);
out = in * scale_factor;
if abs(rms(out) - RMS_power) > 0.01
    error('RMS is wrong.');
end

max_real = max(abs(real(out)));
max_imag = max(abs(imag(out)));
max_max = max(max_real, max_imag);
fprintf('Maximum value: %1.2f\n', max_max);
end