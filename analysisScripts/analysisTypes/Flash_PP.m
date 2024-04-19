classdef Flash_PP< analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            %This function processes data from a Flash stimulus. It is called by
            %analyzer_OKR_Physiology.m if the user has chosen to analyze Flash
            %epochs from the dataViewer gui. Unlike other analysis types, Flash 
            %analysis can be run on epochs that used a variety of stimuli if the 
            %user desires, though this is not necessarily advised.

            %% Modifiable Parameters
            transientThreshold = 100; %in ms, threshold cutoff between transient and sustained flash responses

            processedDataStruct = struct();

            %% Extracellular spikes and current clamp spikes analysis
            if strcmp(obj.recordingType, 'Extracellular') || strcmp(obj.recordingType, 'Current Clamp (K+ Spikes)')
                
                switch obj.recordingType
                    case 'Extracellular'
                        keyword = 'Extracellular';
                    case 'Current Clamp (K+ Spikes)'
                        keyword = 'CurrentClamp_PotassiumSpikes';
                        restingMembranePotentialByEpoch = [];
                end

                %initialize processed data structure;
                processedDataStruct.Flash.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                processedDataStruct.Flash.(keyword).transientThreshold = transientThreshold; %copy of the transient threshold set by user above
                processedDataStruct.Flash.(keyword).allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch
                processedDataStruct.Flash.(keyword).baseline_firingRates = []; %list of firing rates from all epochs during baseline
                processedDataStruct.Flash.(keyword).ON_firingRates = []; %list of firing rates from all epochs during stim on (during the flash)
                processedDataStruct.Flash.(keyword).ON_transient_firingRates = []; %list of firing rates from all epochs between stim on and transient threshold (set above)
                processedDataStruct.Flash.(keyword).ON_sustained_firingRates = []; %list of firing rates from all epochs during stim on and after transient threshold
                processedDataStruct.Flash.(keyword).OFF_firingRates = []; %list of firing rates from all epochs during tail time

                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %Pull out the relevant metadata for analysis
                    preTime = branch_i.meta.preTime; %in ms
                    stimTime = branch_i.meta.stimTime; %in ms
                    tailTime = branch_i.meta.tailTime; %in ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    if strcmp(keyword, 'CurrentClamp_PotassiumSpikes')
                        %get resting Vm for current clamp recording
                        restingMembranePotential = mean(trace(1:(preTime*sampleRate/1000)));
                        restingMembranePotentialByEpoch = [restingMembranePotentialByEpoch, restingMembranePotential];
                    end
                    
                    %Extract spikes using desired spikeDetector
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);                    
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;


                    processedDataStruct.Flash.(keyword).allSpikeTimes{i} = spikeTimes; %add to struct

                    %find spike times that happened during the pretime
                    preSpikeIndx = find(spikeTimes < preTime);
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime));
                    tailSpikeIndx = find(spikeTimes > (preTime + stimTime));

                    %calculate firing rates over each part of the epoch
                    baselineFR = numel(preSpikeIndx)/(preTime/1000); %firing rate in hz;
                    ON_FR = numel(stimSpikeIndx)/(stimTime/1000);
                    OFF_FR = numel(tailSpikeIndx)/(tailTime/1000);

                    %Get a bit more detailed by looking for ON transient/sustained
                    ONtransientSpikes = spikeTimes(stimSpikeIndx) < (stimTime + transientThreshold);
                    ONsustainedSpikes = spikeTimes(stimSpikeIndx) > (stimTime + transientThreshold);

                    numONtransient = numel(find(ONtransientSpikes));
                    numONsustained = numel(find(ONsustainedSpikes));

                    ONtransientFR = numONtransient/(transientThreshold/1000);
                    ONsustainedFR = numONsustained/((stimTime - transientThreshold)/1000);

                    %add to processedDataStruct
                    processedDataStruct.Flash.(keyword).baseline_firingRates = [processedDataStruct.Flash.(keyword).baseline_firingRates; baselineFR];
                    processedDataStruct.Flash.(keyword).ON_firingRates = [processedDataStruct.Flash.(keyword).ON_firingRates; ON_FR];
                    processedDataStruct.Flash.(keyword).ON_transient_firingRates = [processedDataStruct.Flash.(keyword).ON_transient_firingRates; ONtransientFR];
                    processedDataStruct.Flash.(keyword).ON_sustained_firingRates = [processedDataStruct.Flash.(keyword).ON_sustained_firingRates; ONsustainedFR];
                    processedDataStruct.Flash.(keyword).OFF_firingRates = [processedDataStruct.Flash.(keyword).OFF_firingRates; OFF_FR];
                end


                %% calculate means and standard deviations for each metric
                avg_baseline = mean(processedDataStruct.Flash.(keyword).baseline_firingRates);
                std_baseline = std(processedDataStruct.Flash.(keyword).baseline_firingRates);
                avg_ON_FR = mean(processedDataStruct.Flash.(keyword).ON_firingRates);
                std_ON_FR = std(processedDataStruct.Flash.(keyword).ON_firingRates);
                avg_ONtransient_FR = mean(processedDataStruct.Flash.(keyword).ON_transient_firingRates);
                std_ONtransient_FR = std(processedDataStruct.Flash.(keyword).ON_transient_firingRates);
                avg_ONsustained_FR = mean(processedDataStruct.Flash.(keyword).ON_sustained_firingRates);
                std_ONsustained_FR = std(processedDataStruct.Flash.(keyword).ON_sustained_firingRates);
                avg_OFF_FR = mean(processedDataStruct.Flash.(keyword).OFF_firingRates);
                std_OFF_FR = std(processedDataStruct.Flash.(keyword).ON_firingRates);

                %and then add all of these back into the processedDataStruct     
                processedDataStruct.Flash.(keyword).average_baseline_firingRate = avg_baseline;
                processedDataStruct.Flash.(keyword).std_baseline_firingRate = std_baseline;
                processedDataStruct.Flash.(keyword).average_ON_firingRate = avg_ON_FR;
                processedDataStruct.Flash.(keyword).std_ON_firingRate = std_ON_FR;
                processedDataStruct.Flash.(keyword).average_ON_transient_firingRate = avg_ONtransient_FR;
                processedDataStruct.Flash.(keyword).std_ON_transient_firingRate = std_ONtransient_FR;
                processedDataStruct.Flash.(keyword).average_ON_sustained_firingRate = avg_ONsustained_FR;
                processedDataStruct.Flash.(keyword).std_ON_sustained_firingRate = std_ONsustained_FR;
                processedDataStruct.Flash.(keyword).average_OFF_firingRate = avg_OFF_FR;
                processedDataStruct.Flash.(keyword).std_OFF_firingRate = std_OFF_FR;
                if strcmp(keyword, 'CurrentClamp_PotassiumSpikes')
                    processedDataStruct.Flash.(keyword).restingMembranePotentialByEpoch = restingMembranePotentialByEpoch;
                end

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Flash.(keyword).meta = editedMeta;


                %% Create analysis figure. It is a bar plot with the average spike
                %rates from prestim, stim (on), and post stim (off) time points
                analysisFigure1 = figure();

                X = categorical({'baseline','ON','OFF'});
                X = reordercats(X,{'baseline','ON','OFF'});       
                Y = [avg_baseline, avg_ON_FR, avg_OFF_FR];
                bar(X, Y);
                hold on

                err = [std_baseline,std_ON_FR, std_OFF_FR];
                errorTop = err + Y;
                errorBottom = Y - err;

                erPlot = errorbar(X, Y, errorBottom, errorTop);
                erPlot.LineStyle = 'none';

                ylabel('Average Firing Rate');
                title(strcat(obj.cellID, ' Flash '));
                hold off
            end
            
            
            
            %% Intracellular voltage clamp analysis
            if strcmp(obj.recordingType, 'Excitation (Intracellular)') ||...
                strcmp(obj.recordingType, 'Inhibition (Intracellular)')
                
                switch obj.recordingType
                    case 'Excitation (Intracellular)'
                        keyword = 'Intracellular_Excitation';
                    case 'Inhibition (Intracellular)'
                        keyword = 'Intracellular_Inhibition';
                end
                
                
                %initialize processed data structure;
                processedDataStruct.Flash.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                totalEpochs = numel(obj.epochsSelected);
                holdingCurrentByEpoch = zeros(1, totalEpochs);
                totalChargeByEpoch = zeros(1, totalEpochs);
                ON_totalChargeByEpoch = zeros(1, totalEpochs);
                ON_maxPositivePeakByEpoch = zeros(1, totalEpochs);
                ON_maxPositivePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                ON_maxNegativePeakByEpoch = zeros(1, totalEpochs);
                ON_maxNegativePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                OFF_totalChargeByEpoch = zeros(1, totalEpochs);
                OFF_maxPositivePeakByEpoch = zeros(1, totalEpochs);
                OFF_maxPositivePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                OFF_maxNegativePeakByEpoch = zeros(1, totalEpochs);
                OFF_maxNegativePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                
                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %Pull out the relevant metadata for analysis
                    preTime = branch_i.meta.preTime; %in ms
                    stimTime = branch_i.meta.stimTime; %in ms
                    tailTime = branch_i.meta.tailTime; %in ms
                    totalTime = preTime+stimTime+tailTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    %low pass filter
                    lpTrace = lowpass(trace, 60, sampleRate);
                    
                    %get key features
                    baseline = lpTrace(1:preTime*sampleRate/1000);
                    trailLine = lpTrace((preTime+stimTime)*sampleRate/1000:end);
                    holdingCurrent = mean(lpTrace(1:preTime*sampleRate/1000));
                    holdingCurrentByEpoch(i) = holdingCurrent;
                    
                    normalizedTrace = lpTrace - holdingCurrent;
                    
                    %get rid of low pass filter artifacts
                    normalizedTrace(1:100) = mean(normalizedTrace(100:200)); normalizedTrace(end-100:end) = mean(normalizedTrace(end-200:end-100));                    
                    
                    if std(baseline) > 10 || std(trailLine) > 10
                        disp(['***Notice: found a possible anomoly on epoch number ' num2str(obj.epochsSelected(i))])
                    end
                    
                    ONIndex = preTime*sampleRate/1000;
                    OFFIndex = (preTime+stimTime)*sampleRate/1000;
                    
                    totalChargeByEpoch(i) = trapz(normalizedTrace)/sampleRate;
                    ON_totalChargeByEpoch(i) = trapz(normalizedTrace(ONIndex:OFFIndex))/sampleRate;
                    OFF_totalChargeByEpoch(i) = trapz(normalizedTrace(OFFIndex:end))/sampleRate;
                    
                    %biggest positive peak and the time it occured for both
                    %ON and OFF response
                    [ON_peakPositive, ON_peakPositiveTime] = max(normalizedTrace(ONIndex:OFFIndex));
                    ON_maxPositivePeakByEpoch(i) = ON_peakPositive;
                    ON_maxPositivePeakByEpoch_timesToPeak(i) = (ON_peakPositiveTime+ONIndex)*1000/sampleRate; %convert to ms
                    
                    [OFF_peakPositive, OFF_peakPositiveTime] = max(normalizedTrace(OFFIndex:end));
                    OFF_maxPositivePeakByEpoch(i) = OFF_peakPositive;
                    OFF_maxPositivePeakByEpoch_timesToPeak(i) = (OFF_peakPositiveTime+OFFIndex)*1000/sampleRate; %convert to ms
                    
                    %biggest negative peak and the time it occured for both
                    %ON and OFF response
                    [ON_peakNegative, ON_peakNegativeTime] = min(normalizedTrace(ONIndex:OFFIndex));
                    ON_maxNegativePeakByEpoch(i) = ON_peakNegative;
                    ON_maxNegativePeakByEpoch_timesToPeak(i) = (ON_peakNegativeTime+ONIndex)*1000/sampleRate; %convert to ms              
                    
                    [OFF_peakNegative, OFF_peakNegativeTime] = min(normalizedTrace(OFFIndex:end));
                    OFF_maxNegativePeakByEpoch(i) = OFF_peakNegative;
                    OFF_maxNegativePeakByEpoch_timesToPeak(i) = (OFF_peakNegativeTime+OFFIndex)*1000/sampleRate; %convert to ms              
                    
                    %all (low frequency) positive and negative peaks and
                    %the times they occured
                    [positivePeaks, negativePeaks] = findPeaks(normalizedTrace, sampleRate);
                    allPositivePeaksByEpoch{i} = positivePeaks;
                    allNegativePeaksByEpoch{i} = negativePeaks;
                    
                    if i == 1
                        allTraces = zeros(0, numel(normalizedTrace));
                    end
                    allTraces(i, :) = normalizedTrace;
                end
                
                %compute average trace:
                downSampleRate = 10;
                meanTrace = struct();
                mTrace= mean(allTraces, 1);
                stdTrace = std(allTraces, 1);
                
                %a bit of smoothing and downsampling
                smoothedMeanTrace = movmean(mTrace, downSampleRate, 2);
                smoothedSTDTraces = movmean(stdTrace, downSampleRate, 2);
                meanReduced = smoothedMeanTrace(:, 1:downSampleRate:end);
                stdReduced = smoothedSTDTraces(:, 1:downSampleRate:end);
                
                %save to a structure
                meanTrace.meanTrace = meanReduced;
                meanTrace.stdTrace = stdReduced;
                meanTrace.sampleRate = sampleRate/downSampleRate;
                meanTrace.downSampleRate = downSampleRate;
                
                %% calculate means and standard deviations for each metric
                
               
                %and then add all of these back into the processedDataStruct   
                processedDataStruct.Flash.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                processedDataStruct.Flash.(keyword).holdingCurrentByEpoch = holdingCurrentByEpoch;
                processedDataStruct.Flash.(keyword).totalChargeByEpoch = totalChargeByEpoch;
                processedDataStruct.Flash.(keyword).ON_totalChargeByEpoch = totalChargeByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxPositivePeakByEpoch = ON_maxPositivePeakByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxPositivePeakByEpoch_timesToPeak = ON_maxPositivePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).ON_maxNegativePeakByEpoch = ON_maxNegativePeakByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxNegativePeakByEpoch_timesToPeak = ON_maxNegativePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).OFF_totalChargeByEpoch = OFF_totalChargeByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxPositivePeakByEpoch = OFF_maxPositivePeakByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxPositivePeakByEpoch_timesToPeak = OFF_maxPositivePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).OFF_maxNegativePeakByEpoch = OFF_maxNegativePeakByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxNegativePeakByEpoch_timesToPeak = OFF_maxNegativePeakByEpoch_timesToPeak;
                %processedDataStruct.Flash.(keyword).meanTrace = meanTrace;
                processedDataStruct.Flash.(keyword).stimTime = stimTime;
                processedDataStruct.Flash.(keyword).preTime = preTime;
                processedDataStruct.Flash.(keyword).tailTime = tailTime;
                processedDataStruct.Flash.(keyword).totalTime = totalTime;
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Flash.(keyword).meta = editedMeta;


                %% Create analysis figure. It is a bar plot with the average spike
                %rates from prestim, stim (on), and post stim (off) time points
                analysisFigure1 = figure();
                xpoints = linspace(0, totalTime, numel(meanTrace.meanTrace));
                plot(xpoints, meanTrace.meanTrace)
                hold on
                title([obj.cellID, ' Mean Flash Response ', keyword])
                xlabel('time (ms)')
                ylabel('pA')
                hold off
            end
            
            %% Current clamp with cesium (current clamp with K+ for spikes is listed above w/ extracellular spikes)
            if strcmp(obj.recordingType, 'Current Clamp (Cesium)')
                
                switch obj.recordingType
                    case 'Current Clamp (Cesium)'
                        keyword = 'CurrentClamp_Cesium';
                end
                
                
                %initialize processed data structure;
                processedDataStruct.Flash.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                totalEpochs = numel(obj.epochsSelected);
                integralByEpoch = zeros(1, totalEpochs);
                ON_integralByEpoch = zeros(1, totalEpochs);
                ON_maxPositivePeakByEpoch = zeros(1, totalEpochs);
                ON_maxPositivePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                ON_maxNegativePeakByEpoch = zeros(1, totalEpochs);
                ON_maxNegativePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                OFF_integralByEpoch = zeros(1, totalEpochs);
                OFF_maxPositivePeakByEpoch = zeros(1, totalEpochs);
                OFF_maxPositivePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                OFF_maxNegativePeakByEpoch = zeros(1, totalEpochs);
                OFF_maxNegativePeakByEpoch_timesToPeak = zeros(1, totalEpochs);
                restingMembranePotentialByEpoch = zeros(1, numel(obj.epochsSelected)) - 1234.5678; %The trace will be normalized by subtracting off the mean value of the first 1000 points in order to calculate the integral. This number says what that offset is so that you can get back to the original trace by subtracting it from the normalized one.

                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %Pull out the relevant metadata for analysis
                    preTime = branch_i.meta.preTime; %in ms
                    stimTime = branch_i.meta.stimTime; %in ms
                    tailTime = branch_i.meta.tailTime; %in ms
                    totalTime = preTime+stimTime+tailTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    %get offset value for normalized trace
                    restingMembranePotential = mean(trace(1:1000));
                    restingMembranePotentialByEpoch(i) = restingMembranePotential;
                    
                    normalizedTrace = trace - restingMembranePotential;
                    integralByEpoch(i) = trapz(normalizedTrace)/sampleRate;
                    
                    ONIndex = preTime*sampleRate/1000;
                    OFFIndex = (preTime+stimTime)*sampleRate/1000;
                    
                    ON_integralByEpoch(i) = trapz(normalizedTrace(ONIndex:OFFIndex))/sampleRate;
                    OFF_integralByEpoch(i) = trapz(normalizedTrace(OFFIndex:end))/sampleRate;
                    
                    %biggest positive peak and the time it occured for both
                    %ON and OFF response
                    [ON_peakPositive, ON_peakPositiveTime] = max(trace(ONIndex:OFFIndex));
                    ON_maxPositivePeakByEpoch(i) = ON_peakPositive;
                    ON_maxPositivePeakByEpoch_timesToPeak(i) = (ON_peakPositiveTime+ONIndex)*1000/sampleRate; %convert to ms
                    
                    [OFF_peakPositive, OFF_peakPositiveTime] = max(trace(OFFIndex:end));
                    OFF_maxPositivePeakByEpoch(i) = OFF_peakPositive;
                    OFF_maxPositivePeakByEpoch_timesToPeak(i) = (OFF_peakPositiveTime+OFFIndex)*1000/sampleRate; %convert to ms
                    
                    %biggest negative peak and the time it occured for both
                    %ON and OFF response
                    [ON_peakNegative, ON_peakNegativeTime] = min(trace(ONIndex:OFFIndex));
                    ON_maxNegativePeakByEpoch(i) = ON_peakNegative;
                    ON_maxNegativePeakByEpoch_timesToPeak(i) = (ON_peakNegativeTime+ONIndex)*1000/sampleRate; %convert to ms              
                    
                    [OFF_peakNegative, OFF_peakNegativeTime] = min(trace(OFFIndex:end));
                    OFF_maxNegativePeakByEpoch(i) = OFF_peakNegative;
                    OFF_maxNegativePeakByEpoch_timesToPeak(i) = (OFF_peakNegativeTime+OFFIndex)*1000/sampleRate; %convert to ms              
                    
                    %all positive and negative peaks and
                    %the times they occured
                    [positivePeaks, negativePeaks] = findPeaks(trace, sampleRate);
                    allPositivePeaksByEpoch{i} = positivePeaks;
                    allNegativePeaksByEpoch{i} = negativePeaks;
                    
                    if i == 1
                        allTraces = zeros(0, numel(trace));
                    end
                    allTraces(i, :) = trace;
                end
                
                %compute average trace:
                downSampleRate = 10;
                meanTrace = struct();
                mTrace= mean(allTraces, 1);
                stdTrace = std(allTraces, 1);
                
                %a bit of smoothing and downsampling
                smoothedMeanTrace = movmean(mTrace, downSampleRate, 2);
                smoothedSTDTraces = movmean(stdTrace, downSampleRate, 2);
                meanReduced = smoothedMeanTrace(:, 1:downSampleRate:end);
                stdReduced = smoothedSTDTraces(:, 1:downSampleRate:end);
                
                %save to a structure
                meanTrace.meanTrace = meanReduced;
                meanTrace.stdTrace = stdReduced;
                meanTrace.sampleRate = sampleRate/downSampleRate;
                meanTrace.downSampleRate = downSampleRate;
                
                %% calculate means and standard deviations for each metric
                
               
                %and then add all of these back into the processedDataStruct   
                processedDataStruct.Flash.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                processedDataStruct.Flash.(keyword).IntegralByEpoch = integralByEpoch;
                processedDataStruct.Flash.(keyword).ON_integralByEpoch = ON_integralByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxPositivePeakByEpoch = ON_maxPositivePeakByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxPositivePeakByEpoch_timesToPeak = ON_maxPositivePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).ON_maxNegativePeakByEpoch = ON_maxNegativePeakByEpoch;
                processedDataStruct.Flash.(keyword).ON_maxNegativePeakByEpoch_timesToPeak = ON_maxNegativePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).OFF_integralByEpoch = OFF_integralByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxPositivePeakByEpoch = OFF_maxPositivePeakByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxPositivePeakByEpoch_timesToPeak = OFF_maxPositivePeakByEpoch_timesToPeak;
                processedDataStruct.Flash.(keyword).OFF_maxNegativePeakByEpoch = OFF_maxNegativePeakByEpoch;
                processedDataStruct.Flash.(keyword).OFF_maxNegativePeakByEpoch_timesToPeak = OFF_maxNegativePeakByEpoch_timesToPeak;
                %processedDataStruct.Flash.(keyword).meanTrace = meanTrace;
                processedDataStruct.Flash.(keyword).stimTime = stimTime;
                processedDataStruct.Flash.(keyword).preTime = preTime;
                processedDataStruct.Flash.(keyword).tailTime = tailTime;
                processedDataStruct.Flash.(keyword).totalTime = totalTime;
                processedDataStruct.Flash.(keyword).restingMembranePotentialByEpoch = restingMembranePotentialByEpoch;

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Flash.(keyword).meta = editedMeta;


                %% Create analysis figure. It is a bar plot with the average spike
                %rates from prestim, stim (on), and post stim (off) time points
                analysisFigure1 = figure();
                xpoints = linspace(0, totalTime, numel(meanTrace.meanTrace));
                plot(xpoints, meanTrace.meanTrace)
                hold on
                title([obj.cellID, ' Mean Flash Response ', keyword])
                xlabel('time (ms)')
                ylabel('pA')
                hold off
            end
            
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            obj.processedData = processedDataStruct;  
        end
    end
end