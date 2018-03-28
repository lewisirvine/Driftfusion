function solstruct = pindrift(varargin);

%%
% spatial mesh is generated by meshgen_x
% time mesh is generated by meshgen_t
% params sturcture is generated by pinParams
% Solution is analysed and plotted by pinAna

%%%%%%% GENERAL NOTES %%%%%%%%%%%%
% A routine for solving the diffusion and drift equations using the
% matlab pdepe solver. 
% 
% The solution from the solver is a 3D matrix, u:
% rows = time
% columns = space
% u(1), layer 1 = electron density, n
% u(2), layer 2 = hole density, p
% u(3), layer 3 = mobile defect density, a
% u(4), layer 4 = electric potential, V
%
% The solution structure solstruct contains the solution in addition to
% other useful outputs including the parameters sturcture

%%%%% INPUTS ARGUMENTS %%%%%%%
% This version allows a previous solution to be used as the input
% conditions. If there is no input argument asssume default flat background
% condtions. If there is one argument, assume it is the previous solution
% to be used as the initial conditions (IC). If there are two input arguments,
% assume that first is the previous solution, and the
% second is a parameters structure. If the IC sol = 0, default intial conditions
% are used, but parameters can still be input. If the second argument is
% any character e.g. 'params', then the parameters from the input solution
% i.e. the first argument are used.
%  
% AUTHORS
% Piers Barnes last modified (09/01/2016)
% Phil Calado last modified (14/07/2017)
% Mohammed Azzousi
% Benjamin Hilton
% Ilario Gelmetti

%% Graph formatting
set(0,'DefaultLineLinewidth',1);
set(0,'DefaultAxesFontSize',16);
set(0,'DefaultFigurePosition', [600, 400, 450, 300]);
set(0,'DefaultAxesXcolor', [0, 0, 0]);
set(0,'DefaultAxesYcolor', [0, 0, 0]);
set(0,'DefaultAxesZcolor', [0, 0, 0]);
set(0,'DefaultTextColor', [0, 0, 0]);

%% Input arguments are dealt with here
if isempty(varargin)

    p = pinParams;      % Calls Function pinParams and stores in sturcture 'params'

elseif length(varargin) == 1
    
    % Call input parameters function
    icsol = varargin{1, 1}.sol;
    icx = varargin{1, 1}.x;
    p = pinParams;

elseif length(varargin) == 2 

    if max(max(max(varargin{1, 1}.sol))) == 0

       p = varargin{2};
    
    elseif isa(varargin{2}, 'char') == 1            % Checks to see if argument is a character
        
        p = varargin{1, 1}.p;
        icsol = varargin{1, 1}.sol;
        icx = varargin{1, 1}.x;
    
    else
    
        icsol = varargin{1, 1}.sol;
        icx = varargin{1, 1}.x;
        p = varargin{2};
    
    end

end


%% Spatial mesh
if length(varargin) == 0 || length(varargin) == 2 && max(max(max(varargin{1, 1}.sol))) == 0
    
    % Edit meshes in mesh gen
    x = meshgen_x(p);
    
        if p.OC == 1
        
        % Mirror the mesh for symmetric model - symmetry point is an additional
        % point at device length + 1e-7
        x1 = x;
        x2 = xmax - fliplr(p.x) + x(end);
        x2 = p.x2(2:end);                 % Delete initial point to ensure symmetry
        x = [p.x1, p.x2];
        
        end
        
    icx = x;
    
else
          
        x = icx;

end

p.xpoints = length(x);
p.xmax = x(end);     

%% Time mesh
t = meshgen_t(p);

%% Call solver

% SOLVER OPTIONS  - limit maximum time step size during integration.
options = odeset('MaxOrder',5, 'NonNegative', [1, 1, 1, 0], 'RelTol', p.RelTol); % Reduce RelTol to improve precision of solution

% inputs with '@' are function handles to the subfunctions
% below for the: equation, initial conditions, boundary conditions
sol = pdepe(p.m,@pdex4pde,@pdex4ic,@pdex4bc,x,t,options);

%% Set up partial differential equation (pdepe) (see MATLAB pdepe help for details of c, f, and s)
function [c,f,s,iterations] = pdex4pde(x,t,u,DuDx)

% Open circuit condition- symmetric model
if (p.OC ==1)
    
    if x > p.xmax/2

        x = p.xmax - x;

    end
    
end

%% Generation     

