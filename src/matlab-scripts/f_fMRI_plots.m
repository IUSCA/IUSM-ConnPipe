function [paths,flags,configs,parcs,params]=f_fMRI_plots_new(paths,flags,configs,parcs,params)
%                       F_FMRI_PLOTS
% Plots data from fMRI processing and analysis
%                       
% Contributors:
%   Matt Tharp, IU School of Medicine

close all

cd(paths.EPI.dir)
currDir = pwd;

% split EPI dir path and extract EPI session and subject info
pathinfo = split(paths.EPI.dir,'/');
npath = size(pathinfo,1);
EPIsess = string(pathinfo(npath));
subjectinfo = string(pathinfo(npath-1));

disp(strcat('NUISANCE REG==', num2str(flags.EPI.NuisanceReg), ' | PHYS REG==', num2str(flags.EPI.PhysReg)))

%%%%%%%%%%%%%%%%%%%%%%%%%% LOAD REGRESSOR DATA %%%%%%%%%%%%%%%%%%%%%%%%%%%%
dvars_series = load(fullfile(paths.EPI.dir, 'motionMetric_dvars.txt'));
disp('Loaded: motionMetric_dvars.txt')
fd_series = load(fullfile(paths.EPI.dir, 'motionMetric_fd.txt'));
disp('Loaded: motionMetric_fd.txt')
tdim = size(dvars_series,1);
str_fig = ' ';

% global signal regression or not
if flags.EPI.GS == 1
    gsstr = sprintf('_Gs%d',configs.EPI.numGS);
elseif flags.EPI.scrubbing == 0
    gsstr = '';
end

% define scrubbing string
if flags.EPI.scrubbing == 1
    scrubstr = '_scrubbed';
elseif flags.EPI.scrubbing == 0
    scrubstr = '';
end

% define DCT or Bandpass
if flags.EPI.BandPass == 1
    filtering = '';
elseif flags.EPI.scrubbing == 0
    filtering = sprintf('_DCT%d',configs.EPI.dct);
end

if flags.EPI.NuisanceReg == 1
    disp('Loaded: melodic_Tmodes.txt')
    if flags.EPI.PhysReg == 1
        regLoc = fullfile(paths.EPI.dir, 'AROMA/aCompCorr');
        mn_reg = load(fullfile(paths.EPI.dir, 'motion.txt'));
        disp('Loaded: motion.txt')
        nuisanceReg = sprintf('NuisanceRegression_aroma_pca%d%s%s_output.mat',...
            configs.EPI.numPC,gsstr,filtering);
        if exist(fullfile(regLoc, nuisanceReg),'file')
            nreg_gs = load(fullfile(regLoc, nuisanceReg));
            fprintf('\n Loaded: %s',nuisanceReg)
        else
            warning('%s not found. Exiting...',fullfile(regLoc, nuisanceReg));
            return
        end
        if flags.EPI.FigsDmdtRegress == 1
            nuisanceRegDmdt = sprintf('NuisanceRegression_aroma_pca%d%s%s_output_dmdt.mat',...
                configs.EPI.numPC,gsstr,filtering);
            nreg_gs_dmdt = load(fullfile(regLoc, nuisanceRegDmdt));
            fprintf('\n Loaded: %s',nuisanceRegDmdt)
        end
        gs_data = load(fullfile(regLoc, 'dataGS.mat'));
        disp('Loaded: dataGS.mat')
%         wm_csf = load(fullfile(regLoc, 'dataPCA_WM-CSF.mat'));
%         disp('Loaded: dataPCA_WM-CSF.mat')
        if flags.EPI.FigsParcellations == 1
            parc_data = cell(1,max(size(parcs.plabel)));
            parc_label = string(zeros(1,max(size(parc_data))));
            %TimeSeries = strcat('/TimeSeries_aroma',str_fig,'/8_epi_');
            for p = 1:max(size(parcs.plabel))
                % nodal-only excluding subcortical-only parcellations
                if parcs.pnodal(p).true == 1 && parcs.psubcortonly(p).true ~= 1
                    timeseriesDir = sprintf('TimeSeries_aroma_pca%d%s%s',...
                        configs.EPI.numPC,gsstr,filtering);
                    roi_series = fullfile(regLoc, timeseriesDir,sprintf('8_epi_%s_ROIs.mat',parcs.plabel(p).name));
                    % roi_series = strcat(regLoc, TimeSeries, parcs.plabel(p).name, '_ROIs.mat');
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
        end
    elseif flags.EPI.PhysReg == 2
        regLoc = fullfile(paths.EPI.dir, 'AROMA/PhysReg');
        mn_reg = load(fullfile(paths.EPI.dir, 'motion.txt'));
        disp('Loaded: motion.txt')
        nuisanceReg = sprintf('NuisanceRegression_aroma_mPhys%d%s%s_output.mat',...
            configs.EPI.numPhys,gsstr,filtering);
        if exist(fullfile(regLoc, nuisanceReg),'file')
            nreg_gs = load(fullfile(regLoc, nuisanceReg));
            fprintf('\n Loaded: %s',nuisanceReg)
        else
            warning('%s not found. Exiting...',fullfile(regLoc, nuisanceReg));
            return
        end
        if flags.EPI.FigsDmdtRegress == 1
            nuisanceRegDmdt = sprintf('NuisanceRegression_aroma_mPhys%d%s%s_output_dmdt.mat',...
                configs.EPI.numPhys,gsstr,filtering);
            nreg_gs_dmdt = load(fullfile(regLoc, nuisanceRegDmdt));
            fprintf('\n Loaded: %s',nuisanceRegDmdt)
        end
        gs_data = load(fullfile(regLoc, 'dataGS.mat'));
        disp('Loaded: dataGS.mat')
