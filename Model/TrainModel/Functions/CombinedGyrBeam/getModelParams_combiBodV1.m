function [modelParams] = getModelParams_combiBodV1(data, Trial, k, w, walkVel, BMthr, dt, plotIO)
%GETBODYPARAMSV9 Summary of this function goes here
%   Detailed explanation goes here

t = data(Trial).Time.TIME(k);% k/120;

modelParams.Trial.Trial = Trial;
modelParams.Trial.walkVel = walkVel;
modelParams.Trial.dt = dt;

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

LLML = data(Trial).TargetData.LLML_pos_proc(k, 1:3);
RLML = data(Trial).TargetData.RLML_pos_proc(k, 1:3);

RgrfVec = data(Trial).Force.force2(1:10:end,:);
RgrfPos = data(Trial).Force.cop2(10:10:end,:);
LgrfVec = data(Trial).Force.force1(1:10:end,:);
LgrfPos = data(Trial).Force.cop1(10:10:end,:);

LgrfMag = vecnorm(LgrfVec, 2, 2);
RgrfMag = vecnorm(RgrfVec, 2, 2);

%% Filter wrongly measured feet pos
Lidx_correct = find(LgrfPos(:,1)>0.05 & LgrfPos(:,1)<0.15 & LgrfPos(:,2)>0.5 & LgrfPos(:,2)<1.35);
LgrfPos = interp1(Lidx_correct, LgrfPos(Lidx_correct,:), 1:length(LgrfPos), "linear");
Ridx_correct = find(RgrfPos(:,1)<-0.05 & RgrfPos(:,1)>-0.15 & RgrfPos(:,2)>0.5 & RgrfPos(:,2)<1.35);
RgrfPos = interp1(Ridx_correct, RgrfPos(Ridx_correct,:), 1:length(RgrfPos), "linear");

%% Determine initial state
initGRFmagL = norm(LgrfVec(k(1),:));
initGRFmagR = norm(RgrfVec(k(1),:));

m = data(Trial).Participant.Mass;
bound = m*9.81*BMthr;
gaitCycle = ["rDSl", "lSS", "lDSr", "rSS"];

if initGRFmagL>bound && initGRFmagR>bound
    error("Cannot initialise in double stance, ambiguous stance order. Choose a different initial timestep.")
elseif initGRFmagL < bound && initGRFmagR>bound
    gaitCycle = circshift(gaitCycle, -3);
elseif initGRFmagL>bound && initGRFmagR < bound
    gaitCycle = circshift(gaitCycle, -1);
end

xMeas = meas2state(data, Trial, k);

%% Estimate physical paramaters (not provided by Van der Zee)
nWi = vecnorm(RGTR-LGTR, 2, 2);
Wi = mean(nWi);

nhVec = COM - (LGTR + 0.5*(RGTR-LGTR));
h = mean(vecnorm(nhVec, 2, 2));

l0 = max(xMeas(3,:)) - h;

p_bio = [Wi, l0, m, h];

%% Optimise body parameters
% find spring constants
[K_ss, b_ss, K_ds ] = getSpringConsts(k, l0, LLML, LGTR, RLML, RGTR, LgrfVec, RgrfVec, m, gaitCycle, false);
p_spring = [K_ss, b_ss, K_ds 0];

disp("Obtained spring parameters, proceeding with genetic algorithm")

%    params:
%         Wi = pars.p_bio(1); l0 = pars.p_bio(2);  m = pars.p_bio(3); h = pars.p_bio(4);
%         K_ss = pars.p_spring(1); b_ss = pars.p_spring(2);
%         K_ds = pars.p_spring(3); b_ds = pars.p_spring(4);
%         Vl_ss = p(1); Vs_ss = p(2);
%         Vl_ds = p(3);
%         Vs_bl = p(4); Vs_fl = p(5);
%         l_preload = p(6);
%         gamx = p(7);
%         gamy = p(8);
%         rx = p(9);
%         ry = p(10);
%         alpha = p(11);
%         bJ_stat = diag(p(12:14));

lb_vpp      = [-0.2,0]; %[Vl, Vs]
ub_vpp      = [1 1];
lb_gam      = -1e10;
ub_gam      = 1e10;
lb_r        = 0;
ub_r        = 1e3;
lb_alpha    = 0;
ub_alpha    = 1;
lb_preload = 0;
ub_preload = 1;
lb_J   = [0, 0, 0]; %[Jxx, Jyy, Jzz]
ub_J   = [  m/12*(Wi^2 + data(Trial).Participant.Height^2),... Ixx
            m/12*(Wi^2 + data(Trial).Participant.Height^2),... Iyy
            m/12*(Wi^2 + Wi^2) + m*(0.5*data(Trial).Participant.Height)^2]; % Izz

