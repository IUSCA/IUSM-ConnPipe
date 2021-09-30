clear all
close all
clc

path2code = pwd;
path2dvars = '/basepath/ConnPipelineSM/DVARS';
addpath(genpath(path2dvars));
addpath('/basepath/ConnPipelineSM/toolbox_matlab_nifti')

% set path to data directory
path2data = '/N/project/DataDir';

% Define Subjects to run
subjectList = dir(fullfile(path2data,'Subj0*'));   % e.g. All subjects in path2data direcotry whose ID starts with Subj0
% Or a specific set of subjects:
% subjectList(1).name = 'Subj02'; 
% subjectList(2).name = 'Subj09'; 


% These variables should be set up to match the config.sh settings
path2reg = 'HMPreg/aCompCorr'; %other options may be: 'AROMA/aCompCorr', HMPreg/PhysReg, AROMA/PhysReg;
pre_nR = 'hmp12_pca5_Gs4_DCT'; % This should match the regression parameters of your 8_epi_*.nii.gz image; other options may be: 'aroma_pca3_Gs2_DCT';
DVARS = true; 
% postregression parameters
demean_detrend = false;
bandpass = false;
scrubbed = true; 
% ----------------Do not modify the following section ------------------------ %
if DVARS
    nR = strcat(pre_nR,'_DVARS');
else
    nR = pre_nR;
end
if demean_detrend
    post_nR = strcat(nR,'_dmdt');
else
    post_nR = nR;
end
if bandpass
    post_nR = strcat(post_nR,'_butter');
end
if scrubbed
    post_nR = strcat(post_nR,'_scrubbed');
end
 % ---------------------------------------------------------------------- %                    
%% =========================================================================
% SET WHICH PARCELLATIONS YOU WANT TO USE
% Schaefer parcellation of yeo17 into 200 nodes
parcs.plabel(1).name='schaefer200_yeo17';
parcs.pdir(1).name='Schaefer2018_200Parcels_17Networks_order_FSLMNI152_1mm';
parcs.pcort(1).true=1;
parcs.pnodal(1).true=1;
parcs.psubcortonly(1).true=0;

% Schaefer parcellation of yeo17 into 300 nodes
parcs.plabel(2).name='schaefer300_yeo17';
parcs.pdir(2).name='Schaefer2018_300Parcels_17Networks_order_FSLMNI152_1mm';
parcs.pcort(2).true=1;
parcs.pnodal(2).true=1;
parcs.psubcortonly(2).true=0;

% yeo 17 resting state network parcellation
parcs.plabel(3).name='yeo17';
parcs.pdir(3).name='yeo17_MNI152';
parcs.pcort(3).true=1;
parcs.pnodal(3).true=0;
parcs.psubcortonly(3).true=0;

% see MelbourneSubCort for the original parcels 
% Tian subcortical parcellation (7T-derived, S1-S4, coarse-to-fine parcels)
parcs.plabel(4).name='tian_subcortical_S2';
parcs.pdir(4).name='Tian_Subcortex_S2_7T_FSLMNI152_1mm';
parcs.pcort(4).true=0;
parcs.pnodal(4).true=1;
parcs.psubcortonly(4).true=1;