%         wm_csf = load(fullfile(regLoc, 'dataMnRg_WM-CSF.mat'));
%         disp('Loaded: dataMnRg_WM-CSF.mat')
        if flags.EPI.FigsParcellations == 1
            parc_data = cell(1,max(size(parcs.plabel)));
            parc_label = string(zeros(1,max(size(parc_data))));
            for p = 1:max(size(parcs.plabel))
                % nodal-only excluding subcortical-only parcellation
                if parcs.pnodal(p).true == 1 && parcs.psubcortonly(p).true ~= 1 
                    timeseriesDir = sprintf('TimeSeries_aroma_mPhys%d%s%s',...
                        configs.EPI.numPC,gsstr,filtering);
                    roi_series = fullfile(regLoc, timeseriesDir,sprintf('8_epi_%s_ROIs.mat',parcs.plabel(p).name));
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
        end
    else
        warning("Physiological regressor setting should be set to either 1 or 2")
    end
elseif flags.EPI.NuisanceReg == 2

    if flags.EPI.PhysReg == 1
        regLoc = fullfile(paths.EPI.dir, 'HMPreg/aCompCorr');
        mn_reg = load(fullfile(paths.EPI.dir, 'motion.txt'));
        disp('Loaded: motion.txt \n')
        nuisanceReg = sprintf('NuisanceRegression%s_hmp%d_pca%d%s%s_output.mat',...
            scrubstr,configs.EPI.numReg,configs.EPI.numPC,gsstr,filtering);
        nreg_gs = load(fullfile(regLoc, nuisanceReg));
        fprintf('\n Loaded: %s',nuisanceReg)
        if flags.EPI.FigsDmdtRegress == 1
            nuisanceRegDmdt = sprintf('NuisanceRegression%s_hmp%d_pca%d%s%s_output_dmdt.mat',...
            scrubstr,configs.EPI.numReg,configs.EPI.numPC,gsstr,filtering);
            nreg_gs_dmdt = load(fullfile(regLoc,nuisanceRegDmdt));
            fprintf('\n Loaded: %s',nuisanceRegDmdt)
        end
        gs_data = load(fullfile(regLoc, 'dataGS.mat'));
        fprintf('\n Loaded: dataGS.mat')
%         wm_csf = load(fullfile(regLoc, 'dataPCA_WM-CSF.mat'));
%         disp('Loaded: dataPCA_WM-CSF.mat');
        if flags.EPI.FigsParcellations == 1
            parc_data = cell(1,max(size(parcs.plabel)));
            parc_label = string(zeros(1,max(size(parc_data))));
            for p = 1:max(size(parcs.plabel))
                % nodal-only excluding subcortical-only parcellation
                if parcs.pnodal(p).true == 1 && parcs.psubcortonly(p).true ~= 1
                    timeseriesDir = sprintf('TimeSeries%s_hmp%d_pca%d%s%s',...
                        scrubstr,configs.EPI.numReg,configs.EPI.numPC,gsstr,filtering);
                    roi_series = fullfile(regLoc, timeseriesDir,sprintf('8_epi_%s_ROIs.mat',parcs.plabel(p).name));
                    % roi_series = strcat(regLoc, '/TimeSeries_hmp12_pca5_Gs4/8_epi_', parcs.plabel(p).name, '_ROIs.mat');
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
        end
    elseif flags.EPI.PhysReg == 2
        regLoc = fullfile(paths.EPI.dir, 'HMPreg/PhysReg');
        mn_reg = load(fullfile(paths.EPI.dir, 'motion.txt'));
        disp('Loaded: motion.txt')
        nuisanceReg = sprintf('NuisanceRegression%s_hmp%d_mPhys%d%s%s_output.mat',...
            scrubstr,configs.EPI.numReg,configs.EPI.numPhys,gsstr,filtering);
        nreg_gs = load(fullfile(regLoc, nuisanceReg));
        fprintf('\n Loaded: %s',nuisanceReg)
        if flags.EPI.FigsDmdtRegress == 1
            nuisanceRegDmdt = sprintf('NuisanceRegression%s_hmp%d_mPhys%d%s%s_output_dmdt.mat',...
            scrubstr,configs.EPI.numReg,configs.EPI.numPhys,gsstr,filtering);
            nreg_gs_dmdt = load(fullfile(regLoc,nuisanceRegDmdt));
            fprintf('\n Loaded: %s',nuisanceRegDmdt)
        end
        gs_data = load(fullfile(regLoc, 'dataGS.mat'));
        disp('Loaded: dataGS.mat')