% Beer Lambert or Transfer Matrix 1 Sun - NOT CURRENTLY IMPLEMENTED!
if p.Int ~= 0 && p.OM ==1 || p.Int ~= 0 && p.OM == 2
     
      if x > p.tp && x < (p.tp+p.ti) 
          g = p.Int*interp1(genspace, Gx1S, (p.x-p.tp));
      else
          g = 0;
      end
 
    % Add pulse
    if p.pulseon == 1
        if  t >= 10e-6 && t < p.pulselen + 10e-6
           if x > p.tp && x < (p.tp+p.ti)
                lasg = p.pulseint*interp1(genspace, GxLas, (x-p.tp));
                g = g + lasg;
           end
        end
    end
  
% Uniform Generation
elseif p.OM == 0
      
      if p.Int ~= 0 && x > p.tp && x < (p.tp+p.ti)    
           g = p.Int*p.G0;
      else
           g = 0;
      end
        
        % Add pulse
        if p.pulseon == 1
            if  t >= p.pulsestart && t < p.pulselen + p.pulsestart
                
                g = g+(p.pulseint*p.G0);
            
            end
        end
        
else
        g = 0;    
end

%% Transport and continuity equations
% Prefactors set to 1 for time dependent components - can add other
% functions if you want to include the multiple trapping model
% f indicates flux terms
% s indicates source terms - see pdepe help for how these are implemented - be careful of signs! 

c = [1      % electron density
     1      % hole density
     1      % mobile ion density
     0];    % electric potential

% p-type
if x >= 0 && x <= p.tp - p.tscr

 f = [(p.mue_p*(u(1)*-DuDx(4)+p.kB*p.T*DuDx(1)));
     (p.muh_p*(u(2)*DuDx(4)+p.kB*p.T*DuDx(2)));     
     0;                                         % Ion mobility is switched off in the contact regions
     DuDx(4);];                                  
 
 % source terms - for electrons and hole the first term is radiative rec,
 % second term is SRH recombination
 s = [ - p.kradhtl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_htl*(u(2)+p.pthtl)) + (p.taup_htl*(u(1)+p.nthtl))));
       - p.kradhtl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_htl*(u(2)+p.pthtl)) + (p.taup_htl*(u(1)+p.nthtl))));
      0;
      (p.q/p.eppp)*(-u(1)+u(2)-p.NA+u(3)-p.NI);];
  
elseif x > p.tp - p.tscr && x <= p.tp
    
 f = [(p.mue_p*(u(1)*-DuDx(4)+p.kB*p.T*DuDx(1)));
     (p.muh_p*(u(2)*DuDx(4)+p.kB*p.T*DuDx(2)));     
     0;
     DuDx(4);];                                  

 s = [ - p.kradhtl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_htl*(u(2)+p.pthtl)) + (p.taup_htl*(u(1)+p.nthtl)))); %- klincon*min((u(1)- htln0), (u(2)- htlp0)); % 
       - p.kradhtl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_htl*(u(2)+p.pthtl)) + (p.taup_htl*(u(1)+p.nthtl)))); %- kradhtl*((u(1)*u(2))-(ni^2)); %- klincon*min((u(1)- htln0), (u(2)- htlp0)); % - (((u(1)*u(2))-ni^2)/((taun_htl*(u(2)+pthtl)) + (taup_htl*(u(1)+nthtl))));
      0;
      (p.q/p.eppp)*(-u(1)+u(2)+u(3)-p.NI-p.NA);];
 
% Intrinsic
elseif x > p.tp && x < p.tp + p.ti
    
   f = [(p.mue_i*(u(1)*-DuDx(4)+p.kB*p.T*DuDx(1)));
     (p.muh_i*(u(2)*DuDx(4)+p.kB*p.T*DuDx(2))); 
     (p.mui*(u(3)*DuDx(4)+p.kB*p.T*DuDx(3))); 
     DuDx(4);];                                     

 s = [g - p.krad*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_i*(u(2)+p.pti)) + (p.taup_i*(u(1)+p.nti)))); 
      g - p.krad*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_i*(u(2)+p.pti)) + (p.taup_i*(u(1)+p.nti))));
      0;
      (p.q/p.eppi)*(-u(1)+u(2)+u(3)-p.NI);]; 

% n-type
elseif x >= p.tp + p.ti && x < p.tp + p.ti + p.tscr
  
 f = [(p.mue_n*(u(1)*-DuDx(4)+p.kB*p.T*DuDx(1)));
     (p.muh_n*(u(2)*DuDx(4)+p.kB*p.T*DuDx(2)));      
     0;
     DuDx(4)];                                      

