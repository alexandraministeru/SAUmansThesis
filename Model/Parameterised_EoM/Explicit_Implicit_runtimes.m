%% Compare explicit to implicit EoM calls
load modelParams_combiBod
pars.p_bio(1) = modelParams.physical.Wi; pars.p_bio(2) = modelParams.physical.l0;
pars.p_bio(3) = modelParams.physical.m; pars.p_bio(4) = modelParams.physical.h;

pars.p(7) = modelParams.inertia.gamx;
pars.p(8) = modelParams.inertia.gamy;
pars.p(9) = modelParams.inertia.rx;
pars.p(10) = modelParams.inertia.ry;
pars.p(11) = modelParams.inertia.alpha;
pars.p(12:14) = modelParams.inertia.J_stat;

pars.p(6) = modelParams.spring.l_preload;
pars.p_spring(1) = modelParams.spring.K_ss; pars.p_spring(2) = modelParams.spring.b_ss;
pars.p_spring(3) = modelParams.spring.K_ds; pars.p_spring(4) = modelParams.spring.b_ds;

pars.p(1) = modelParams.vpp.Vl_ss; pars.p(2) = modelParams.vpp.Vs_ss;
pars.p(3) = modelParams.vpp.Vl_ds;
pars.p(4) = modelParams.vpp.Vs_bl; pars.p(5) = modelParams.vpp.Vs_fl;

tic
for i = 1:1000
    x = rand(14,1);
    x(1:2) = x(1:2) - 0.5;
    x(3) = x(3)*0.3 + 1.1;
    x(4:14) = x(4:14) - 0.5;
    x(7:10) = x(7:10)./norm(x(7:10));
    u = rand(2) - 0.5;
    dx = ImplicitEoM_combiBod_dyns(x, u, pars, "lDSr");
end
ImplicitRuntime = toc

%%
Vl = modelParams.vpp.Vl_ds;
Vs_bl = modelParams.vpp.Vs_bl;
Vs_fl = modelParams.vpp.Vs_fl;
h = modelParams.physical.h;
Wi = modelParams.physical.Wi;
l = modelParams.physical.l0 + modelParams.spring.l_preload;
m = modelParams.physical.m;
k = modelParams.spring.K_ds;
b = modelParams.spring.b_ds;
gamx = modelParams.inertia.gamx;
gamy = modelParams.inertia.gamy;
rx = modelParams.inertia.rx;
ry =  modelParams.inertia.ry;
alpha =  modelParams.inertia.alpha;

tic
for i = 1:1000
    x = rand(14,1);
    x(1:2) = x(1:2) - 0.5;
    x(3) = x(3)*0.3 + 1.1;
    x(4:14) = x(4:14) - 0.5;
    x(7:10) = x(7:10)./norm(x(7:10));
    u = rand(2) - 0.5;
    dx = lDSr_split_eom_gyrBod(12,x',u(:,1)',u(:,2)',Vl,Vs_bl,Vs_fl,h,Wi,l,m,k,b,gamx,gamy,rx,ry,alpha);
end
ExplicitRuntime = toc