%         wm_csf = load(fullfile(regLoc, 'dataMnRg_WM-CSF.mat'));
%         disp('Loaded: dataMnRg_WM-CSF.mat')
        if flags.EPI.FigsParcellations == 1
            parc_data = cell(1,max(size(parcs.plabel)));
            parc_label = string(zeros(1,max(size(parc_data))));
            for p = 1:max(size(parcs.plabel))
                % nodal-only except subcortical-only parcellation
                if parcs.pnodal(p).true == 1 && parcs.psubcortonly(p).true ~= 1
                    timeseriesDir = sprintf('TimeSeries%s_hmp%d_mPhys%d%s%s',...
                        scrubstr,configs.EPI.numReg,configs.EPI.numPhys,gsstr,filtering);
                    roi_series = fullfile(regLoc, timeseriesDir,sprintf('8_epi_%s_ROIs.mat',parcs.plabel(p).name));
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
        end
    else
        warning("Physiological regressor setting should be set to either 1 or 2")
    end
else
    warning("Nuisance regressor setting should be set to either 1 or 2")
end

%%%%%%%%%%%%%%%%%%%%%%%% SET PATH TO SAVE FIGURES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

path2figs = fullfile(currDir,sprintf('figures_%s',timeseriesDir));
if ~exist( path2figs, 'dir')
    mkdir(path2figs)
end

%%%%%%%%%%%%%%%%%%%%%%%% LOAD TISSUE MASKS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
wm_mask = MRIread(fullfile(paths.EPI.dir, 'rT1_WM_mask.nii.gz'));
wm_mask = wm_mask.vol;
csf_mask = MRIread(fullfile(paths.EPI.dir, 'rT1_CSF_mask.nii.gz'));
csf_mask = csf_mask.vol;
gm_mask = MRIread(fullfile(paths.EPI.dir, 'rT1_GM_mask.nii.gz'));
gm_mask = gm_mask.vol;
xdim = size(gm_mask,1);
ydim = size(gm_mask,2);
zdim = size(gm_mask,3);

%%%%%%%%%%%%%%%%%%%%% LOAD PRE-REGRESS TISSUE DATA %%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsPreRegress == 1
    pre_regress = nreg_gs.resting.vol;
    gm_pre_regress = zeros(xdim,ydim,zdim,tdim);
    wm_pre_regress = zeros(xdim,ydim,zdim,tdim);
    csf_pre_regress = zeros(xdim,ydim,zdim,tdim);
    for slice = 1:tdim
       gm_out = gm_mask .* pre_regress(:,:,:,slice);
       gm_pre_regress(:,:,:,slice) = gm_out;
       wm_out = wm_mask .* pre_regress(:,:,:,slice);
       wm_pre_regress(:,:,:,slice) = wm_out;
       csf_out = csf_mask .* pre_regress(:,:,:,slice);
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
end

%%%%%%%%%%%%%%%%% LOAD POST-REGRESS RESIDUAL TISSUE DATA %%%%%%%%%%%%%%%%%%
if flags.EPI.FigsPostRegress == 1
    post_resid = nreg_gs.resid;
    post_resid = cell2mat(post_resid);
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
end