s = [ - p.kradetl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_etl*(u(2)+p.ptetl)) + (p.taup_etl*(u(1)+p.ntetl))));   %- kradetl*((u(1)*u(2))-(ni^2)); %- klincon*min((u(1)- etln0), (u(2)- etlp0)); %  - (((u(1)*u(2))-ni^2)/((taun_etl*(u(2)+ptetl)) + (taup_etl*(u(1)+ntetl))));
      - p.kradetl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_etl*(u(2)+p.ptetl)) + (p.taup_etl*(u(1)+p.ntetl))));   %- kradetl*((u(1)*u(2))-(ni^2)); % - klincon*min((u(1)- etln0), (u(2)- etlp0)); %- (((u(1)*u(2))-ni^2)/((taun_etl*(u(2)+ptetl)) + (taup_etl*(u(1)+ntetl))));
      0;
      (p.q/p.eppn)*(-u(1)+u(2)+u(3)-p.NI+p.ND);];%+ptetl-ntetl)];

  % n-type
elseif x >= p.tp + p.ti + p.tscr && x <= p.xmax
  
 f = [(p.mue_n*(u(1)*-DuDx(4)+p.kB*p.T*DuDx(1)));
     (p.muh_n*(u(2)*DuDx(4)+p.kB*p.T*DuDx(2)));      
     0;
     DuDx(4)];                                      

s = [ - p.kradetl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_etl*(u(2)+p.ptetl)) + (p.taup_etl*(u(1)+p.ntetl))));   %- kradetl*((u(1)*u(2))-(ni^2)); %- klincon*min((u(1)- etln0), (u(2)- etlp0)); %  - (((u(1)*u(2))-ni^2)/((taun_etl*(u(2)+ptetl)) + (taup_etl*(u(1)+ntetl))));
      - p.kradetl*((u(1)*u(2))-(p.ni^2)) - (((u(1)*u(2))-p.ni^2)/((p.taun_etl*(u(2)+p.ptetl)) + (p.taup_etl*(u(1)+p.ntetl))));   %- kradetl*((u(1)*u(2))-(ni^2)); % - klincon*min((u(1)- etln0), (u(2)- etlp0)); %- (((u(1)*u(2))-ni^2)/((taun_etl*(u(2)+ptetl)) + (taup_etl*(u(1)+ntetl))));
      0;
      (p.q/p.eppn)*(-u(1)+u(2)+p.ND+u(3)-p.NI);];%+ptetl-ntetl)];

end

end

%% Initial conditions
function u0 = pdex4ic(x)

%% Open circuit condition- symmetric model
if p.OC == 1
    
    if x >= p.xmax/2

        x = p.xmax - x;

    end
    
end

%% Initial conditions based on analytical solution p-i-n junction

if length(varargin) == 0 || length(varargin) >= 1 && max(max(max(varargin{1, 1}.sol))) == 0
    
    % p-type
    if x < (p.tp - p.wp)
    
       u0 = [p.htln0;
             p.htlp0;
              p.NI;
              0];  

    % p-type SCR    
    elseif  x >= (p.tp - p.wp) && x < p.tp

        u0 = [p.N0*exp((p.Efnside + p.EA + p.q*((((p.q*p.NA)/(2*p.eppi))*(x-p.tp+p.wp)^2)))/(p.kB*p.T));                            %ni*exp((Efnside - (-q*((((q*NA)/(2*eppp))*(x-tp+wp)^2))))/(kB*T));
              p.N0*exp(-(p.q*((((p.q*p.NA)/(2*p.eppi))*(x-p.tp+p.wp)^2)) + p.EA + p.Eg + p.Efpside)/(p.kB*p.T));
              p.NI;
              (((p.q*p.NA)/(2*p.eppi))*(x-p.tp+p.wp)^2)];

    % Intrinsic

    elseif x >= p.tp && x <= p.tp+ p.ti

        u0 =  [p.N0*exp((p.Efnside + p.EA + p.q*(((x - p.tp)*((1/p.ti)*(p.Vbi - ((p.q*p.NA*p.wp^2)/(2*p.eppi)) - ((p.q*p.ND*p.wn^2)/(2*p.eppi))))) + ((p.q*p.NA*p.wp^2)/(2*p.eppi))))/(p.kB*p.T));
                p.N0*exp(-(p.q*(((x - p.tp)*((1/p.ti)*(p.Vbi - ((p.q*p.NA*p.wp^2)/(2*p.eppi)) - ((p.q*p.ND*p.wn^2)/(2*p.eppi))))) + ((p.q*p.NA*p.wp^2)/(2*p.eppi))) + p.EA + p.Eg + p.Efpside)/(p.kB*p.T));
                p.NI;
                ((x - p.tp)*((1/p.ti)*(p.Vbi - ((p.q*p.NA*p.wp^2)/(2*p.eppi)) - ((p.q*p.ND*p.wn^2)/(2*p.eppi))))) + ((p.q*p.NA*p.wp^2)/(2*p.eppi)) ;];

    % n-type SCR    
    elseif  x > (p.tp+p.ti) && x <= (p.tp + p.ti + p.wn)

        u0 = [p.N0*exp((p.Efnside + p.EA + p.q*((((-(p.q*p.ND)/(2*p.eppi))*(x-p.ti-p.tp-p.wn)^2) + p.Vbi)))/(p.kB*p.T));
              p.N0*exp(-(p.q*((((-(p.q*p.ND)/(2*p.eppi))*(x-p.ti-p.tp-p.wn)^2) + p.Vbi)) + p.EA + p.Eg + p.Efpside)/(p.kB*p.T));
              p.NI;
              (((-(p.q*p.ND)/(2*p.eppi))*(x-p.tp - p.ti -p.wn)^2) + p.Vbi)]; 

    % n-type
    elseif x > (p.tp + p.ti + p.wn) && x <= p.xmax

         u0 = [p.etln0;
               p.etlp0;
               p.NI;
               p.Vbi];
    end      
    

