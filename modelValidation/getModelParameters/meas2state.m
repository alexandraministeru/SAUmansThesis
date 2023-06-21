function [x] = meas2state(data, Trial, k)
%% Extract data
SACR = data(Trial).TargetData.SACR_pos_proc(k, 1:3);
LASI = data(Trial).TargetData.LASI_pos_proc(k, 1:3);
RASI = data(Trial).TargetData.RASI_pos_proc(k, 1:3);
COM = (SACR+LASI+RASI)./3; % COM estimate

LAC = data(Trial).TargetData.LAC_pos_proc(k, 1:3);
RAC = data(Trial).TargetData.RAC_pos_proc(k, 1:3);
CAC = (LAC+RAC)./2; % Center of shoulderblades

%% Body fixed frame
nBz = CAC-COM;
nBy = LASI-RASI;
nBx = cross(nBy, nBz);

nBz = nBz./vecnorm(nBz, 2, 2);
nBy = nBy./vecnorm(nBy, 2, 2);
nBx = nBx./vecnorm(nBx, 2, 2);

%% Quaternions
nRb = cat(3, nBx', nBy', nBz');
nRb = permute(nRb, [1 3 2]);
nqb = rotm2quat(nRb);

%% Differentiate
dCOM = diff(COM, 1, 1).*120;
dnqb = diff(nqb, 1, 1).*120;

%% Compile
x = [COM(1:end-1,:), dCOM, nqb(1:end-1,:), dnqb].';
end