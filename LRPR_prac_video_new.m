function [B_hat, Uo, Xhat3, Uo_track, err_iter, time_iter] = ...
    LRPR_prac_video_new(Params, Paramsrwf, Y, Afull, Afull_t, Afull_tk, X)
Ysqrt = sqrt(Y);
err_iter = zeros(Params.tnew, 1);
time_iter = zeros(Params.tnew, 1);
%%contains some changes to consider the CDP setting. Check if it can be
%%made general to be able to handle simulated data too
%X_hat = zeros(100);
tic;
for  o = 1 :Params.tnew % Main loop
    fprintf('outer loop iteration %d\n', o)
    %%%%%%%
    % Initialization
    %%%%%%%
    if o == 1
        fprintf('initialization\n');
        %Den_X      =   norm(X,'fro');
        
        %truncating the measurements
        Ytrk    =   zeros(Params.n_1,Params.n_2,Params.L,Params.q);
        for ni = 1 : Params.q
            Yk  =   reshape( Y(:,:,:,ni) , Params.n_1*Params.n_2*Params.L, 1);
            normest =   sum(Yk(:))/Params.m;
            Eyk     =   ( Yk <= Params.alpha_y^2 *normest);
            Ytrk(:,:,:,ni)  =   reshape(Eyk.*Yk,Params.n_1,Params.n_2,Params.L);
        end
        
        %initializing U
        U_tmp1  = randn(Params.n_1*Params.n_2,Params.r);
        [U_upd_vec, ~, ~]   =   qr(U_tmp1, 0);
        Uupdt          =   reshape(U_upd_vec, Params.n_1, Params.n_2, Params.r);
        U_tmp   =  zeros(Params.n_1,Params.n_2,Params.r);
        
        for t = 1 : Params.itr_num_pow_mth
            %fprintf('power method iteration %d\n', t);
            for nr  =   1 : Params.r
                U_tmp(:,:,nr) = Afull_t( Ytrk.* Afull(repmat(Uupdt(:,:,nr), [1,1,Params.q])));
            end
            [Uupdt3, ~, ~]   =   qr(reshape(U_tmp, Params.n_1*Params.n_2, Params.r), 0);
            Uupdt            =     reshape(Uupdt3, Params.n_1, Params.n_2, Params.r);
        end
        Uhat_vec    =   reshape(Uupdt, Params.n_1*Params.n_2, Params.r);
        Uhat            =    Uhat_vec;
        %[Qu, ~] = BlockIter(Uhat, 100, Params.r);
        [Qu, ~] = qr(Uhat, 0);
        Uo = Qu(:, 1 : Params.r);
        Uo_track{o} = Uo;
    end
    
    %%trying to use 2d RWF on r X q matrix B
    
    %A_U takes r x q and returns m x q
    
    A_pr = @(I) reshape(Afull(reshape(Uo * I, Params.n_1, Params.n_2, Params.q)), [], Params.q);
    At_pr = @(W) Uo' * ...
        reshape(Afull_tk(reshape(W, Params.n_1, Params.n_2, Params.L, Params.q)), [], Params.q) ;
    
    
    y_tmp = reshape(sqrt(Y), [], Params.q);
    Paramsrwf.Tb_LRPRnew = Params.Tb_LRPRnew(o);
    Paramsrwf.n_1 = Params.r;
    Paramsrwf.n_2 = Params.q;
    B_hat = RWF_2d(y_tmp, Paramsrwf, A_pr, At_pr);
    Xhat3 = Uo * B_hat;
    Chat = reshape(exp(1i * angle(A_pr(B_hat))), Params.n_1, Params.n_2, Params.L, Params.q);
    
    %B_hat  =   zeros(Params.r, Params.q);
    %Chat = zeros(Params.n_1 * Params.n_2, Params.q);
    %Xhat3 = zeros(Params.n_1 * Params.n_2, Params.q);
    %     Chat = zeros(size(Y));
    %     for ni = 1 : Params.q
    %         %fprintf('RWF for %d\n', ni);
    %         Masks  =   Masks2(:,:,:,ni);
    %         A_pr  = @(I)  reshape(fft2( Masks .* ...
    %             reshape(repmat(Uo, Params.L, 1) * I, Params.n_1, Params.n_2, Params.L)), [],1);
    %         At_pr = @(W) Params.n_1 * Params.n_2 * Uo' * reshape(sum(conj(Masks) .* ...
    %             ifft2(reshape(W, Params.n_1, Params.n_2, Params.L)), 3), [], 1);
    %
    %         y_tmp = reshape(Y(:, :, :, ni), [], 1);
    %         Paramsrwf.Tb_LRPRnew = Params.Tb_LRPRnew(o);
    %         [bhat] = RWFsimple(sqrt(y_tmp), Paramsrwf, A_pr, At_pr);
    %         B_hat(:, ni) = bhat;
    %         %x_k =  Uo *  B_hat(:,ni);
    %         Chat3 = exp(1i * angle(A_pr(B_hat(:,ni))));
    %         %Xhat3(:, ni) = x_k;
    %         Chat(:, :, :, ni) = reshape(Chat3, Params.n_1, Params.n_2, Params.L, 1); %reshape(repmat(Chat3, Params.L, 1), Params.n_1, Params.n_2, Params.L, 1);
    %     end
    %
    %     Xhat3 = Uo * B_hat;
    Den_X      =   norm(X,'fro');
    Tmp_Err_X2   =   zeros(Params.q, 1);
    for   ct    =  1  :   Params.q
        xa_hat        =   Xhat3(:,ct);
        xa            =   X(:,ct);
        Tmp_Err_X2(ct)  =   norm(xa - exp(-1i*angle(trace(xa'*xa_hat))) * xa_hat, 'fro');
    end
    Nom_Err_X_twf	    =   sum(Tmp_Err_X2);
    err_iter(o)             =  Nom_Err_X_twf / Den_X;
    
    %     [Qb,~] = BlockIter(B_hat', 100, Params.r);
    [Qb,~] = qr(B_hat', 0);% 100, Params.r);
    Bo = Qb(:, 1:Params.r)';
    
    if (o==1)
        D      =    Uo*B_hat;
        Den_X      =   norm(X,'fro');
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%initialization error
        for na = 1 : Params.q
            xa_hat      =   D(:,na);
            xa          =   X(:,na);
            %                 %  Tmp_Err_X(na)   =   min(norm(xa-xa_hat)^2, norm(xa+xa_hat)^2);
            Tmp_Err_X1(na) 	=   norm(xa - exp(-1i*angle(trace(xa'*xa_hat))) * xa_hat, 'fro');
        end
        % Rel_Err(:,t)=  Tmp_Err_X;
        Err      = sum(Tmp_Err_X1);
        ERRinit     =   Err / Den_X;
        fprintf('Our initialization Error is:\t%2.2e\n',ERRinit);
    end
    
    
    K1       =   Chat .* Ysqrt; %sqrt;
    Zvec     =   reshape(K1,Params.n_1*Params.n_2*Params.L*Params.q,1);
    Uvec    =   cgls_new(@mult_H2, @mult_Ht2 , Zvec, 0,1e-6 ,3);
    U_hat    =   reshape(Uvec, Params.n_1*Params.n_2, Params.r);
    
    
    %[Qu,~]  =  BlockIter(U_hat, 100, Params.r);
    [Qu,~] = qr(U_hat, 0);
    Uo  =  Qu(:, 1:Params.r);
    Uo_track{o} = Uo;
    time_iter(o) = toc;
    
    
end
    function i_out = mult_H2(i_in)
        I_mat    =   reshape(i_in, Params.n_1*Params.n_2, Params.r);
        % i_out    =   zeros(Params.q*Params.m, 1);
        Xmat        =    I_mat * Bo;
        Xmat2   =   reshape(Xmat,Params.n_1,Params.n_2,Params.q);
        Iout        =     Afull(Xmat2);
        i_out       =     reshape(Iout,Params.q*Params.m, 1);
    end

%   Defining mult_Ht

    function w_out = mult_Ht2(w_in)
        w_out   =   zeros(Params.n_1*Params.n_2*Params.r, 1);
        TmpVec  =    permute(Afull_tk(reshape(w_in, Params.n_1,Params.n_2,Params.L,Params.q)), [1,2,4,3]);
        for nk = 1: Params.q
            w_out    =   w_out + kron(Bo(:,nk), reshape(TmpVec(:,:,nk), Params.n_1*Params.n_2, 1));
        end
    end
end