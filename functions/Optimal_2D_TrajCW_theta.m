% Compute the minimal-fuel reference trajectory with satellite pointing towards target    
% x is the reference trajectory with constant attitude of the spacecraft [~, x, ~] = Optimal_2D_TrajCW(params);
% Based on the list of positions, calculate the matrix Bd of each step
% Redo a cvx optimization with these different Bd matrices, instead of
% having the same for every step.
%
% Author: Himmat Panag

function [x, u] = Optimal_2D_TrajCW_theta(params, x)

    N = params.numSteps; % Number of discretization steps in control input

    f = ones(N,1)./params.Omega^2;    
    simTime = params.transfer_time*60*60; 
    dt = simTime/N;
    A = params.matrix_A;
    B = params.matrix_B/params.thrust_factor;
    [n, m] = size(B);

    Phi = expm(A*dt);
    Bd = zeros(n,n,N);

    for ii = 1:N
        theta = atan2(x(2,ii), x(1,ii)); % orientation at each step of initial orbit
        R_theta = [zeros(2,4); zeros(2,2), [cos(theta), -sin(theta); sin(theta), cos(theta)]];
        A2tExp = expm([-A,R_theta*B;zeros(m,n+m)]*dt);
        Bd(:,:,ii) = Phi*A2tExp(1:n,n+1:n+m); % Bd matrix for this specific orientation
    end

    %%% Optimization
    cvx_begin quiet
        variable eta(N)
        variable x(n,N)
        variable u(m,N)

        minimize(f'*eta)
        subject to 
        x(:,1) == [params.rInit;params.vInit];
        x(:,N) == [params.rFinal;params.vFinal];
        
        for ii = 1:N
            norm(u(:,ii)) <= eta(ii); % thrust minimizer
            0 <= eta(ii);
            eta(ii) <= params.max_thrust; % max thrust
            
            for jj = 1:m
                0 <= u(jj,ii); % only positive thrust
            end
        end 
        for ii = 2:N
            x(:,ii) == Phi*x(:,ii-1) + Bd(:,:,ii)*u(:,ii-1);
        end         
    cvx_end 
end 