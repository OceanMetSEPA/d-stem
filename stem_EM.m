%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% D-STEM - Distributed Space Time Expecation Maximization      %
%                                                              %
% Author: Francesco Finazzi                                    %
% E-mail: francesco.finazzi@unibg.it                           %
% Affiliation: University of Bergamo - Dept. of Engineering    %
% Author website: http://www.unibg.it/pers/?francesco.finazzi  %
% Code website: https://code.google.com/p/d-stem/              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

classdef stem_EM < EM
    
    %CONSTANTS
    %N_g = n1_g+...+nq_g - total number of point sites
    %N_r = n1_r+...+nq_r - total number of pixel sites
    %N   = N_g+N_r - total number of observation sites
    %N_b = n1_b+...+nq_b+n1_r+...+nq_r - total number of covariates
    %S   = 2 if both point and pixel data are considered. S = 1 if only point data are considered.
    %T   - number of temporal steps
    %TT  = T if the space-time varying coefficients are time-variant and TT=1 if they are time-invariant
    %p   - dimension of the latent temporal variable z    
   
    properties
        stem_model=[];               %[stem_model object] (1x1)
        stem_EM_options=[];          %[stem_EM_options]   (1x1)
    end
    
    methods
        function obj = stem_EM(stem_model,stem_EM_options)
            %DESCRIPTION: object constructor
            %
            %INPUT
            %stem_model        - [stem_model object] (1x1)
            %stem_EM_options   - [stem_EM_options]   (1x1)
            %
            %OUTPUT
            %obj               - [stem_EM object]    (1x1)
            if nargin<2
                error('All the arguments must be provided');
            end

            if isa(stem_model,'stem_model')
                obj.stem_model=stem_model;
            else
                error('The first argument must be of class stem_model');
            end
            
            if isa(stem_EM_options,'stem_EM_options');
                obj.stem_EM_options=stem_EM_options;
            else
                error('The second argument must be of class stem_EM_options');
            end

            if isempty(obj.stem_model.stem_par_initial)
                error('Initial value estimation for model parameters must be provided first');
            end            
        end
        
        function st_EM_result = estimate(obj)
            %DESCRIPTION: EM estimation
            %
            %INPUT
            %obj            - [stem_EM object]      (1x1)
            %
            %OUTPUT
            %st_EM_result   - [st_EM_result object] (1x1)
            
            t1_full=clock;
            if isempty(obj.stem_model)&&(nargin==0)
                error('You have to set the stem_model property first');
            end
            if isempty(obj.stem_model.stem_par_initial)
                error('Initial value estimation for model parameters must be provided first');
            end
            delta=9999;
            delta_logL=9999;
            last_logL=0;
            last_stem_par=obj.stem_model.stem_par;
            iteration=0;
            st_EM_result=stem_EM_result(); 
            st_EM_result.max_iterations=obj.stem_EM_options.max_iterations;
            st_EM_result.exit_toll=obj.stem_EM_options.exit_toll;
            st_EM_result.machine=computer;
            st_EM_result.date_start=datestr(now);
            while (delta>obj.stem_EM_options.exit_toll)&&(delta_logL>obj.stem_EM_options.exit_toll)&&(iteration<obj.stem_EM_options.max_iterations)
                ct1=clock;
                iteration=iteration+1;
                disp('************************');
                disp(['Iteration ',num2str(iteration),' started...']);
                disp('************************');
                
                clear E_wr_y1
                clear sum_Var_wr_y1
                clear diag_Var_wr_y1
                clear cov_wr_z_y1
                clear E_wg_y1 
                clear sum_Var_wg_y1
                clear diag_Var_wg_y1
                clear cov_wg_z_y1
                clear M_cov_wr_wg_y1
                clear cov_wgk_wgh_y1
                clear diag_Var_e_y1
                clear E_e_y1
                clear sigma_eps
                clear Xbeta

                [E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,sigma_W_r,sigma_W_g,Xbeta,st_kalmansmoother_result] = obj.E_step();
                obj.M_step(E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,st_kalmansmoother_result,iteration);

                st_EM_result.stem_par_all(:,iteration)=obj.stem_model.stem_par.vec;
                if not(isempty(st_kalmansmoother_result))
                    if not(st_kalmansmoother_result.logL==0)
                        logL=st_kalmansmoother_result.logL;
                        st_EM_result.logL_all(iteration)=logL;
                        delta_logL=abs(logL-last_logL)/abs(logL);
                        last_logL=logL;
                        disp('****************');
                        disp( ['logL: ',num2str(logL)]);
                        disp(['relative delta logL: ',num2str(delta_logL)]);
                    else
                       delta_logL=9999; 
                    end
                else
                    delta_logL=9999;
                end
                delta=norm(obj.stem_model.stem_par.vec()-last_stem_par.vec())/norm(last_stem_par.vec());
                last_stem_par=obj.stem_model.stem_par;
                disp(['Norm: ',num2str(delta)]);
                obj.stem_model.stem_par.print;
                ct2=clock;
                disp('**********************************************');
                disp(['Iteration ',num2str(iteration),' ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                disp('**********************************************');
            end
            t2_full=clock;
            st_EM_result.stem_par=obj.stem_model.stem_par;
            st_EM_result.stem_kalmansmoother_result=st_kalmansmoother_result;
            st_EM_result.E_wg_y1=E_wg_y1;
            st_EM_result.E_wr_y1=E_wr_y1;
            st_EM_result.diag_Var_wg_y1=diag_Var_wg_y1;
            st_EM_result.diag_Var_wr_y1=diag_Var_wr_y1;
            st_EM_result.y_hat=obj.stem_model.stem_data.Y;
            st_EM_result.y_hat(isnan(st_EM_result.y_hat))=0;
            st_EM_result.y_hat=st_EM_result.y_hat-E_e_y1;
            st_EM_result.res=obj.stem_model.stem_data.Y-st_EM_result.y_hat;
            
            %DA GENERALIZZARE AL CASO MULTIVARIATO!!
            if obj.stem_model.stem_data.stem_varset_g.standardized
                s=obj.stem_model.stem_data.stem_varset_g.Y_stds{1};
                m=obj.stem_model.stem_data.stem_varset_g.Y_means{1};
            end
            if (obj.stem_model.stem_data.stem_varset_g.standardized)&&not(obj.stem_model.stem_data.stem_varset_g.log_transformed)
                y_hat_back=st_EM_result.y_hat*s+m;
                y=obj.stem_model.stem_data.Y*s+m;
                st_EM_result.y_hat_back=y_hat_back;
                st_EM_result.y_back=y;
                st_EM_result.res_back=y-y_hat_back;
            end
            if (obj.stem_model.stem_data.stem_varset_g.standardized)&&(obj.stem_model.stem_data.stem_varset_g.log_transformed)
                y_hat_back=st_EM_result.y_hat;
                y_hat_back=exp(y_hat_back*s+m+(s^2)/2);
                %y_hat_back=exp(y_hat_back*s+m);
                y=exp(obj.stem_model.stem_data.Y*s+m);
                st_EM_result.y_hat_back=y_hat_back;
                st_EM_result.y_back=y;
                st_EM_result.res_back=y-y_hat_back;
            end
         
            st_EM_result.iterations=iteration;
            st_EM_result.computation_time=etime(t2_full,t1_full);
        end
        
        function st_EM_result = estimate_parallel(obj,pathparallel)
            %DESCRIPTION: EM parallel estimation
            %
            %INPUT
            %obj                  - [stem_EM object]      (1x1)
            %pathparallel         - [string]              (1x1)  full or relative path of the folder to use for distributed computation
            %
            %OUTPUT
            %st_EM_result         - [st_EM_result object] (1x1)            
            t1_full=clock;
            if isempty(obj.stem_model)&&(nargin==0)
                error('You have to set the stem_model property first');
            end
            if isempty(obj.stem_model.stem_par_initial)
                error('Initial value estimation for model parameters must be provided first');
            end
            
            T=obj.stem_model.T;
            K=obj.stem_model.stem_par.k;
            local_efficiency=1;
            delta=9999;
            delta_logL=9999;
            last_logL=0;
            last_stem_par=obj.stem_model.stem_par;
            iteration=0;
            st_EM_result=stem_EM_result(); 
            st_EM_result.max_iterations=obj.stem_EM_options.max_iterations;
            st_EM_result.exit_toll=obj.stem_EM_options.exit_toll;
            st_EM_result.machine=computer;
            st_EM_result.date_start=datestr(now);
            while (delta>obj.stem_EM_options.exit_toll)&&(delta_logL>obj.stem_EM_options.exit_toll)&&(iteration<obj.stem_EM_options.max_iterations)
                ct1_iteration=clock;
                iteration=iteration+1;
                disp('************************');
                disp(['Iteration ',num2str(iteration),' started...']);
                disp('************************');
                
                %repeat the E-step until no timeout occurs
                timeout=1;
                while timeout
                    %set the timeout to zero
                    timeout=0;
                    clear E_wr_y1
                    clear sum_Var_wr_y1
                    clear diag_Var_wr_y1
                    clear cov_wr_z_y1
                    clear E_wg_y1
                    clear sum_Var_wg_y1
                    clear diag_Var_wg_y1
                    clear cov_wg_z_y1
                    clear M_cov_wr_wg_y1
                    clear cov_wgk_wgh_y1
                    clear diag_Var_e_y1
                    clear E_e_y1
                    clear sigma_eps
                    
                    %delete all the file in the exchange directory
                    files=dir([pathparallel,'*.mat']);
                    for i=1:length(files)
                        delete([pathparallel,files(i).name]);
                    end
                    
                    %create the file for the whoishere request
                    disp('  Looking for distributed clients...');
                    whoishere.IDrequest=unifrnd(0,100000,1,1);

                    save([pathparallel,'temp/whoishere.mat'],'whoishere');
                    pause(0.5);
                    movefile([pathparallel,'temp/whoishere.mat'],[pathparallel,'whoishere.mat']);
                   
                    if iteration==1
                        hosts=[];
                    end
                    nhosts=length(hosts);
                    
                    %wait for the replies from the clients
                    wait1=clock;
                    exit=0;
                    while not(exit)
                        files=dir([pathparallel,'machine_*.*']);
                        for i=1:length(files)
                            try
                                load([pathparallel,files(i).name])
                                if machine.IDrequest==whoishere.IDrequest
                                    %check if the client is already in the hosts list
                                    idx=[];
                                    for j=1:nhosts
                                        if hosts(j).node_code==machine.node_code
                                            hosts(j).active=1;
                                            hosts(j).require_stemmodel=machine.require_stemmodel;
                                            idx=j;
                                        end
                                    end
                                    %if not, add the client
                                    if isempty(idx)
                                        nhosts=nhosts+1;
                                        hosts(nhosts).node_code=machine.node_code;
                                        hosts(nhosts).data_received=0;
                                        %the first time a client is added it has the efficiency of the server
                                        hosts(nhosts).efficiency=local_efficiency;
                                        hosts(nhosts).require_stemmodel=machine.require_stemmodel;
                                        hosts(nhosts).active=1;
                                    end
                                end
                            catch
                            end
                        end
                        wait2=clock;
                        if etime(wait2,wait1)>120 %120 seconds timeout
                            exit=1;
                        end
                        pause(0.1);
                    end
                    delete([pathparallel,'whoishere.mat']);
                    %check for inactive clients
                    idx=[];
                    for i=1:nhosts
                        if hosts(i).active==0
                            idx=[idx i];
                        end
                    end
                    if not(isempty(idx))
                        hosts(idx)=[];
                        nhosts=length(hosts);
                    end
                    
                    %if there is at least one client then distribute the st_model
                    if nhosts>=1
                        disp(['  ',num2str(nhosts),' parallel client(s) found']);
                        disp('  Saving st_model to distribute');
                        st_model=obj.stem_model;
                        for i=1:nhosts
                            if hosts(i).require_stemmodel
                                save([pathparallel,'temp/st_model_parallel_',num2str(hosts(i).node_code),'.mat'],'st_model','-v7.3');
                                movefile([pathparallel,'temp/st_model_parallel_',num2str(hosts(i).node_code),'.mat'],[pathparallel,'st_model_parallel_',num2str(hosts(i).node_code),'.mat']);
                            end
                        end
                    else
                        disp('  No clients found. Only the server is used');
                    end
                   
                    if nhosts>=1
                        %the st_par to be distributed is the same for all the clients
                        disp('  Saving st_par to distribute')
                        st_par=obj.stem_model.stem_par;
                        for i=1:nhosts
                            save([pathparallel,'temp/st_par_parallel_',num2str(hosts(i).node_code),'.mat'],'st_par');
                            movefile([pathparallel,'temp/st_par_parallel_',num2str(hosts(i).node_code),'.mat'],[pathparallel,'st_par_parallel_',num2str(hosts(i).node_code),'.mat']);
                        end
                        clear st_par
                    end
                    
                    Lt_all=sum(not(isnan(obj.stem_model.stem_data.Y)));
                    Lt_sum=sum(Lt_all);
                    Lt_csum=cumsum(Lt_all);
                    veff=local_efficiency;
                    for i=1:nhosts
                        veff=[veff hosts(i).efficiency];
                    end
                    veff=veff/sum(veff);
                    veff=[0 cumsum(veff)];
                    if not(veff(end)==1)
                        veff(end)=1;
                    end
                    %compute the time_steps for the server
                    l1=Lt_sum*veff(1);
                    l2=Lt_sum*veff(2);
                    t1=find(Lt_csum>l1,1);
                    t2=find(Lt_csum>=l2,1);
                    time_steps=t1:t2;
                    local_cb=sum(Lt_all(time_steps));
                    disp(['  ',num2str(length(time_steps)),' time will be assigned to the server machine']);                    
                    
                    %Kalman smoother
                    if obj.stem_model.stem_par.p>0
                        %distribute the st_par and the data needed to the clients
                        if nhosts>=1
                            disp('  Saving the Kalman data structure to distribute')
                            %send the information for the computation of the parallel kalman
                            data.iteration=iteration;
                            last_t2=t2;
                            for i=1:nhosts
                                %compute the time_steps for the clients
                                l1=Lt_sum*veff(i+1);
                                l2=Lt_sum*veff(i+2);
                                t1=find(Lt_csum>l1,1);
                                if t1<=last_t2
                                    t1=last_t2+1;
                                end
                                t2=find(Lt_csum>=l2,1);
                                if t2<t1
                                    t2=t1;
                                end
                                data.time_steps=t1:t2;
                                last_t2=t2;
                                disp(['  ',num2str(length(data.time_steps)),' time steps assigned to client ',num2str(hosts(i).node_code)]);
                                save([pathparallel,'temp/kalman_parallel_',num2str(hosts(i).node_code),'.mat'],'data');
                                movefile([pathparallel,'temp/kalman_parallel_',num2str(hosts(i).node_code),'.mat'],[pathparallel,'kalman_parallel_',num2str(hosts(i).node_code),'.mat']);
                            end
                            %local Kalman Smoother computation
                            st_kalman=stem_kalman(obj.stem_model);
                            [st_kalmansmoother_result,sigma_eps,~,~,~,~,~,~,~] = st_kalman.smoother(obj.stem_EM_options.compute_logL_at_all_steps,0,time_steps,pathparallel);
                        else
                            %The computation is only local. The standard Kalman smoother is considered
                            st_kalman=stem_kalman(obj.stem_model);
                            [st_kalmansmoother_result,sigma_eps,~,~,~,~,~,~,~] = st_kalman.smoother(obj.stem_EM_options.compute_logL_at_all_steps,0);
                            time_steps=1:T;
                        end
                    else
                        st_kalmansmoother_result=[];
                        %sigma_eps
                        d=[];
                        dim=obj.stem_model.stem_data.dim;
                        for i=1:obj.stem_model.stem_data.nvar
                            d=[d;repmat(obj.stem_model.stem_par.sigma_eps(i,i),dim(i),1)];
                        end
                        sigma_eps=diag(d);
                    end
                    
                    ct1_distributed=clock;
                    disp('  Saving the E-step data structure to distribute')
                    data.st_kalmansmoother_result=st_kalmansmoother_result;
                    data.iteration=iteration;
                    
                    l2=Lt_sum*veff(2);
                    t2=find(Lt_csum>=l2,1);
                    last_t2=t2;
                    for i=1:nhosts
                        %compute the time_steps for the clients
                        l1=Lt_sum*veff(i+1);
                        l2=Lt_sum*veff(i+2);
                        t1=find(Lt_csum>l1,1);
                        if t1<=last_t2
                            t1=last_t2+1;
                        end
                        t2=find(Lt_csum>=l2,1);
                        if t2<t1
                            t2=t1;
                        end
                        data.time_steps=t1:t2;
                        data.cb=sum(Lt_all(data.time_steps));
                        last_t2=t2;
                        disp(['  ',num2str(length(data.time_steps)),' time steps assigned to client ',num2str(hosts(i).node_code)]);
                        save([pathparallel,'temp/data_parallel_',num2str(hosts(i).node_code),'.mat'],'data');
                        movefile([pathparallel,'temp/data_parallel_',num2str(hosts(i).node_code),'.mat'],[pathparallel,'data_parallel_',num2str(hosts(i).node_code),'.mat']);
                    end
                    clear data

                    %local E-step computation
                    ct1_local=clock;
                    [E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1] = obj.E_step_parallel(time_steps,st_kalmansmoother_result);
                    ct2_local=clock;
                    local_efficiency=local_cb/etime(ct2_local,ct1_local);
                    disp(['    Local computation time: ',num2str(etime(ct2_local,ct1_local))]);
                    disp(['    Local efficiency: ',num2str(local_efficiency)]);
                    
                    if nhosts>=1
                        disp('    Waiting for the results from the client(s)...');
                        exit=0;
                        wait1=clock;
                        while not(exit)
                            files=dir([pathparallel,'output_*.*']);
                            for i=1:length(files)
                                ct2_distributed=clock;
                                load([pathparallel,files(i).name]);
                                disp(['    Received output file from client ',num2str(output.node_code)]);
                                if iteration==output.iteration
                                    idx=[];
                                    for j=1:nhosts
                                        if (hosts(j).node_code==output.node_code)&&(hosts(j).data_received==0)
                                            idx=j;
                                        end
                                    end
                                    if not(isempty(idx))
                                        disp('    The data from the client was expected');
                                        hosts(idx).efficiency=output.cb/output.ct;
                                        disp(['    Computational time of client ',num2str(hosts(idx).node_code),': ',num2str(output.ct)]);
                                        disp(['    Efficiency of client ',num2str(hosts(idx).node_code),': ',num2str(hosts(idx).efficiency)]);
                                        tsteps=output.time_steps;
                                        if not(isempty(E_wr_y1))
                                            E_wr_y1(:,tsteps)=output.E_wr_y1;
                                        end
                                        if not(isempty(sum_Var_wr_y1))
                                            %the matrix is recomposed since only the upper triangular part is received
                                            sum_Var_wr_y1=sum_Var_wr_y1+output.sum_Var_wr_y1+triu(output.sum_Var_wr_y1,1)';
                                        end
                                        if not(isempty(diag_Var_wr_y1))
                                            diag_Var_wr_y1(:,tsteps)=output.diag_Var_wr_y1;
                                        end
                                        if not(isempty(cov_wr_z_y1))
                                            cov_wr_z_y1(:,:,tsteps)=output.cov_wr_z_y1;
                                        end
                                        if not(isempty(E_wg_y1))
                                            for k=1:K
                                                E_wg_y1(:,tsteps,k)=output.E_wg_y1(:,:,k);
                                            end
                                        end
                                        if not(isempty(sum_Var_wg_y1))
                                            for k=1:K
                                                %the matrix is recomposed since only the upper triangular part is received
                                                sum_Var_wg_y1{k}=sum_Var_wg_y1{k}+output.sum_Var_wg_y1{k}+triu(output.sum_Var_wg_y1{k},1)';
                                            end
                                        end
                                        if not(isempty(diag_Var_wg_y1))
                                            for k=1:K
                                                diag_Var_wg_y1(:,tsteps,k)=output.diag_Var_wg_y1(:,:,k);
                                            end
                                        end
                                        if not(isempty(cov_wg_z_y1))
                                            for k=1:K
                                                cov_wg_z_y1(:,:,tsteps,k)=output.cov_wg_z_y1(:,:,:,k);
                                            end
                                        end
                                        if not(isempty(M_cov_wr_wg_y1))
                                            for k=1:K
                                                M_cov_wr_wg_y1(:,tsteps,k)=output.M_cov_wr_wg_y1(:,:,k);
                                            end
                                        end
                                        if iscell(cov_wgk_wgh_y1)
                                            for h=1:K
                                                for k=h+1:K
                                                    cov_wgk_wgh_y1{k,h}(:,tsteps)=output.cov_wgk_wgh_y1{k,h};
                                                end
                                            end
                                        end
                                        diag_Var_e_y1(:,tsteps)=output.diag_Var_e_y1;
                                        E_e_y1(:,tsteps)=output.E_e_y1;
                                        
                                        hosts(idx).data_received=1;
                                        clear output
                                    else
                                        disp('    Something is wrong');
                                    end
                                    exit=1;
                                    for j=1:nhosts
                                        if hosts(j).data_received==0
                                            exit=0;
                                        end
                                    end
                                    if exit==1
                                        disp('    All the data from the client(s) have been collected');
                                    end
                                else
                                    disp('    The iteration within the output file does not match. The file is deleted');
                                end
                                deleted=0;
                                while not(deleted)
                                    try
                                        delete([pathparallel,files(i).name]);
                                        deleted=1;
                                    catch
                                    end
                                end
                            end
                            wait2=clock;
                            if etime(wait2,wait1)>72000 %two hours
                                disp('    Timeout');
                                timeout=1;
                                exit=1;
                            end
                            pause(0.02);
                        end
                    end
                    
                    for i=1:nhosts
                        hosts(i).active=0;
                        hosts(i).data_received=0;
                    end
                end
                
                clear data
                if (K<=1)
                    %run the non parallel version of the M-step
                    obj.M_step(E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,st_kalmansmoother_result,iteration);
                    %send the message to the other machine that they don't have to run the M-step
                    for i=1:nhosts
                        data.iteration=iteration;
                        data.index=[];
                        save([pathparallel,'temp/data_parallel_mstep',num2str(hosts(i).node_code),'.mat'],'data');
                        movefile([pathparallel,'temp/data_parallel_mstep',num2str(hosts(i).node_code),'.mat'],[pathparallel,'data_parallel_mstep',num2str(hosts(i).node_code),'.mat']);
                    end
                else
                    step=ceil(K/(nhosts+1));
                    counter=1;
                    for i=1:nhosts+1
                        if (i==1)
                            index_local=counter:step+counter-1;
                        else
                            index{i-1}=counter:step+counter-1;
                            index{i-1}(index{i-1}>K)=[];
                        end
                        counter=counter+step;
                    end
                    %send the messages to the host
                    clear data
                    for i=1:nhosts
                        data.iteration=iteration;
                        data.index=index{i};
                        disp(['    Preparing M-step data for client ',num2str(hosts(i).node_code)]);
                        data.sum_Var_wg_y1=sum_Var_wg_y1(index{i});
                        data.E_wg_y1=E_wg_y1(:,:,index{i});
                        disp(['    Sending M-step data to client ',num2str(hosts(i).node_code)]);
                        save([pathparallel,'temp/data_parallel_mstep',num2str(hosts(i).node_code),'.mat'],'data');
                        movefile([pathparallel,'temp/data_parallel_mstep',num2str(hosts(i).node_code),'.mat'],[pathparallel,'data_parallel_mstep',num2str(hosts(i).node_code),'.mat']);
                        disp(['    M-Step data sent.']);
                    end
                    %M-step locale
                    obj.M_step_parallel(E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,st_kalmansmoother_result,index_local);
                end
                
                %Attende la ricezione dagli altri nodi
                if nhosts>0
                    disp(['  Wait for output_mstep from the client(s)']);
                    exit=0;
                    while not(exit)
                        files=dir([pathparallel,'output_mstep_*.*']);
                        for i=1:length(files)
                            % try
                            ct2_distributed=clock;
                            load([pathparallel,files(i).name]);
                            disp(['  Received output_mstep file from client ',num2str(output.node_code)]);
                            if iteration==output.iteration
                                idx=[];
                                for j=1:nhosts
                                    if (hosts(j).node_code==output.node_code)&&(hosts(j).data_received==0)
                                        idx=j;
                                    end
                                end
                                if not(isempty(idx))
                                    disp('  The output_mstep from the client was expected');
                                    if not(isempty(output.index))
                                        for z=1:length(output.index)
                                            obj.stem_model.stem_par.v_g(:,:,output.index(z))=output.mstep_par.v_g(:,:,output.index(z));
                                            obj.stem_model.stem_par.theta_g(output.index(z))=output.mstep_par.theta_g(output.index(z));
                                            disp(['  ',num2str(output.index(z)),'th component of vg and theta_g updated']);
                                        end
                                    else
                                        disp('  The output_mstep data from the client is empty');
                                    end
                                    hosts(idx).data_received=1;
                                    clear output
                                else
                                    disp('    Something is wrong');
                                end
                                exit=1;
                                for j=1:nhosts
                                    if hosts(j).data_received==0
                                        exit=0;
                                    end
                                end
                                if exit==1
                                    disp('  All the M-step data from the client(s) have been collected');
                                end
                            else
                                disp('    The iteration within the output file does not match. The file is deleted');
                            end
                            deleted=0;
                            while not(deleted)
                                try
                                    delete([pathparallel,files(i).name]);
                                    deleted=1;
                                catch
                                end
                            end
                            %catch
                            %end
                        end
                        wait2=clock;
                        if etime(wait2,wait1)>72000 %two hours
                            disp('    Timeout');
                            timeout=1;
                            exit=1;
                        end
                        pause(0.05);
                    end
                    for i=1:nhosts
                        hosts(i).active=0;
                        hosts(i).data_received=0;
                    end
                end

                if not(isempty(st_kalmansmoother_result))
                    if not(st_kalmansmoother_result.logL==0)
                        logL=st_kalmansmoother_result.logL;
                        st_EM_result.logL_all(iteration)=logL;
                        delta_logL=abs(logL-last_logL)/abs(logL);
                        last_logL=logL;
                        disp('****************');
                        disp( ['logL: ',num2str(logL)]);
                        disp(['relative delta logL: ',num2str(delta_logL)]);
                    else
                       delta_logL=9999; 
                    end
                else
                    delta_logL=9999;
                end
                delta=norm(obj.stem_model.stem_par.vec()-last_stem_par.vec())/norm(last_stem_par.vec());
                last_stem_par=obj.stem_model.stem_par;
                disp(['Norm: ',num2str(delta)]);
                obj.stem_model.stem_par.print;
                ct2_iteration=clock;
                disp('**********************************************');
                disp(['Iteration ',num2str(iteration),' ended in ',stem_misc.decode_time(etime(ct2_iteration,ct1_iteration))]);
                disp('**********************************************');
            end
            t2_full=clock;
            st_EM_result.stem_par=obj.stem_model.stem_par;
            st_EM_result.stem_kalmansmoother_result=st_kalmansmoother_result;
            st_EM_result.E_wg_y1=E_wg_y1;
            st_EM_result.E_wr_y1=E_wr_y1;
            st_EM_result.diag_Var_wg_y1=diag_Var_wg_y1;
            st_EM_result.diag_Var_wr_y1=diag_Var_wr_y1;
            st_EM_result.iterations=iteration;
            st_EM_result.computation_time=etime(t2_full,t1_full);
        end        
        
        function [E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,sigma_W_r,sigma_W_g,Xbeta,st_kalmansmoother_result] = E_step(obj,T)
            %DESCRIPTION: E-step of the EM algorithm
            %
            %INPUT
            %obj                            - [stem_EM object]  (1x1)
            %<T>                            - [integer >0]      (1x1) The E-step is computed only for the data related to the time steps between 1 and T
            %
            %OUTPUT
            %E_wr_y1                        - [double]          (N_rxT) E[wr|Y(1)] conditional expectation of w_r_t with respect to the observed data Y(1)
            %sum_Var_wr_y1                  - [doulbe]          (N_rxN_r) sum(Var[wr|Y(1)]) sum with respect to time of the conditional variance of w_r_t with respect to the observed data
            %diag_Var_wr_y1                 - [double]          (N_rxT) diagonals of Var[wr|Y(1)]
            %cov_wr_z_y1                    - [double]          (N_rxpxT) cov[wr,z_t|Y(1)]
            %E_wg_y1                        - [double]          (N_gxTxK) E[wg|Y(1)]
            %sum_Var_wg_y1                  - [double]          {k}(N_gxN_g) sum(Var[wg_k|Y(1)])
            %diag_Var_wg_y1                 - [double]          (N_gxTxK) diagonals of Var[wg|Y(1)]
            %cov_wg_z_y1                    - [double]          (N_gxpxTxK) cov[wg,z|Y(1)]
            %M_cov_wr_wg_y1                 - [double]          (NxTxK)
            %cov_wgk_wgh_y1                 - [double]          {KxK}(N_gxT) cov[wg_k,wg_h|Y(1)] k,h=1,...,K
            %diag_Var_e_y1                  - [double]          (NxT) diagonals of Var[e|Y(1)]
            %E_e_y1                         - [double]          (NxT) E[e|Y(1)]
            %sigma_eps                      - [double]          (NxN) sigma_eps
            %sigma_W_r                      - [double]          (N_rxN_r) sigma_wr
            %sigma_W_g                      - [double]          {k}(N_gxN_g) sigma_wg
            %Xbeta                          - [double]          (NxT) X*beta'
            %st_kalmansmoother_result       - [stem_kalmansmoother_result object] (1x1)

            if nargin==1
                T=obj.stem_model.stem_data.T;
            end
            N=obj.stem_model.stem_data.N;
            if not(isempty(obj.stem_model.stem_data.stem_varset_r))
                Nr=obj.stem_model.stem_data.stem_varset_r.N;
            else
                Nr=0;
            end
            Ng=obj.stem_model.stem_data.stem_varset_g.N;
            
            K=obj.stem_model.stem_par.k;
            p=obj.stem_model.stem_par.p;
            par=obj.stem_model.stem_par;

            disp('  E step started...');
            ct1_estep=clock;
            
            if p>0
                %Kalman smoother
                st_kalman=stem_kalman(obj.stem_model);
                [st_kalmansmoother_result,sigma_eps,sigma_W_r,sigma_W_g,sigma_Z,aj_rg,aj_g,M,sigma_geo] = st_kalman.smoother(obj.stem_EM_options.compute_logL_at_all_steps,0);
                if not(obj.stem_model.stem_data.X_z_tv)&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    if obj.stem_model.tapering
                        %migliorare la creazione della matrice sparsa!!!
                        var_Zt=sparse(obj.stem_model.stem_data.X_z(:,:,1))*sparse(sigma_Z)*sparse(obj.stem_model.stem_data.X_z(:,:,1)');
                        if (size(obj.stem_model.stem_data.X_z(:,:,1),1)<N)
                            var_Zt=blkdiag(var_Zt,speye(N-size(obj.stem_model.stem_data.X_z(:,:,1),1)));
                        end
                    else
                        var_Zt=obj.stem_model.stem_data.X_z(:,:,1)*sigma_Z*obj.stem_model.stem_data.X_z(:,:,1)';
                        if (size(obj.stem_model.stem_data.X_z(:,:,1),1)<N)
                            var_Zt=blkdiag(var_Zt,eye(N-size(obj.stem_model.stem_data.X_z(:,:,1),1)));
                        end
                    end
                end
                if not(isempty(sigma_geo))&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    var_Yt=sigma_geo+var_Zt;
                end
            else
                [sigma_eps,sigma_W_r,sigma_W_g,sigma_geo,~,aj_rg,aj_g,M] = obj.stem_model.get_sigma();
                st_kalmansmoother_result=stem_kalmansmoother_result([],[],[],[],[]);
                var_Zt=[];
                
                if not(isempty(sigma_geo))&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    var_Yt=sigma_geo; %sigma_geo includes sigma_eps
                end
            end
            
            if obj.stem_model.stem_par.clustering==1
                obj.stem_model.stem_data.stem_varset_g.Y{1}=[];
            end
            
            E_e_y1=obj.stem_model.stem_data.Y;
            E_e_y1(isnan(E_e_y1))=0;
            if not(isempty(obj.stem_model.stem_data.X_beta))
                disp('    Xbeta evaluation started...');
                ct1=clock;
                Xbeta=zeros(N,T);
                if obj.stem_model.stem_data.X_beta_tv
                    for t=1:T
                        if size(obj.stem_model.stem_data.X_beta(:,:,t),1)<N
                            X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,t);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,t),1),size(obj.stem_model.stem_data.X_beta(:,:,t),2))];
                        else
                            X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,t);
                        end
                        Xbeta(:,t)=X_beta_orlated*par.beta;
                    end
                else
                    if size(obj.stem_model.stem_data.X_beta(:,:,1),1)<N
                        X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,1);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,1),1),size(obj.stem_model.stem_data.X_beta(:,:,1),2))];
                    else
                        X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,1);
                    end
                    Xbeta=repmat(X_beta_orlated*par.beta,1,T);
                end
                ct2=clock;
                disp(['    Xbeta evaluation ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                E_e_y1=E_e_y1-Xbeta;
            else
                Xbeta=[];
            end
            diag_Var_e_y1=zeros(N,T,'single');
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %   Conditional expectation, conditional variance and conditional covariance evaluation  %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %sigma_Z=Var(Zt)
            %var_Zt=Var(X_z*Zt*X_z')
            
            disp('    Conditional E, Var, Cov evaluation started...');
            ct1=clock;
            %cov_wr_yz time invariant case
            if not(isempty(obj.stem_model.stem_data.X_rg))
                if (obj.stem_model.tapering)
                    Lr=find(sigma_W_r);
                    [Ir,Jr]=ind2sub(size(sigma_W_r),Lr);
                    nnz_r=length(Ir);
                end
                
                if not(obj.stem_model.stem_data.X_rg_tv)
                    cov_wr_y=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'r'),obj.stem_model.stem_data.X_rg(:,1,1),'r'),aj_rg,'r');
                end
                E_wr_y1=zeros(Nr,T);
                if (obj.stem_model.tapering)
                    sum_Var_wr_y1=spalloc(size(sigma_W_r,1),size(sigma_W_r,2),nnz_r);
                else
                    sum_Var_wr_y1=zeros(Nr);
                end
                diag_Var_wr_y1=zeros(Nr,T);
                cov_wr_z_y1=zeros(Nr,p,T);
            end
            
            %cov_wg_yz time invariant case
            if not(isempty(obj.stem_model.stem_data.X_g))
                if obj.stem_model.tapering
                    Lg=find(sigma_W_g{1});
                    [Ig,Jg]=ind2sub(size(sigma_W_g{1}),Lg);
                    nnz_g=length(Ig);
                end
                if not(obj.stem_model.stem_data.X_g_tv)
                    for k=1:K
                        cov_wg_y{k}=stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,1,k),'r'),aj_g(:,k),'r');
                    end
                end
                for h=1:K
                    for k=h+1:K
                        %VERIFICARE SE PU� ESSERE SPARSA!!!
                        cov_wgk_wgh_y1{k,h}=zeros(Ng,T);
                    end
                end
                E_wg_y1=zeros(Ng,T,K);
                for k=1:K
                    if obj.stem_model.tapering
                        sum_Var_wg_y1{k}=spalloc(size(sigma_W_g{k},1),size(sigma_W_g{k},2),nnz_g);
                    else
                        sum_Var_wg_y1{k}=zeros(Ng,Ng);
                    end
                end
                diag_Var_wg_y1=zeros(Ng,T,K);
                cov_wg_z_y1=zeros(Ng,p,T,K);
            end
            
            if not(isempty(obj.stem_model.stem_data.X_rg)) && not(isempty(obj.stem_model.stem_data.X_g))
                M_cov_wr_wg_y1=zeros(N,T,K);
            else
                M_cov_wr_wg_y1=[];
            end
            
            for t=1:T
                t_partial1=clock;
                %missing at time t
                Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                
                if obj.stem_model.stem_data.X_rg_tv
                    tRG=t;
                else
                    tRG=1;
                end
                if obj.stem_model.stem_data.X_z_tv
                    tT=t;
                else
                    tT=1;
                end
                if obj.stem_model.stem_data.X_g_tv
                    tG=t;
                else
                    tG=1;
                end
                
                %evaluate var_yt in the time variant case
                if obj.stem_model.stem_data.X_tv
                    if not(isempty(obj.stem_model.stem_data.X_rg))
                        sigma_geo=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'b'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),aj_rg,'b');
                    end
                    
                    if not(isempty(obj.stem_model.stem_data.X_g))
                        if isempty(obj.stem_model.stem_data.X_rg)
                            if obj.stem_model.tapering
                                sigma_geo=spalloc(size(sigma_W_g{1},1),size(sigma_W_g{1},1),nnz(sigma_W_g{1}));
                            else
                                sigma_geo=zeros(N);
                            end
                        end
                        for k=1:size(obj.stem_model.stem_data.X_g,4)
                            sigma_geo=sigma_geo+stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,tG,k),'b'),aj_g(:,k),'b');
                        end
                    end
                    if isempty(obj.stem_model.stem_data.X_g)&&isempty(obj.stem_model.stem_data.X_rg)
                        sigma_geo=sigma_eps;
                    else
                        sigma_geo=sigma_geo+sigma_eps;
                    end
                    
                    if not(isempty(obj.stem_model.stem_data.X_z))
                        if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                            if obj.stem_model.stem_data.X_z_tv
                                if obj.stem_model.tapering
                                    var_Zt=sparse(obj.stem_model.stem_data.X_z(:,:,tT))*sparse(sigma_Z)*sparse(obj.stem_model.stem_data.X_z(:,:,tT)');
                                    if (size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N)
                                        var_Zt=blkdiag(var_Zt,speye(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1)));
                                    end
                                else
                                    var_Zt=obj.stem_model.stem_data.X_z(:,:,tT)*sigma_Z*obj.stem_model.stem_data.X_z(:,:,tT)';
                                    if (size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N)
                                        var_Zt=blkdiag(var_Zt,eye(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1)));
                                    end
                                end
                            end
                            var_Yt=sigma_geo+var_Zt;
                        end
                    else
                        if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                            var_Yt=sigma_geo;
                        end
                    end
                end
                
                %check if the temporal loadings are time variant
                if not(isempty(obj.stem_model.stem_data.X_z))
                    if size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N
                        X_z_orlated=[obj.stem_model.stem_data.X_z(:,:,tT);zeros(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1),size(obj.stem_model.stem_data.X_z(:,:,tT),2))];
                        orlated=true;
                    else
                        orlated=false;
                    end
                    
                    if N>obj.stem_model.system_size
                        blocks=0:80:size(diag_Var_e_y1,1);
                        if not(blocks(end)==size(diag_Var_e_y1,1))
                            blocks=[blocks size(diag_Var_e_y1,1)];
                        end
                        for i=1:length(blocks)-1
                            if orlated
                                diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag(X_z_orlated(blocks(i)+1:blocks(i+1),:)*st_kalmansmoother_result.Pk_s(:,:,t+1)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                            else
                                diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag(obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)*st_kalmansmoother_result.Pk_s(:,:,t+1)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                            end
                        end
                    else
                        if orlated
                            temp=X_z_orlated*st_kalmansmoother_result.Pk_s(:,:,t+1);
                            diag_Var_e_y1(:,t)=diag(temp*X_z_orlated');
                        else
                            temp=obj.stem_model.stem_data.X_z(:,:,tT)*st_kalmansmoother_result.Pk_s(:,:,t+1);
                            diag_Var_e_y1(:,t)=diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                        end
                    end
                    %update E(e|y1)
                    temp=st_kalmansmoother_result.zk_s(:,t+1);
                    if orlated
                        E_e_y1(:,t)=E_e_y1(:,t)-X_z_orlated*temp;
                    else
                        E_e_y1(:,t)=E_e_y1(:,t)-obj.stem_model.stem_data.X_z(:,:,tT)*temp;
                    end
                end
                
                if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                    %build the Ht matrix
                    if not(isempty(var_Zt))
                        if orlated
                            H1t=[var_Yt(Lt,Lt), X_z_orlated(Lt,:)*sigma_Z; sigma_Z*X_z_orlated(Lt,:)', sigma_Z];
                        else
                            H1t=[var_Yt(Lt,Lt), obj.stem_model.stem_data.X_z(Lt,:,tT)*sigma_Z; sigma_Z*obj.stem_model.stem_data.X_z(Lt,:,tT)', sigma_Z];
                        end
                    else
                        H1t=var_Yt(Lt,Lt);
                        temp=[];
                    end
                    
                    res=obj.stem_model.stem_data.Y;
                    if not(isempty(Xbeta))
                        res=res-Xbeta;
                    end
                    if obj.stem_model.tapering
                        cs=[];
                        r = symamd(H1t);
                        chol_H1t=chol(H1t(r,r));
                        temp2=[res(Lt,t);temp];
                        cs(r,1)=stem_misc.chol_solve(chol_H1t,temp2(r));
                    else
                        chol_H1t=chol(H1t);
                        cs=stem_misc.chol_solve(chol_H1t,[res(Lt,t);temp]);
                    end
                end
                
                if not(isempty(obj.stem_model.stem_data.X_rg))
                    %check if the pixel loadings are time variant
                    if obj.stem_model.stem_data.X_rg_tv
                        %cov_wr_yz time variant case
                        cov_wr_y=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'r'),obj.stem_model.stem_data.X_rg(:,1,tRG),'r'),aj_rg,'r');
                    end
                    cov_wr_y1z=[cov_wr_y(:,Lt),zeros(size(cov_wr_y,1),p)];
                    %compute E(w_r|y1);
                    E_wr_y1(:,t)=cov_wr_y1z*cs;
                    %compute Var(w_r|y1)
                    if obj.stem_model.tapering
                        temp_r(r,:)=stem_misc.chol_solve(chol_H1t,cov_wr_y1z(:,r)',1);
                        blocks=0:200:size(cov_wr_y1z,1);
                        if not(blocks(end)==size(cov_wr_y1z,1))
                            blocks=[blocks size(cov_wr_y1z,1)];
                        end
                        Id=[];
                        Jd=[];
                        elements=[];
                        for i=1:length(blocks)-1
                            temp_r2=cov_wr_y1z(blocks(i)+1:blocks(i+1),:)*temp_r;  
                            idx=find(temp_r2);
                            [idx_I,idx_J]=ind2sub(size(temp_r2),idx);
                            Id=[Id;idx_I+blocks(i)];
                            Jd=[Jd;idx_J];
                            elements=[elements;temp_r2(idx)];
                        end
                        Var_wr_y1=sigma_W_r-sparse(Id,Jd,elements,size(sigma_W_r,1),size(sigma_W_r,2));
                    else
                        temp_r=stem_misc.chol_solve(chol_H1t,cov_wr_y1z');
                        Var_wr_y1=sigma_W_r-cov_wr_y1z*temp_r;
                    end
                    
                    if p>0
                        %compute cov(w_r,z|y1)
                        cov_wr_z_y1(:,:,t)=temp_r(end-p+1:end,:)'*st_kalmansmoother_result.Pk_s(:,:,t+1);
                        Var_wr_y1=Var_wr_y1+cov_wr_z_y1(:,:,t)*temp_r(end-p+1:end,:);
                        %update diag(Var(e|y1))
                        temp=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(cov_wr_z_y1(:,:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                        if N>obj.stem_model.system_size
                            blocks=0:80:size(diag_Var_e_y1,1);
                            if not(blocks(end)==size(diag_Var_e_y1,1))
                                blocks=[blocks size(diag_Var_e_y1,1)];
                            end
                            for i=1:length(blocks)-1
                                if orlated
                                    diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)'); %note 2*
                                else
                                    diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)'); %note 2*
                                end
                            end
                        else
                            %faster for N small
                            if orlated
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*X_z_orlated');
                            else
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                            end
                        end
                    else
                        cov_wr_z_y1=[];
                    end
                    %compute diag(Var(w_r|y1))
                    diag_Var_wr_y1(:,t)=diag(Var_wr_y1);
                    %compute sum(Var(w_r|y1))
                    sum_Var_wr_y1=sum_Var_wr_y1+Var_wr_y1;
                    %update E(e|y1)
                    E_e_y1(:,t)=E_e_y1(:,t)-stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                    %update diag(Var(e|y1))
                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(diag_Var_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),aj_rg,'b');
                else
                    E_wr_y1=[];
                    diag_Var_wr_y1=[];
                    sum_Var_wr_y1=[];
                    cov_wr_z_y1=[];
                end
                clear temp_r
                if not(isempty(obj.stem_model.stem_data.X_g))
                    %check if the point loadings are time variant
                    if obj.stem_model.stem_data.X_g_tv
                        %cov_wg_yz time invariant case
                        for k=1:K
                            cov_wg_y{k}=stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,tG,k),'r'),aj_g(:,k),'r');
                        end
                    end
                    for k=1:K
                        cov_wg_y1z=[cov_wg_y{k}(:,Lt) zeros(size(cov_wg_y{k},1),p)];
                        %compute E(w_g_k|y1);
                        E_wg_y1(:,t,k)=cov_wg_y1z*cs;
                        %compute Var(w_g_k|y1)
                        if obj.stem_model.tapering
                            temp_g{k}(r,:)=stem_misc.chol_solve(chol_H1t,cov_wg_y1z(:,r)',1);
                            blocks=0:200:size(cov_wg_y1z,1);
                            if not(blocks(end)==size(cov_wg_y1z,1))
                                blocks=[blocks size(cov_wg_y1z,1)];
                            end
                            Id=[];
                            Jd=[];
                            elements=[];
                            for i=1:length(blocks)-1
                                temp_g2=cov_wg_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{k};
                                idx=find(temp_g2);
                                [idx_I,idx_J]=ind2sub(size(temp_g2),idx);
                                Id=[Id;idx_I+blocks(i)];
                                Jd=[Jd;idx_J];
                                elements=[elements;temp_g2(idx)];
                            end
                            Var_wg_y1=sigma_W_g{k}-sparse(Id,Jd,elements,size(sigma_W_g{k},1),size(sigma_W_g{k},2));
                        else
                            temp_g{k}=stem_misc.chol_solve(chol_H1t,cov_wg_y1z');
                            Var_wg_y1=sigma_W_g{k}-cov_wg_y1z*temp_g{k};
                        end
                        
                        if p>0
                            %compute cov(w_g,z|y1)
                            cov_wg_z_y1(:,:,t,k)=temp_g{k}(end-p+1:end,:)'*st_kalmansmoother_result.Pk_s(:,:,t+1);
                            Var_wg_y1=Var_wg_y1+cov_wg_z_y1(:,:,t,k)*temp_g{k}(end-p+1:end,:);
                            %update diag(Var(e|y1))
                            temp=stem_misc.D_apply(stem_misc.D_apply(cov_wg_z_y1(:,:,t,k),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                            if N>obj.stem_model.system_size
                                blocks=0:80:size(diag_Var_e_y1,1);
                                if not(blocks(end)==size(diag_Var_e_y1,1))
                                    blocks=[blocks size(diag_Var_e_y1,1)];
                                end
                                for i=1:length(blocks)-1
                                    if orlated
                                        diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)'); %note 2*
                                    else
                                        diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)'); %note 2*
                                    end
                                end
                            else
                                if orlated
                                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*X_z_orlated');
                                else
                                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                                end
                            end
                        else
                            cov_wg_z_y1=[];
                        end
                        diag_Var_wg_y1(:,t,k)=diag(Var_wg_y1);
                        sum_Var_wg_y1{k}=sum_Var_wg_y1{k}+Var_wg_y1;
                        %update E(e|y1)
                        E_e_y1(:,t)=E_e_y1(:,t)-stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,k),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                        %update diag(Var(e|y1))
                        diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(diag_Var_wg_y1(:,t,k),obj.stem_model.stem_data.X_g(:,:,tG,k),'b'),aj_g(:,k),'b'); %K varianze
                        
                        if not(isempty(obj.stem_model.stem_data.X_rg))
                            %compute M_cov(w_r,w_g|y1) namely M*cov(w_r,w_g|y1)
                            if length(M)>obj.stem_model.system_size
                                blocks=0:80:length(M);
                                if not(blocks(end)==length(M))
                                    blocks=[blocks length(M)];
                                end
                                for i=1:length(blocks)-1
                                    if p>0
                                        M_cov_wr_wg_y1(blocks(i)+1:blocks(i+1),t,k)=diag(-cov_wr_y1z(M(blocks(i)+1:blocks(i+1)),:)*temp_g{k}(:,blocks(i)+1:blocks(i+1))+cov_wr_z_y1(M(blocks(i)+1:blocks(i+1)),:,t)*temp_g{k}(end-p+1:end,blocks(i)+1:blocks(i+1))); %ha gia' l'stem_misc.M_apply su left!!
                                    else
                                        M_cov_wr_wg_y1(blocks(i)+1:blocks(i+1),t,k)=diag(-cov_wr_y1z(M(blocks(i)+1:blocks(i+1)),:)*temp_g{k}(:,blocks(i)+1:blocks(i+1)));
                                    end
                                end
                            else
                                if p>0
                                    M_cov_wr_wg_y1(1:length(M),t,k)=diag(-cov_wr_y1z(M,:)*temp_g{k}(:,1:length(M))+cov_wr_z_y1(M,:,t)*temp_g{k}(end-p+1:end,1:length(M))); %ha gi� l'stem_misc.M_apply su left!!
                                else
                                    M_cov_wr_wg_y1(1:length(M),t,k)=diag(-cov_wr_y1z(M,:)*temp_g{k}(:,1:length(M)));
                                end
                            end
                            %update diag(Var(e|y1))
                            temp=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,k),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                            temp=stem_misc.D_apply(stem_misc.D_apply(temp,[obj.stem_model.stem_data.X_g(:,1,tG,k);zeros(Nr,1)],'l'),aj_g(:,k),'l');
                            diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*temp;
                        end
                    end
                    
                    if K>1
                        %compute cov(w_gk,w_gh|y1);
                        for h=1:K
                            for k=h+1:K
                                cov_wgk_y1z=[cov_wg_y{k}(:,Lt) zeros(size(cov_wg_y{k},1),p)];
                                if N>obj.stem_model.system_size
                                    blocks=0:80:size(cov_wgk_y1z,1);
                                    if not(blocks(end)==size(cov_wgk_y1z,1))
                                        blocks=[blocks size(cov_wgk_y1z,1)];
                                    end
                                    for i=1:length(blocks)-1
                                        if not(isempty(cov_wg_z_y1))
                                            cov_wgk_wgh_y1{k,h}(blocks(i)+1:blocks(i+1),t)=diag(-cov_wgk_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{h}(:,blocks(i)+1:blocks(i+1))+cov_wg_z_y1(blocks(i)+1:blocks(i+1),:,t,k)*temp_g{h}(end-p+1:end,blocks(i)+1:blocks(i+1)));
                                        else
                                            cov_wgk_wgh_y1{k,h}(blocks(i)+1:blocks(i+1),t)=diag(-cov_wgk_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{h}(:,blocks(i)+1:blocks(i+1)));
                                        end
                                    end
                                else
                                    if not(isempty(cov_wg_z_y1))
                                        cov_wgk_wgh_y1{k,h}(:,t)=diag(-cov_wgk_y1z*temp_g{h}+cov_wg_z_y1(:,:,t,k)*temp_g{h}(end-p+1:end,:));
                                    else
                                        cov_wgk_wgh_y1{k,h}(:,t)=diag(-cov_wgk_y1z*temp_g{h});
                                    end
                                end
                                temp=stem_misc.D_apply(stem_misc.D_apply(cov_wgk_wgh_y1{k,h}(:,t),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                                temp=stem_misc.D_apply(stem_misc.D_apply(temp,[obj.stem_model.stem_data.X_g(:,1,tG,h);zeros(Nr,1)],'l'),aj_g(:,h),'l');
                                %update diag(Var(e|y1))
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*temp;
                            end
                        end
                    else
                        cov_wgk_wgh_y1=[];
                    end
                else
                    E_wg_y1=[];
                    diag_Var_wg_y1=[];
                    sum_Var_wg_y1=[];
                    M_cov_wr_wg_y1=[];
                    cov_wg_z_y1=[];
                    cov_wgk_wgh_y1=[];
                end
                %delete the variables the dimension of which changes every t
                clear temp_g
                clear temp
                t_partial2=clock;
                %disp(['      Time step ',num2str(t),' evaluated in ',stem_misc.decode_time(etime(t_partial2,t_partial1)),' - Non missing: ',num2str(sum(Lt))]);
            end
            
            if obj.stem_model.stem_par.clustering==1
                obj.stem_model.stem_data.stem_varset_g.Y{1}=obj.stem_model.stem_data.Y;
            end
            
            ct2=clock;
            disp(['    Conditional E, Var, Cov evaluation ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            ct2_estep=clock;
            disp(['  E step ended in ',stem_misc.decode_time(etime(ct2_estep,ct1_estep))]);
            disp('');
        end
        
        function M_step(obj,E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,st_kalmansmoother_result,iteration)
            %DESCRIPTION: M-step of the EM algorithm
            %
            %INPUT
            %obj                            - [stem_EM object]  (1x1)
            %E_wr_y1                        - [double]          (N_rxT) E[wr|Y(1)] conditional expectation of w_r_t with respect to the observed data Y(1)
            %sum_Var_wr_y1                  - [doulbe]          (N_rxN_r) sum(Var[wr|Y(1)]) sum with respect to time of the conditional variance of w_r_t with respect to the observed data
            %diag_Var_wr_y1                 - [double]          (N_rxT) diagonals of Var[wr|Y(1)]
            %cov_wr_z_y1                    - [double]          (N_rxpxT) cov[wr,z_t|Y(1)]
            %E_wg_y1                        - [double]          (N_gxTxK) E[wg|Y(1)]
            %sum_Var_wg_y1                  - [double]          {k}(N_gxN_g) sum(Var[wg|Y(1)])
            %diag_Var_wg_y1                 - [double]          (N_gxTxK) diagonals of Var[wg|Y(1)]
            %cov_wg_z_y1                    - [double]          (N_gxpxTxK) cov[wg,z|Y(1)]
            %M_cov_wr_wg_y1                 - [double]          (NxTxK)
            %cov_wgk_wgh_y1                 - [double]          {KxK}(N_gxT) cov[wg_k,wg_h|Y(1)] k,h=1,...,K
            %diag_Var_e_y1                  - [double]          (NxT) diagonals of Var[e|Y(1)]
            %E_e_y1                         - [double]          (NxT) E[e|Y(1)]
            %sigma_eps                      - [double]          (NxN) sigma_eps
            %st_kalmansmoother_result       - [st_kalmansmoother_result object] (1x1)
            %iteration                      - [double]          (1x1) EM iteration number     
            %
            %OUTPUT
            %none: the stem_par property of the stem_model object is updated
            
            disp('  M step started...');
            ct1_mstep=clock;
            if not(isempty(obj.stem_model.stem_data.stem_varset_r))
                Nr=obj.stem_model.stem_data.stem_varset_r.N;
            else
                Nr=0;
            end
            Ng=obj.stem_model.stem_data.stem_varset_g.N;
            T=obj.stem_model.stem_data.T;
            N=obj.stem_model.stem_data.N;
            K=obj.stem_model.stem_par.k;
            M=obj.stem_model.stem_data.M;
            dim=obj.stem_model.stem_data.dim;
            
            par=obj.stem_model.stem_par;
            st_par_em_step=par;
            
            d=1./diag(sigma_eps);
            I=1:length(d);
            inv_sigma_eps=sparse(I,I,d);
            
            if obj.stem_model.stem_par.clustering==1
                obj.stem_model.stem_data.stem_varset_g.Y{1}=[];
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             beta update                %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_beta))
                ct1=clock;
                disp('    beta update started...');
                temp1=zeros(size(obj.stem_model.stem_data.X_beta,2));
                temp2=zeros(size(obj.stem_model.stem_data.X_beta,2),1);
                d=diag(inv_sigma_eps);
                for t=1:T
                    Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                    if obj.stem_model.stem_data.X_beta_tv
                        tB=t;
                    else
                        tB=1;
                    end
                    if size(obj.stem_model.stem_data.X_beta(:,:,tB),1)<N
                        X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,tB);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,tB),1),size(obj.stem_model.stem_data.X_beta(:,:,tB),2))];
                    else
                        X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,tB);
                    end
                    temp1=temp1+X_beta_orlated(Lt,:)'*stem_misc.D_apply(X_beta_orlated(Lt,:),d(Lt),'l');
                    temp2=temp2+X_beta_orlated(Lt,:)'*stem_misc.D_apply(E_e_y1(Lt,t)+X_beta_orlated(Lt,:)*par.beta,d(Lt),'l');
                end
                st_par_em_step.beta=temp1\temp2;
                ct2=clock;
                disp(['    beta update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %              sigma_eps                 %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            disp('    sigma_eps update started...');
            ct1=clock;
            temp=zeros(N,1);
            temp1=zeros(N,1);
            d=diag(sigma_eps);
            for t=1:T
                Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                %the next two lines are ok only for sigma_eps diagonal
                temp1(Lt)=E_e_y1(Lt,t).^2+diag_Var_e_y1(Lt,t);
                temp1(~Lt)=d(~Lt);
                temp=temp+temp1;
            end
            temp=temp/T;
            blocks=[0 cumsum(dim)];
            for i=1:length(dim)
               st_par_em_step.sigma_eps(i,i)=mean(temp(blocks(i)+1:blocks(i+1)));
            end
            ct2=clock;
            disp(['    sigma_eps update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
           

            %%%%%%%%%%%%%%%%%%%%%%%%%
            %    G and sigma_eta    %
            %%%%%%%%%%%%%%%%%%%%%%%%%
            if par.p>0
                disp('    G and sigma_eta update started...');
                ct1=clock;
                if not(obj.stem_model.stem_par.time_diagonal)
                    S11=st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,2:end)'+sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3);
                    S00=st_kalmansmoother_result.zk_s(:,1:end-1)*st_kalmansmoother_result.zk_s(:,1:end-1)'+sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3);
                    S10=st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,1:end-1)'+sum(st_kalmansmoother_result.PPk_s(:,:,2:end),3);
                else
                    S11=diag(diag(st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,2:end)'))+diag(diag(sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3)));
                    S00=diag(diag(st_kalmansmoother_result.zk_s(:,1:end-1)*st_kalmansmoother_result.zk_s(:,1:end-1)'))+diag(diag(sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3)));
                    S10=diag(diag(st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,1:end-1)'))+diag(diag(sum(st_kalmansmoother_result.PPk_s(:,:,2:end),3)));
                end
                
                temp=S10/S00;
                if max(eig(temp))<1
                    st_par_em_step.G=temp;
                else
                    warning('G is not stable. The last G is retained.');    
                end

                temp=(S11-S10*par.G'-par.G*S10'+par.G*S00*par.G')/T;
                %st_par_em_step.sigma_eta=(S11-S10*par.G'-par.G*S10'+par.G*S00*par.G')/T;
                %st_par_em_step.sigma_eta=(S11-st_par_em_step.G*S10')/T;
                if min(eig(temp))>0
                    st_par_em_step.sigma_eta=temp;
                else
                    warning('Sigma eta is not s.d.p. The last s.d.p. solution is retained');
                end
                ct2=clock;
                disp(['    G and sigma_eta ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end
            
            [aj_rg,aj_g]=obj.stem_model.get_aj();
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %          alpha_rg, theta_r and v_r            %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_rg))
                disp('    alpha_rg update started...');
                ct1=clock;
                for r=1:obj.stem_model.stem_data.nvar
                    [aj_rg_r,j_r] = obj.stem_model.get_jrg(r);
                    sum_num=0;
                    sum_den=0;
                    for t=1:T
                        if obj.stem_model.stem_data.X_rg_tv
                            tRG=t;
                        else
                            tRG=1;
                        end
                        if obj.stem_model.stem_data.X_z_tv
                            tT=t;
                        else
                            tT=1;
                        end
                        Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                        temp1=E_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg_r,'l');
                        temp2=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t)',M,'r'),obj.stem_model.stem_data.X_rg(:,1,tRG),'r'),j_r,'r');
                        sum_num=sum_num+sum(temp1(Lt).*temp2(Lt)');
                        
                        if par.p>0
                            if size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N
                                X_z_orlated=[obj.stem_model.stem_data.X_z(:,:,tT);zeros(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1),size(obj.stem_model.stem_data.X_z(:,:,tT),2))];
                                orlated=true;
                            else
                                orlated=false;
                            end
                            temp1=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(cov_wr_z_y1(:,:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),j_r,'l');
                            temp2=zeros(size(temp1,1),1);
                            if N>obj.stem_model.system_size
                                blocks=0:80:size(temp1,1);
                                if not(blocks(end)==size(temp1,1))
                                    blocks=[blocks size(temp1,1)];
                                end
                                for i=1:length(blocks)-1
                                    if orlated
                                        temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                                    else
                                        temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                                    end
                                end
                            else
                                if orlated
                                    temp2=diag(temp1*X_z_orlated');
                                else
                                    temp2=diag(temp1*obj.stem_model.stem_data.X_z(:,:,tT)');
                                end
                            end
                            sum_num=sum_num-sum(temp2(Lt));
                        end
                        
                        if par.k>0
                            if obj.stem_model.stem_data.X_g_tv
                                tG=t;
                            else
                                tG=1;
                            end
                            for k=1:K
                                temp1=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,k),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),j_r,'l');
                                temp2=[obj.stem_model.stem_data.X_g(:,1,tG,k);zeros(size(temp1,1)-size(obj.stem_model.stem_data.X_g(:,1,tG,k),1),1)];
                                temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',temp2,'r'),aj_g(:,k),'r');
                                sum_num=sum_num-sum(temp1(Lt));
                            end
                        end
                        
                        temp1=E_wr_y1(:,t).^2+diag_Var_wr_y1(:,t);
                        temp1=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(temp1,M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),j_r,'b');
                        sum_den=sum_den+sum(temp1(Lt));
                    end
                    alpha_rg(r)=sum_num/sum_den;
                end
                st_par_em_step.alpha_rg=alpha_rg';
                ct2=clock;
                disp(['    alpha_rg update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);

                disp('    v_r update started...');
                ct1=clock;
                
                if Nr<=obj.stem_EM_options.mstep_system_size
                    %TEMP NrxNr VA CALCOLATA IN OGNI CASO SE NON SI RISOLVE
                    %LA STIMA A BLOCCHI DI v E theta NEL CASO DI v NON DIAGONALE!!!
                    temp=zeros(size(sum_Var_wr_y1));
                    for t=1:T
                        temp=temp+E_wr_y1(:,t)*E_wr_y1(:,t)';
                    end
                    temp=temp+sum_Var_wr_y1;
                end
                
                %MANCA LA STIMA A BLOCCHI COS� COME FATTO PER THETA!
                
                
                if par.pixel_correlated
                    %indices are permutated in order to avoid deadlock
                    kindex=randperm(size(par.v_r,1));
                    for k=kindex
                        hindex=randperm(size(par.v_r,1)-k)+k;
                        for h=hindex
                            initial=par.v_r(k,h);
                            if Nr<=obj.stem_EM_options.mstep_system_size
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_r,par.theta_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                    obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            else
                                disp('WARNING: this operation will take a long time');
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_r,par.theta_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                    obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.v_r(k,h)=min_result;
                            st_par_em_step.v_r(h,k)=min_result;
                        end
                    end
                    ct2=clock;
                    disp(['    v_r update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                else
                    %nothing because V in this case is the identity matrix
                end

                disp('    theta_r updating started...');
                ct1=clock;
                initial=par.theta_r;
                if par.pixel_correlated
                    if Nr<=obj.stem_EM_options.mstep_system_size
                        min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                            obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        st_par_em_step.theta_r=exp(min_result);
                    else
                        if obj.stem_model.stem_data.stem_varset_r.nvar>1
                            disp('WARNING: this operation will take a long time');
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_r=exp(min_result);
                        else
                            s=ceil(Nr/obj.stem_EM_options.mstep_system_size);
                            step=ceil(Nr/s);
                            blocks=0:step:Nr;
                            if not(blocks(end)==Nr)
                                blocks=[blocks Nr];
                            end
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wr_y1(idx,t)*E_wr_y1(idx,t)';
                                end
                                temp=temp+sum_Var_wr_y1(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_r=exp(mean(min_result));
                        end
                    end
                else
                    if Nr<=obj.stem_EM_options.mstep_system_size
                        blocks=[0 cumsum(obj.stem_model.stem_data.stem_varset_r.dim)];
                        for i=1:obj.stem_model.stem_data.stem_varset_r.nvar
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(blocks(i)+1:blocks(i+1),blocks(i)+1:blocks(i+1)),...
                                obj.stem_model.stem_data.stem_varset_r.dim(i),temp(blocks(i)+1:blocks(i+1),blocks(i)+1:blocks(i+1)),T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial(i)),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_r(i)=exp(min_result);
                        end
                    else
                        blocks_var=[0 cumsum(obj.stem_model.stem_data.stem_varset_r.dim)];
                        for i=1:obj.stem_model.stem_data.stem_varset_r.nvar
                            s=ceil(obj.stem_model.stem_data.stem_varset_r.dim(i)/obj.stem_EM_options.mstep_system_size);
                            step=ceil(obj.stem_model.stem_data.stem_varset_r.dim(i)/s);
                            blocks=blocks_var(i):step:blocks_var(i+1);
                            if not(blocks(end)==blocks_var(i+1))
                                blocks=[blocks blocks_var(i+1)];
                            end
                            min_result=[];
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wr_y1(idx,t)*E_wr_y1(idx,t)';
                                end
                                temp=temp+sum_Var_wr_y1(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial(i)),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_r(i)=exp(mean(min_result));
                        end
                    end
                end
                ct2=clock;
                disp(['    theta_r update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %          alpha_g               %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_g))
                disp('    alpha_g update started...');
                for s=1:K
                    for r=1:obj.stem_model.stem_data.stem_varset_g.nvar
                        [aj_g_rs,j_r] = obj.stem_model.get_jg(r,s);
                        sum_num=0;
                        sum_den=0;
                        for t=1:T
                            if obj.stem_model.stem_data.X_rg_tv
                                tRG=t;
                            else
                                tRG=1;
                            end
                            if obj.stem_model.stem_data.X_z_tv
                                tT=t;
                            else
                                tT=1;
                            end
                            if obj.stem_model.stem_data.X_g_tv
                                tG=t;
                            else
                                tG=1;
                            end
                            Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                            
                            temp1=E_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,s),obj.stem_model.stem_data.X_g(:,1,tG,s),'l'),aj_g_rs,'l');
                            temp2=stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,s)',obj.stem_model.stem_data.X_g(:,1,tG,s),'r'),j_r,'r');
                            sum_num=sum_num+sum(temp1(Lt).*temp2(Lt)');
                            
                            if par.p>0
                                if size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N
                                    X_z_orlated=[obj.stem_model.stem_data.X_z(:,:,tT);zeros(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1),size(obj.stem_model.stem_data.X_z(:,:,tT),2))];
                                    orlated=true;
                                else
                                    orlated=false;
                                end
                                temp1=stem_misc.D_apply(stem_misc.D_apply(cov_wg_z_y1(:,:,t,s),obj.stem_model.stem_data.X_g(:,1,tG,s),'l'),j_r,'l');
                                temp2=zeros(size(temp1,1),1);
                                if N>obj.stem_model.system_size
                                    blocks=0:80:size(temp1,1);
                                    if not(blocks(end)==size(temp1,1))
                                        blocks=[blocks size(temp1,1)];
                                    end
                                    for i=1:length(blocks)-1
                                        if orlated
                                            temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                                        else
                                            temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                                        end
                                    end
                                else
                                    if orlated
                                        temp2=diag(temp1*X_z_orlated');
                                    else
                                        temp2=diag(temp1*obj.stem_model.stem_data.X_z(:,:,tT)');
                                    end
                                end
                                sum_num=sum_num-sum(temp2(Lt));
                            end
                            
                            if K>1
                                for k=1:K
                                    if not(k==s)
                                        if k<s
                                            kk=s;
                                            ss=k;
                                        else
                                            kk=k;
                                            ss=s;
                                        end
                                        temp1=stem_misc.D_apply(stem_misc.D_apply(cov_wgk_wgh_y1{kk,ss}(:,t),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                                        temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',[obj.stem_model.stem_data.X_g(:,1,tG,s);zeros(Nr,1)],'r'),j_r,'r');
                                        sum_num=sum_num-sum(temp1(Lt));
                                    end
                                end
                            end
                            
                            if not(isempty(obj.stem_model.stem_data.X_rg))
                                temp1=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,s),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                                temp2=[obj.stem_model.stem_data.X_g(:,1,tG,s);zeros(size(temp1,1)-size(obj.stem_model.stem_data.X_g(:,1,tG,s),1),1)];
                                temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',temp2,'r'),j_r,'r');
                                sum_num=sum_num-sum(temp1(Lt));
                            end
                            
                            temp1=E_wg_y1(:,t,s).^2+diag_Var_wg_y1(:,t,s);
                            temp1=stem_misc.D_apply(stem_misc.D_apply(temp1,obj.stem_model.stem_data.X_g(:,1,tG,s),'b'),j_r,'b');
                            sum_den=sum_den+sum(temp1(Lt));
                        end
                        alpha_g(r,s)=sum_num/sum_den;
                    end
                end
                st_par_em_step.alpha_g=alpha_g;
                ct2=clock;
                disp(['    alpha_g update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                
                
                disp('    v_g and theta_g update started...');
                ct1=clock;
                for z=1:K
                    disp(num2str(z));%Da eliminare
                    
                    %AGGIUNGERE LA STIMA A BLOCCHI ANCHE PER v_g?????
                    if Ng<=obj.stem_EM_options.mstep_system_size
                        temp=zeros(size(sum_Var_wg_y1{z}));
                        for t=1:T
                            temp=temp+E_wg_y1(:,t,z)*E_wg_y1(:,t,z)';
                        end
                        temp=temp+sum_Var_wg_y1{z};
                    end
                    
                    %indices are permutated in order to avoid deadlock
                    kindex=randperm(size(par.v_g(:,:,z),1));
                    for k=kindex
                        hindex=randperm(size(par.v_g(:,:,z),1)-k)+k;
                        for h=hindex
                            initial=par.v_g(k,h,z);
                            ctv1=clock;
                            if Ng<=obj.stem_EM_options.mstep_system_size
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_g(:,:,z),par.theta_g(z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                    obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            else
                                disp('WARNING: this operation will take a long time');
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_g(:,:,z),par.theta_g(z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                    obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            ctv2=clock;
                            disp(['    v_g(',num2str(h),',',num2str(k),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
                            st_par_em_step.v_g(k,h,z)=min_result;
                            st_par_em_step.v_g(h,k,z)=min_result;
                        end
                    end
                    
                    initial=par.theta_g(z);
                    ctv1=clock;
                    if Ng<=obj.stem_EM_options.mstep_system_size
                        min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                            obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        st_par_em_step.theta_g(z)=exp(min_result);
                    else
                        if obj.stem_model.stem_data.stem_varset_g.nvar>1
                            disp('WARNING: this operation will take a long time');
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_g(z)=exp(min_result);
                        else
                            s=ceil(Ng/obj.stem_EM_options.mstep_system_size);
                            step=ceil(Ng/s);
                            blocks=0:step:Ng;
                            if not(blocks(end)==Ng)
                                blocks=[blocks Ng];
                            end
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wg_y1(idx,t,z)*E_wg_y1(idx,t,z)';
                                end
                                temp=temp+sum_Var_wg_y1{z}(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_g(z)=exp(mean(min_result));
                        end
                        ctv2=clock;
                        disp(['    theta_g(',num2str(z),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
                    end
                    ct2=clock;
                    disp(['    v_g and theta_g update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                end
            end
            
            if obj.stem_model.stem_par.clustering==1
                if not(isempty(st_kalmansmoother_result))
                    E_e_y1=[];
                    diag_Var_e_y1=[];
                    sigma_eps=[];
                    inv_sigma_eps=[];
                    temp1=[];
                    d=[];
                    I=[];
                    K=[];
                    if size(obj.stem_model.stem_data.X_z,3)==1
                        %correlation computation
                        for i=1:N
                            L=not(isnan(obj.stem_model.stem_data.Y(i,:)));
                            a=obj.stem_model.stem_data.Y(i,L)';
                            b=st_kalmansmoother_result.zk_s(:,2:end)';
                            b=b(L,:);
                            if not(isempty(b))
                                temp=corr(a,b);
                            else
                                temp=repmat(0.0001,1,par.p);
                            end
                            temp(temp<=0)=0.0001;
                            temp(isnan(temp))=0.0001;
                            obj.stem_model.stem_data.X_z(i,:)=temp;
                        end
                        
                        theta_clustering=obj.stem_model.stem_par.theta_clustering;
                        if theta_clustering>0
                            for i=1:N
                                v=exp(-obj.stem_model.stem_data.DistMat_g(:,i)/theta_clustering);
                                for j=1:par.p
                                    obj.stem_model.stem_data.X_z(i,j)=(v'*obj.stem_model.stem_data.X_z(:,j))/length(v);
                                end
                            end
                        end
                        
                        %weight computation
                        for h=1:iteration
                            obj.stem_model.stem_data.X_z=obj.stem_model.stem_data.X_z.^2;
                            ss=sum(obj.stem_model.stem_data.X_z,2);
                            for j=1:size(obj.stem_model.stem_data.X_z,2)
                                obj.stem_model.stem_data.X_z(:,j)=obj.stem_model.stem_data.X_z(:,j)./ss;
                            end
                        end
                    else
                        %DA MODIFICARE NON CREANDO VARIABILI TEMPORANEE!!!
                        %correlation computation
                        for t=1:T
                            t1=t-30;
                            t2=t+30;
                            if t1<1
                                t1=1;
                            end
                            if t2>T
                                t2=T;
                            end
                            Y_temp=obj.stem_model.stem_data.Y(:,t1:t2);
                            z_temp=st_kalmansmoother_result.zk_s(:,t1+1:t2+1)';
                            parfor i=1:N
                                L=not(isnan(Y_temp(i,:)));
                                a=Y_temp(i,L)';
                                b=z_temp(L,:);
                                if not(isempty(b))
                                    temp=corr(a,b);
                                else
                                    temp=repmat(0.0001,1,par.p);
                                end
                                temp(temp<=0)=0.0001;
                                temp(isnan(temp))=0.0001;
                                X_z_new(i,:,t)=temp;
                            end
                        end
                        
                        theta_clustering=obj.stem_model.stem_par.theta_clustering;
                        if theta_clustering>0
                            X_z_new2=zeros(size(X_z_new));
                            for t=1:T
                                for i=1:N
                                    v=exp(-obj.stem_model.stem_data.DistMat_g(:,i)/theta_clustering);
                                    for j=1:par.p
                                        X_z_new2(i,j,t)=(v'*X_z_new(:,j,t))/length(v);
                                    end
                                end
                            end
                            X_z_new=X_z_new2;
                        end
                        
                        %weight computation
                        for h=1:iteration
                            X_z_new=X_z_new.^2;
                            for t=1:T
                                ss=sum(X_z_new(:,:,t),2);
                                for j=1:size(X_z_new,2)
                                    X_z_new(:,j,t)=X_z_new(:,j,t)./ss;
                                end
                            end
                        end
                    end
                else
                    error('The Kalman smoother output is empty');
                end
                
                if obj.stem_model.stem_par.clustering==1
                    obj.stem_model.stem_data.stem_varset_g.Y{1}=obj.stem_model.stem_data.Y;
                end 
            end
            
            
            obj.stem_model.stem_par=st_par_em_step;
            ct2_mstep=clock;
            disp(['  M step ended in ',stem_misc.decode_time(etime(ct2_mstep,ct1_mstep))]);
        end
            
        function [E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1] = E_step_parallel(obj,time_steps,st_kalmansmoother_result)
            %DESCRIPTION: parallel version of the E-step of the EM algorithm
            %
            %INPUT
            %obj                            - [stem_EM object]  (1x1)
            %time_steps                     - [double]          (dTx1) The E-step is computed only for the data related to the time steps in the time_steps vector
            %st_kalmansmoother_result       - [stem_kalmansmoother_result object] (1x1)
            %
            %OUTPUT
            %E_wr_y1                        - [double]          (N_rxT) E[wr|Y(1)] conditional expectation of w_r_t with respect to the observed data Y(1)
            %sum_Var_wr_y1                  - [doulbe]          (N_rxN_r) sum(Var[wr|Y(1)]) sum with respect to time of the conditional variance of w_r_t with respect to the observed data
            %diag_Var_wr_y1                 - [double]          (N_rxT) diagonals of Var[wr|Y(1)]
            %cov_wr_z_y1                    - [double]          (N_rxpxT) cov[wr,z_t|Y(1)]
            %E_wg_y1                        - [double]          (N_gxTxK) E[wg|Y(1)]
            %sum_Var_wg_y1                  - [double]          {k}(N_gxN_g) sum(Var[wg|Y(1)])
            %diag_Var_wg_y1                 - [double]          (N_gxTxK) diagonals of Var[wg|Y(1)]
            %cov_wg_z_y1                    - [double]          (N_gxpxTxK) cov[wg,z|Y(1)]
            %M_cov_wr_wg_y1                 - [double]          (NxTxK)
            %cov_wgk_wgh_y1                 - [double]          {KxK}(N_gxT) cov[wg_k,wg_h|Y(1)] k,h=1,...,K
            %diag_Var_e_y1                  - [double]          (NxT) diagonals of Var[e|Y(1)]
            %E_e_y1                         - [double]          (NxT) E[e|Y(1)]
            
            N=obj.stem_model.stem_data.N;
            if not(isempty(obj.stem_model.stem_data.stem_varset_r))
                Nr=obj.stem_model.stem_data.stem_varset_r.N;
            else
                Nr=0;
            end
            Ng=obj.stem_model.stem_data.stem_varset_g.N;
            T=length(time_steps);
            K=obj.stem_model.stem_par.k;
            p=obj.stem_model.stem_par.p;
            par=obj.stem_model.stem_par;
            
            fts=time_steps(1);

            disp('  E step started...');
            ct1_estep=clock;
            
            [sigma_eps,sigma_W_r,sigma_W_g,sigma_geo,sigma_Z,aj_rg,aj_g,M] = obj.stem_model.get_sigma();
            if p>0
                if not(obj.stem_model.stem_data.X_z_tv)&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    if obj.stem_model.tapering
                        %migliorare la creazione della matrice sparsa!!!
                        var_Zt=sparse(obj.stem_model.stem_data.X_z(:,:,1))*sparse(sigma_Z)*sparse(obj.stem_model.stem_data.X_z(:,:,1)');
                        if (size(obj.stem_model.stem_data.X_z(:,:,1),1)<N)
                            var_Zt=blkdiag(var_Zt,speye(N-size(obj.stem_model.stem_data.X_z(:,:,1),1)));
                        end
                    else
                        var_Zt=obj.stem_model.stem_data.X_z(:,:,1)*sigma_Z*obj.stem_model.stem_data.X_z(:,:,1)';
                        if (size(obj.stem_model.stem_data.X_z(:,:,1),1)<N)
                            var_Zt=blkdiag(var_Zt,eye(N-size(obj.stem_model.stem_data.X_z(:,:,1),1)));
                        end
                    end
                end
                if not(isempty(sigma_geo))&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    var_Yt=sigma_geo+var_Zt;
                end                
            else
                st_kalmansmoother_result=stem_kalmansmoother_result([],[],[],[]);    
                var_Zt=[];
                %variance of Y
                if not(isempty(sigma_geo))&&(not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g)))
                    var_Yt=sigma_geo; %sigma_geo includes sigma_eps
                end                
            end            
            
            E_e_y1=obj.stem_model.stem_data.Y(:,time_steps);
            E_e_y1(isnan(E_e_y1))=0;
            if not(isempty(obj.stem_model.stem_data.X_beta))
                disp('    Xbeta evaluation started...');
                ct1=clock;
                Xbeta=zeros(N,T);
                if obj.stem_model.stem_data.X_beta_tv
                    for t=1:T
                        if size(obj.stem_model.stem_data.X_beta(:,:,t+fts-1),1)<N
                            X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,t+fts-1);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,t+fts-1),1),size(obj.stem_model.stem_data.X_beta(:,:,t+fts-1),2))];
                        else
                            X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,t+fts-1);
                        end
                        Xbeta(:,t)=X_beta_orlated*par.beta;
                    end
                else
                    if size(obj.stem_model.stem_data.X_beta(:,:,1),1)<N
                        X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,1);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,1),1),size(obj.stem_model.stem_data.X_beta(:,:,1),2))];
                    else
                        X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,1);
                    end
                    Xbeta=repmat(X_beta_orlated*par.beta,1,T);
                end
                ct2=clock;
                disp(['    Xbeta evaluation ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                E_e_y1=E_e_y1-Xbeta;
            else
                Xbeta=[];
            end
            diag_Var_e_y1=zeros(N,T);
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %   Conditional expectation, conditional variance and conditional covariance evaluation  %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %sigma_Z=Var(Zt)
            %var_Zt=Var(X_z*Zt*X_z')
            
            disp('    Conditional E, Var, Cov evaluation started...');
            ct1=clock;
            %cov_wr_yz time invariant case
            if not(isempty(obj.stem_model.stem_data.X_rg))
                if obj.stem_model.tapering
                    Lr=find(sigma_W_r);
                    [Ir,Jr]=ind2sub(size(sigma_W_r),Lr);
                    nnz_r=length(Ir);
                end
                if not(obj.stem_model.stem_data.X_rg_tv)
                    cov_wr_y=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'r'),obj.stem_model.stem_data.X_rg(:,1,1),'r'),aj_rg,'r');
                end
                E_wr_y1=zeros(Nr,T);
                
                if not(obj.stem_model.tapering)
                    sum_Var_wr_y1=zeros(Nr);
                else
                    sum_Var_wr_y1=spalloc(size(sigma_W_r,1),size(sigma_W_r,2),nnz_r);
                end
                
                diag_Var_wr_y1=zeros(Nr,T);
                cov_wr_z_y1=zeros(Nr,p,T);
            end
            %cov_wg_yz time invariant case
            if not(isempty(obj.stem_model.stem_data.X_g))
                if obj.stem_model.tapering
                    Lg=find(sigma_W_g{1});
                    [Ig,Jg]=ind2sub(size(sigma_W_g{1}),Lg);
                    nnz_g=length(Ig);
                end
                if not(obj.stem_model.stem_data.X_g_tv)
                    for k=1:K
                        cov_wg_y{k}=stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,1,k),'r'),aj_g(:,k),'r');
                    end
                end
                for h=1:K
                    for k=h+1:K
                        cov_wgk_wgh_y1{k,h}=zeros(Ng,T);
                    end
                end
                E_wg_y1=zeros(Ng,T,K);
                for k=1:K
                    if not(obj.stem_model.tapering)
                        sum_Var_wg_y1{k}=zeros(Ng,Ng);
                    else
                        sum_Var_wg_y1{k}=spalloc(size(sigma_W_g{k},1),size(sigma_W_g{k},2),nnz_g);
                    end
                end
                diag_Var_wg_y1=zeros(Ng,T,K);
                cov_wg_z_y1=zeros(Ng,p,T,K);
            end
            
            if not(isempty(obj.stem_model.stem_data.X_rg)) && not(isempty(obj.stem_model.stem_data.X_g))
                M_cov_wr_wg_y1=zeros(N,T,K);
            else
                M_cov_wr_wg_y1=[];
            end
            
            for t=1:T
                t_partial1=clock;
                %missing at time t
                Lt=not(isnan(obj.stem_model.stem_data.Y(:,t+fts-1)));
                
                if obj.stem_model.stem_data.X_rg_tv
                    tRG=t+fts-1;
                else
                    tRG=1;
                end
                if obj.stem_model.stem_data.X_z_tv
                    tT=t+fts-1;
                else
                    tT=1;
                end
                if obj.stem_model.stem_data.X_g_tv
                    tG=t+fts-1;
                else
                    tG=1;
                end
                
                %evaluate var_yt in the time variant case
                if obj.stem_model.stem_data.X_tv
                    if not(isempty(obj.stem_model.stem_data.X_rg))
                        sigma_geo=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'b'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),aj_rg,'b');
                    end
                    
                    if not(isempty(obj.stem_model.stem_data.X_g))
                        if isempty(obj.stem_model.stem_data.X_rg)
                            if obj.stem_model.tapering
                                sigma_geo=spalloc(size(sigma_W_g{1},1),size(sigma_W_g{1},1),nnz(sigma_W_g{1}));
                            else
                                sigma_geo=zeros(N);
                            end
                        end
                        for k=1:size(obj.stem_model.stem_data.X_g,4)
                            sigma_geo=sigma_geo+stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,tG,k),'b'),aj_g(:,k),'b');
                        end
                    end
                    if isempty(obj.stem_model.stem_data.X_g)&&isempty(obj.stem_model.stem_data.X_rg)
                        sigma_geo=sigma_eps;
                    else
                        sigma_geo=sigma_geo+sigma_eps;
                    end
                    
                    if not(isempty(obj.stem_model.stem_data.X_z))
                        if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                            if obj.stem_model.stem_data.X_z_tv
                                if obj.stem_model.tapering
                                    var_Zt=sparse(obj.stem_model.stem_data.X_z(:,:,tT))*sparse(sigma_Z)*sparse(obj.stem_model.stem_data.X_z(:,:,tT)');
                                    if (size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N)
                                        var_Zt=blkdiag(var_Zt,speye(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1)));
                                    end
                                else
                                    var_Zt=obj.stem_model.stem_data.X_z(:,:,tT)*sigma_Z*obj.stem_model.stem_data.X_z(:,:,tT)';
                                    if (size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N)
                                        var_Zt=blkdiag(var_Zt,eye(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1)));
                                    end
                                end
                            end
                            var_Yt=sigma_geo+var_Zt;
                        end
                    else
                        if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                            var_Yt=sigma_geo;
                        end
                    end
                end
                
                %check if the temporal loadings are time variant
                if not(isempty(obj.stem_model.stem_data.X_z))
                    if size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N
                        X_z_orlated=[obj.stem_model.stem_data.X_z(:,:,tT);zeros(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1),size(obj.stem_model.stem_data.X_z(:,:,tT),2))];
                        orlated=true;
                    else
                        orlated=false;
                    end

                    if N>obj.stem_model.system_size
                        blocks=0:80:size(diag_Var_e_y1,1);
                        if not(blocks(end)==size(diag_Var_e_y1,1))
                            blocks=[blocks size(diag_Var_e_y1,1)];
                        end
                        for i=1:length(blocks)-1
                            %update diag(Var(e|y1))
                            if orlated
                                diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag(X_z_orlated(blocks(i)+1:blocks(i+1),:)*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                            else
                                diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag(obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                            end
                        end
                    else
                        if orlated
                            temp=X_z_orlated*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1);
                            diag_Var_e_y1(:,t)=diag(temp*X_z_orlated');
                        else
                            temp=obj.stem_model.stem_data.X_z(:,:,tT)*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1);
                            diag_Var_e_y1(:,t)=diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                        end
                    end
                end
                
                if not(isempty(obj.stem_model.stem_data.X_rg))||not(isempty(obj.stem_model.stem_data.X_g))
                    %build the Ht matrix
                    if not(isempty(var_Zt))
                        temp=st_kalmansmoother_result.zk_s(:,t+fts-1+1);
                        if orlated
                            H1t=[var_Yt(Lt,Lt), X_z_orlated(Lt,:)*sigma_Z; sigma_Z*X_z_orlated(Lt,:)', sigma_Z];
                        else
                            H1t=[var_Yt(Lt,Lt), obj.stem_model.stem_data.X_z(Lt,:,tT)*sigma_Z; sigma_Z*obj.stem_model.stem_data.X_z(Lt,:,tT)', sigma_Z];
                        end
                        %update E(e|y1)
                        if orlated
                            E_e_y1(:,t)=E_e_y1(:,t)-X_z_orlated*temp;
                        else
                            E_e_y1(:,t)=E_e_y1(:,t)-obj.stem_model.stem_data.X_z(:,:,tT)*temp;
                        end
                    else
                        H1t=var_Yt(Lt,Lt);
                        temp=[];
                    end
                    
                    res=obj.stem_model.stem_data.Y(:,time_steps);
                    if not(isempty(Xbeta))
                        res=res-Xbeta;
                    end
                    if obj.stem_model.tapering
                        cs=[];
                        r = symamd(H1t);
                        chol_H1t=chol(H1t(r,r));
                        temp2=[res(Lt,t);temp];
                        cs(r,1)=stem_misc.chol_solve(chol_H1t,temp2(r));
                    else
                        chol_H1t=chol(H1t);
                        cs=stem_misc.chol_solve(chol_H1t,[res(Lt,t);temp]);
                    end
                end
                
                if not(isempty(obj.stem_model.stem_data.X_rg))
                    %check if the pixel loadings are time variant
                    if obj.stem_model.stem_data.X_rg_tv
                        %cov_wr_yz time variant case
                        cov_wr_y=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(sigma_W_r,M,'r'),obj.stem_model.stem_data.X_rg(:,1,tRG),'r'),aj_rg,'r');
                    end
                    cov_wr_y1z=[cov_wr_y(:,Lt),zeros(size(cov_wr_y,1),p)];
                    %compute E(w_r|y1);
                    E_wr_y1(:,t)=cov_wr_y1z*cs;
                    %compute Var(w_r|y1)
                    if obj.stem_model.tapering
                        temp_r(r,:)=stem_misc.chol_solve(chol_H1t,cov_wr_y1z(:,r)',1);
                        blocks=0:200:size(cov_wr_y1z,1);
                        if not(blocks(end)==size(cov_wr_y1z,1))
                            blocks=[blocks size(cov_wr_y1z,1)];
                        end
                        Id=[];
                        Jd=[];
                        elements=[];
                        for i=1:length(blocks)-1
                            temp_r2=cov_wr_y1z(blocks(i)+1:blocks(i+1),:)*temp_r;  
                            idx=find(temp_r2);
                            [idx_I,idx_J]=ind2sub(size(temp_r2),idx);
                            Id=[Id;idx_I+blocks(i)];
                            Jd=[Jd;idx_J];
                            elements=[elements;temp_r2(idx)];
                        end
                        Var_wr_y1=sigma_W_r-sparse(Id,Jd,elements,size(sigma_W_r,1),size(sigma_W_r,2));
                    else
                        temp_r=stem_misc.chol_solve(chol_H1t,cov_wr_y1z');
                        Var_wr_y1=sigma_W_r-cov_wr_y1z*temp_r;
                    end
                    
                    if p>0
                        %compute cov(w_r,z|y1)
                        cov_wr_z_y1(:,:,t)=temp_r(end-p+1:end,:)'*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1);
                        Var_wr_y1=Var_wr_y1+cov_wr_z_y1(:,:,t)*temp_r(end-p+1:end,:);
                        %update diag(Var(e|y1))
                        temp=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(cov_wr_z_y1(:,:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                        if N>obj.stem_model.system_size
                            blocks=0:80:size(diag_Var_e_y1,1);
                            if not(blocks(end)==size(diag_Var_e_y1,1))
                                blocks=[blocks size(diag_Var_e_y1,1)];
                            end
                            for i=1:length(blocks)-1
                                if orlated
                                    diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)'); %note 2*
                                else
                                    diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+2*diag(temp(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)'); %note 2*
                                end
                            end
                        else
                            %faster for N 
                            if orlated
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*X_z_orlated');
                            else
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                            end
                        end
                    else
                        cov_wr_z_y1=[];
                    end
                    %compute diag(Var(w_r|y1))
                    diag_Var_wr_y1(:,t)=diag(Var_wr_y1);
                    %compute sum(Var(w_r|y1))
                    sum_Var_wr_y1=sum_Var_wr_y1+Var_wr_y1;
                    %update E(e|y1)
                    E_e_y1(:,t)=E_e_y1(:,t)-stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                    %update diag(Var(e|y1))
                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(diag_Var_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),aj_rg,'b');
                else
                    E_wr_y1=[];
                    diag_Var_wr_y1=[];
                    sum_Var_wr_y1=[];
                    cov_wr_z_y1=[];
                end
                clear temp_r
                if not(isempty(obj.stem_model.stem_data.X_g))
                    %check if the point loadings are time variant
                    if obj.stem_model.stem_data.X_g_tv
                        %cov_wg_yz time invariant case
                        for k=1:K
                            cov_wg_y{k}=stem_misc.D_apply(stem_misc.D_apply(sigma_W_g{k},obj.stem_model.stem_data.X_g(:,1,tG,k),'r'),aj_g(:,k),'r');
                        end
                    end
                    for k=1:K
                        cov_wg_y1z=[cov_wg_y{k}(:,Lt) zeros(size(cov_wg_y{k},1),p)];
                        %compute E(w_g_k|y1);
                        E_wg_y1(:,t,k)=cov_wg_y1z*cs;
                        %compute Var(w_g_k|y1)
                        if obj.stem_model.tapering
                            temp_g{k}(r,:)=stem_misc.chol_solve(chol_H1t,cov_wg_y1z(:,r)',1);
                            blocks=0:200:size(cov_wg_y1z,1);
                            if not(blocks(end)==size(cov_wg_y1z,1))
                                blocks=[blocks size(cov_wg_y1z,1)];
                            end
                            Id=[];
                            Jd=[];
                            elements=[];
                            for i=1:length(blocks)-1
                                temp_g2=cov_wg_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{k};
                                idx=find(temp_g2);
                                [idx_I,idx_J]=ind2sub(size(temp_g2),idx);
                                Id=[Id;idx_I+blocks(i)];
                                Jd=[Jd;idx_J];
                                elements=[elements;temp_g2(idx)];
                            end
                            Var_wg_y1=sigma_W_g{k}-sparse(Id,Jd,elements,size(sigma_W_g{k},1),size(sigma_W_g{k},2));
                        else
                            temp_g{k}=stem_misc.chol_solve(chol_H1t,cov_wg_y1z');
                            Var_wg_y1=sigma_W_g{k}-cov_wg_y1z*temp_g{k};
                        end
                        
                        if p>0
                            %compute cov(w_g,z|y1)
                            cov_wg_z_y1(:,:,t,k)=temp_g{k}(end-p+1:end,:)'*st_kalmansmoother_result.Pk_s(:,:,t+fts-1+1);
                            Var_wg_y1=Var_wg_y1+cov_wg_z_y1(:,:,t,k)*temp_g{k}(end-p+1:end,:);
                            %update diag(Var(e|y1))
                            temp=stem_misc.D_apply(stem_misc.D_apply(cov_wg_z_y1(:,:,t,k),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                            if N>obj.stem_model.system_size
                                blocks=0:80:size(diag_Var_e_y1,1);
                                if not(blocks(end)==size(diag_Var_e_y1,1))
                                    blocks=[blocks size(diag_Var_e_y1,1)];
                                end
                                for i=1:length(blocks)-1
                                    if orlated
                                        diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+diag(2*temp(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)'); %note 2*
                                    else
                                        diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)=diag_Var_e_y1(blocks(i)+1:blocks(i+1),t)+diag(2*temp(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)'); %note 2*
                                    end
                                end
                            else
                                if orlated
                                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*X_z_orlated');
                                else
                                    diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*diag(temp*obj.stem_model.stem_data.X_z(:,:,tT)');
                                end
                            end
                        else
                            cov_wg_z_y1=[];
                        end
                        diag_Var_wg_y1(:,t,k)=diag(Var_wg_y1);
                        sum_Var_wg_y1{k}=sum_Var_wg_y1{k}+Var_wg_y1;
                        %update E(e|y1)
                        E_e_y1(:,t)=E_e_y1(:,t)-stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,k),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                        %update diag(Var(e|y1))
                        diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(diag_Var_wg_y1(:,t,k),obj.stem_model.stem_data.X_g(:,:,tG,k),'b'),aj_g(:,k),'b');
                        
                        if not(isempty(obj.stem_model.stem_data.X_rg))
                            %compute M_cov(w_r,w_g|y1) namely M*cov(w_r,w_g|y1)
                            if length(M)>obj.stem_model.system_size
                                for i=1:length(M)
                                    if p>0
                                        M_cov_wr_wg_y1(i,t,k)=-cov_wr_y1z(M(i),:)*temp_g{k}(:,i)+cov_wr_z_y1(M(i),:,t)*temp_g{k}(end-p+1:end,i); %ha gi� l'stem_misc.M_apply su left!!
                                    else
                                        M_cov_wr_wg_y1(i,t,k)=-cov_wr_y1z(M(i),:)*temp_g{k}(:,i);
                                    end
                                end
                            else
                                if p>0
                                    M_cov_wr_wg_y1(1:length(M),t,k)=diag(-cov_wr_y1z(M,:)*temp_g{k}(:,1:length(M))+cov_wr_z_y1(M,:,t)*temp_g{k}(end-p+1:end,1:length(M))); %ha gi� l'stem_misc.M_apply su left!!
                                else
                                    M_cov_wr_wg_y1(1:length(M),t,k)=diag(-cov_wr_y1z(M,:)*temp_g{k}(:,1:length(M)));
                                end
                            end
                            %update diag(Var(e|y1))
                            temp=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,k),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                            temp=stem_misc.D_apply(stem_misc.D_apply(temp,[obj.stem_model.stem_data.X_g(:,1,tG,k);zeros(Nr,1)],'l'),aj_g(:,k),'l');
                            diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*temp;
                        end
                    end
                    
                    if K>1
                        %compute cov(w_gk,w_gh|y1);
                        for h=1:K
                            for k=h+1:K
                                cov_wgk_y1z=[cov_wg_y{k}(:,Lt) zeros(size(cov_wg_y{k},1),p)];
                                if N>obj.stem_model.system_size
                                    blocks=0:80:size(cov_wgk_y1z,1);
                                    if not(blocks(end)==size(cov_wgk_y1z,1))
                                        blocks=[blocks size(cov_wgk_y1z,1)];
                                    end
                                    for i=1:length(blocks)-1
                                        if not(isempty(cov_wg_z_y1))
                                            cov_wgk_wgh_y1{k,h}(blocks(i)+1:blocks(i+1),t)=diag(-cov_wgk_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{h}(:,blocks(i)+1:blocks(i+1))+cov_wg_z_y1(blocks(i)+1:blocks(i+1),:,t,k)*temp_g{h}(end-p+1:end,blocks(i)+1:blocks(i+1)));
                                        else
                                            cov_wgk_wgh_y1{k,h}(blocks(i)+1:blocks(i+1),t)=diag(-cov_wgk_y1z(blocks(i)+1:blocks(i+1),:)*temp_g{h}(:,blocks(i)+1:blocks(i+1)));
                                        end
                                    end
                                else
                                    if not(isempty(cov_wg_z_y1))
                                        cov_wgk_wgh_y1{k,h}(:,t)=diag(-cov_wgk_y1z*temp_g{h}+cov_wg_z_y1(:,:,t,k)*temp_g{h}(end-p+1:end,:));
                                    else
                                        cov_wgk_wgh_y1{k,h}(:,t)=diag(-cov_wgk_y1z*temp_g{h});
                                    end
                                end
                                temp=stem_misc.D_apply(stem_misc.D_apply(cov_wgk_wgh_y1{k,h}(:,t),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                                temp=stem_misc.D_apply(stem_misc.D_apply(temp,[obj.stem_model.stem_data.X_g(:,1,tG,h);zeros(Nr,1)],'l'),aj_g(:,h),'l');
                                %update diag(Var(e|y1))
                                diag_Var_e_y1(:,t)=diag_Var_e_y1(:,t)+2*temp;
                            end
                        end
                    else
                        cov_wgk_wgh_y1=[];
                    end
                else
                    E_wg_y1=[];
                    diag_Var_wg_y1=[];
                    sum_Var_wg_y1=[];
                    M_cov_wr_wg_y1=[];
                    cov_wg_z_y1=[];
                    cov_wgk_wgh_y1=[];
                end
                clear temp_g
                t_partial2=clock;
                %disp(['      Time step ',num2str(t),' evaluated in ',stem_misc.decode_time(etime(t_partial2,t_partial1)),' - Non missing: ',num2str(sum(Lt))]);
            end
            
            ct2=clock;
            disp(['    Conditional E, Var, Cov evaluation ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            ct2_estep=clock;
            disp(['  E step ended in ',stem_misc.decode_time(etime(ct2_estep,ct1_estep))]);
            disp('');
        end
        
        function M_step_parallel(obj,E_wr_y1,sum_Var_wr_y1,diag_Var_wr_y1,cov_wr_z_y1,E_wg_y1,sum_Var_wg_y1,diag_Var_wg_y1,cov_wg_z_y1,M_cov_wr_wg_y1,cov_wgk_wgh_y1,diag_Var_e_y1,E_e_y1,sigma_eps,st_kalmansmoother_result,index,iteration)
            %DESCRIPTION: parallel version of the M-step of the EM algorithm
            %
            %INPUT
            %obj                            - [stem_EM object]  (1x1)
            %E_wr_y1                        - [double]          (N_rxT) E[wr|Y(1)] conditional expectation of w_r_t with respect to the observed data Y(1)
            %sum_Var_wr_y1                  - [doulbe]          (N_rxN_r) sum(Var[wr|Y(1)]) sum with respect to time of the conditional variance of w_r_t with respect to the observed data
            %diag_Var_wr_y1                 - [double]          (N_rxT) diagonals of Var[wr|Y(1)]
            %cov_wr_z_y1                    - [double]          (N_rxpxT) cov[wr,z_t|Y(1)]
            %E_wg_y1                        - [double]          (N_gxTxK) E[wg|Y(1)]
            %sum_Var_wg_y1                  - [double]          {k}(N_gxN_g) sum(Var[wg|Y(1)])
            %diag_Var_wg_y1                 - [double]          (N_gxTxK) diagonals of Var[wg|Y(1)]
            %cov_wg_z_y1                    - [double]          (N_gxpxTxK) cov[wg,z|Y(1)]
            %M_cov_wr_wg_y1                 - [double]          (NxTxK)
            %cov_wgk_wgh_y1                 - [double]          {KxK}(N_gxT) cov[wg_k,wg_h|Y(1)] k,h=1,...,K
            %diag_Var_e_y1                  - [double]          (NxT) diagonals of Var[e|Y(1)]
            %E_e_y1                         - [double]          (NxT) E[e|Y(1)]
            %sigma_eps                      - [double]          (NxN) sigma_eps
            %st_kalmansmoother_result       - [st_kalmansmoother_result object] (1x1)
            %index                          - [integer >0]      (dKx1) the subset of indices from 1 to K with respect to which estimate the elements of theta_g and v_g          
            %iteration                      - [double]          (1x1) EM iteration number     
            %
            %OUTPUT
            %none: the stem_par property of the stem_model object is updated            
            
            disp('  M step started...');
            ct1_mstep=clock;
            if not(isempty(obj.stem_model.stem_data.stem_varset_r))
                Nr=obj.stem_model.stem_data.stem_varset_r.N;
            else
                Nr=0;
            end
            Ng=obj.stem_model.stem_data.stem_varset_g.N;
            T=obj.stem_model.stem_data.T;
            N=obj.stem_model.stem_data.N;
            K=obj.stem_model.stem_par.k;
            M=obj.stem_model.stem_data.M;
            dim=obj.stem_model.stem_data.dim;
            
            par=obj.stem_model.stem_par;
            st_par_em_step=par;
            
            d=1./diag(sigma_eps);
            I=1:length(d);
            inv_sigma_eps=sparse(I,I,d);
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %             beta update                %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_beta))
                ct1=clock;
                disp('    beta update started...');
                temp1=zeros(size(obj.stem_model.stem_data.X_beta,2));
                temp2=zeros(size(obj.stem_model.stem_data.X_beta,2),1);
                d=diag(inv_sigma_eps);
                for t=1:T
                    Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                    if obj.stem_model.stem_data.X_beta_tv
                        tB=t;
                    else
                        tB=1;
                    end
                    if size(obj.stem_model.stem_data.X_beta(:,:,tB),1)<N
                        X_beta_orlated=[obj.stem_model.stem_data.X_beta(:,:,tB);zeros(N-size(obj.stem_model.stem_data.X_beta(:,:,tB),1),size(obj.stem_model.stem_data.X_beta(:,:,tB),2))];
                    else
                        X_beta_orlated=obj.stem_model.stem_data.X_beta(:,:,tB);
                    end
                    temp1=temp1+X_beta_orlated(Lt,:)'*stem_misc.D_apply(X_beta_orlated(Lt,:),d(Lt),'l');
                    temp2=temp2+X_beta_orlated(Lt,:)'*stem_misc.D_apply(E_e_y1(Lt,t)+X_beta_orlated(Lt,:)*par.beta,d(Lt),'l');
                end
                st_par_em_step.beta=temp1\temp2;
                ct2=clock;
                disp(['    beta update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %              sigma_eps                 %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            disp('    sigma_eps update started...');
            ct1=clock;
            temp=zeros(N,1);
            temp1=zeros(N,1);
            d=diag(sigma_eps);
            for t=1:T
                Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                %the next two lines are ok only for sigma_eps diagonal
                temp1(Lt)=E_e_y1(Lt,t).^2+diag_Var_e_y1(Lt,t);
                temp1(~Lt)=d(~Lt);
                temp=temp+temp1;
            end
            temp=temp/T;
            blocks=[0 cumsum(dim)];
            for i=1:length(dim)
                st_par_em_step.sigma_eps(i,i)=mean(temp(blocks(i)+1:blocks(i+1)));
            end
            ct2=clock;
            disp(['    sigma_eps update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            
            
            %%%%%%%%%%%%%%%%%%%%%%%%%
            %    G and sigma_eta    %
            %%%%%%%%%%%%%%%%%%%%%%%%%
            if par.p>0
                disp('    G and sigma_eta update started...');
                ct1=clock;
                if not(obj.stem_model.stem_par.time_diagonal)
                    S11=st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,2:end)'+sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3);
                    S00=st_kalmansmoother_result.zk_s(:,1:end-1)*st_kalmansmoother_result.zk_s(:,1:end-1)'+sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3);
                    S10=st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,1:end-1)'+sum(st_kalmansmoother_result.PPk_s(:,:,2:end),3);
                else
                    S11=diag(diag(st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,2:end)'))+diag(diag(sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3)));
                    S00=diag(diag(st_kalmansmoother_result.zk_s(:,1:end-1)*st_kalmansmoother_result.zk_s(:,1:end-1)'))+diag(diag(sum(st_kalmansmoother_result.Pk_s(:,:,2:end),3)));
                    S10=diag(diag(st_kalmansmoother_result.zk_s(:,2:end)*st_kalmansmoother_result.zk_s(:,1:end-1)'))+diag(diag(sum(st_kalmansmoother_result.PPk_s(:,:,2:end),3)));
                end
                
                temp=S10/S00;
                if max(eig(temp))<1
                    st_par_em_step.G=temp;
                else
                    warning('G is not stable. The last G is retained.');
                end
                
                temp=(S11-S10*par.G'-par.G*S10'+par.G*S00*par.G')/T;
                %st_par_em_step.sigma_eta=(S11-S10*par.G'-par.G*S10'+par.G*S00*par.G')/T;
                %st_par_em_step.sigma_eta=(S11-st_par_em_step.G*S10')/T;
                if min(eig(temp))>0
                    st_par_em_step.sigma_eta=temp;
                else
                    warning('Sigma eta is not s.d.p. The last s.d.p. solution is retained');
                end
                ct2=clock;
                disp(['    G and sigma_eta ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end
            
            [aj_rg,aj_g]=obj.stem_model.get_aj();
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %          alpha_rg, theta_r and v_r            %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_rg))
                disp('    alpha_rg update started...');
                ct1=clock;
                for r=1:obj.stem_model.stem_data.nvar
                    [aj_rg_r,j_r] = obj.stem_model.get_jrg(r);
                    sum_num=0;
                    sum_den=0;
                    for t=1:T
                        if obj.stem_model.stem_data.X_rg_tv
                            tRG=t;
                        else
                            tRG=1;
                        end
                        if obj.stem_model.stem_data.X_z_tv
                            tT=t;
                        else
                            tT=1;
                        end
                        Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                        temp1=E_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg_r,'l');
                        temp2=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(E_wr_y1(:,t)',M,'r'),obj.stem_model.stem_data.X_rg(:,1,tRG),'r'),j_r,'r');
                        sum_num=sum_num+sum(temp1(Lt).*temp2(Lt)');
                        
                        if par.p>0
                            if size(obj.stem_model.stem_data.X_z(:,:,tT),1)<N
                                X_z_orlated=[obj.stem_model.stem_data.X_z(:,:,tT);zeros(N-size(obj.stem_model.stem_data.X_z(:,:,tT),1),size(obj.stem_model.stem_data.X_z(:,:,tT),2))];
                                orlated=true;
                            else
                                orlated=false;
                            end
                            temp1=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(cov_wr_z_y1(:,:,t),M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),j_r,'l');
                            temp2=zeros(size(temp1,1));
                            if N>obj.stem_model.system_size
                                blocks=0:80:size(temp1,1);
                                if not(blocks(end)==size(temp1,1))
                                    blocks=[blocks size(temp1,1)];
                                end
                                for i=1:length(blocks)-1
                                    if orlated
                                        temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                                    else
                                        temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                                    end
                                end
                            else
                                temp2=diag(temp1*X_z_orlatated');
                            end
                            sum_num=sum_num-sum(temp2(Lt));
                        end
                        
                        if par.k>0
                            if obj.stem_model.stem_data.X_g_tv
                                tG=t;
                            else
                                tG=1;
                            end
                            for k=1:K
                                temp1=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,k),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),j_r,'l');
                                temp2=[obj.stem_model.stem_data.X_g(:,1,tG,k);zeros(size(temp1,1)-size(obj.stem_model.stem_data.X_g(:,1,tG,k),1),1)];
                                temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',temp2,'r'),aj_g(:,k),'r');
                                sum_num=sum_num-sum(temp1(Lt));
                            end
                        end
                        
                        temp1=E_wr_y1(:,t).^2+diag_Var_wr_y1(:,t);
                        temp1=stem_misc.D_apply(stem_misc.D_apply(stem_misc.M_apply(temp1,M,'l'),obj.stem_model.stem_data.X_rg(:,1,tRG),'b'),j_r,'b');
                        sum_den=sum_den+sum(temp1(Lt));
                    end
                    alpha_rg(r)=sum_num/sum_den;
                end
                st_par_em_step.alpha_rg=alpha_rg';
                ct2=clock;
                disp(['    alpha_rg update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                
                disp('    v_r update started...');
                %AGGIUNGERE LA STIMA A BLOCCHI ANCHE PER v_r?????
                ct1=clock;
                if Nr<=obj.stem_EM_options.mstep_system_size
                    temp=zeros(size(sum_Var_wr_y1));
                    for t=1:T
                        temp=temp+E_wr_y1(:,t)*E_wr_y1(:,t)';
                    end
                    temp=temp+sum_Var_wr_y1;
                end
                
                if par.pixel_correlated
                    %indices are permutated in order to avoid deadlock
                    kindex=randperm(size(par.v_r,1));
                    for k=kindex
                        hindex=randperm(size(par.v_r,1)-k)+k;
                        for h=hindex
                            initial=par.v_r(k,h);
                            if Nr<=obj.stem_EM_options.mstep_system_size
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_r,par.theta_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                    obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            else
                                disp('WARNING: this operation will take a long time');
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_r,par.theta_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                    obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.v_r(k,h)=min_result;
                            st_par_em_step.v_r(h,k)=min_result;
                        end
                    end
                    ct2=clock;
                    disp(['    v_r update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                end
                
                disp('    theta_r updating started...');
                ct1=clock;
                initial=par.theta_r;
                if par.pixel_correlated
                    if Nr<=obj.stem_EM_options.mstep_system_size
                        min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                            obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        st_par_em_step.theta_r=exp(min_result);
                    else
                        if obj.stem_model.stem_data.stem_varset_r.nvar>1
                            disp('WARNING: this operation will take a long time');
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r,...
                                obj.stem_model.stem_data.stem_varset_r.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_r=exp(min_result);
                        else
                            s=ceil(Nr/obj.stem_EM_options.mstep_system_size);
                            step=ceil(Nr/s);
                            blocks=0:step:Nr;
                            if not(blocks(end)==Nr)
                                blocks=[blocks Nr];
                            end
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wr_y1(idx,t)*E_wr_y1(idx,t)';
                                end
                                temp=temp+sum_Var_wr_y1(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_r=exp(mean(min_result));
                        end
                    end
                else
                    if Nr<=obj.stem_EM_options.mstep_system_size
                        blocks=[0 cumsum(obj.stem_model.stem_data.stem_varset_r.dim)];
                        for i=1:obj.stem_model.stem_data.stem_varset_r.nvar
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(blocks(i)+1:blocks(i+1),blocks(i)+1:blocks(i+1)),...
                                obj.stem_model.stem_data.stem_varset_r.dim(i),temp(blocks(i)+1:blocks(i+1),blocks(i)+1:blocks(i+1)),T,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial(i)),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_r(i)=exp(min_result);
                        end
                    else
                        blocks_var=[0 cumsum(obj.stem_model.stem_data.stem_varset_r.dim)];
                        for i=1:obj.stem_model.stem_data.stem_varset_r.nvar
                            s=ceil(obj.stem_model.stem_data.stem_varset_r.dim(i)/obj.stem_EM_options.mstep_system_size);
                            step=ceil(obj.stem_model.stem_data.stem_varset_r.dim(i)/s);
                            blocks=blocks_var(i):step:blocks_var(i+1);
                            if not(blocks(end)==blocks_var(i+1))
                                blocks=[blocks blocks_var(i+1)];
                            end
                            min_result=[];
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wr_y1(idx,t)*E_wr_y1(idx,t)';
                                end
                                temp=temp+sum_Var_wr_y1(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_r,par.correlation_type,obj.stem_model.stem_data.DistMat_r(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_r.tap),log(initial(i)),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_r(i)=exp(mean(min_result));
                        end
                    end
                    ct2=clock;
                    disp(['    theta_r update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                end
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %          alpha_g               %
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if not(isempty(obj.stem_model.stem_data.X_g))
                disp('    alpha_g update started...');
                for s=1:K
                    for r=1:obj.stem_model.stem_data.stem_varset_g.nvar
                        [aj_g_rs,j_r] = obj.stem_model.get_jg(r,s);
                        sum_num=0;
                        sum_den=0;
                        for t=1:T
                            if obj.stem_model.stem_data.X_rg_tv
                                tRG=t;
                            else
                                tRG=1;
                            end
                            if obj.stem_model.stem_data.X_z_tv
                                tT=t;
                            else
                                tT=1;
                            end
                            if obj.stem_model.stem_data.X_g_tv
                                tG=t;
                            else
                                tG=1;
                            end
                            Lt=not(isnan(obj.stem_model.stem_data.Y(:,t)));
                            
                            temp1=E_e_y1(:,t)+stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,s),obj.stem_model.stem_data.X_g(:,1,tG,s),'l'),aj_g_rs,'l');
                            temp2=stem_misc.D_apply(stem_misc.D_apply(E_wg_y1(:,t,s)',obj.stem_model.stem_data.X_g(:,1,tG,s),'r'),j_r,'r');
                            sum_num=sum_num+sum(temp1(Lt).*temp2(Lt)');
                            
                            if par.p>0
                                temp1=stem_misc.D_apply(stem_misc.D_apply(cov_wg_z_y1(:,:,t,s),obj.stem_model.stem_data.X_g(:,1,tG,s),'l'),j_r,'l');
                                temp2=zeros(size(temp1,1),1);
                                if N>obj.stem_model.system_size
                                    blocks=0:80:size(temp1,1);
                                    if not(blocks(end)==size(temp1,1))
                                        blocks=[blocks size(temp1,1)];
                                    end
                                    for i=1:length(blocks)-1
                                        if orlated
                                            temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*X_z_orlated(blocks(i)+1:blocks(i+1),:)');
                                        else
                                            temp2(blocks(i)+1:blocks(i+1),1)=diag(temp1(blocks(i)+1:blocks(i+1),:)*obj.stem_model.stem_data.X_z(blocks(i)+1:blocks(i+1),:,tT)');
                                        end
                                    end
                                else
                                    if orlated
                                        temp2=diag(temp1*X_z_orlated');
                                    else
                                        temp2=diag(temp1*obj.stem_model.stem_data.X_z(:,:,tT)');
                                    end
                                end
                                sum_num=sum_num-sum(temp2(Lt));
                            end
                            
                            if K>1
                                for k=1:K
                                    if not(k==s)
                                        if k<s
                                            kk=s;
                                            ss=k;
                                        else
                                            kk=k;
                                            ss=s;
                                        end
                                        temp1=stem_misc.D_apply(stem_misc.D_apply(cov_wgk_wgh_y1{kk,ss}(:,t),obj.stem_model.stem_data.X_g(:,1,tG,k),'l'),aj_g(:,k),'l');
                                        temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',[obj.stem_model.stem_data.X_g(:,1,tG,s);zeros(Nr,1)],'r'),j_r,'r');
                                        sum_num=sum_num-sum(temp1(Lt));
                                    end
                                end
                            end
                            
                            if not(isempty(obj.stem_model.stem_data.X_rg))
                                temp1=stem_misc.D_apply(stem_misc.D_apply(M_cov_wr_wg_y1(:,t,s),obj.stem_model.stem_data.X_rg(:,1,tRG),'l'),aj_rg,'l');
                                temp2=[obj.stem_model.stem_data.X_g(:,1,tG,s);zeros(size(temp1,1)-size(obj.stem_model.stem_data.X_g(:,1,tG,s),1),1)];
                                temp1=stem_misc.D_apply(stem_misc.D_apply(temp1',temp2,'r'),j_r,'r');
                                sum_num=sum_num-sum(temp1(Lt));
                            end
                            
                            temp1=E_wg_y1(:,t,s).^2+diag_Var_wg_y1(:,t,s);
                            temp1=stem_misc.D_apply(stem_misc.D_apply(temp1,obj.stem_model.stem_data.X_g(:,1,tG,s),'b'),j_r,'b');
                            sum_den=sum_den+sum(temp1(Lt));
                        end
                        alpha_g(r,s)=sum_num/sum_den;
                    end
                end
                st_par_em_step.alpha_g=alpha_g;
                ct2=clock;
                disp(['    alpha_g update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
                
                %indices are permutated in order to avoid deadlock
                disp('    v_g and theta_g update started...');
                ct1=clock;
                for z=index %note that z moves over index and not from 1 to K 
                    if Ng<=obj.stem_EM_options.mstep_system_size
                        temp=zeros(size(sum_Var_wg_y1{z}));
                        for t=1:T
                            temp=temp+E_wg_y1(:,t,z)*E_wg_y1(:,t,z)';
                        end
                        temp=temp+sum_Var_wg_y1{z};
                    end
                    
                    kindex=randperm(size(par.v_g(:,:,z),1));
                    for k=kindex
                        hindex=randperm(size(par.v_g(:,:,z),1)-k)+k;
                        for h=hindex
                            initial=par.v_g(k,h,z);
                            ctv1=clock;
                            if Ng<=obj.stem_EM_options.mstep_system_size
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_g(:,:,z),par.theta_g(z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                    obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            else
                                disp('WARNING: this operation will take a long time');
                                min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,par.v_g(:,:,z),par.theta_g(z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                    obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            ctv2=clock;
                            disp(['    v_g(',num2str(h),',',num2str(k),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
                            st_par_em_step.v_g(k,h,z)=min_result;
                            st_par_em_step.v_g(h,k,z)=min_result;
                        end
                    end
                    
                    initial=par.theta_g(z);
                    ctv1=clock;
                    if Ng<=obj.stem_EM_options.mstep_system_size
                        min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                            obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        st_par_em_step.theta_g(z)=exp(min_result);
                    else
                        if obj.stem_model.stem_data.stem_varset_g.nvar>1
                            disp('WARNING: this operation will take a long time');
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                obj.stem_model.stem_data.stem_varset_g.dim,temp,T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            st_par_em_step.theta_g(z)=exp(min_result);
                        else
                            s=ceil(Ng/obj.stem_EM_options.mstep_system_size);
                            step=ceil(Ng/s);
                            blocks=0:step:Ng;
                            if not(blocks(end)==Ng)
                                blocks=[blocks Ng];
                            end
                            for j=1:length(blocks)-1
                                block_size=blocks(j+1)-blocks(j);
                                idx=blocks(j)+1:blocks(j+1);
                                temp=zeros(block_size);
                                for t=1:T
                                    temp=temp+E_wg_y1(idx,t,z)*E_wg_y1(idx,t,z)';
                                end
                                temp=temp+sum_Var_wg_y1{z}(idx,idx);
                                min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,par.v_g(:,:,z),par.correlation_type,obj.stem_model.stem_data.DistMat_g(idx,idx),...
                                    length(idx),temp,t,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                            end
                            st_par_em_step.theta_g(z)=exp(mean(min_result));
                        end
                    end
                    ctv2=clock;
                    disp(['    theta_g(',num2str(z),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
                end
                ct2=clock;
                disp(['    v_g and theta_g update ended in ',stem_misc.decode_time(etime(ct2,ct1))]);
            end
            
            if obj.stem_model.stem_par.clustering==1
                if not(isempty(st_kalmansmoother_result))
                    clear E_e_y1
                    clear diag_Var_e_y1
                    clear sigma_eps
                    clear inv_sigma_eps
                    clear temp1
                    clear d
                    clear I
                    clear K
                    if size(obj.stem_model.stem_data.X_z,3)==1
                        %correlation computation
                        for i=1:N
                            L=not(isnan(obj.stem_model.stem_data.Y(i,:)));
                            a=obj.stem_model.stem_data.Y(i,L)';
                            b=st_kalmansmoother_result.zk_s(:,2:end)';
                            b=b(L,:);
                            if not(isempty(b))
                                temp=corr(a,b);
                            else
                                temp=repmat(0.0001,1,par.p);
                            end
                            temp(temp<=0)=0.0001;
                            temp(isnan(temp))=0.0001;
                            obj.stem_model.stem_data.X_z(i,:)=temp;
                        end
                        
                        theta_clustering=obj.stem_model.stem_par.theta_clustering;
                        if theta_clustering>0
                            for i=1:N
                                v=exp(-obj.stem_model.stem_data.DistMat_g(:,i)/theta_clustering);
                                for j=1:par.p
                                    obj.stem_model.stem_data.X_z(i,j)=(v'*obj.stem_model.stem_data.X_z(:,j))/length(v);
                                end
                            end
                        end
                        
                        %weight computation
                        for h=1:iteration
                            obj.stem_model.stem_data.X_z=obj.stem_model.stem_data.X_z.^2;
                            ss=sum(obj.stem_model.stem_data.X_z,2);
                            for j=1:size(obj.stem_model.stem_data.X_z,2)
                                obj.stem_model.stem_data.X_z(:,j)=obj.stem_model.stem_data.X_z(:,j)./ss;
                            end
                        end
                    else
                        error('The Kalman smoother output is empty');
                    end
                end
            end
            obj.stem_model.stem_par=st_par_em_step;
            ct2_mstep=clock;
            disp(['  M step ended in ',stem_misc.decode_time(etime(ct2_mstep,ct1_mstep))]);
        end
        
        function st_par_em_step = M_step_vg_and_theta(obj,E_wg_y1,sum_Var_wg_y1,index)
            %DESCRIPTION: parallel version of the M-step of the EM algorithm only for the parameters v_g and theta_g
            %
            %INPUT
            %obj                            - [stem_EM object]  (1x1)
            %E_wg_y1                        - [double]          (N_gxTxK) E[wg_k|Y(1)]
            %sum_Var_wg_y1                  - [double]          {k}(N_gxN_g) sum(Var[wg_k|Y(1)])
            %diag_Var_wg_y1                 - [double]          (N_gxTxK) diagonals of Var[wg_k|Y(1)]
            %index                          - [integer >0]      (dKx1) the subset of indices from 1 to K with respect to which estimate the elements of theta_g and v_g          
            %
            %OUTPUT
            %none: the stem_par property of the stem_model object is updated               
            st_par_em_step=obj.stem_model.stem_par;
            Ng=obj.stem_model.stem_data.stem_varset_g.N;
            for z=index
                if Ng<=obj.stem_EM_options.mstep_system_size
                    temp=zeros(size(sum_Var_wg_y1{z-index(1)+1}));
                    for t=1:size(E_wg_y1,2)
                        temp=temp+E_wg_y1(:,t,z-index(1)+1)*E_wg_y1(:,t,z-index(1)+1)';
                    end
                    temp=temp+sum_Var_wg_y1{z-index(1)+1};
                end
                kindex=randperm(size(st_par_em_step.v_g(:,:,z),1));
                for k=kindex
                    hindex=randperm(size(st_par_em_step.v_g(:,:,z),1)-k)+k;
                    for h=hindex
                        initial=st_par_em_step.v_g(k,h,z);
                        ctv1=clock;
                        if Ng<=obj.stem_EM_options.mstep_system_size
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,st_par_em_step.v_g(:,:,z),st_par_em_step.theta_g(z),st_par_em_step.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                obj.stem_model.stem_data.stem_varset_g.dim,temp,obj.stem_model.stem_data.T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        else
                            disp('WARNING: this operation will take a long time');
                            min_result = fminsearch(@(x) stem_EM.geo_coreg_function_velement(x,k,h,st_par_em_step.v_g(:,:,z),st_par_em_step.theta_g(z),st_par_em_step.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                                obj.stem_model.stem_data.stem_varset_g.dim,temp,obj.stem_model.stem_data.T,obj.stem_model.stem_data.stem_gridlist_g.tap),initial,optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        end
                        ctv2=clock;
                        disp(['    v_g(',num2str(h),',',num2str(k),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
                        st_par_em_step.v_g(k,h,z)=min_result;
                        st_par_em_step.v_g(h,k,z)=min_result;
                    end
                end
                
                initial=st_par_em_step.theta_g(z);
                ctv1=clock;
                if Ng<=obj.stem_EM_options.mstep_system_size
                    min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,st_par_em_step.v_g(:,:,z),st_par_em_step.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                        obj.stem_model.stem_data.stem_varset_g.dim,temp,obj.stem_model.stem_data.T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                    st_par_em_step.theta_g(z)=exp(min_result);
                else
                    if obj.stem_model.stem_data.stem_varset_g.nvar>1
                        disp('WARNING: this operation will take a long time');
                        min_result = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,st_par_em_step.v_g(:,:,z),st_par_em_step.correlation_type,obj.stem_model.stem_data.DistMat_g,...
                            obj.stem_model.stem_data.stem_varset_g.dim,temp,obj.stem_model.stem_data.T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        st_par_em_step.theta_g(z)=exp(min_result);
                    else
                        s=ceil(Ng/obj.stem_EM_options.mstep_system_size);
                        step=ceil(Ng/s);
                        blocks=0:step:Ng;
                        if not(blocks(end)==Ng)
                            blocks=[blocks Ng];
                        end
                        for j=1:length(blocks)-1
                            block_size=blocks(j+1)-blocks(j);
                            idx=blocks(j)+1:blocks(j+1);
                            temp=zeros(block_size);
                            for t=1:size(E_wg_y1,2)
                                temp=temp+E_wg_y1(idx,t,z-index(1)+1)*E_wg_y1(idx,t,z-index(1)+1)';
                            end
                            temp=temp+sum_Var_wg_y1{z-index(1)+1}(idx,idx);
                            min_result(j,:) = fminsearch(@(x) stem_EM.geo_coreg_function_theta(x,st_par_em_step.v_g(:,:,z),st_par_em_step.correlation_type,obj.stem_model.stem_data.DistMat_g(idx,idx),...
                                length(idx),temp,obj.stem_model.stem_data.T,obj.stem_model.stem_data.stem_gridlist_g.tap),log(initial),optimset('MaxIter',20,'TolFun',1,'UseParallel','always'));
                        end
                        st_par_em_step.theta_g(z)=exp(mean(min_result));
                    end
                end
                ctv2=clock;
                disp(['    theta_g(',num2str(z),') update ended in ',stem_misc.decode_time(etime(ctv2,ctv1))]);
            end
        end
        
        %Class set function
        function set.stem_model(obj,stem_model)
            if strcmp(class(stem_model),'stem_model')
                obj.stem_model=stem_model;
            else
                error('You have to provide an object of class stem_model');
            end
        end
    end

    
    methods (Static)
        function f = geo_coreg_function_theta(log_theta,v,correlation_type,DistMat,var_dims,U,T,tapering_par)
            %DESCRIPTION: log-likelihood evaluation with respect to the theta_r or theta_g parameter
            %
            %INPUT
            %log_theta          - [double]      (1x1) natural logarithm of theta
            %v                  - [double]      (qxq) the v_r of v_q matrix
            %correlation type   - [double]      (1x1) either 'exponential' or 'matern'
            %DistMat            - [double]      (N_g|N_rxN_g|N_r) the distance matrix
            %var_dims           - [double]      (qx1) the number of time series for each variable
            %U                  - [double]      (N_g|N_rxN_g|N_r) sum(Var[w|Y(1)]+E[w|Y(1)]*E[w|Y(1)]') there w is w_r of w_g
            %T                  - [integer >0]  (1x1) number of time steps
            %tapering_par       - [double >0]   (1x1) maximum distance after which the spatial correlation is zero
            %
            %OUTPUT
            %f: the log-likelihood value
            
            theta=exp(log_theta);
            n_var=length(var_dims);
            
            if min(eig(v))>0
                if not(isempty(tapering_par))
                    I=zeros(nnz(DistMat),1);
                    J=zeros(nnz(DistMat),1);
                    elements=zeros(nnz(DistMat),1);
                    idx=0;
                    blocks=[0 cumsum(var_dims)];
                    for j=1:n_var
                        for i=j:n_var
                            [B,block_i,block_j] = stem_misc.get_block(var_dims,i,var_dims,j,DistMat);
                            corr_result=stem_misc.correlation_function(theta,B,correlation_type);
                            weights=stem_misc.wendland(B,tapering_par); %possibile calcolarli una sola volta???
                            corr_result.correlation=v(i,j)*corr_result.correlation.*weights;
                            l=length(corr_result.I);
                            I(idx+1:idx+l)=corr_result.I+blocks(i);
                            J(idx+1:idx+l)=corr_result.J+blocks(j);
                            elements(idx+1:idx+l)=corr_result.correlation;
                            idx=idx+l;
                            if not(i==j)
                                I(idx+1:idx+l)=corr_result.J+blocks(j);
                                J(idx+1:idx+l)=corr_result.I+blocks(i);
                                elements(idx+1:idx+l)=corr_result.correlation;
                                idx=idx+l;
                            end
                            
                        end
                    end
                    sigma_W=sparse(I,J,elements);
                else
                    sigma_W=zeros(sum(var_dims));
                    for j=1:n_var
                        for i=j:n_var
                            [B,block_i,block_j] = stem_misc.get_block(var_dims,i,var_dims,j,DistMat);
                            sigma_W(block_i,block_j)=v(i,j)*stem_misc.correlation_function(theta,B,correlation_type);
                            if not(isempty(tapering_par))
                                sigma_W(block_i,block_j)=sigma_W(block_i,block_j).*stem_misc.wendland(DistMat(block_i,block_j),tapering_par);
                            end
                            if (i~=j)
                                sigma_W(block_j,block_i)=sigma_W(block_i,block_j)';
                            end
                        end
                    end
                end
                
                if strcmp(correlation_type,'matern')
                    for i=1:size(sigma_W,1)
                        sigma_W(i,i)=1;
                    end
                    sigma_W(isnan(sigma_W_core))=0;
                end
                if not(isempty(tapering_par))
                    r = symamd(sigma_W);
                    c=chol(sigma_W(r,r));
                    f=2*T*sum(log(diag(c)))+trace(sigma_W(r,r)\U(r,r));
                else
                    c=chol(sigma_W);
                    f=2*T*sum(log(diag(c)))+trace(stem_misc.chol_solve(c,U));
                end
            else
                f=10^10;
            end
        end
        
        function f = geo_coreg_function_velement(v_element,row,col,v,theta,correlation_type,DistMat,var_dims,U,T,tapering_par)
            %DESCRIPTION: log-likelihood evaluation with respect to an extra-diagonal element of v_r or v_g
            %
            %INPUT
            %v_element          - [double]      (1x1) the extra-diagonal element of v_r or v_g
            %row                - [double]      (1x1) the row index of the v_element
            %col                - [double]      (1x1) the column index of the v_element
            %v                  - [double]      (qxq) the full v_r or v_g matrix
            %theta              - [double>0]    (1x1) the value of theta_r or theta_g
            %correlation type   - [double]      (1x1) either 'exponential' or 'matern'
            %DistMat            - [double]      (N_g|N_rxN_g|N_r) the distance matrix
            %var_dims           - [double]      (qx1) the number of time series for each variable
            %U                  - [double]      (N_g|N_rxN_g|N_r) sum(Var[w|Y(1)]+E[w|Y(1)]*E[w|Y(1)]') there w is w_r of w_g
            %T                  - [integer >0]  (1x1) number of time steps
            %tapering_par       - [double >0]   (1x1) maximum distance after which the spatial correlation is zero
            %
            %OUTPUT
            %f: the log-likelihood value
            
            n_var=length(var_dims);
            v(row,col)=v_element;
            v(col,row)=v_element;
            
            if min(eig(v))>0
                if not(isempty(tapering_par))
                    sigma_W=DistMat;
                else
                    sigma_W=zeros(sum(var_dims));
                end
                
                if not(isempty(tapering_par))
                    I=zeros(nnz(DistMat),1);
                    J=zeros(nnz(DistMat),1);
                    elements=zeros(nnz(DistMat),1);
                    idx=0;
                    blocks=[0 cumsum(var_dims)];
                    for j=1:n_var
                        for i=j:n_var
                            [B,block_i,block_j] = stem_misc.get_block(var_dims,i,var_dims,j,DistMat);
                            corr_result=stem_misc.correlation_function(theta,B,correlation_type);
                            weights=stem_misc.wendland(B,tapering_par); %possibile calcolarli una sola volta???
                            corr_result.correlation=v(i,j)*corr_result.correlation.*weights;
                            l=length(corr_result.I);
                            I(idx+1:idx+l)=corr_result.I+blocks(i);
                            J(idx+1:idx+l)=corr_result.J+blocks(j);
                            elements(idx+1:idx+l)=corr_result.correlation;
                            idx=idx+l;
                            if not(i==j)
                                I(idx+1:idx+l)=corr_result.J+blocks(j);
                                J(idx+1:idx+l)=corr_result.I+blocks(i);
                                elements(idx+1:idx+l)=corr_result.correlation;
                                idx=idx+l;
                            end
                        end
                    end
                    sigma_W=sparse(I,J,elements);
                else
                    for j=1:n_var
                        for i=j:n_var
                            [B,block_i,block_j] = stem_misc.get_block(var_dims,i,var_dims,j,DistMat);
                            sigma_W(block_i,block_j)=v(i,j)*stem_misc.correlation_function(theta,B,correlation_type);
                            if not(isempty(tapering_par))
                                sigma_W(block_i,block_j)=sigma_W(block_i,block_j).*stem_misc.wendland(DistMat(block_i,block_j),tapering_par);
                            end
                            if (i~=j)
                                sigma_W(block_j,block_i)=sigma_W(block_i,block_j)';
                            end
                        end
                    end
                end
                if strcmp(correlation_type,'matern')
                    for i=1:size(sigma_W,1)
                        sigma_W(i,i)=1;
                    end
                    sigma_W(isnan(sigma_W_core))=0;
                end
                if not(isempty(tapering_par))
                    r = symamd(sigma_W);
                    c=chol(sigma_W(r,r));
                    f=2*T*sum(log(diag(c)))+trace(stem_misc.chol_solve(c,U(r,r)));
                else
                    c=chol(sigma_W);
                    f=2*T*sum(log(diag(c)))+trace(stem_misc.chol_solve(c,U));
                end
            else
                f=10^10;
            end
        end
    end
end

