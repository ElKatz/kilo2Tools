%% batch_convertAndSort
%
% example script for batch conversion and sorting of raw ephys files.
%
% INSTRUCTIONS:
% - provide script with list of files.
% script will convert each raw file into .dat, will copy masterMegaFile.m
% into each directory, and kiloSort each
% - make sure you have correct path to kiloTools

%% add necessary paths to toolboxes:
cd('D:\Code\Toolboxes\kilo2Tools');
paths = addPathsForSpikeSorting;

%% settings :

% we have gathered here today to:
performConversion   = true;
performKiloSort     = true;

% basic options. Please review carefully!
opts.extractLfp     = true;         % extract LFP from the plx file during conversion and save?
opts.extractAi      = true;         % extract AI from the plx file during conversion and save?
opts.fs             = 40000;        % sampling rate of recording
opts.nCh            = 24;           % number of channels
opts.Nfilt          = ceil(opts.nCh / 32) * 32 * 3; % number of templates (aka filters) to use (recommendation: 2-4 times more than Nchan, should be a multiple of 32)
opts.probeGeometry  = 'linear100';  % see probeGeometry2coords.m for options

% advanced options:
opts.commonAverageReferencing   = false;
opts.specificChannels           = false; % either false or (eg) 65:96
if opts.specificChannels
    opts.nCh = length(opts.specificChannels);
end
opts.plotProbeVoltage           = true;
opts.removeArtifacts            = false;

%% list of paths to raw ephys files

% input your folders:
folderList = {...
%     'Y:\LAB PROJECTS\fefAttention\sna20150717a_msc_pre'...
%     'Y:\LAB PROJECTS\fefAttention\sna20150717b_msc_post'...
    'Y:\LAB PROJECTS\fefAttention\sna20150719a_msc_pre'...
    'Y:\LAB PROJECTS\fefAttention\sna20150719b_msc_post'...
    'Y:\LAB PROJECTS\fefAttention\sna20150721a_msc_pre'...
    'Y:\LAB PROJECTS\fefAttention\sna20150721b_msc_post'...
    'Y:\LAB PROJECTS\fefAttention\sna20150724a_msc_pre'...
    'Y:\LAB PROJECTS\fefAttention\sna20150724b_msc_post'...
    'Y:\LAB PROJECTS\fefAttention\sna20150726a_msc_pre'...
    'Y:\LAB PROJECTS\fefAttention\sna20150726b_msc_post'...
    };
nFiles = numel(folderList);

% Please specifiy the string by which you wish to identify your file of
% interest within each of the folders listed (e.g. 'pl2', 'mrg.plx'...):
fileIdentifierString = 'mrg.plx';

% Make list of dat files by adding .dat and inserting 'kiloSorted' folder:
rawPath         = cell(nFiles,1);
datPathList     = cell(nFiles,1);
kiloFolderList  = cell(nFiles,1);
fileName        = cell(nFiles,1);
for iF = 1:nFiles
    fileList    = dir(folderList{iF});
    idxGood     = arrayfun(@(x) ~strcmp(x.name(1), '.'), fileList); % identify files that do not start with '.'
    fileList    = fileList(idxGood);
    idxPl2      = arrayfun(@(x) ~isempty(strfind(x.name, fileIdentifierString)), fileList); % identify file that contain .pl (i.e. .plx or .pl2) 
    rawFile     = fileList(idxPl2).name;
    rawPath{iF} = fullfile(folderList{iF}, rawFile);
    [~, fileName{iF}]   = fileparts(rawPath{iF});
    kiloFolderList{iF}  = fullfile(folderList{iF}, 'kiloSorted2');
    datPathList{iF}     = fullfile(kiloFolderList{iF}, [fileName{iF} '.dat']);
end

%%  (1) convert, (2) copy masterMegaFile into kiloSorted folder, (3) sort:

for iF = 1:nFiles
    disp('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
    disp('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
    disp(['~~~~~  ' rawPath{iF}])
    disp('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
    
    % convert:
    if performConversion
        if exist(rawPath{iF}, 'file')
            opts.outputFolder = kiloFolderList{iF};
            convertRawToDat(rawPath{iF}, opts);
        end
    end
    
    % kiloSort:
    if performKiloSort
        copyfile(fullfile(paths.kilo2Tools, 'masterMegaFile.m') ,kiloFolderList{iF});
        if exist(datPathList{iF}, 'file')
            cd(kiloFolderList{iF})
            masterMegaFile(datPathList{iF}, opts.fs, opts.nCh, opts.probeGeometry, opts.Nfilt);
        end
    end
    
end

try
    load gong
    soundsc(y, Fs)
%     evalc('soundsc(double(aiffread(''/System/Library/Sounds/Glass.aiff''))'',50000)');
catch
end

%% NOW YOU SORT BY HAND.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% manually curate spikes with PHY %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% and then run batch_mkKsFigs.m %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



% fin.


%%%%%%%%%%%%%%%%%%%%%


