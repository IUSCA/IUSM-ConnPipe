%                     DATA_QUALITY_CONTROL_FIGURES
%                          make_QC_figures_test
%  This code generates Quality Control (QC) figures for various ConnPipe
%  stages of processing T1 and EPI. 
%  
%
%
%  Contributors:
%           Evgeny Chumin, Indiana University, Bloomington, 2019
%           Andrea Conway, IU UITS, 2022. Updated/Adapted to run with ConnPipe



%%
clearvars
clc

%% --------------------- USER DEFINED INPUT DATA ----------------------- %%
% Path to ConnPipe Supplementary Materials folder
path2SM = '/N/project/username/ConnPipelineSM/';

% Data directory (contains subject directories)
path2data = '/N/project/username/Derivables';

% Define Subjects to run
%subjectList = dir(fullfile(path2data,'Subj0*'));   % e.g. All subjects in path2data direcotry whose ID starts with Subj0
% Or a specific set of subjects:
subjectList(1).name = 'NF0011';

% These variables should be set up to match the config.sh settings
EPIdir = 'EPI1';
T1dir = 'T1';

% Set to 1 the modalities you wish to create QA figures for:
section_T1brainmask = 1;
section_T1masks = 0; % we recommend running this section alone and manually rotating the 3D image for inspection 
section_T1reg = 1;
section_T1parc = 1;
section_EPI = 1;
%
%% ------------------------------- PATHS ------------------------------- %%

% Exporting FSL path
paths.FSL='/N/soft/rhel7/fsl/6.0.1b/bin';
% Addings connectome spripts path (Includes NIfTI toolbox)
fsl_config = fullfile(paths.FSL,'..','etc','fslconf','fsl.sh');
run_fsl_config = sprintf('. %s',fsl_config);
system(run_fsl_config)

path2code = pwd;
addpath(genpath(path2SM));
MNI = fullfile(path2SM,'MNI_templates','MNI152_T1_1mm.nii.gz');
addpath(genpath(fullfile(path2SM,'toolbox_matlab_nifti')))
addpath(fullfile(path2SM,'functions'));


%%
%% -------------------------- GENERATE FIGS -------------------------- %%

