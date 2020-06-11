function EA_script_ana_phase(EA_results)
%EA_SCRIPT_ANA_PHASE - Plot phase Bode plots from ElectroAbsorbance (EA)
% in a range of background light intensities or applied DC voltages
% This script is very similar to IS_script_ana_phase
% Plots the first and second harmonic phase shift with regards to the
% applied voltage.
%
% Syntax:  EA_script_ana_phase(EA_results)
%
% Inputs:
%   EA_RESULTS - a struct containing the most important results of the EA simulation
%
% Example:
%   EA_script_ana_phase(EA_results)
%     do plot
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also EA_script, IS_script_ana_phase, EA_script_ana_Efield.

% Author: Ilario Gelmetti, Ph.D. student, perovskite photovoltaics
% Institute of Chemical Research of Catalonia (ICIQ)
% Research Group Prof. Emilio Palomares
% email address: iochesonome@gmail.com
% Supervised by: Dr. Phil Calado, Dr. Piers Barnes, Prof. Jenny Nelson
% Imperial College London
% October 2017; Last revision: March 2018

%------------- BEGIN CODE --------------

% check which was the variable being explored
if numel(unique(EA_results.Int)) > 1
    legend_text = EA_results.Int;
    legend_append = ' sun';
else
    legend_text = EA_results.Vdc;
    legend_append = ' Vdc';
end

% create a color array with one color more than necessary
jet_matrix = jet(length(legend_text) + 1);
% find the yellow (which in RGB code is 1,1,0) and remove it from the
% colors list
jet_yellow_logical = ismember(jet_matrix, [1, 1, 0], 'rows');
jet_no_yellow = jet_matrix(~jet_yellow_logical, :);
Int_colors = colormap(jet_no_yellow);

% round to two significant digits
legend_flip = round(legend_text, 2, 'significant');
% flip array and matrixes for starting from dark
legend_flip = string(flipud(legend_flip));
% add sun to numbers in legend
legend_flip = strcat(legend_flip, legend_append);
% replace zero in legend with dark
legend_flip(legend_flip=="0 sun") = "dark";

% preallocate figures handles
h = zeros(length(legend_text), 1);

% in case just a single frequency was simulated, min and max are
% coincident, so they are modified by a small percentage
xlim_array = [min(min(EA_results.Freq))*0.99, max(max(EA_results.Freq)*1.01)];

%% do EA first and second harmonic phase plots

phase_n_deg = rad2deg(wrapTo2Pi(EA_results.AC_ExDC_E_phase));
phase_i_deg = rad2deg(wrapTo2Pi(EA_results.AC_ExDC_E_i_phase));
figure('Name', 'Phase plot of EA first harmonic', 'NumberTitle', 'off')
    hold off
    for i = 1:length(legend_text)
        h(i) = plot(EA_results.Freq(i, :), phase_n_deg(i, :)',...
            'Color', Int_colors(i, :), 'MarkerEdgeColor', Int_colors(i, :),...
            'MarkerFaceColor', Int_colors(i, :), 'Marker', 's',...
            'MarkerSize', 3, 'LineWidth', 1.3);
        hold on
        plot(EA_results.Freq(i, :), phase_i_deg(i, :)', 'Color', Int_colors(i, :), 'LineStyle', '--');
    end
    ax = gca;
    ax.XScale = 'log'; % for putting the scale in log
    xlim(xlim_array)
    xlabel('Frequency [Hz]');
    ylabel('Phase [deg]');
    legend(flipud(h), legend_flip)
    legend boxoff

phase_2h_deg = rad2deg(wrapTo2Pi(EA_results.AC_Efield2_phase));
phase_2h_i_deg = rad2deg(wrapTo2Pi(EA_results.AC_Efield2_i_phase));
figure('Name', 'Phase plot of EA second harmonic', 'NumberTitle', 'off')
    hold off
    for i = 1:length(legend_text)
        h(i) = plot(EA_results.Freq(i, :), phase_2h_deg(i, :)',...
            'Color', Int_colors(i, :), 'MarkerEdgeColor', Int_colors(i, :),...
            'MarkerFaceColor', Int_colors(i, :), 'Marker', 's',...
            'MarkerSize', 3, 'LineWidth', 1.3);
        hold on
        plot(EA_results.Freq(i, :), phase_2h_i_deg(i, :)', 'Color', Int_colors(i, :), 'LineStyle', '--');
    end
    ax = gca;
    ax.XScale = 'log'; % for putting the scale in log
    xlim(xlim_array)
    xlabel('Frequency [Hz]');
    ylabel('Phase [deg]');
    legend(flipud(h), legend_flip)
    legend boxoff

%------------- END OF CODE --------------