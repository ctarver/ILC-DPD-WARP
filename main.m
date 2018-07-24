clear; clc; close all;
%% Setup Everything
% Add the submodules to path
addpath(genpath('OFDM-Matlab'))
addpath(genpath('WARPLab-Matlab-Wrapper'))
addpath(genpath('Power-Amplifier-Model'))

use_warp = 0;

nIterations = 60;
Fs = 40e6;

%type = 'instantaneous_gain';  % Conditioning gets bad!
type = 'linear';

% Create OFDM Signal
ofdm_params.nSubcarriers = 600;
ofdm_params.subcarrier_spacing = 15e3; % 15kHz subcarrier spacing
ofdm_params.constellation = 'QPSK';
ofdm_params.cp_length = 140; % Number of samples in cyclic prefix.
ofdm_params.nSymbols = 20;
modulator = OFDM(ofdm_params);
tx_data = modulator.use;
upsampled_tx_data = up_sample(tx_data, modulator.sampling_rate);

% Desired PA Output
y_d = normalize_for_pa(upsampled_tx_data, 0.25);

% Set up WARP
if use_warp
    warp_params.nBoards = 1;         % Number of boards
    warp_params.RF_port  = 'A2B';    % Broadcast from RF A to RF B. Can also do 'B2A'
    board = WARP(warp_params);
else
    board = PowerAmplifier(7, 4);
end

%% Main Learning Algorithm
u_k = y_d; % Initial guess at tx signal.
plot_results('psd', 'Original', u_k, Fs);

for k = 1:nIterations
    y_k = board.transmit(u_k);
    if k == 1
        plot_results('psd', 'No DPD', y_k, Fs);
    end
    
    e_k = y_d - y_k;
    test(k)= norm(e_k);
    
    switch type
        case 'instantaneous_gain'
            learning_matrix = diag(y_k./u_k);
            u_k = u_k + learning_matrix \ e_k;
        case 'linear'
            u_k = u_k + 0.1 * e_k;
    end
end
figure
plot(test);
ylabel('Error Magnitude')
xlabel('Iteration')

plot_results('psd', 'ILC Final', y_k, Fs);

%% Figure out the DPD

% Use the PA class as a Predistorter.
order = 7;          % Order must be odd
memory_depth = 4;
dpd = PowerAmplifier(order, memory_depth);

dpd = dpd.make_pa_model(y_d, u_k); % What is the PH model that gets us to the ideal PA input signal?

%% Make a new signal and send through DPD
modulator = OFDM(ofdm_params);
tx_data = modulator.use;
upsampled_tx_data = up_sample(tx_data, modulator.sampling_rate);
dpd_input = normalize_for_pa(upsampled_tx_data, 0.2);
dpd_ouput = dpd.transmit(dpd_input);

with_dpd = board.transmit(dpd_ouput);

plot_results('psd', 'w/DPD', with_dpd, Fs);

%% Some helper functions
function out = up_sample(in, sampling_rate)
upsample_rate = floor(40e6/sampling_rate);
up = upsample(in, upsample_rate);
b = firls(255,[0 (1/upsample_rate -0.02) (1/upsample_rate +0.02) 1],[1 1 0 0]);
out = filter(b,1,up);
%beta = 0.25;
%upsample_span = 60;
%sps = upsample_rate;
%upsample_rrcFilter = rcosdesign(beta, upsample_span, sps);
%out = upfirdn(in, upsample_rrcFilter, upsample_rate);
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