function sp = getSp(ksDir, varargin)
%   sp = getSp(ksDir, varargin)
%
% get a spike struct from a kiloSort output directory (ksDir)
% The function reads npy files from the ksDir to populate the sp struct
% with all you ever dreamt of and more.
%
% It gets all spike info and computes certain spike metrics such as ISI
% violation and cluster quality using routines stolen from CortexLab, using
% the sqKilosort.computeAllMeasures function.
%
% INPUT:
%   ksDir - path to directory of kiloSort output
%   varargin:
%   (see default wihin code)
%       waves   - if true, adds individual waveforms to the strcut (time
%                 consuming, so default is false)
%       exNoise - if true, excludes noise clusters (as defined in phy)
%       exMu    - if true, excludes multiunit clusters (as defined in phy)
%       loadPCs - if true, loads PCs.
%       waveWinT - [2x1] vector of time before & after spike time to extract
%                 the full waveform. in ms.
%
% OUTPUT:
%   sp - struct with all the goodies you need to access your spike data.
%

%% info:

%   dat_path:         your filename e.g. 'expt52.dat'
%   n_channels_dat:   e.g. 24
%   dtype:            e.g. 'int16'
%   offset:           offset between recording start time and sort time.
%   sample_rate:      sample rate of your DAQ system, e.g. 40000
%   hp_filtered:      0
%   dat_folder:       folder for your filename e.g. '/Users/leorkatz/Dropbox/Code/spike_sorting/pilot_dat?'
%   ss:             sample number at which there was a spike from any cluster
%   st:             [nTotalSpikes x 1] !!!! 2do !!! (* naming: st_s to indicate that it
%       is in seconds.
%   spikeTemplates: [nTotalSpikes x 1] the template number associated with
%       each spike.
%   clu: [nTotalSpikes x 1] the cluster number associated with
%       each spike.
%   tempScalingAmps: [nTotalSpikes x 1] the template scaling amplitude for
%   each spike
%%% the following are in size [nClusters x 1] i.e. for each sorted cluster
% cgs: [nClusters x 1] group number of each cluster e.g. [2 1 1 0 2] where 0=noise,
% 1=multiunit, 2=good.
% cids: [nClusters x 1] cluster id for each cluster e.g. [1 7 22 23 38]
% nClu: number of clusters
% nCh: number of channels
% xcoords: [nCh×1] x locations of recording channels
% ycoords: [nCh×1] y locations of recording channels
% temps: [nTemplates × nTemplateSamples × nCh] template shapes used for
% kilosort
% winv: [24×24 single]  !!!!! 2do
% pcFeat: [] !!!!! 2do
% pcFeatInd: [] !!!!! 2do
% wv: [nCh × nWaveformSamples × nTotalSpikes] full waveform within a window
% (window size defined in 'getSp.m')
% medWfs: [nClusters × nCh × nWaveformSamples] median waveform on channel
% which had the largest waveform amplitude.
%




%% defaults:

p = inputParser;
p.addOptional('waves', false);
p.addOptional('exNoise', true);
p.addOptional('exMu', true);
p.addOptional('loadPCs', false);
p.addOptional('waveWinT', [-300 900]);
p.addOptional('medWave', true)
p.addOptional('runQualityMeasures', true)
p.addOptional('visualize', false)
p.addOptional('save', true)
p.parse(varargin{:});

%% Store the info:

% load thee info struct
load(fullfile(ksDir, 'convertInfo.mat'));
info.ksDir          = ksDir;
info.depth          = [];
info.dTip2lowestCh  = [];
info.b              = [];

%% LOAD UP DATA FROM npy & csv FILES:

% load the sampsToSecMap:
load(fullfile(ksDir, 'sampsToSecsMap.mat'));

%%
% load spike data from npy:
sp              = loadParamsPy(fullfile(ksDir, 'params.py'));
sp.info         = info;
spikeTimesSamps = readNPY(fullfile(ksDir, 'spike_times.npy'));
spikeTimesSecs  = sampsToSecsMap(spikeTimesSamps);
spikeTemplates  = readNPY(fullfile(ksDir, 'spike_templates.npy')); % note: zero-indexed
if exist(fullfile(ksDir, 'spike_clusters.npy'), 'file')
    spikeClusters         = readNPY(fullfile(ksDir, 'spike_clusters.npy'));
else
    spikeClusters         = spikeTemplates;
end
tempScalingAmps = readNPY(fullfile(ksDir, 'amplitudes.npy'));


% get the phy output data from csv:
if exist(fullfile(ksDir, 'cluster_groups.csv'), 'file')
    csvFile         = fullfile(ksDir, 'cluster_groups.csv');
    disp('unit classification - via cluster_groups.csv')
elseif exist(fullfile(ksDir, 'cluster_group.tsv'), 'file')
    csvFile         = fullfile(ksDir, 'cluster_group.tsv');
    disp('unit classification - via cluster_group.tsv')
elseif exist(fullfile(ksDir, 'cluster_KSLabel.tsv'), 'file')
    csvFile         = fullfile(ksDir, 'cluster_KSLabel.tsv');
    disp('unit classification - via KSLabel')
else
    error('why no csv file? you baaad')
end
[clusterId, clusterScore]  = readClusterGroupsCSV(csvFile);

%% if you wish to exlcude noise or multiunit, this is where it happens:
idxGood = true(1,numel(clusterId));
if p.Results.exNoise
    idxGood(clusterScore==0) = false;
end
if p.Results.exMu
    idxGood(clusterScore==1) = false;
end  
cIdGood = clusterId(idxGood);

% exclude'em:
spikeTimesSamps = spikeTimesSamps(ismember(spikeClusters, cIdGood));
spikeTimesSecs  = spikeTimesSecs(ismember(spikeClusters, cIdGood));
spikeTemplates  = spikeTemplates(ismember(spikeClusters, cIdGood));
tempScalingAmps = tempScalingAmps(ismember(spikeClusters, cIdGood));
spikeClusters   = spikeClusters(ismember(spikeClusters, cIdGood));
clusterScore    = clusterScore(ismember(clusterId, cIdGood));
clusterId       = clusterId(ismember(clusterId, cIdGood));


% get the last pieces of data:
coords  = readNPY(fullfile(ksDir, 'channel_positions.npy'));
xcoords = coords(:,1);
ycoords = coords(:,2);
temps   = readNPY(fullfile(ksDir, 'templates.npy'));
winv    = readNPY(fullfile(ksDir, 'whitening_mat_inv.npy'));

% and pack it up:
sp.spikeTimesSamps  = spikeTimesSamps;
sp.spikeTimesSecs   = spikeTimesSecs;
sp.spikeTemplates   = spikeTemplates;
sp.spikeClusters    = spikeClusters;
sp.tempScalingAmps  = tempScalingAmps;
sp.clusterScore     = clusterScore;
sp.clusterId        = clusterId;
sp.clusterStr       = arrayfun(@(x) sprintf('%0.3d', x), clusterId, 'UniformOutput', 0); % for easy figure titles
sp.nClusters        = numel(sp.clusterId);
sp.nChannels        = numel(xcoords);
sp.xcoords          = xcoords;
sp.ycoords          = ycoords;
sp.temps            = temps;
sp.winv             = winv;
sp.wf               = [];

%% Sort quality meausres:
if p.Results.runQualityMeasures
    disp('Computing sort quality measures...')
    %   uQ   - unitQuality AKA isolation distance
    %   cR   - contamination rate = the proportion of spikes inside the cluster
    %          boundary that aren't from the cluster (false positive rate)
    [~, uQ, cR] = sqKilosort.maskedClusterQuality(ksDir);
    
    % indexing in with idxGood:
    sp.uQ           = uQ(idxGood);
    sp.cR           = cR(idxGood);
else
    sp.uQ = nan(sp.nClusters,1);
    sp.cR = nan(sp.nClusters,1);
    sp.isiV_fpRate = nan(sp.nClusters,1);
    sp.isiV_rate = nan(sp.nClusters,1);
end
%% isi violations:
%   isiV - isi Violations = the estimated false positive rate of your spike
%          train, based on the rate of refractory period violations.
[isiV_fpRate, isiV_rate] = compute_isiViolations(ksDir);
% indexing in with idxGood:
sp.isiV_fpRate  = isiV_fpRate(idxGood);
sp.isiV_rate    = isiV_rate(idxGood);

%% median waveform
% kinda just hacking this section together so probably not the most
% efficient or clean...
if p.Results.medWave
    disp('Retreiving median waveforms...')
    load(fullfile(ksDir, 'ops.mat'));
    %     d = dir(ops.fbinary);
    d = dir([info.ksDir '/*.dat']);
    nSamp = d.bytes/2/sp.n_channels_dat;
    dataSize = [sp.n_channels_dat nSamp];
    chanMap = readNPY(fullfile(ksDir, 'channel_map.npy'));
    gain = 0.6/512/500*1e6; % raw file units to uV ***SHOULD BE RIG SPECIFIC. NEED TO DO THIS...
    
    % median wf per cluster per channel, size: [nClu, nCh, nSamps]
    %     sp.medWfs = extractMedianWFs(sp.spikeClusters, sp.spikeTimesSecs, sp.sample_rate, fullfile(ksDir, sp.dat_path), sp.dtype, dataSize, chanMap, gain);
    sp.medWfs = extractMedianWFs(sp.spikeClusters, sp.spikeTimesSamps, sp.sample_rate, fullfile(ksDir, sp.dat_path), sp.dtype, dataSize, chanMap, gain, 'samples');
    % median wf per cluster on peak amplitude channel, size: [nClu, nSamps]
    for iS = 1:sp.nClusters
        medWfPerCh              = squeeze(sp.medWfs(iS,:,:))';
        medWfAmpPerCh           = max(medWfPerCh) - min(medWfPerCh);
        sp.peakCh(iS)           = find(medWfAmpPerCh == max(medWfAmpPerCh), 1);
        sp.medWfOnPeakCh(iS,:)  = medWfPerCh(:, sp.peakCh(iS));
    end
    
    if p.Results.visualize
        mkfig.medWfPerChannel(sp)
    end
end


%% save sp

if p.Results.save
    save(fullfile(ksDir, 'sp.mat'), '-struct', 'sp')
    disp('Done saving ''sp''')
else
    disp('not saving')
end


%% waves from all channels:
% if you wish to get waveforms (time consuming), this is where it happens:
if p.Results.waves
    
    disp('Retreiving all (yes all) waveforms. This might take a while...')
    % load in raw data
    load(fullfile(ksDir, 'ops.mat'));
    
    clu = sp.spikeClusters;
    st  = sp.spikeTimesSamps;
    Fs = sp.sample_rate;
    datPath = fullfile(ksDir, sp.dat_path);
    dataType = sp.dtype;
    d = dir([info.ksDir '/*.dat']);
    nSamp = d.bytes/2/sp.n_channels_dat;
    dataSize = [sp.n_channels_dat nSamp];
    chanMap = readNPY(fullfile(ksDir, 'channel_map.npy'));
    gain = 0.6/512/500*1e6; % raw file units to uV ***SHOULD BE RIG SPECIFIC. NEED TO DO THIS...
    method = 'samples';
    
    % window is -0.5 to 1.25ms
    wfWin = -round(0.5/1000*Fs):round(1.25/1000*Fs);
    nWFsamps = numel(wfWin);
    
    nChInFile = dataSize(1);
    nSamp = dataSize(2);
    mmf = memmapfile(datPath, 'Format', {dataType, [nChInFile nSamp], 'x'});
    
    cids = unique(clu);
    
    nClu = length(cids);
    nCh = length(chanMap);
    hWait = waitbar(0, 'Extracting individual waveforms....');
    wf = cell(1, nClu);
    tic
    for iClu = 1:nClu
        fprintf(1, 'cluster %d (%d/%d)\n', cids(iClu), iClu, nClu);
        theseST = st(clu==cids(iClu));
        nWFsToLoad = length(theseST);
        switch method
            case 'secs'
                extractST = round(theseST(randperm(length(theseST), nWFsToLoad))*Fs);
            case 'samples'
                extractST = round(theseST(randperm(length(theseST), nWFsToLoad)));
        end
        % in case a spike is detected at the very start or end of the
        % recording its full waveform can't be extracted, so remove it:
        extractST((extractST - wfWin(1))< 1) = [];
        extractST((extractST + wfWin(end))> size(mmf.Data.x,2)) = [];
        nWf = numel(extractST);
        
        
        % get the waveforms:
        theseWF = zeros(nWf, nCh, nWFsamps);
        for i=1:nWf
            tempWF = mmf.Data.x(1:nChInFile, extractST(i) + wfWin(1):extractST(i) + wfWin(end));
            theseWF(i,:,:) = tempWF(chanMap+1,:);
        end
        
        wf{iClu}  = theseWF;
        waitbar(iClu/nClu, hWait);
        disp(toc)
    end
   %  save(fullfile(ksDir, 'sp_waveforms.mat'), 'wf', '-v7.3');
    
    % now extract only waveforms from the peak channel, and save:
    wfOnPeak = cell(1, nClu);
    for iClu = 1:nClu
        wfOnPeak{iClu} = squeeze(wf{iClu}(:, sp.peakCh(iClu), :));
    end
    save(fullfile(ksDir, 'sp_waveformsOnPeak.mat'), 'wfOnPeak', '-v7.3');
end