%%%%%%%%%%%%%%%%%%%%% LOAD DM/DT RESIDUAL TISSUE DATA %%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsDmdtRegress == 1
    post_resid_dmdt = squeeze(nreg_gs_dmdt.resid);
    %post_resid_dmdt = cell2mat(post_resid_dmdt);
    gm_post_resid_dmdt = zeros(xdim,ydim,zdim,tdim);
    wm_post_resid_dmdt = zeros(xdim,ydim,zdim,tdim);
    csf_post_resid_dmdt = zeros(xdim,ydim,zdim,tdim);
    for slice = 1:tdim
       gm_out = gm_mask .* post_resid_dmdt(:,:,:,slice);
       gm_post_resid_dmdt(:,:,:,slice) = gm_out;
       wm_out = wm_mask .* post_resid_dmdt(:,:,:,slice);
       wm_post_resid_dmdt(:,:,:,slice) = wm_out;
       csf_out = csf_mask .* post_resid_dmdt(:,:,:,slice);
       csf_post_resid_dmdt(:,:,:,slice) = csf_out;
    end
    gm_post_resid_dmdt = reshape(gm_post_resid_dmdt,[xdim*ydim*zdim,tdim]);
    wm_post_resid_dmdt = reshape(wm_post_resid_dmdt,[xdim*ydim*zdim,tdim]);
    csf_post_resid_dmdt = reshape(csf_post_resid_dmdt,[xdim*ydim*zdim,tdim]);

    % Isolate GM voxels
    numVoxels = max(size(gm_post_resid_dmdt));
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid_dmdt(voxel,:)) > 0
          gmCount = gmCount + 1;
       end
    end
    dataGMresid_dmdt = zeros(gmCount,tdim);
    gmCount = 1;
    for voxel = 1:numVoxels
       if sum(gm_post_resid_dmdt(voxel,:)) > 0
          dataGMresid_dmdt(gmCount,:) = gm_post_resid_dmdt(voxel,:);
          gmCount = gmCount + 1;
       end
    end
    disp('Loaded: Post-regression DM/DT residual GM data')

    % Isolate WM voxels
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid_dmdt(voxel,:)) > 0
          wmCount = wmCount + 1;
       end
    end
    dataWMresid_dmdt = zeros(wmCount,tdim);
    wmCount = 1;
    for voxel = 1:numVoxels
       if sum(wm_post_resid_dmdt(voxel,:)) > 0
          dataWMresid_dmdt(wmCount,:) = wm_post_resid_dmdt(voxel,:);
          wmCount = wmCount + 1;
       end
    end
    disp('Loaded: Post-regression DM/DT residual WM data')

    % Isolate CSF voxels
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid_dmdt(voxel,:)) > 0
          csfCount = csfCount + 1;
       end
    end
    dataCSFresid_dmdt = zeros(csfCount,tdim);
    csfCount = 1;
    for voxel = 1:numVoxels
       if sum(csf_post_resid_dmdt(voxel,:)) > 0
          dataCSFresid_dmdt(csfCount,:) = csf_post_resid_dmdt(voxel,:);
          csfCount = csfCount + 1;
       end
    end
    disp('Loaded: Post-regression DM/DT residual CSF data')
end

%%%%%%%%%%%%%%%%%%%%%%%%%%% MOTION & GS PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsMotionGS == 1
    figure1 = figure('visible','off');    
    sgtitle({sprintf('%s %s%s %s','Motion and Global Signal Plots,',subjectinfo,',',EPIsess)})
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
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%% PRE IMG PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsPreRegress == 1
    figure2 = figure('visible','off');
    sgtitle({sprintf('%s %s%s %s','Pre-Regression Motion and Tissue Plots,',subjectinfo,',',EPIsess)})
%     sgtitle('Pre-Regression Motion and Tissue Plots')
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
    caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    subplot(6,1,5)
    imagesc(dataWMpre)
    ylabel('WM')
    caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    subplot(6,1,6)
    imagesc(dataCSFpre)
    ylabel('CSF')
    caxis([configs.EPI.preColorMin configs.EPI.preColorMax])
    colormap gray
    set(gcf,'Position',[200 100 1200 800])
end
    
%%%%%%%%%%%%%%%%%%%%%%%%% POST IMG RESID PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsPostRegress == 1
    figure3 = figure('visible','off');
    sgtitle({sprintf('%s %s%s %s','Post-Regression Motion and Tissue Plots,',subjectinfo,',',EPIsess)})
%     sgtitle('Post-Regression Motion and Tissue Plots')
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
    caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    subplot(6,1,5)
    imagesc(dataWMresid)
    ylabel('WM')
    caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    subplot(6,1,6)
    imagesc(dataCSFresid)
    ylabel('CSF')
    caxis([configs.EPI.postColorMin configs.EPI.postColorMax])
    colormap gray
    set(gcf,'Position',[250 100 1200 800])
end
    
%%%%%%%%%%%%%%%%%%%%%% POST IMG RESID DM/DT PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsDmdtRegress == 1
    figure4 = figure('visible','off');
    sgtitle({sprintf('%s %s%s %s','Post-Regression Motion and Tissue (dm/dt) Plots,',subjectinfo,',',EPIsess)})
%     sgtitle('Post-Regression Motion and Tissue (dm/dt) Plots')
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
    imagesc(dataGMresid_dmdt)
    ylabel('GM')
    caxis([configs.EPI.dmdtColorMin configs.EPI.dmdtColorMax])
    subplot(6,1,5)
    imagesc(dataWMresid_dmdt)
    ylabel('WM')
    caxis([configs.EPI.dmdtColorMin configs.EPI.dmdtColorMax])
    subplot(6,1,6)
    imagesc(dataCSFresid_dmdt)
    ylabel('CSF')
    caxis([configs.EPI.dmdtColorMin configs.EPI.dmdtColorMax])
    colormap gray
    set(gcf,'Position',[250 100 1200 800])
end

