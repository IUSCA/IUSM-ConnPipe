

% generating slurm job files

%% user info:
email = 'echumin@iu.edu';

%% RT Projects account
acct = 'r00216'; % this is Jenya's carbonate connproc acct

%% resources requested:
ppn = '1';
walltime = '2:00:00';
vmem = '12G';

%% data
% path to bids project
path2deriv='/N/project/HCPaging/iadrc2024q3/derivatives/connpipe';
% path to raw data
path2data='/N/project/HCPaging/iadrc2024q3/raw';
% number of subjects per job
nS = 4; 

% where to write job, log, and error files
batch_path = '/N/project/HCPaging/iadrc2024q3/batch_files';

%% pipeline
% pipeline directory
connPipe = '/N/u/echumin/Quartz/img_proc_tools/IUSM-ConnPipe';

% config file
config = '/N/project/HCPaging/iadrc2024q3/config.sh';

%% building subject list 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% build a list of subjID and session pairs from a connpipe derivative
%  directory
subj=dir([path2data '/sub-*']);
subj2run=cell.empty;

for ss=1:length(subj)
    ses=dir(fullfile(subj(ss).folder,subj(ss).name,'ses*'));
    for ee=1:length(ses)
        %subj2run{end+1,1}=subj(ss).name;
        %subj2run{end,2}=ses(ee).name;
        %-------------------------------------------------%
        % if exist([ses(ee).folder '/' ses(ee).name '/func'],'dir') && ~exist([ses(ee).folder '/' ses(ee).name '/fmap'],'dir')
        % % ADDING CHECK THAT FUNC EXISTS BUT FMAP DOES NOT
        % subj2run{end+1,1}=subj(ss).name;
        % subj2run{end,2}=ses(ee).name;
        % end
        %-------------------------------------------------%
        %-------------------------------------------------%
        if ~exist([path2deriv '/' subj(ss).name '/' ses(ee).name '/anat/T1_WM_mask.nii.gz'],'file')
        % ADDING CHECK THAT T1_WM_MASK 
        subj2run{end+1,1}=subj(ss).name;
        subj2run{end,2}=ses(ee).name;
        end
        %-------------------------------------------------%
    end
    clear ses
end
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tS=size(subj2run,1); % total subjects
nJ = ceil(tS/nS);   % number of jobs
rt='fmri_preproc_fsl607';

for j = 1:nJ
    sS=(j*nS)-nS+1; % starting subject
    eS=j*nS;        % ending subject
    if eS<=tS
        s2r=subj2run(sS:eS,:);
    else
        s2r=subj2run(sS:end,:);
    end
    subj2run_file = [batch_path '/subj2run_' rt '_' num2str(j) 'of' num2str(nJ) '.txt'];
    writecell(s2r,subj2run_file,'Delimiter',' ')
    clear s2r

    %% build slurm job file
    fidslurm = fopen([batch_path '/conn_job_' rt '_' num2str(j) 'of' num2str(nJ) '.sbatch'],'w');

    fprintf(fidslurm, '#!/bin/bash\n\n');
    fprintf(fidslurm, ['#SBATCH -J conn_proc_' rt '_' num2str(j) 'of' num2str(nJ) '\n']);
    fprintf(fidslurm, ['#SBATCH -o ' batch_path '/out_job_' rt '_' num2str(j) 'of' num2str(nJ) '.txt\n']);
    fprintf(fidslurm, ['#SBATCH -e ' batch_path '/err_' rt '_' num2str(j) 'of' num2str(nJ) '.txt\n\n']);
    fprintf(fidslurm, ['#SBATCH -A ' acct '\n']);
    fprintf(fidslurm, '#SBATCH -p general\n');
    fprintf(fidslurm, '#SBATCH --mail-type=ALL\n');
    fprintf(fidslurm, ['#SBATCH --mail-user=' email '\n']);
    fprintf(fidslurm, '#SBATCH --nodes=1\n');
    fprintf(fidslurm, ['#SBATCH --ntasks-per-node=' ppn '\n']);
    fprintf(fidslurm, ['#SBATCH --time=' walltime '\n']);
    fprintf(fidslurm, ['#SBATCH --mem=' vmem '\n']);

    fprintf(fidslurm, ['cd ' connPipe '\n\n']);        
    fprintf(fidslurm, ['./main_connpipe.sh ' config ' ' subj2run_file]); 
    fclose(fidslurm);
end

%%  Generate file that will submit all PBS scripts created
sscripts = dir([batch_path '/conn_job_' rt '*.sbatch']);
fidSLURMrun = fopen([batch_path '/' rt '_submitSLURMscripts.sh'],'w');
for i=1:size(sscripts,1)
    fprintf(fidSLURMrun,['sbatch ' sscripts(i).name '\n']);
end
fclose(fidSLURMrun);
system(['chmod ug+x ' batch_path '/' rt '_submitSLURMscripts.sh']);