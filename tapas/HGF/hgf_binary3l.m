function [traj, infStates] = hgf_binary3l(r, p, varargin)
% Calculates the trajectories of the agent's representations under the HGF
%
% This function can be called in two ways:
% 
% (1) hgf_binary3l(r, p)
%   
%     where r is the structure generated by fitModel and p is the parameter vector in native space;
%
% (2) hgf_binary3l(r, ptrans, 'trans')
% 
%     where r is the structure generated by fitModel, ptrans is the parameter vector in
%     transformed space, and 'trans' is a flag indicating this.
%
% --------------------------------------------------------------------------------------------------
% Copyright (C) 2012-2013 Christoph Mathys, TNU, UZH & ETHZ
%
% This file is part of the HGF toolbox, which is released under the terms of the GNU General Public
% Licence (GPL), version 3. You can redistribute it and/or modify it under the terms of the GPL
% (either version 3 or, at your option, any later version). For further details, see the file
% COPYING or <http://www.gnu.org/licenses/>.


% Transform paramaters back to their native space if needed
if ~isempty(varargin) && strcmp(varargin{1},'trans');
    p = hgf_binary3l_transp(r, p);
end

% Number of levels
l = 3;

% Unpack parameters
mu2_0 = p(1);
sa2_0 = p(2);
mu3_0 = p(3);
sa3_0 = p(4);
ka    = p(5);
om    = p(6);
th    = p(7);

% Add dummy "zeroth" trial
u = [0; r.u(:,1)];

% Number of trials (including prior)
n = length(u);

% Initialize updated quantities

% Representations
mu1 = NaN(n,1);
mu2 = NaN(n,1);
pi2 = NaN(n,1);
mu3 = NaN(n,1);
pi3 = NaN(n,1);

% Other quantities
mu1hat = NaN(n,1);
pi1hat = NaN(n,1);
pi2hat = NaN(n,1);
pi3hat = NaN(n,1);
w2     = NaN(n,1);
da1    = NaN(n,1);
da2    = NaN(n,1);

% Representation priors
% Note: first entries of the other quantities remain
% NaN because they are undefined and are thrown away
% at the end; their presence simply leads to consistent
% trial indices.
mu1(1) = sgm(mu2_0, 1);
mu2(1) = mu2_0;
pi2(1) = 1/sa2_0;
mu3(1) = mu3_0;
pi3(1) = 1/sa3_0;

% Pass through representation update loop
for k = 2:1:n
    if not(ismember(k-1, r.ign))
        
        %%%%%%%%%%%%%%%%%%%%%%
        % Effect of input u(k)
        %%%%%%%%%%%%%%%%%%%%%%

        % 1st level
        % ~~~~~~~~~
        % Prediction
        mu1hat(k) = sgm(mu2(k-1), 1);
        
        % Precision of prediction
        pi1hat(k) = 1/(mu1hat(k)*(1 -mu1hat(k)));

        % Update
        mu1(k) = u(k);

        % Prediction error
        da1(k) = mu1(k) -mu1hat(k);

        % 2nd level
        % ~~~~~~~~~
        % Precision of prediction
        pi2hat(k) = 1/(1/pi2(k-1) +exp(ka *mu3(k-1) +om));

        % Updates
        pi2(k) = pi2hat(k) +1/pi1hat(k);

        mu2(k) = mu2(k-1) +1/pi2(k) *da1(k);

        % Volatility prediction error
        da2(k) = (1/pi2(k) +(mu2(k) -mu2(k-1))^2) *pi2hat(k) -1;


        % 3rd level
        % ~~~~~~~~~
        % Precision of prediction
        pi3hat(k) = 1/(1/pi3(k-1) +th);

        % Weighting factor
        w2(k) = exp(ka *mu3(k-1) +om) *pi2hat(k);

        % Updates
        pi3(k) = pi3hat(k) +1/2 *ka^2 *w2(k) *(w2(k) +(2 *w2(k) -1) *da2(k));

        if pi3(k) <= 0
            error('Error: negative pi3. Parameters are in a region where model assumptions are violated.');
        end

        mu3(k) = mu3(k-1) +1/2 *1/pi3(k) *ka *w2(k) *da2(k);
    
    else
        mu1(k) = mu1(k-1); 
        mu2(k) = mu2(k-1);
        pi2(k) = pi2(k-1);
        mu3(k) = mu3(k-1);
        pi3(k) = pi3(k-1);

        mu1hat(k) = mu1hat(k-1);
        pi1hat(k) = pi1hat(k-1);
        pi2hat(k) = pi2hat(k-1);
        pi3hat(k) = pi3hat(k-1);
        w2(k)     = w2(k-1);
        da1(k)    = da1(k-1);
        da2(k)    = da2(k-1);
    end
end

% Get predictions on mu2 and mu3
mu2hat = mu2;
mu2hat(end) = [];
mu3hat = mu3;
mu3hat(end) = [];

% Remove representation priors
mu1(1)  = [];
mu2(1)  = [];
pi2(1)  = [];
mu3(1)  = [];
pi3(1)  = [];

% Remove other dummy initial values
mu1hat(1) = [];
pi1hat(1) = [];
pi2hat(1) = [];
pi3hat(1) = [];
w2(1)     = [];
da1(1)    = [];
da2(1)    = [];

% Calculate variance at 1st level
sa1 = mu1.*(1-mu1);

% Create result data structure
traj = struct;

traj.mu = [mu1, mu2, mu3];
traj.sa = [sa1, 1./pi2, 1./pi3]; 

traj.muhat = [mu1hat, mu2hat, mu3hat];
traj.sahat = [1./pi1hat, 1./pi2hat, 1./pi3hat];

traj.w       = w2;
traj.da      = [da1, da2];

% Create matrices for use by observation model
infStates = NaN(n-1,l,2);
infStates(:,:,1) = traj.muhat;
infStates(:,:,2) = traj.sahat;

return;
