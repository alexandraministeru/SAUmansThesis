

%% Load data
clc; close all;
if exist("data","var") ~= 1
    clear;
    load([pwd '\..\..\human-walking-biomechanics\Level 3 - MATLAB files\Level 3 - MATLAB files\All Strides Data files\p6_AllStridesData.mat'])
end

Trial = 12; %randi(33);
k = 5000:5240;
t = data(Trial).Time.TIME(k);% k/120;
dt = 1/120;

%% Extract data
SACR = data(Trial).TargetData.SACR_pos_proc(k, 1:3);
LASI = data(Trial).TargetData.LASI_pos_proc(k, 1:3);
RASI = data(Trial).TargetData.RASI_pos_proc(k, 1:3);
COM = (SACR+LASI+RASI)./3; % COM estimate

LAC = data(Trial).TargetData.LAC_pos_proc(k, 1:3);
RAC = data(Trial).TargetData.RAC_pos_proc(k, 1:3);
CAC = (LAC+RAC)./2; % Center of shoulderblades

LGTR = data(Trial).TargetData.LGTR_pos_proc(k, 1:3);
RGTR = data(Trial).TargetData.RGTR_pos_proc(k, 1:3);

RgrfVec = data(Trial).Force.force2(1:10:end,:);
RgrfPos = data(Trial).Force.cop2(10:10:end,:);
LgrfVec = data(Trial).Force.force1(1:10:end,:);
LgrfPos = data(Trial).Force.cop1(10:10:end,:);

LgrfMag = vecnorm(LgrfVec, 2, 2);
RgrfMag = vecnorm(RgrfVec, 2, 2);

% Filter wrongly measured feet pos
Lidx_correct = find(LgrfPos(:,1)>0 & LgrfPos(:,1)<0.15 & LgrfPos(:,2)>0.4 & LgrfPos(:,2)<1.4);
LgrfPos = interp1(Lidx_correct, LgrfPos(Lidx_correct,:), 1:length(LgrfPos));

%% Determine initial state
initGRFmagL = norm(LgrfVec(k(1),:));
initGRFmagR = norm(RgrfVec(k(1),:));

bound = 20;
gaitCycle = ["rDSl", "lSS", "lDSr", "rSS"];

if initGRFmagL>bound && initGRFmagR>bound
    error("Cannot initialise in double stance, ambiguous stance order")
elseif initGRFmagL < bound && initGRFmagR>bound
    gaitCycle = circshift(gaitCycle, -3);
elseif initGRFmagL>bound && initGRFmagR < bound
    gaitCycle = circshift(gaitCycle, -1);
end


xMeas = meas2state(data, Trial, k);
%% Run model
Vl = 0.03;
Vs = 0.1;
h = 0.05;
Wi = 0.43;
l0 = 1.15;
m = data(Trial).Participant.Mass;
K = 2e4;
b = 20;
J = [1, 1, 1];
p = [Vl, Vs, h, Wi, l0, K, b, J];

xModelRes = runModel(p, m, k, xMeas, gaitCycle, bound, LgrfPos, RgrfPos, LgrfMag, RgrfMag, dt);

%% Optimise
options = optimoptions(@lsqnonlin,'MaxFunctionEvaluations', 1e4, 'MaxIterations', 800);
Popt = lsqnonlin(@(p)runModel(p, m, k, xMeas, gaitCycle, bound, LgrfPos, RgrfPos, LgrfMag, RgrfMag, dt),p,...
            [-0.1, -0.1, -0.1, 0, 1, 0.5e4, 0, 0,0,0], [0.2, 0.2, 0.5, 1, 2, 1e5, 100, 100,100,100], options);
%%
% TestEnd = 5240;
% 
% figure()
% subplot(2,2,1);
% plot(xMeas(1:3,1:(TestEnd-k(1)))', 'r')
% hold on
% plot(xModel(1:3,k(1):TestEnd)', 'b')
% 
% subplot(2,2,2);
% plot(xMeas(4:6,1:(TestEnd-k(1)))', 'r')
% hold on
% plot(xModel(4:6,k(1):TestEnd)', 'b')
% 
% subplot(2,2,3);
% plot(xMeas(7:10,1:(TestEnd-k(1)))', 'r')
% hold on
% plot(xModel(7:10,k(1):TestEnd)', 'b')
% 
% subplot(2,2,4);
% plot(xMeas(11:14,1:(TestEnd-k(1)))', 'r')
% hold on
% plot(xModel(11:14,k(1):TestEnd)', 'b')

%%
function [xModelResNorm] = runModel(p, m, k, xMeas, gaitCycle, bound, LgrfPos, RgrfPos, LgrfMag, RgrfMag, dt)
Vl = p(1);
Vs = p(2);
h = p(3);
Wi = p(4);
l0 = p(5);
K = p(6);
b = p(7);
J = p(8:10);

ki = k(1);
xModel = [zeros(14, k(1)-1), xMeas(:,1), zeros(14,length(k)-1)];
while ki < k(end)
    switch gaitCycle(1)
        case "lSS"
            k_end = ki+ find(RgrfMag(ki:end)>bound, 1);
            for ki = ki:k_end
                xModel(:,ki+1) = xModel(:,ki) + dt*LSSeom(0,xModel(:,ki)',LgrfPos(ki,1:2),Vl,Vs,h,Wi,l0,m,K,b,J);
            end
            gaitCycle = circshift(gaitCycle, -1);
        case "rSS"
            k_end = ki+ find(LgrfMag(ki:end)>bound, 1);
            for ki = ki:k_end
                xModel(:,ki+1) = xModel(:,ki) + dt*RSSeom(0,xModel(:,ki)',RgrfPos(ki,1:2),Vl,Vs,h,Wi,l0,m,K,b,J);
            end
            gaitCycle = circshift(gaitCycle, -1);
        case "lDSr"
            k_end = ki+ find(LgrfMag(ki:end) < bound, 1);
            for ki = ki:k_end
                xModel(:,ki+1) = xModel(:,ki) + dt*DSeom(0,xModel(:,ki)',LgrfPos(ki,1:2),RgrfPos(ki,1:2),Vl,Vs,h,Wi,l0,m,K,b,J);
            end
            gaitCycle = circshift(gaitCycle, -1);
        case "rDSl"
            k_end = ki+ find(RgrfMag(ki:end) < bound, 1);
            for ki = ki:k_end
                xModel(:,ki+1) = xModel(:,ki) + dt*DSeom(0,xModel(:,ki)',LgrfPos(ki,1:2),RgrfPos(ki,1:2),Vl,Vs,h,Wi,l0,m,K,b,J);
            end
            gaitCycle = circshift(gaitCycle, -1);
            
    end

end

xModel = xModel(:,k(1:end-1));
xModelRes = xModel - xMeas;
xModelResNorm = vecnorm(xModelRes,2,1)';

end