%% Previous solution as initial conditions
elseif length(varargin) == 1 || length(varargin) >= 1 && max(max(max(varargin{1, 1}.sol))) ~= 0
    % insert previous solution and interpolate the x points
    u0 = [interp1(icx,icsol(end,:,1),x)
          interp1(icx,icsol(end,:,2),x)
          interp1(icx,icsol(end,:,3),x)
          interp1(icx,icsol(end,:,4),x)];

end

end

%% Boundary conditions
% Refer pdepe help for the precise meaning of p and q
% l and r refer to left and right.

function [pl,ql,pr,qr] = pdex4bc(xl,ul,xr,ur,t)

%% Current voltage scan, voltage sweep
if p.JV == 1
        
    p.Vapp = p.Vstart + ((p.Vend-p.Vstart)*t*(1/p.tmax));
    
end

%% Open circuit condition- symmetric model
if p.OC == 1
      
    pl = [0;
          0;
          0;
          -ul(4)];

    ql = [1; 
          1;
          1;
          0];

    pr = [0;
          0;
          0;
          -ur(4)];  

    qr = [1; 
          1;
          1;
          0];

else

%% Closed circuit condition
    
    % Zero current - rarely used but can be useful to switch off currents before switching
    % to OC in procedures.
    if p.BC == 0
        
        pl = [0;
            0;
            0;
            -ul(4)];
        
        ql = [1;
            1;
            1;
            0];
        
        pr = [0;
            0;
            0;
            -ur(4) + p.Vbi - p.Vapp;];
        
        qr = [1;
            1;
            1;
            0];
        
    % Fixed majority charge densities at the boundaries- contact in equilibrium with etl and htl
    % Blocking electrode- zero flux for minority carriers
    elseif p.BC == 1
        
        pl = [0;
            (ul(2)-p.htlp0);
            0;
            -ul(4);];
        
        ql = [1;
            0;
            1;
            0];
        
        pr = [(ur(1)-p.etln0);
            0;
            0;
            -ur(4)+p.Vbi-p.Vapp;];
        
        qr = [0;
            1;
            1;
            0];
        
    % Non- selective contacts - fixed charge densities for majority and minority carriers
    % equivalent to infinite surface recombination velocity for minority carriers
    elseif p.BC == 2
        
        pl = [ul(1) - p.htln0;
            ul(2) - p.htlp0;
            0;
            -ul(4);];
        
        ql = [0;
            0;
            1;
            0];
        
        pr = [ur(1) - p.etln0;
            ur(2) - p.etlp0;
            0;
            -ur(4)+p.Vbi-p.Vapp;];
        
        qr = [0;
            0;
            1;
            0];
    
    end
end

end


%% Analysis, graphing-  required to obtain J and Voc

% Readout solutions to structure
solstruct.sol = sol;            
solstruct.x = x; 
solstruct.t = t;

% Store parameters structure
p.x =x;
p.t =t;

solstruct.p = p;

if p.Ana == 1
    
    [Voc, Vapp_arr, Jn, ~, ~] = pinAna(solstruct);
    
    if p.OC == 1
        
        solstruct.Voc = Voc;
        
    else
        
        solstruct.Jn = Jn;
        
    end
    
    if p.JV == 1
        
        solstruct.Vapp = Vapp_arr;
        
    end
    
end

% Store parameters structure again
solstruct.p = p;
solstruct.x = x;
solstruct.t = t;

end