%%%%%%%%%%%%%%%%%%%%%%%%%%% PARCELLATION PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
if flags.EPI.FigsParcellations == 1
    checkParcs = zeros(1,10); % Assumes you will never have more than 10 parcs
    for parc = 1:max(size(parc_data))
        if ~isempty(parc_data{parc}) && parc_label(parc) ~= 'NonNodal'
            checkParcs(parc) = parc;
        end
    end
    checkParcs = checkParcs(checkParcs~=0);
    numParcSubPlots = max(size(checkParcs)) + 3;
    figure5 = figure('visible','off');
    sgtitle({sprintf('%s %s%s %s','Parcellation Motion and Tissue Plots,',subjectinfo,',',EPIsess)})
%     sgtitle('Parcellation Motion and Tissue Plots')
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
        caxis([configs.EPI.parcsColorMin configs.EPI.parcsColorMax])
        colormap gray
    end
    set(gcf,'Position',[250 100 1200 800])
end
clear numParcSubPlots parcLabel parcCount parcSeries

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% FC PLOTS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cd(path2figs)

        
if flags.EPI.FigsFC == 1
    parcCount = 0;
    if str_fig ~= ' '
        pdftextName1 = strcat('pdfit_Pearson',str_fig,'.txt');
        pdftextName2 = strcat('pdfit_MutualI',str_fig,'.txt');
    else
        pdftextName1 = strcat('pdfit_Pearson.txt');
        pdftextName2 = strcat('pdfit_MutualI.txt');
    end
    if exist(pdftextName1,'file')
        delete(pdftextName1)
    end
    if exist(pdftextName2,'file')
        delete(pdftextName2)
    end
    
    for parc = checkParcs
        parcCount = parcCount + 1;
        parcSeries = parc_data{parc};
        numParcSize = size(parcSeries);
        numParcRows = numParcSize(1);
        numParcCols = numParcSize(2);
        adjParcSeries = zeros(numParcRows,numParcCols - 20);
        for parcRow = 1:numParcRows
            adjParcSeries(parcRow,:) = parcSeries(parcRow, 11:(numParcCols - 10));
        end
        parcSeries = adjParcSeries;
        miSeries = round(parcSeries);
        miSeries = miSeries - min(min(miSeries)) + 1;
        TF = isnan(miSeries); % nan's crash nmi calculations
        miSeries(TF) = 0;     % Substitute nan's with zeros 
        numRois = size(parcSeries);
        numRois = numRois(1);
        fcMatrixPearson = zeros(numRois, numRois);
        fcMatrixSpearman = zeros(numRois, numRois);
        fcMatrixZscore = zeros(numRois, numRois);
        fcMatrixMutualI = zeros(numRois, numRois);
        for roiRow = 1:numRois
            for roiCol = 1:numRois
                rowCorr = parcSeries(roiRow,:);
                colCorr = parcSeries(roiCol,:);
                miRow = miSeries(roiRow,:);
                miCol = miSeries(roiCol,:);
                fcCorrP = corr(rowCorr',colCorr','Type','Pearson');
                fcCorrS = corr(rowCorr',colCorr','Type','Spearman');
                fcCorrZ = corr(zscore(rowCorr)',zscore(colCorr)');
                fcCorrM = nmi(miRow',miCol');
                fcMatrixPearson(roiRow, roiCol) = fcCorrP;
                fcMatrixSpearman(roiRow, roiCol) = fcCorrS;
                fcMatrixZscore(roiRow, roiCol) = fcCorrZ;
                fcMatrixMutualI(roiRow, roiCol) = fcCorrM;
            end
            disp(strcat('Calculating metrics for FC matrices - ROI:_', num2str(roiRow)))
        end
%         fcMatrixPearsonU = triu(fcMatrixPearson,1);
%         fcMatrixPearsonU = fcMatrixPearsonU(:); 

        figTitle = strcat('ParcHist-', num2str(parcCount));
        parcFig = figure('visible','off');
        sgtitle({sprintf('%s%s %s',subjectinfo,',',EPIsess)})
        fcMatrixPearsonU = reshape(triu(fcMatrixPearson,1),[],1);
        fcMatrixPearsonU = fcMatrixPearsonU(abs(fcMatrixPearsonU)>0.000001);
        fcMatrixSpearmanU = reshape(triu(fcMatrixSpearman,1),[],1);
        fcMatrixSpearmanU = fcMatrixSpearmanU(abs(fcMatrixSpearmanU)>0.000001);
        fcMatrixZscoreU = reshape(triu(fcMatrixZscore,1),[],1);
        fcMatrixZscoreU = fcMatrixZscoreU(abs(fcMatrixZscoreU)>0.000001);
        fcMatrixMutualIU = reshape(triu(fcMatrixMutualI,1),[],1);
        fcMatrixMutualIU = fcMatrixMutualIU(abs(fcMatrixMutualIU)>0.000001);
        
        subplot(2,2,1)
        % normalized
        hh = histogram(fcMatrixPearsonU,configs.EPI.nbinPearson,'BinLimits',[-1.005,1.005], ...
        'Normalization','probability','DisplayStyle','stairs');
        % count
