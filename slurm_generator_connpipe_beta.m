

% generating slurm job files

%% user info:
email = 'echumin@iu.edu';

%% RT Projects account
acct = 'r00216'; % this is Jenya's carbonate connproc acct

%% resources requested:
ppn = '8';
walltime = '6:00:00';
vmem = '12G';

%% data
% path to bids project
path2deriv='/N/project/kbase-imaging/kbase1-bids/derivatives/connpipe';
% path to raw data
path2data='/N/project/kbase-imaging/kbase1-bids/raw';
% number of subjects per job
nS = 2; 

% where to write job, log, and error files
batch_path = '/N/project/kbase-imaging/connpipe_job_test';

%% pipeline
% pipeline directory
connPipe = '/N/project/kbase-imaging/connpipe_job_test/IUSM-ConnPipe';

% config file
config = '/N/project/kbase-imaging/connpipe_job_test/hpc_config_s2_dwiA_REGon.sh';

%% building subject list from raw
% subjALL = struct2cell(dir([path2data '/sub-*']));
subjALL = subj_runREGon{2}';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% just for me
% filter to only subjects with specific visit data
% subjV=cell.empty;
% for su=1:length(subjALL)
%     path = [path2deriv '/' subjALL{1,su} '/ses-v0'];
%     if exist(path,'dir')
%         subjV(1,end+1)=subjALL(1,su);
%     end
%     clear path
% end
% subjALL=subjV; clear subjV
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tS=length(subjALL); % total subjects
nJ = ceil(tS/nS);   % number of jobs
rt='dwi_regon_v2';

for j = 1:nJ
    sS=(j*nS)-nS+1; % starting subject
    eS=j*nS;        % ending subject
    if eS<=tS
        s2r=subjALL(1,sS:eS)';
    else
        s2r=subjALL(1,sS:end)';
    end
    subj2run = [batch_path '/subj2run_' rt '_' num2str(j) 'of' num2str(nJ) '.txt'];
    writecell(s2r,subj2run)
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
    fprintf(fidslurm, ['./hpc_main_kbase.sh ' config ' ' subj2run]); %!!!!!!!!!!!!!!!!
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