%% UNLESS YOU KNOW WHAT YOU ARE DOING, DON'T TOUCH CODE BELOW THIS LINE!!!
% ========================================================================= 
%                   ---- Figure configurations ----
configs.EPI.preColorMin = 0; % minimum colorbar value for pre-regress plots
configs.EPI.preColorMax = 1500; % maximum colorbar value for pre-regress plots
configs.EPI.postColorMin = 0; % minimum colorbar value for post-regress plots
configs.EPI.postColorMax = 10; % maximum colorbar value for post-regress plots
configs.EPI.DVARSdiffColorMin = -150; % minimum colorbar value for dmdt-regress plots
configs.EPI.DVARSdiffColorMax = 150; % maximum colorbar value for dmdt-regress plots
configs.EPI.parcsColorMin = -10; % minimum colorbar value for parcs-regress plots
configs.EPI.parcsColorMax = 10; % minimum colorbar value for parcs-regress plots
configs.EPI.fcColorMinP = -0.8; % -0.75; % minimum colorbar value for Pearson's FC plots
configs.EPI.fcColorMaxP = 0.8; % 0.75; % maximum colorbar value for Pearson;s FC plots
% histogramming and fitting Pearson's correlations 
configs.EPI.nbinPearson = 201; % number of histogram bins (Pearson's correlation)
configs.EPI.kernelPearsonBw = 0.05; % fitting kernel bandwidth  

%% FOR LOOP OVER SUBJECTS STARTS HERE
% Generate figures for all subjects in subjectList
for i=1:length(subjectList)

    % =========================================================================
    %% GENERATE SUBJECT PATHS
    subjID = subjectList(i).name;
    disp(['======== PROCESING SUBJECT ',subjID,' ========='])

    path2EPI = fullfile(path2data,subjID,'EPI1');
    path2regressors = fullfile(path2EPI,path2reg);  % This needs to be expanded to all nuissance reg options

    timeseriesDir = sprintf('TimeSeries_%s_%s',nR,post_nR);
    nuisanceReg_all = sprintf('NuisanceRegression_%s_%s.mat',nR,post_nR);
    nuisanceReg = sprintf('NuisanceRegression_%s.mat',nR);
    preReg = sprintf('NuisanceRegression_%s.mat',pre_nR);

    path2figures = fullfile(path2EPI,sprintf('figures_%s',timeseriesDir));
    if ~exist( path2figures, 'dir')
        mkdir(path2figures)
    end

    % =========================================================================
    %% LOAD THE DATA

    dvars_series = load(fullfile(path2EPI,'motionMetric_dvars.txt'));
    disp('Loaded: motionMetric_dvars.txt')
    fd_series = load(fullfile(path2EPI,'motionMetric_fd.txt'));
    disp('Loaded: motionMetric_fd.txt')
    mn_reg = load(fullfile(path2EPI, 'motion.txt'));
    disp('Loaded: motion.txt \n')
    tdim = size(dvars_series,1);

    nreg_gs_all = load(fullfile(path2regressors, nuisanceReg_all));
    disp(['Loaded: ',nuisanceReg_all])

    nreg_gs = load(fullfile(path2regressors, nuisanceReg));
    disp(['Loaded: ',nuisanceReg])

    nreg_gs_preDVARS = load(fullfile(path2regressors, preReg));
    preReg_rest_vol = nreg_gs_preDVARS.resting_vol;
    disp(['Loaded: ',preReg])

    gs_data = load(fullfile(path2regressors, 'dataGS.mat'));
    disp('Loaded: dataGS.mat')

    parc_data = cell(1,max(size(parcs.plabel)));
    parc_label = string(zeros(1,max(size(parc_data))));
    for p = 1:max(size(parcs.plabel))
        % nodal-only excluding subcortical-only parcellation
        if parcs.pnodal(p).true == 1 && parcs.psubcortonly(p).true ~= 1
            roi_series = fullfile(path2regressors,timeseriesDir,...
                sprintf('8_epi_%s_ROIs.mat',parcs.plabel(p).name));
            try
                roi_data = load(roi_series);
                disp(strcat('Loaded: 8_epi_', parcs.plabel(p).name, '_ROIs.mat'))
                parc_data{p} = roi_data.restingROIs;
                parc_label(p) = parcs.plabel(p).name;
            catch
                disp(strcat('Time series data for_', parcs.plabel(p).name, '_not found.'))
            end
        else
            parc_label(p) = 'NonNodal';
        end
    end

    % LOAD TISSUE MASKS 
    wm_mask = MRIread(fullfile(path2EPI, 'rT1_WM_mask.nii.gz'));
    wm_mask = wm_mask.vol;
    csf_mask = MRIread(fullfile(path2EPI, 'rT1_CSF_mask.nii.gz'));
    csf_mask = csf_mask.vol;
    gm_mask = MRIread(fullfile(path2EPI, 'rT1_GM_mask.nii.gz'));
    gm_mask = gm_mask.vol;
    xdim = size(gm_mask,1);
    ydim = size(gm_mask,2);
    zdim = size(gm_mask,3);


    gm_pre_regress = zeros(xdim,ydim,zdim,tdim);
    wm_pre_regress = zeros(xdim,ydim,zdim,tdim);
    csf_pre_regress = zeros(xdim,ydim,zdim,tdim);
    for slice = 1:tdim
       gm_out = gm_mask .* preReg_rest_vol(:,:,:,slice);
       gm_pre_regress(:,:,:,slice) = gm_out;
       wm_out = wm_mask .* preReg_rest_vol(:,:,:,slice);
       wm_pre_regress(:,:,:,slice) = wm_out;
       csf_out = csf_mask .* preReg_rest_vol(:,:,:,slice);
       csf_pre_regress(:,:,:,slice) = csf_out;
    end
    gm_pre_regress = reshape(gm_pre_regress,[xdim*ydim*zdim,tdim]);
    wm_pre_regress = reshape(wm_pre_regress,[xdim*ydim*zdim,tdim]);
    csf_pre_regress = reshape(csf_pre_regress,[xdim*ydim*zdim,tdim]);

    % Isolate GM voxels
    numVoxels = max(size(gm_pre_regress));
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_pre_regress(voxel,:)) > 0
          gmCount = gmCount + 1;
       end
    end
    dataGMpre = zeros(gmCount,tdim);
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_pre_regress(voxel,:)) > 0
          dataGMpre(gmCount,:) = gm_pre_regress(voxel,:);
          gmCount = gmCount + 1;
       end
    end
    disp('Loaded: Pre-regression GM data')

    % Isolate WM voxels
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_pre_regress(voxel,:)) > 0
          wmCount = wmCount + 1;
       end
    end
    dataWMpre = zeros(wmCount,tdim);
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_pre_regress(voxel,:)) > 0
          dataWMpre(wmCount,:) = wm_pre_regress(voxel,:);
          wmCount = wmCount + 1;
       end
    end
    disp('Loaded: Pre-regression WM data')

    % Isolate CSF voxels
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_pre_regress(voxel,:)) > 0
          csfCount = csfCount + 1;
       end
    end
    dataCSFpre = zeros(csfCount,tdim);
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_pre_regress(voxel,:)) > 0
          dataCSFpre(csfCount,:) = csf_pre_regress(voxel,:);
          csfCount = csfCount + 1;
       end
    end
    disp('Loaded: Pre-regression CSF data')


    post_resid = nreg_gs_all.resid;
    xdim = size(post_resid,1);
    ydim = size(post_resid,2);
    zdim = size(post_resid,3);
    tdim = size(post_resid,4);
    gm_post_resid = zeros(xdim,ydim,zdim,tdim);
    wm_post_resid = zeros(xdim,ydim,zdim,tdim);
    csf_post_resid = zeros(xdim,ydim,zdim,tdim);
    for slice = 1:tdim
       gm_out = gm_mask .* post_resid(:,:,:,slice);
       gm_post_resid(:,:,:,slice) = gm_out;
       wm_out = wm_mask .* post_resid(:,:,:,slice);
       wm_post_resid(:,:,:,slice) = wm_out;
       csf_out = csf_mask .* post_resid(:,:,:,slice);
       csf_post_resid(:,:,:,slice) = csf_out;
    end
    gm_post_resid = reshape(gm_post_resid,[xdim*ydim*zdim,tdim]);
    wm_post_resid = reshape(wm_post_resid,[xdim*ydim*zdim,tdim]);
    csf_post_resid = reshape(csf_post_resid,[xdim*ydim*zdim,tdim]);

    % Isolate GM voxels
    numVoxels = max(size(gm_post_resid));
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid(voxel,:)) > 0
          gmCount = gmCount + 1;
       end
    end
    dataGMresid = zeros(gmCount,tdim);
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid(voxel,:)) > 0
          dataGMresid(gmCount,:) = gm_post_resid(voxel,:);
          gmCount = gmCount + 1;
       end
    end
    disp('Loaded: Post-regression residual GM data')

    % Isolate WM voxels
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid(voxel,:)) > 0
          wmCount = wmCount + 1;
       end
    end
    dataWMresid = zeros(wmCount,tdim);
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid(voxel,:)) > 0
          dataWMresid(wmCount,:) = wm_post_resid(voxel,:);
          wmCount = wmCount + 1;
       end
    end
    disp('Loaded: Post-regression residual WM data')

    % Isolate CSF voxels
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid(voxel,:)) > 0
          csfCount = csfCount + 1;
       end
    end
    dataCSFresid = zeros(csfCount,tdim);
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid(voxel,:)) > 0
          dataCSFresid(csfCount,:) = csf_post_resid(voxel,:);
          csfCount = csfCount + 1;
       end
    end
    disp('Loaded: Post-regression residual CSF data')


    % %%%%%%%%%%%%%%%%%%%%% LOAD PRE-DVARS RESIDUAL TISSUE DATA %%%%%%%%%%%%%%%%%%%%%
    nreg_gs_postDVARS = nreg_gs.resid;
    nreg_gs_preDVARS = nreg_gs_preDVARS.resid;
    post_resid = nreg_gs_postDVARS - nreg_gs_preDVARS;
    gm_post_resid = zeros(xdim,ydim,zdim,tdim);
    wm_post_resid = zeros(xdim,ydim,zdim,tdim);
    csf_post_resid = zeros(xdim,ydim,zdim,tdim);
    for slice = 1:tdim
       gm_out = gm_mask .* post_resid(:,:,:,slice);
       gm_post_resid(:,:,:,slice) = gm_out;
       wm_out = wm_mask .* post_resid(:,:,:,slice);
       wm_post_resid(:,:,:,slice) = wm_out;
       csf_out = csf_mask .* post_resid(:,:,:,slice);
       csf_post_resid(:,:,:,slice) = csf_out;
    end
    gm_post_resid = reshape(gm_post_resid,[xdim*ydim*zdim,tdim]);
    wm_post_resid = reshape(wm_post_resid,[xdim*ydim*zdim,tdim]);
    csf_post_resid = reshape(csf_post_resid,[xdim*ydim*zdim,tdim]);

    % Isolate GM voxels
    numVoxels = max(size(gm_post_resid));
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid(voxel,:)) > 0
          gmCount = gmCount + 1;
       end
    end
    dataGMresid_preDVARS = zeros(gmCount,tdim);
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid(voxel,:)) > 0
          dataGMresid_preDVARS(gmCount,:) = gm_post_resid(voxel,:);
          gmCount = gmCount + 1;
       end
    end
    disp('Loaded: Pre and Post-regression DVARS residual GM data')

    % Isolate WM voxels
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid(voxel,:)) > 0
          wmCount = wmCount + 1;
       end
    end
    dataWMresid_preDVARS = zeros(wmCount,tdim);
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid(voxel,:)) > 0
          dataWMresid_preDVARS(wmCount,:) = wm_post_resid(voxel,:);
          wmCount = wmCount + 1;
       end
    end
    disp('Loaded: Pre and Post-regression DVARS residual WM data')

    % Isolate CSF voxels
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid(voxel,:)) > 0
          csfCount = csfCount + 1;
       end
    end
    dataCSFresid_preDVARS = zeros(csfCount,tdim);
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid(voxel,:)) > 0
          dataCSFresid_preDVARS(csfCount,:) = csf_post_resid(voxel,:);
          csfCount = csfCount + 1;
       end
    end
    disp('Loaded: Pre and Post-DVARS regression residual data')


    %% ======================================================================

    %%%%%%%%%%%%%%%%%%%%%%%%%%% MOTION & GS PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    figure1 = figure('visible','off');    
    sgtitle({sprintf('%s','Motion and Global Signal Plots,',subjID)})
    subplot(4,1,1)
    plot(mn_reg(:,1:3)) 
    legend('X', 'Y', 'Z', 'Location', 'best')
    xlim([0 tdim])
    %     ylim([-.02, .02])
    subplot(4,1,2)
    plot(mn_reg(:,4:6))
    legend('pitch', 'yaw', 'roll', 'Location', 'best')
    xlim([0 tdim])
    %     ylim([-.5, .5])
    subplot(4,1,3)
    plot(gs_data.GSavg)
    legend('GSavg', 'Location', 'best')
    xlim([0 tdim])
    subplot(4,1,4)
    plot(gs_data.GSderiv)
    legend('GSderiv', 'Location', 'best')
    xlim([0 tdim])
    set(gcf,'Position',[150 100 1200 800])

    saveas(figure1,fullfile(path2figures,'motion_GS'), 'png')



    %%%%%%%%%%%%%%%%%%%%%%%%%%%% PRE IMG PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    figure2 = figure('visible','off');
    sgtitle({sprintf('%s','Pre-Regression Motion and Tissue Plots,',subjID)})
    subplot(6,1,1)
    plot(fd_series)
    legend('FD', 'Location', 'best')
    subplot(6,1,2)
    plot(dvars_series)
    legend('DVARS', 'Location', 'best')
    subplot(6,1,3)
    plot(mn_reg(:,1:3)) 
    legend('X', 'Y', 'Z', 'Location', 'best')
    ylim([-.02, .02])
    subplot(6,1,4)
    imagesc(dataGMpre)
    ylabel('GM')
    %caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    %colorbar
    subplot(6,1,5)
    imagesc(dataWMpre)
    ylabel('WM')
    %caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    %colorbar
    subplot(6,1,6)
    imagesc(dataCSFpre)
    ylabel('CSF')
    %caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    clrbr = colorbar('east');
    colormap gray
    set(gcf,'Position',[200 100 1200 800])

    saveas(figure2,fullfile(path2figures,'pre_reg_tissue'), 'png')


    %%%%%%%%%%%%%%%%%%%%%%%%% POST IMG RESID PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    figure3 = figure('visible','off');
    sgtitle({sprintf('%s','Post-Regression Motion and Tissue Plots,',subjID)})
    subplot(6,1,1)
    plot(fd_series)
    legend('FD', 'Location', 'best')
    subplot(6,1,2)
    plot(dvars_series)
    legend('DVARS', 'Location', 'best')
    subplot(6,1,3)
    plot(mn_reg(:,1:3)) 
    legend('X', 'Y', 'Z', 'Location', 'best')
    ylim([-.02, .02])
    subplot(6,1,4)
    imagesc(dataGMresid)
    ylabel('GM')
    %     caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    % colorbar
    subplot(6,1,5)
    imagesc(dataWMresid)
    ylabel('WM')
    %     caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    % colorbar
    subplot(6,1,6)
    imagesc(dataCSFresid)
    ylabel('CSF')
    %     caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    clrbr = colorbar('east');
    colormap gray
    set(gcf,'Position',[250 100 1200 800])

    saveas(figure3,fullfile(path2figures,'post_reg_tissue'), 'png')


    %%%%%%%%%%%%%%%%%%%%%% PRE-DVARS REG RESID PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%
    figure4 = figure('visible','off');
    sgtitle({sprintf('%s','Pre-DVARS-Regression Motion and Tissue Plots,',subjID)})
    subplot(6,1,1)
    plot(fd_series)
    legend('FD', 'Location', 'best')
    xlim([0 tdim])
    subplot(6,1,2)
    plot(dvars_series)
    legend('DVARS', 'Location', 'best')
    xlim([0 tdim])
    subplot(6,1,3)
    plot(mn_reg(:,1:3)) 
    legend('X', 'Y', 'Z', 'Location', 'best')
    xlim([0 tdim])
    %     ylim([-.02, .02])
    subplot(6,1,4)
    imagesc(dataGMresid_preDVARS)
    %colorbar
    ylabel('GM')
    caxis([configs.EPI.DVARSdiffColorMin configs.EPI.DVARSdiffColorMax])
    subplot(6,1,5)
    imagesc(dataWMresid_preDVARS)
    %colorbar
    ylabel('WM')
    caxis([configs.EPI.DVARSdiffColorMin configs.EPI.DVARSdiffColorMax])
    subplot(6,1,6)
    imagesc(dataCSFresid_preDVARS)
    %colorbar
    ylabel('CSF')
    caxis([configs.EPI.DVARSdiffColorMin configs.EPI.DVARSdiffColorMax])
    clrmp=jet(63); 
    clrmp(32,:)=[1,1,1];
    colormap(clrmp)
    clrbr = colorbar('east');
    set(gcf,'Position',[250 100 1200 800])

    saveas(figure4,fullfile(path2figures,'diff_pre_post_DVARS_tissue'), 'png')


    %%%%%%%%%%%%%%%%%%%%%%%%%%% PARCELLATION PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    checkParcs = zeros(1,10); % Assumes you will never have more than 10 parcs
    for parc = 1:max(size(parc_data))
        if ~isempty(parc_data{parc}) && parc_label(parc) ~= 'NonNodal'
            checkParcs(parc) = parc;
        end
    end
    
    checkParcs = checkParcs(checkParcs~=0);
    numParcSubPlots = max(size(checkParcs)) + 3;
    figure5 = figure('visible','off');
    sgtitle({sprintf('%s','Parcellation Motion and Tissue Plots,',subjID)})
    subplot(numParcSubPlots,1,1)
    plot(fd_series)
    legend('FD', 'Location', 'best')
    xlim([0 tdim])
    subplot(numParcSubPlots,1,2)
    plot(dvars_series)
    legend('DVARS', 'Location', 'best')    
    xlim([0 tdim])
    subplot(numParcSubPlots,1,3)
    plot(mn_reg(:,1:3)) 
    legend('X', 'Y', 'Z', 'Location', 'best')
    xlim([0 tdim])
    %     ylim([-.02, .02])
    parcCount = 3;
    for parc = checkParcs
        parcCount = parcCount + 1;
        parcSeries = parc_data{parc};
        subplot(numParcSubPlots,1,parcCount)
        imagesc(parcSeries)
        parclabelstr = strrep(parc_label(parc),'_','\_');
        xlabel(parclabelstr) % indexing issues - temporarily commented out (MDZ)
    %         caxis([configs.EPI.parcsColorMin configs.EPI.parcsColorMax])
        colormap gray
    end
    
    clrbr = colorbar('east');
    set(gcf,'Position',[250 100 1200 800])
    clear numParcSubPlots parcLabel parcCount parcSeries

    saveas(figure5,fullfile(path2figures,'post_reg_parcellations'), 'png')


    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FC PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    parcCount = 0;

    for parc = checkParcs
        parcCount = parcCount + 1;
        parcSeries = parc_data{parc};
        [numParcRows,numParcCols] = size(parcSeries);

        parcSeries = parcSeries(:, 11:(numParcCols - 10));
        halftS = floor(size(parcSeries,2)/2);
        parcSeries1 = parcSeries(:,1:halftS);
        parcSeries2 = parcSeries(:,halftS+1:end);
        
        fcMatrix = cell(2,3);

        fcMatrix{1,1} = corr(parcSeries1','Type','Pearson');
        fcMatrix{2,1} = corr(parcSeries1','Type','Spearman');
        fcMatrix{3,1} = corr(zscore(parcSeries1,[],2)','Type','Pearson');
        
        fcMatrix{1,2} = corr(parcSeries2','Type','Pearson');
        fcMatrix{2,2} = corr(parcSeries2','Type','Spearman');
        fcMatrix{3,2} = corr(zscore(parcSeries2,[],2)','Type','Pearson');

        fcMatrix{1,3} = corr(parcSeries','Type','Pearson');
        fcMatrix{2,3} = corr(parcSeries','Type','Spearman');
        fcMatrix{3,3} = corr(zscore(parcSeries,[],2)','Type','Pearson');

        figNames = {'Pearson','Spearman','Zcore'};
        tsNames = {'First Half','Second Half','Full'};
        
        for fig = 1:length(figNames)
            
            figTitle = strcat(figNames{fig},'_ParcHist_', num2str(parcCount));
            figure6 = figure('visible','off','Position', [653 51 1137 821]);
            sgtitle({sprintf('%s',subjID)})

            for ts = 1:length(tsNames)

                fcMatrixU = reshape(triu(fcMatrix{fig,ts},1),[],1);
                fcMatrixU = fcMatrixU(abs(fcMatrixU)>0.000001);

                subplot(3,3,ts)
                % normalized
                hh = histogram(fcMatrixU,configs.EPI.nbinPearson,'BinLimits',[-1.005,1.005], ...
                'Normalization','probability','DisplayStyle','stairs');
                % count
                hhBinEdgesLeft = hh.BinEdges(1:hh.NumBins); % configs.EPI.nbinPearson
                hhBinEdgesRight = hh.BinEdges(2:hh.NumBins+1);
                hhPearson_x = 0.5*(hhBinEdgesLeft + hhBinEdgesRight);
                hhPearson_y = hh.Values; % normalized; hh.BinCounts for histogram count

                ylim10 = 1.10*ylim;
                ylim(ylim10)
                xlabel(strcat(figNames{fig},'-',tsNames{ts}))
                % fit normal distribution
                pdPearson_n = fitdist(fcMatrixU,'Normal'); 
                pdPearson_ci = paramci(pdPearson_n);
                % fit kernel distribution
                pdPearson_k = fitdist(fcMatrixU,'Kernel','Kernel','epanechnikov','Bandwidth',configs.EPI.kernelPearsonBw);        

                % normal distribution parameters
                y_n = pdf(pdPearson_n,hhPearson_x);
                Pearson_y_n = y_n/sum(y_n);
                [Pearson_ymax_n, indmaxy_n] = max(Pearson_y_n);
                Pearson_xmax_n = hhPearson_x(indmaxy_n);
                Pearson_mean_n = mean(Pearson_y_n);
                Pearson_med_n = median(Pearson_y_n);
                Pearson_std_n = std(Pearson_y_n);

                % kernel distribution parameters
                y_k = pdf(pdPearson_k,hhPearson_x); % kernel
                Pearson_y_k = y_k/sum(y_k);
                [Pearson_ymax_k, indmaxy_k] = max(Pearson_y_k);
                Pearson_xmax_k = hhPearson_x(indmaxy_k);
                Pearson_mean_k = mean(Pearson_y_k);
                Pearson_med_k = median(Pearson_y_k);
                Pearson_std_k = std(Pearson_y_k);

                subplot(3,3,ts+length(tsNames))
                plot(hhPearson_x,Pearson_y_n,'b-o','LineWidth',1,'MarkerSize',3)
                hold
                plot(hhPearson_x,Pearson_y_k,'r-s','LineWidth',1,'MarkerSize',3)
                xlim([-1.1 1.1]);
                ylim10 = 1.10*ylim;
                ylim(ylim10)
                legend('Normal','Kernel','Fontsize',8,'Box','Off','Location','Northeast')
                xlabel(strcat(figNames{fig},'-',tsNames{ts}))

                fcmatfile = strcat(tsNames{ts},'-fc',figNames{fig},'Mat-',num2str(parcCount),'.txt');
                % write correlation matrices
                writematrix(fcMatrix{ts},fullfile(path2figures,fcmatfile))
                
                subplot(3,3,ts+(2*length(tsNames)))
                numRois = size(fcMatrix{fig,ts},2);
                imagesc(fcMatrix{fig,ts}-eye(numRois))
                xlabel(strcat(figNames{fig},'-',tsNames{ts}))
                caxis([configs.EPI.fcColorMinP configs.EPI.fcColorMaxP])
                colorbar('Ticks',linspace(configs.EPI.fcColorMinP, configs.EPI.fcColorMaxP,5))
                axis square
                
            end

            saveas(figure6,fullfile(path2figures,figTitle), 'png')

            pause(5)
        end
    
    end
    
    % =========================================================================

    resting_file=fullfile(path2regressors,sprintf('7_epi_%s.nii.gz',pre_nR));
    V1 = load_untouch_nii(resting_file);
    V2 = V1.img;
    X0 = size(V2,1); Y0 = size(V2,2); Z0 = size(V2,3); T0 = size(V2,4);
    I0 = prod([X0,Y0,Z0]);
    Y  = reshape(V2,[I0,T0]); clear V2 V1;

    [DVARS,DVARS_Stat]=DVARSCalc(Y,'scale',1/10,'TransPower',1/3,'RDVARS','verbose',1);
    [V,DSE_Stat]=DSEvars(Y,'scale',1/10);
    figure8=figure('position',[226 40 896 832]);
    
    if exist(fullfile(path2EPI,'motionRegressor_fd.txt'),'file')
        MovPar=MovPartextImport(fullfile(path2EPI,'motionRegressor_fd.txt'));
        [FDts,FD_Stat]=FDCalc(MovPar);        
        fMRIDiag_plot(V,DVARS_Stat,'BOLD',Y,'FD',FDts,'AbsMov',[FD_Stat.AbsRot FD_Stat.AbsTrans],'figure',figure8)
    else 
        fMRIDiag_plot(V,DVARS_Stat,'BOLD',Y,'FD',FDts,'figure',figure8)
    end

    %figure8 = gcf
    saveas(figure8,fullfile(path2figures,'DVARS'), 'png')
    
    pause(3)
    disp(['======== DONE SUBJECT ',subjID,' ========='])
    close all
    clc


end