%         hh = histogram(fcMatrixPearsonU,configs.EPI.nbinPearson,'BinLimits',[-1.005,1.005], ...
%         'DisplayStyle','stairs');
        hhBinEdgesLeft = hh.BinEdges(1:hh.NumBins); % configs.EPI.nbinPearson
        hhBinEdgesRight = hh.BinEdges(2:hh.NumBins+1);
        hhPearson_x = 0.5*(hhBinEdgesLeft + hhBinEdgesRight);
        hhPearson_y = hh.Values; % normalized; hh.BinCounts for histogram count
%         hhPearson_y = hh.BinCounts'; % normalized; hh.BinCounts for histogram count

        ylim10 = 1.10*ylim;
        ylim(ylim10)
        xlabel('Pearson''s')
        % fit normal distribution
%         pdPearson_n = fitdist(hh.Data,'Normal'); % use hh.Data for counts
        pdPearson_n = fitdist(fcMatrixPearsonU,'Normal'); 
        pdPearson_ci = paramci(pdPearson_n);
        % fit kernel distribution
%         pdPearson_k = fitdist(hh.Data,'Kernel','Kernel','epanechnikov','Bandwidth',configs.EPI.kernelPearsonBw);
        pdPearson_k = fitdist(fcMatrixPearsonU,'Kernel','Kernel','epanechnikov','Bandwidth',configs.EPI.kernelPearsonBw);        

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
        
        subplot(2,2,3)
        plot(hhPearson_x,Pearson_y_n,'b-o','LineWidth',1,'MarkerSize',3)
        hold
        plot(hhPearson_x,Pearson_y_k,'r-s','LineWidth',1,'MarkerSize',3)
        xlim([-1.1 1.1]);
        ylim10 = 1.10*ylim;
        ylim(ylim10)
        legend('Normal','Kernel','Fontsize',8,'Box','Off','Location','Northeast')
        xlabel('Pearson''s')
        hold
        
% KS test
% Left tail
% FC<-0.74:hhPearson_x(1:26) -- GSR
% FC<0 hhPearson_x(1:100) -- No GSR
% Right tail
% FC>0.74:hhPearson_x(176:201)
% use peak of the normal distribution fitting as a central bin (GSR used)
% use peak of the kernel distribution fitting as a central bin (GSR NOT used)
% x-range of the left and right tail is fixed as is the interval around the pea      
        if flags.EPI.GS == 0
            xpleft1 = 1;
            xpleft2 = 100;
            xpright1 = 176;
            xpright2 = 201;
            xplow = indmaxy_k-10;
            xphigh = min(indmaxy_k+10,xpright2);
        else
            xpleft1 = 1;
            xpleft2 = 26;
            xpright1 = 176;
            xpright2 = 201;
            xplow = indmaxy_n-10;
            xphigh = min(indmaxy_n+10,xpright2);
        end
%
        [hks2,pks2,ks2stat] = kstest2(Pearson_y_n,Pearson_y_k);
        [hks2left,pks2left,ks2statleft] = kstest2(Pearson_y_n(xpleft1:xpleft2),...
            Pearson_y_k(xpleft1:xpleft2));
        [hks2right,pks2right,ks2statright] = kstest2(Pearson_y_n(xpright1:xpright2),...
            Pearson_y_k(xpright1:xpright2));
        [hks2peak,pks2peak,ks2statpeak] = kstest2(Pearson_y_n(xplow:xphigh),...
            Pearson_y_k(xplow:xphigh));        
        subplot(2,2,2)
        hh = histogram(fcMatrixMutualIU,configs.EPI.nbinMutualI,'BinLimits',[-0.005,1.005],...
            'Normalization','probability','DisplayStyle','stairs');
        hhBinEdgesLeft = hh.BinEdges(1:hh.NumBins); % configs.EPI.nbinPearson
        hhBinEdgesRight = hh.BinEdges(2:hh.NumBins+1);
        hhMutualI_x = 0.5*(hhBinEdgesLeft + hhBinEdgesRight);
        hhMutualI_y = hh.Values; % hh.BinCounts for histogram counts
        
        ylim10 = 1.10*ylim;
        ylim(ylim10)
        xlabel('Mutual Information')        
        % fit lognormal distribution
        pdMI_ln = fitdist(fcMatrixMutualIU,'Lognormal');
        pdMI_ci = paramci(pdMI_ln);
        % fit kernel distribution
        pdMI_k = fitdist(fcMatrixMutualIU,'Kernel','Kernel','epanechnikov',...
            'Bandwidth',configs.EPI.kernelMutualIBw);

        % lognormal distribution parameters
        y_n = pdf(pdMI_ln,hhMutualI_x);
        MutualI_y_n = y_n/sum(y_n);
        [MutualI_ymax_n, indmaxy_n] = max(MutualI_y_n);
        MutualI_xmax_n = hhMutualI_x(indmaxy_n);
        MutualI_mean_n = mean(MutualI_y_n);
        MutualI_med_n = median(MutualI_y_n);
        MutualI_std_n = std(MutualI_y_n);        
        
        % kernel distribution parameters
        y_k = pdf(pdMI_k,hhMutualI_x);
        MutualI_y_k = y_k/sum(y_k);
        [MutualI_ymax_k, indmaxy_k] = max(MutualI_y_k);
        MutualI_xmax_k = hhMutualI_x(indmaxy_k);
        MutualI_mean_k = mean(MutualI_y_k);
        MutualI_med_k = median(MutualI_y_k);
        MutualI_std_k = std(MutualI_y_k); 

        
        subplot(2,2,2)
        hh = histogram(fcMatrixMutualIU,configs.EPI.nbinMutualI,'BinLimits',[-0.005,1.005],...
            'Normalization','probability','DisplayStyle','stairs');
        hhBinEdgesLeft = hh.BinEdges(1:hh.NumBins); % configs.EPI.nbinMutualI
        hhBinEdgesRight = hh.BinEdges(2:hh.NumBins+1);
        hhMutualI_x = 0.5*(hhBinEdgesLeft + hhBinEdgesRight);
        hhMutualI_y = hh.Values; % hh.BinCounts for histogram count
        
        subplot(2,2,4)
        plot(hhMutualI_x,MutualI_y_n,'b-o','LineWidth',1,'MarkerSize',3)
        hold
        plot(hhMutualI_x,MutualI_y_k,'r-s','LineWidth',1,'MarkerSize',3)
        xlim([-0.05 1.05]);
        ylim10 = 1.10*ylim;
        ylim(ylim10)
        xlabel('Mutual Information')
        legend('Lognormal','Kernel','Fontsize',8,'Box','Off','Location','Northeast')
        hold