for k=1:length(subjectList)
    
    %% GENERATE SUBJECT PATHS
    subjID = subjectList(k).name;
    disp(['======== PROCESING SUBJECT ',subjID,' ========='])

    Subj_T1 = fullfile(path2data,subjID,T1dir);
    path2EPI = fullfile(path2data,subjID,EPIdir);

    paths.subject=fullfile(path2data,subjID); % path to subject
    paths.QAdir=fullfile(paths.subject,'QC_figures'); %output directory
    if ~exist(paths.QAdir,'dir')
        mkdir(paths.QAdir) % make output directory if it doesn't exist
    end

    %% 1-brain_mask_on_fov_denoised
    if section_T1brainmask == 1
        % Set paths and filenames
        T1fpath=fullfile(Subj_T1,'T1_fov_denoised.nii');
        maskfpath=fullfile(Subj_T1,'T1_brain_mask_filled.nii.gz');
        if isfile(T1fpath) && isfile(maskfpath)
            T1=MRIread(T1fpath);
            mask=MRIread(maskfpath);
            % Select representative slices from T1 volume
            midslice=round(size(T1.vol,3)/2);
            slices=[midslice-30 midslice-15 midslice midslice+25 midslice+40];
            % initialize figure
            h=figure;
            h.Units='pixels';
            h.Position=[671 469 1084 242];
            % generate a grayscale loropmap with red as the highest intensity color
            cmap=colormap(gray(128));
            cmap(129,:)=[1 0 0];
            colormap(cmap)
            % For each representative slice
            for i=1:5
                subplot(1,5,i) % create plot in figure
                tslice=T1.vol(:,:,slices(i)); % select & display T1 slice
                h(1)=imagesc(tslice);
                hold on
                mslice=mask.vol(:,:,slices(i)); % select matching brain mask slice
                % set mask value to 1+ highest intensity in T1 slice
                mslice(mslice==1)=max(max(tslice))+1;
                h(2)=imagesc(mslice); % overlay mask
                h(2).AlphaData = 0.5; % set mask transparency
                set(gca,'Visible','off') % hide axes
                hold off
                clear tslice mslice
            end
            % Add title to figure and save as high resolution png
            sgtitle(sprintf('%s: T1 brain mask overlay',subjectList(k).name),'Interpreter','none')
            fileout = fullfile(paths.QAdir,'1-brain_mask_on_fov_denoised.png');
            count=length(dir(strcat(fileout(1:end-4),'*')));
            if count > 0
                fileout = fullfile(paths.QAdir,sprintf('1-brain_mask_on_fov_denoised_v%d.png',count+1));
            end
            %set(gcf, 'Units', 'pixels','Position',[150 100 1200 800])
            print(fileout,'-dpng','-r600')
            % close all
        else
            disp('no T1_fov_denoised and/or T1_brain_mask found.')
        end
    end
    
    %% 2-T1-warped_contour_onMNI
    if section_T1reg == 1
        % read in template and subject data
        T1mnifile = fullfile(Subj_T1,'registration','T1_warped.nii.gz');
        if exist(T1mnifile,'file')
            T1mni=MRIread(T1mnifile);
            upperT1=.75*(max(max(max(T1mni.vol))));
            MNIt=MRIread(MNI);
            filename=fullfile(paths.QAdir,'2-T1_warped_contour_onMNI.gif');
            count=length(dir(strcat(filename(1:end-4),'*')));
            if count > 0
                filename = fullfile(paths.QAdir,sprintf('2-T1_warped_contour_onMNI_v%d.gif',count+1));
            end
            % open figure
            h=figure;
            h.Position = [671 254 574 616];
            colormap(gray(128))
            for n=1:5:size(MNIt.vol,3) % for every 5th slice in MNI volume
                imagesc(T1mni.vol(:,:,n)); % plot MNI
                hold all
                % overlay contour image of subject MNI space transforment T1
                contour(MNIt.vol(:,:,n),'LineWidth',1,'LineColor','r','LineStyle','-')
                set(gca,'XTickLabel',[],'YTickLabel',[])
                caxis([0 upperT1])
                title(sprintf('%s: MNI space T1 with MNI template contour overlay',subjectList(k).name),'Interpreter','none')
                drawnow
                % convert plots into iamges
                frame=getframe(h);
                im=frame2im(frame);
                [imind,cm]=rgb2ind(im,256);
                % write the gif file
                if n==1
                    imwrite(imind,cm,filename,'gif','DelayTime',.2,'Loopcount',inf);
                else
                    imwrite(imind,cm,filename,'gif','DelayTime',.2,'WriteMode','append')
                end
            end
            % close all
        else
            fprintf('%s: No T1_warped.nii.gz found.\n',subjectList(k).name)
        end
    end
    
    %% 3-T1_tissue_masks
    if section_T1masks == 1
        
        masks=struct;
        masks(1).name = 'T1_subcort_mask.nii.gz';
        masks(2).name = 'registration/Cerebellum_dil_bin.nii.gz';
        masks(3).name = 'T1_mask_CSFvent.nii.gz';
        if exist(fullfile(Subj_T1,masks(2).name),'file')
            T1=MRIread(fullfile(Subj_T1,'T1_fov_denoised.nii'));
            f3=figure;
            for mm = 1:length(masks)
                tmp_mask=MRIread(fullfile(Subj_T1,masks(mm).name));
                [X,Y,Z]=ind2sub(size(tmp_mask.vol),find(tmp_mask.vol>0));
                if mm==1
                    %plot3(X(1:3:end),Y(1:3:end),Z(1:3:end))%,'.','MarkerEdgeAlpha',.05,'MarkerFaceAlpha',.05)
                    scatter3(X(1:100:end),Y(1:100:end),Z(1:100:end),10,'filled');
                    xlim([1 size(tmp_mask.vol,1)])
                    ylim([1 size(tmp_mask.vol,2)])
                    zlim([1 size(tmp_mask.vol,3)])
                    hold on
                elseif mm ==2
                    %plot3(X(1:3:end),Y(1:3:end),Z(1:3:end),'.')%,'MarkerEdgeAlpha',.05,'MarkerFaceAlpha',.05)
                    scatter3(X(1:100:end),Y(1:100:end),Z(1:100:end),10,'filled','MarkerEdgeAlpha',.2,'MarkerFaceAlpha',.2);
                elseif mm ==3
                    %plot3(X(1:3:end),Y(1:3:end),Z(1:3:end),'.')%,'MarkerEdgeAlpha',.05,'MarkerFaceAlpha',.05)
                    scatter3(X(1:100:end),Y(1:100:end),Z(1:100:end),10,'filled','MarkerEdgeAlpha',.5,'MarkerFaceAlpha',.5);
                end
                clear tmp_mask
            end
            hold off
            legend({'Subcortical','Cerebellar','Ventricular'},'Location','northeast')
            title(subjectList(k).name,'Interpreter','none')
            
            fileout = fullfile(paths.QAdir,'3-subcort_vols.png');
            count=length(dir(strcat(fileout(1:end-4),'*')));
            if count > 0
                fileout = fullfile(paths.QAdir,sprintf('3-subcort_vols_v%d.png',count+1));
            end
            % print(fileout,'-dpng','-r300')
            % close all
        else
            fprintf('Subject %s no Cerebellum mask found!\n',subjectList(k).name)
        end
    end
    
    %% 3-GM_parc_on_fov_denoised
    if section_T1parc == 1
        
        % get a list of parcellation files
        parcs=dir(fullfile(Subj_T1,'T1_GM_parc*'));
        % remove the dilated versions
        idx=double.empty;
        for j=1:length(parcs)
            if ~isempty(strfind(parcs(j).name,'dil'))
                idx(end+1)=j; %#ok<*SAGROW>
            end
        end
        parcs(idx)=[];
        % find max T1 intensity
        T1=fullfile(Subj_T1,'T1_fov_denoised.nii');
        if exist(T1,'file')
            T1=MRIread(fullfile(Subj_T1,'T1_fov_denoised.nii'));
            Tmax=round(max(max(max(T1.vol))));
            % set representative slices
            midslice=round(size(T1.vol,3)/2);
            slices=[midslice-30 midslice-15 midslice midslice+25 midslice+40];
            
            % for each parcellation
            numparcs = length(parcs);
            maxIdx=double.empty;
            for p=1:numparcs
                T1p=MRIread(fullfile(Subj_T1,parcs(p).name)); % load parcellation
                maxIdx(end+1)=max(unique(T1p.vol)); % find max index value in parcellation
                
                % initialize figure
                if p==1
                    h=figure;
                    h.Units='inches';
                    height = 5*numparcs; % set 5in for each parcellation
                    h.Position=[1 1 20 height];
                end
                
                for n=1:5 % for each representatice slice
                    numplot=n+(5*(p-1));
                    subplot(numparcs,5,numplot)
                    h(1)=imagesc(T1.vol(:,:,slices(n))); % plot T1 slice
                    hold on
                    % scale parcellation IDs to ID+twice the maximun T1 intensity
                    % this ensures the color portion of the colormap is used
                    mslice=T1p.vol(:,:,slices(n))+2*Tmax;
                    mslice(mslice<=2*Tmax)=0;
                    h(2)=imagesc(mslice); % plot parcellation slice
                    a=mslice; a(a>0)=0.7;
                    h(2).AlphaData = a; % set transparency
                    set(gca,'Visible','off') % hide axes
                    hold off
                    clear mslice
                end
            end
            % generate colormap that is a joined grayscale (low values) and
            % colors (high values); 2x size the number of nodes in parcellation.
            c2map=gray(128);
            c3map=lines(max(maxIdx));
            cpmap=vertcat(c2map,c3map);
            colormap(cpmap)
            sgtitle(sprintf('%s: GM parcs overlays',subjectList(k).name),'Interpreter','none')
            fileout = fullfile(paths.QAdir,'3-GM_parc_on_fov_denoised.png');
            count=length(dir(strcat(fileout(1:end-4),'*')));
            if count > 0
                fileout = fullfile(paths.QAdir,sprintf('3-GM_parc_on_fov_denoised_v%d.png',count+1));
            end
            print(fileout,'-dpng','-r600')
            %close all
        else
            fprintf(2,'%s - no T1_fov_denoised found.\n',subjectList(k).name)
        end
    end
    
    %%
    if section_EPI ==1
        
        %% 4-MCFLIRT-motion-parameters
        motion=dlmread(fullfile(path2EPI,'motion.txt'));
        rmax = max(max(abs(motion(:,1:3))));
        h=figure('Units','inches','Position',[1 1 10 5]);
        h(1)=subplot(2,1,1);
        plot(zeros(length(motion),1),'k--')
        hold all
        plot(motion(:,1:3))
        l=rmax+(.25*rmax);
        ylim([-l l])
        title('rotation relative to mean'); legend('','x','y','z','Location','eastoutside')
        ylabel('radians')
        hold off
        
        tmax = max(max(abs(motion(:,4:6))));
        h(2)=subplot(2,1,2); %#ok<*NASGU>
        plot(zeros(length(motion),1),'k--')
        hold all
        plot(motion(:,4:6))
        l=tmax+(.25*tmax);
        ylim([-l l])
        title('translation relative to mean'); legend('','x','y','z','Location','eastoutside')
        ylabel('millimeters')
        hold off
        sgtitle(sprintf('%s: mcFLIRT motion parameters',subjectList(k).name),'Interpreter','none')
        fileout = fullfile(paths.QAdir,sprintf('4-mcFLIRT_motion_parameters.png'));
        count=length(dir(strcat(fileout(1:end-4),'*')));
        if count > 0
            fileout = fullfile(paths.QAdir,sprintf('4-mcFLIRT_motion_parameters_v%d.png',count+1));
        end
        print(fileout,'-dpng','-r600')
       % close all
        
        %% 5-rT1_GM_mask_on_epiMeanVol
        % Set filenames/read in data
        MeanVol=MRIread(fullfile(path2EPI,'2_epi_meanvol.nii.gz'));
        mask=MRIread(fullfile(path2EPI,'rT1_GM_mask.nii.gz'));
        % Select representative slices from EPI volume
        midslice=round(size(MeanVol.vol,3)/2);
        slices=[midslice-15 midslice-9 midslice-2 midslice+2 midslice+9 midslice+15];
        % initialize figure
        h=figure;
        h.Units='inches';
        h.Position=[7.0729 3.4375 8.2292 5.6562];
        % generate a grayscale loropmap with red as the highest intensity color
        cmap=colormap(gray(128));
        cmap(129,:)=[1 0 0];
        colormap(cmap)
        % For each representative slice
        for i=1:length(slices)
            subplot(2,length(slices)/2,i) % create plot in figure
            vslice=MeanVol.vol(:,:,slices(i)); % select & display epi slice
            h(1)=imagesc(vslice);
            hold on
            mslice=mask.vol(:,:,slices(i)); % select matching brain mask slice
            % set mask value to 1+ highest intensity in epi slice
            mslice(mslice==1)=max(max(vslice))+1;
            h(2)=imagesc(mslice); % overlay mask
            h(2).AlphaData = 0.5; % set mask transparency
            title(sprintf('Slice %d',slices(i)));
            %set(gca,'Visible','off') % hide axes
            axis off
            hold off
            clear vslice mslice
        end
        % Add title to figure and save as high resolution png
        sgtitle(sprintf('%s: rT1_GM_mask on epi_meanvol',subjID),'Interpreter','none')
        fileout = fullfile(paths.QAdir,sprintf('5-rT1_GM_mask_on_epiMeanVol.png'));
        count=length(dir(strcat(fileout(1:end-4),'*')));
        if count > 0
            fileout = fullfile(paths.QAdir,sprintf('5-rT1_GM_mask_on_epiMeanVol_v%d.png',count+1));
        end
        print(fileout,'-dpng','-r600')
        %close all
        
        %% 6-rT1_GM_parc_on_epi_meanVol
        % get a list of parcellation files
        parcs=dir(fullfile(path2EPI,'rT1_GM_parc*clean*'));
        % find max T1 intensity
        Emax=round(max(max(max(MeanVol.vol))));
        % for each parcellation
        numparcs = length(parcs);
        maxIdx=double.empty;
        for p=1:numparcs
            EPIp=MRIread(fullfile(path2EPI,parcs(p).name)); % load parcellation
            maxIdx(end+1)=max(unique(EPIp.vol)); % find max index value in parcellation
            
            % initialize figure
            if p==1
                h=figure;
                h.Units='inches';
                height = 5*numparcs; % set 5in for each parcellation
                h.Position=[1 1 20 height];
            end
            
            for n=1:length(slices) % for each representatice slice
                numplot=n+(length(slices)*(p-1));
                subplot(numparcs,length(slices),numplot)
                h(1)=imagesc(MeanVol.vol(:,:,slices(n))); % plot T1 slice
                hold on
                % scale parcellation IDs to ID+twice the maximun T1 intensity
                % this ensures the color portion of the colormap is used
                mslice=EPIp.vol(:,:,slices(n))+Emax;
                mslice(mslice<=Emax)=0;
                h(2)=imagesc(mslice); % plot parcellation slice
                a=mslice; a(a>0)=0.7;
                h(2).AlphaData = a; % set transparency
                set(gca,'Visible','off') % hide axes
                hold off
                clear mslice
            end
        end
        % generate colormap that is a joined grayscale (low values) and
        % colors (high values); 2x size the number of nodes in parcellation.
        c2map=gray(Emax);
        c3map=lines(max(maxIdx));
        cpmap=vertcat(c2map,c3map);
        colormap(cpmap)
        sgtitle(sprintf('%s: EPI-GM parc overlays',subjID),'Interpreter','none')
        fileout = fullfile(paths.QAdir,sprintf('6-rT1_GM_parc_on_epi_meanVol.png'));
        count=length(dir(strcat(fileout(1:end-4),'*')));
        if count > 0
            fileout = fullfile(paths.QAdir,sprintf('6-rT1_GM_parc_on_epi_meanVol_v%d.png',count+1));
        end
        print(fileout,'-dpng','-r600')
        %close all
        
        %% 8-Nuisance_regressors
        %TBD
        %         end
    end
end
%%

% DWI
clear subjectList