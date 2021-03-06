clear all;
close all;
clc;

load('mazumdar.mat');
% figure(1);
DEAD = 0;
% ETX = 10^-9;
S(n+1).yd = 50;
% Rmax = 20;

for r= 1:1:2500
% Compute Neigbor desity & neighbor cost
    r
    dead = 0;
    for i=1:1:n
        %checking if there is a dead node
        if (S(i).RE<=0)
%             plot(S(i).xd,S(i).yd,'red D');
            S(i).RE = 0;
            dead=dead+1;
            S(i).state='DEAD';
            S(i).type = 'DEAD';
            S(i).number_worker = 0;
%             hold on;
        else
            S(i).type='N';
            S(i).state='Initial_State';
            S(i).number_worker = 0;
%             plot(S(i).xd,S(i).yd,'o');
%             hold on;
        end
    end
    DEAD(r) = dead;
    for i= 1:1:n
        if S(i).RE > 0
            S(i).distoBS = norm([S(i).xd-50 S(i).yd-50]);
            number_neighbor_i = 0;
            sigma_neigh_cost = 0;
            for j= 1:1:n
                disJToI = norm([S(i).xd-S(j).xd S(i).yd-S(j).yd]);
                if (disJToI <= Rmax && disJToI > 0)
                    number_neighbor_i = number_neighbor_i + 1;
                    sigma_neigh_cost = sigma_neigh_cost + disJToI^2;
                end
            end
            S(i).neigh_des  = number_neighbor_i/n;%HERE
            S(i).neigh_cost = (sqrt(sigma_neigh_cost/number_neighbor_i))/Rmax;%HERE
        end
    end
    
    %  Tinh Fuzzy va Td %
    for i= 1:1:n
        if (S(i).RE >0 )
            % compute Td 
            Energy_level = S(i).RE/S(i).Initial_energy;
            S(i).Fuzzy_fitness1 = evalfis([Energy_level S(i).distoBS], fis1);
            S(i).Fuzzy_fitness2 = evalfis([S(i).neigh_des S(i).neigh_cost], fis2);
            alpha = rand(1,1)/10 + 0.9;
            S(i).Td = alpha * (1 - S(i).Fuzzy_fitness1) * Tc;       
            S(i).candidate = [];
%             plot(S(i).xd,S(i).yd,'o');
%             hold on;
        end
    end

    %Start bau CH
    %Sap xep S(i) theo chieu tang dan cua Td
    [x,idx] = sort([S.Td]);
    S = S(idx);
    for i=1:1:n
        if S(i).RE > 0
          if S(i).type == 'W'
              continue;
          else
              S(i).rad = evalfis([S(i).Fuzzy_fitness1 S(i).Fuzzy_fitness2],fis3);
              S(i).type = 'CH';
%               plot(S(i).xd,S(i).yd,'k*');
              for t=1:1:n
                distance = norm([S(i).xd-S(t).xd S(i).yd-S(t).yd]);
                if distance <= S(i).rad && distance > 0 && (S(i).RE>0)
                  k = length(S(t).candidate) + 1;
                  S(t).candidate(k) = S(i).id;
                  S(t).type = 'W';
                end
              end
          end
        end
    end
    %Remember to sort S
    % Check
    [x,idx] = sort([S.id]);
    S = S(idx);
    for i=1:1:n
      if isequal(S(i).type,'W') && (S(i).RE >0) && ~isempty(S(i).candidate)
        CH_cost = 0;
        for t=1:1:length(S(i).candidate)
          if S(S(i).candidate(t)).RE > 0
            distoCH = norm([S(i).xd-S(S(i).candidate(t)).xd S(i).yd-S(S(i).candidate(t)).yd]);
            CH_cost(t) = distoCH * S(S(i).candidate(t)).distoBS/S(S(i).candidate(t)).RE;
          end
        end
        k = find(CH_cost==min(CH_cost));
        S(i).candidate = S(i).candidate(k);
      end
    end
    for i=1:1:n
        if isequal(S(i).type, 'CH') && S(i).RE >0
            x = [S.candidate];
            tf1 = x == S(i).id;
            S(i).number_worker = sum(tf1==1);
        end
    end
    % --- End Bau CH

    %Routing Start%
    for i=1:1:n
        if isequal(S(i).type,'CH') && S(i).RE > 0
            S(i).L = ceil(S(i).distoBS/Rmax);
            S(i).PN = [];
        end
    end
    for i=1:1:n
        Cost_election = [];
        if isequal(S(i).type,'CH') && S(i).RE > 0
            for k=2:1:S(i).L
                for j=1:1:n
                    if isequal(S(j).type,'CH') && S(j).RE > 0
                        distance = norm([S(i).xd-S(j).yd S(i).yd-S(j).yd]);
                        if S(i).L > S(j).L && distance <= k*Rmax && S(i).id ~= S(j).id
                            if ismember(S(j).id,S(i).PN)
                                continue;
                            else
                                S(i).PN(length(S(i).PN)+1)= S(j).id;
                                if distance < d0
                                    Eij = ETX + Efs*(distance^2);
                                end
                                if distance >= d0
                                    Eij = ETX + Emp*(distance^4);
                                end
                                TEij = (Eij + ETX)*S(i).number_worker*bit;
                                phi = (pi - (pi*S(j).RE/(2*S(j).Initial_energy)));
                                Wij = exp(1/(sin(phi)));
                                Costij = TEij * Wij;
                                Cost_election(length(Cost_election)+1,:) = [Costij j TEij];
                                
                            end
                        else
                            continue;
                        end
                    end
                end
            end
            if isempty(Cost_election)
                continue;
            end
            Cost_election(~any(Cost_election,2),:)=[];
            [a,ida] = min(Cost_election(:,1));
            S(i).PN = S(Cost_election(ida,2)).id;
            S(i).cost = a;
            S(i).TEij = Cost_election(ida,3);
        end
    end
    % Routing
    %End of routing
    
    for i=1:1:n
        if isequal(S(i).type,'W') && S(i).RE >0
            CH = S(i).candidate;
            distoCH = norm([S(i).xd-S(CH).xd S(i).yd-S(CH).yd]);
            if distoCH < d0
                S(i).RE = S(i).RE - bit*(ETX + Efs*(distoCH^2));
            end
            if distoCH >= d0
                S(i).RE = S(i).RE - bit*(ETX + Emp*(distoCH^4));
            end
        elseif isequal(S(i).type,'CH') && S(i).RE > 0
            %Nang luong nhan
            S(i).RE = S(i).RE - S(i).number_worker*bit*ETX;
            parent = S(i).PN;
            %Nang luong truyen
            if ~isempty(parent)
                distance = norm([S(i).xd-S(parent).xd S(i).yd-S(parent).yd]);
%                 S(parent).RE = S(parent).RE - S(i).TEij*10^-1;
                if distance < d0
                    S(i).RE = S(i).RE - S(i).number_worker*bit*(ETX + Efs*(distance^2));
                end
                if distance >= d0
                    S(i).RE = S(i).RE - S(i).number_worker*bit*(ETX + Emp*(distance^4));                    
                end
            else
                if S(i).distoBS < d0
                    S(i).RE = S(i).RE - S(i).number_worker*bit*(ETX + Efs*(S(i).distoBS^2));
                end
                if S(i).distoBS >= d0
                    S(i).RE = S(i).RE - S(i).number_worker*bit*(ETX + Emp*(S(i).distoBS^4));                    
                end
            end
        end
    end
    [S.RE]
end