% KS test for MutualI
% use peak of the lognormal or kernel distribution fitting as a central bin - GSR/NoGSR
% x-range of the left and right tail is fixed as is the interval around the peak 
        if flags.EPI.GS == 0
            xpleft1 = 1;
            xpleft2 = 13;
            xpright1 = 89;
            xpright2 = 101;
            xplow = max(1,indmaxy_k-5);
            xphigh = min(indmaxy_k+5,xpright2);
        else
            xpleft1 = 1;
            xpleft2 = 13;
            xpright1 = 89;
            xpright2 = 101;
            xplow = max(1,indmaxy_n-5);
            xphigh = min(indmaxy_n+5,xpright2);
        end
        [hks2_MI,pks2_MI,ks2stat_MI] = kstest2(MutualI_y_n,MutualI_y_k);
        [hks2left_MI,pks2left_MI,ks2statleft_MI] = kstest2(MutualI_y_n(xpleft1:xpleft2),...
            MutualI_y_k(xpleft1:xpleft2));
        [hks2right_MI,pks2right_MI,ks2statright_MI] = kstest2(MutualI_y_n(xpright1:xpright2),...
            MutualI_y_k(89:101));
        [hks2peak_MI,pks2peak_MI,ks2statpeak_MI] = kstest2(MutualI_y_n(xplow:xphigh),...
            MutualI_y_k(xplow:xphigh));
        
        if str_fig ~= ' '
            figTitle = strcat(figTitle,str_fig);
            pdftextName1 = strcat('pdfit_Pearson',str_fig,'.txt');
            pdftextName2 = strcat('pdfit_MutualI',str_fig,'.txt');
            fcmatfile = strcat('fcPearsonMat-',num2str(parcCount),str_fig,'.txt');
            fcfitfile1 = strcat('fcPearsonFit-',num2str(parcCount),str_fig,'.txt');
            fcfitfile2 = strcat('fcMutualIFit-',num2str(parcCount),str_fig,'.txt');
        else
            pdftextName1 = strcat('pdfit_Pearson.txt');
            pdftextName2 = strcat('pdfit_MutualI.txt');
            fcmatfile = strcat('fcPearsonMat-',num2str(parcCount),'.txt');
            fcfitfile1 = strcat('fcPearsonFit-',num2str(parcCount),'.txt');
            fcfitfile2 = strcat('fcMutualIFit-',num2str(parcCount),'.txt');        
        end
        
        % write correlation matrices
        writematrix(fcMatrixPearson,fcmatfile)
	% write out normalized histogram values and fits (Pearson's and MutualInfo)
        clear fcfit
        fcfit = [hhPearson_x' hhPearson_y' Pearson_y_n' Pearson_y_k'];
%         fcfit(:,1) = hhPearson_x';
%         fcfit(:,2) = hhPearson_y';
%         fcfit(:,3) = Pearson_y_n';
%         fcfit(:,4) = Pearson_y_k';
        writematrix(fcfit,fcfitfile1)
        clear fcfit
        fcfit = [hhMutualI_x' hhMutualI_y' MutualI_y_n' MutualI_y_k'];
%         fcfit(:,1) = hhMutualI_x';
%         fcfit(:,2) = hhMutualI_y';
%         fcfit(:,3) = MutualI_y_n';
%         fcfit(:,4) = MutualI_y_k';
        writematrix(fcfit,fcfitfile2)

        % set fit parameters to text files
        fileID = fopen(pdftextName1,'a+');
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',pdPearson_n.mu,pdPearson_ci(:,1));
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',pdPearson_n.sigma,pdPearson_ci(:,2));
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',pdPearson_n.mu,pdPearson_ci(:,1));
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',Pearson_mean_n,Pearson_med_n,Pearson_std_n);
        fprintf(fileID,'%7.4f %7.4f\n',Pearson_xmax_n,Pearson_ymax_n);
        fprintf(fileID,'%7.4f\n',pdPearson_k.BandWidth);
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',Pearson_mean_k,Pearson_med_k,Pearson_std_k);
        fprintf(fileID,'%7.4f %7.4f\n',Pearson_xmax_k,Pearson_ymax_k);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2,pks2,ks2stat);
