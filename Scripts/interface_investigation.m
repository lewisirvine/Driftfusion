%
%% LICENSE
% Copyright (C) 2020  Philip Calado, Ilario Gelmetti, and Piers R. F. Barnes
% Imperial College London
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as published
% by the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
%% Start code
% Initialise the system
initialise_df

%% Create a parameters object for Spiro/MAPI/TiO2 by including a filepath to the 
% appropriate .csv as the arugment to the parameters class PC
par = pc('Input_files/3_layer_test_vary.csv');

%% Ideal transport, no rec
par_ideal = par;
par_ideal.sn(2) = 1e-20;
par_ideal.sp(2) = 1e-20;
par_ideal.sn(4) = 1e-20;
par_ideal.sp(4) = 1e-20;
par_ideal.mue(2) = 1e3;
par_ideal.muh(2) = 1e3;
par_ideal.mue(4) = 1e3;
par_ideal.muh(4) = 1e3;
par_ideal = refresh_device(par_ideal);

soleq_ideal = equilibrate(par_ideal);

%sol_CV = doCV(sol_ini, light_intensity, V0, Vmax, Vmin, scan_rate, cycles, tpoints)
sol_CV_ideal = doCV(soleq_ideal.el, 1, 0, 1, 0, 100e-3, 1, 281);

%% With ions
sol_CV_ideal_ion = doCV(soleq_ideal.ion, 1, 0, 1, 0, 100e-3, 1, 281);

%% Poor transport, no rec
par_trans = par;
par_trans.sn(2) = 1e-20;
par_trans.sp(2) = 1e-20;
par_trans.sn(4) = 1e-20;
par_trans.sp(4) = 1e-20;
par_trans.mue(2) = 1e-4;
par_trans.muh(2) = 1e-4;
par_trans.mue(4) = 1e-4;
par_trans.muh(4) = 1e-4;
par_trans = refresh_device(par_trans);

soleq_trans = equilibrate(par_trans);

%sol_CV = doCV(sol_ini, light_intensity, V0, Vmax, Vmin, scan_rate, cycles, tpoints)
sol_CV_trans = doCV(soleq_trans.el, 1, 0, 1, 0, 100e-3, 1, 281);

%% With ions
sol_CV_trans_ion = doCV(soleq_trans.ion, 1, 0, 1, 0, 100e-3, 1, 281);

%% High rec
par_rec = par;
par_rec.r_constant = 0;  % Uniform rec rate within interfacial regions
par_rec.sn(2) = 1e7;      
par_rec.sp(2) = 1e3;
par_rec.sn(4) = 1e3;
par_rec.sp(4) = 1e7;
par_rec.mue(2) = 1e-4;
par_rec.muh(2) = 1e-4;
par_rec.mue(4) = 1e-4;
par_rec.muh(4) = 1e-4;
par_rec = refresh_device(par_rec);

soleq_rec = equilibrate(par_rec);

%sol_CV = doCV(sol_ini, light_intensity, V0, Vmax, Vmin, scan_rate, cycles, tpoints)
sol_CV_rec = doCV(soleq_rec.el, 1, 0, 1, 0, 100e-3, 1, 281);

dfplot.JtotVapp(sol_CV_rec,0)
hold off
ylim([-30e-3,10e-3])
%% With ions
sol_CV_rec_ion = doCV(soleq_rec.ion, 1, 0, 1, 0, 100e-3, 1, 281);

%% Comparison with analytical solutions
compare_carrier_interfaces_2(sol_CV_ideal, [0, 4, 8, 12]);
%%
compare_carrier_interfaces_2(sol_CV_trans, [0, 4, 8, 12]);
%%
compare_carrier_interfaces_2(sol_CV_rec, [0, 4, 8, 12]);

%% Comparison with analytical solutions
compare_carrier_interfaces_2(sol_CV_ideal_ion, [0, 4, 8, 12]);
%%
compare_carrier_interfaces_2(sol_CV_trans_ion, [0, 4, 8, 12]);
%%
compare_carrier_interfaces_2(sol_CV_rec_ion, [0, 4, 8, 12]);
% dfplot.JtotVapp(sol_CV_ideal,0)
% hold on
% dfplot.JtotVapp(sol_CV_trans,0)
% hold on
% dfplot.JtotVapp(sol_CV_rec,0)
% hold off
% ylim([-30e-3,10e-3])

% dfplot.npx(sol_CV_ideal,5)
% hold on
% dfplot.npx(sol_CV_trans,5)
% hold on
% dfplot.npx(sol_CV_rec,5)
% hold off