lb = [lb_vpp, lb_vpp(1), lb_vpp, lb_preload, lb_gam, lb_gam, lb_r, lb_r, lb_alpha, lb_J];
ub = [ub_vpp, ub_vpp(1), ub_vpp, ub_preload, ub_gam, ub_gam, ub_r, ub_r, ub_alpha, ub_J];

% pars.p_spring = p_spring;
pars.p_bio = p_bio;

Pga = ga(@(p)compareModelPerStrideGA_combiBod([p p_spring], pars, w, k, xMeas, walkVel, gaitCycle, bound,...
    LgrfPos, RgrfPos, LgrfVec, RgrfVec, LgrfMag, RgrfMag, LLML, LGTR, RLML, RGTR, dt, false),...
    length(lb),[],[],[],[],...
    lb,...
    ub, [],[],...
    optimoptions('ga','UseParallel', true, 'UseVectorized', false,'MaxTime', 0.5*60));

disp("Obtained initialisation body parameters, proceeding with fmincon")

%    params:
%         Wi = pars.p_bio(1); l0 = pars.p_bio(2);  m = pars.p_bio(3); h = pars.p_bio(4);
%         Vl_ss = p(1); Vs_ss = p(2);
%         Vl_ds = p(3);
%         Vs_bl = p(4); Vs_fl = p(5);
%         l_preload = p(6);
%         gamx = p(7);
%         gamy = p(8);
%         rx = p(9);
%         ry = p(10);
%         alpha = p(11);
%         bJ_stat = diag(p(12:14));
%         K_ss = p(15); b_ss = p(16);
%         K_ds = p(17); b_ds = p(18);

Pinit = [Pga, K_ss, b_ss, K_ds, 0];
Popt = fmincon(@(p)compareModelPerStrideFMC_combiBod(p, pars, w, k, xMeas, walkVel, gaitCycle, bound,...
    LgrfPos, RgrfPos, LgrfVec, RgrfVec, LgrfMag, RgrfMag, LLML, LGTR, RLML, RGTR, dt, false),...
    Pinit, [],[],[],[],...
    [lb, 0.8*p_spring],[ub, 1.2*p_spring(1:3), 2*b_ss], [],...
    optimoptions('fmincon','UseParallel',true));


%%
if plotIO
resnormCombibod = compareModelPerStrideFMC_combiBod(Popt, pars, w, k, xMeas, walkVel, gaitCycle, bound,...
    LgrfPos, RgrfPos, LgrfVec, RgrfVec, LgrfMag, RgrfMag, LLML, LGTR, RLML, RGTR, dt, plotIO)
drawnow
end

p_spring = Popt(15:18);

modelParams.physical.Wi = p_bio(1); modelParams.physical.l0 = p_bio(2);
modelParams.physical.m = p_bio(3); modelParams.physical.h = p_bio(4);

modelParams.inertia.gamx = Popt(7);
modelParams.inertia.gamy = Popt(8);
modelParams.inertia.rx = Popt(9);
modelParams.inertia.ry = Popt(10);
modelParams.inertia.alpha = Popt(11);
modelParams.inertia.J_stat = Popt(12:14);

modelParams.spring.l_preload = Popt(6);
modelParams.spring.K_ss = Popt(15); modelParams.spring.b_ss = Popt(16);
modelParams.spring.K_ds = Popt(17); modelParams.spring.b_ds = Popt(18);

modelParams.vpp.Vl_ss = Popt(1); modelParams.vpp.Vs_ss = Popt(2);
modelParams.vpp.Vl_ds = Popt(3);
modelParams.vpp.Vs_bl = Popt(4); modelParams.vpp.Vs_fl = Popt(5);

%%
disp("Obtained all body parameters, proceeding with obtaining foot placement estimator")

[FPEparam, lpFilt, nFilt] = getFPEparams(data, Trial, p_bio, walkVel, k, bound, dt, true);

modelParams.FPE.SW = FPEparam(1);
modelParams.FPE.SL = FPEparam(2);
modelParams.FPE.lpFilt = lpFilt;
modelParams.FPE.nFilt = nFilt;

disp("Obtained all model parameters")

end