%         fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2zero,pks2zero,ks2statzero);        
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2peak,pks2peak,ks2statpeak);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2left,pks2left,ks2statleft);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n\n',hks2right,pks2right,ks2statright);        
        fclose(fileID);        
        fileID = fopen(pdftextName2,'a+');
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',pdMI_ln.mu,pdMI_ci(:,1));
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',pdMI_ln.sigma,pdMI_ci(:,2));
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',MutualI_mean_n,MutualI_med_n,MutualI_std_n);
        fprintf(fileID,'%7.4f %7.4f\n',MutualI_xmax_n,MutualI_ymax_n);        
        fprintf(fileID,'%7.4f\n',pdMI_k.BandWidth);
        fprintf(fileID,'%7.4f %7.4f %7.4f\n',MutualI_mean_k,MutualI_med_k,MutualI_std_k);        
        fprintf(fileID,'%7.4f %7.4f\n',MutualI_xmax_k,MutualI_ymax_k);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2_MI,pks2_MI,ks2stat_MI);       
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2peak_MI,pks2peak_MI,ks2statpeak_MI);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n',hks2left_MI,pks2left_MI,ks2statleft_MI);
        fprintf(fileID,'%7.4f %7.4e %7.4f\n\n',hks2right_MI,pks2right_MI,ks2statright_MI);                
        fclose(fileID); 
        saveas(parcFig, figTitle, 'png')
        pause(5)
    
        figTitle = strcat('ParcFig-', num2str(parcCount));
        parcFig = figure('visible','off');
        sgtitle({sprintf('%s%s %s',subjectinfo,',',EPIsess)})
        subplot(2,2,1)
        imagesc(fcMatrixPearson-eye(numRois))
        xlabel('Pearson''s')
        caxis([configs.EPI.fcColorMinP configs.EPI.fcColorMaxP])
        colorbar('Ticks',linspace(configs.EPI.fcColorMinP, configs.EPI.fcColorMaxP,5))
        axis square
        subplot(2,2,2)
        imagesc(fcMatrixSpearman-eye(numRois))
        xlabel('Spearman''s')
        caxis([configs.EPI.fcColorMinS configs.EPI.fcColorMaxS])
        colorbar('Ticks',linspace(configs.EPI.fcColorMinS, configs.EPI.fcColorMaxS,5))
        axis square
        subplot(2,2,3)
        imagesc(fcMatrixZscore-eye(numRois))
        xlabel('Z-score Pearson''s')
        caxis([configs.EPI.fcColorMinZ configs.EPI.fcColorMaxZ])
        colorbar
        axis square
        subplot(2,2,4)
        imagesc(fcMatrixMutualI-eye(numRois))
        xlabel('Mutual Information');
        caxis([configs.EPI.fcColorMinM configs.EPI.fcColorMaxM])
        colorbar
        axis square
        if str_fig ~= ' '
            figTitle = strcat(figTitle,str_fig);
        end
        saveas(parcFig, figTitle, 'png')
    end
end
% set(gcf,'Position',[300 100 1200 1200])

%%%%%%%%%%%%%%%%%%%%%%%%%%%% SAVE FIGURES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


fprintf('\n Saving figures at %s ...',fullfile(currDir,sprintf('figures_%s',timeseriesDir)))

if flags.EPI.FigsMotionGS == 1
    saveas(figure1,'motion_gs.png')
end
if flags.EPI.FigsPreRegress == 1
    saveas(figure2,'pre_regress_motion_tissue.png')
end
if flags.EPI.FigsPostRegress == 1
    saveas(figure3,'post_regress_motion_tissue.png')
end
if flags.EPI.FigsDmdtRegress == 1
    if str_fig ~= ' '
       figTitle = strcat('post_regress_dmdt_motion_tissue',str_fig,'.png');
    else
       figTitle = strcat('post_regress_dmdt_motion_tissue.png');
    end
    saveas(figure4,figTitle)
end
if flags.EPI.FigsParcellations == 1
    saveas(figure5,'parcellation_motion_tissue.png')
end

cd(currDir)

disp('fMRI_b analysis complete... continuing!')
