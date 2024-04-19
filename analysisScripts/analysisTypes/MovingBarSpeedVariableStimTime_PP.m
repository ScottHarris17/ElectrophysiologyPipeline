classdef MovingBarSpeedVariableStimTime_PP < analysisSuperClass_PP
    %MOVINGBARSPEEDVARIABLESTIMTIME_OKR_PHYSIOLOGY moving bar that changes
    %speed. Stim time changes on every epoch according to speed
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = analysis(obj)            
            %% Analysis for moving bar variable stim time
            processedDataStruct = struct();

            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')
                %create a Nx2 cell array to hold responses speed by speed
                %The first column will hold a single number that
                %corresponds to the speed
                %The second column will hold a 1xM array that contains the
                %responses at that speed. N corresponds to the number of
                %speeds, and M corresponds to the number of
                %epochs at each orientation.
                allSpeeds = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %in degrees/s, 1xN vector of all speeds used
                responsesBySpeed = cell(numel(allSpeeds), 2); %initialize the Nx2 cell array        
                responsesBySpeed(:, 1) = num2cell(allSpeeds');%fill the first column of the cell array with all speeds (in degrees/s)

                orientation = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %degrees        
                orientation = convertToRetinaAngle_PP(orientation, obj.recordingDate); %convert angles based on how projector is flipped
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth; %um
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight; %um

                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.allStimTimes = zeros(1, numel(obj.epochsSelected)); %initialize to save stim time for each epoch
                speedByEpoch = []; %record which epoch had which speed.
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentSpeed = branch_i.meta.currentSpeed;%deg
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.currentStimTime; %ms - this changes with the currentSpeed
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    speedByEpoch = [speedByEpoch, currentSpeed];

                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.allSpikeTimes{i} = spikeTimes;
                    
                    relevantSpikeTimes = spikeTimes(spikeTimes>preTime & spikeTimes < (preTime + stimTime));
                    maxFiringRate = obj.maxFiringRate(relevantSpikeTimes);
                    
                    %append maxFiringRate to relevant position in
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(responsesBySpeed(:,1)) == currentSpeed);

                    if isempty(indexToUse) %if the current speed doesn't exist, add it to the bottom
                        responsesBySpeed{end + 1, 1} = currentSpeed;
                        responsesBySpeed{end, 2} = [];
                        indexToUse = find(cell2mat(responsesBySpeed(:,1)) == currentSpeed);
                        allSpeeds = [allSpeeds, currentSpeed];
                    end

                    responsesBySpeed{indexToUse, 2} = [responsesBySpeed{indexToUse, 2}, maxFiringRate];
                    processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.allStimTimes(i) = stimTime;
                end
                
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.barWidth = barWidth;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.barHeight = barHeight;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.speedByEpoch = speedByEpoch;

                %calculate mean and standard deviation maxFiringRate for
                %each speed
                meanBySpeed = [];
                stdBySpeed = [];
                semBySpeed = [];
                for i = 1:numel(allSpeeds)
                    meanBySpeed = [meanBySpeed mean(responsesBySpeed{i,2})];
                    stdBySpeed = [stdBySpeed std(responsesBySpeed{i, 2})];
                    semBySpeed = [semBySpeed, std(responsesBySpeed{i, 2})/sqrt(numel(responsesBySpeed{i, 2}))];
                end

                %add to processed data struct
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.Speed = allSpeeds;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.Orientation = orientation;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.spikesByspeed = responsesBySpeed;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.mean_spikesBySpeed = meanBySpeed;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.std_spikesBySpeed = stdBySpeed;

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentSpeed'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar_Speed_VarStimTime.Extracellular.meta = editedMeta;
                
                %% Build analysis figure
                X = allSpeeds;
                Y = meanBySpeed;
                errorTop = Y + semBySpeed;
                errorBottom = Y - semBySpeed;
                
                analysisFigure1 = figure();
                bar(X, Y)
                hold on
                erPlot = errorbar(X, Y, errorBottom, errorTop);
                erPlot.LineStyle = 'none';
                title(strcat(obj.cellID, 'Moving Bar Speed (VST)'));
                xlabel('speed (deg/s)')
                ylabel('Mean Maximum Firing Rate (hz)');
                caption = ['Orientation = ' num2str(orientation)];
                a = annotation('textbox',[0.5 0.65 0 0], 'String',caption,'FitBoxToText','on');
                a.FontSize = 9;
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
                                
                allSpeeds = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %in degrees/s, 1xN vector of all speeds used
                orientation = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %degrees
                orientation = convertToRetinaAngle_PP(orientation, obj.recordingDate); %convert angles based on how projector is flipped
                
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth; %um
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight; %um
                
                tracesBySpeed = cell(numel(allSpeeds), 2); %initialize the Nx2 cell array        
                tracesBySpeed(:, 1) = num2cell(allSpeeds');%fill the first column of the cell array with all orientations (in degrees)
                
                epochNumsBySpeed = tracesBySpeed; %initialize Nx2 cell array. This one lists which epochs were which orientations
                
                %create arrays to hold each parameter epoch by epoch. Also
                %write down the speed of each epoch.
                integralByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %default is a -1234.5678 --> a number that should probably never occur organically. This way you know if there's a bug
                peakPositiveCurrentByEpoch =  zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakPositiveCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                holdingCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                speedByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %record which epoch had which orientation.
                
                %cell arrays to keep track of data with indeterminate
                %number of peaks
                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).allStimTimes = zeros(1, numel(obj.epochsSelected)); %initialize to save stim time for each epoch

                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    %Pull out the recording trace
                    trace = branch_i.epoch;
                    
                    %get relevant parameters
                    currentSpeed = branch_i.meta.currentSpeed;%deg
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.currentStimTime; %ms - this changes with the currentSpeed
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    speedByEpoch(i) = currentSpeed;
                    
                    %low pass filter
                    lpTrace = lowpass(trace, 60, sampleRate);
                    
                    %get key features
                    baseline = lpTrace(1:round(preTime*sampleRate/1000));
                    trailLine = lpTrace(round((preTime+stimTime)*sampleRate/1000):end);
                    holdingCurrent = mean(lpTrace(1:round(preTime*sampleRate/1000)));
                    holdingCurrentByEpoch(i) = holdingCurrent;
                    
                    normalizedTrace = lpTrace - holdingCurrent;
                    
                    %get rid of low pass filter artifacts
                    normalizedTrace(1:100) = mean(normalizedTrace(100:200)); normalizedTrace(end-100:end) = mean(normalizedTrace(end-200:end-100));                    
                    
                    if std(baseline) > 10 || std(trailLine) > 10
                        disp(['***Notice: found a possible anomoly on epoch number ' num2str(obj.epochsSelected(i))])
                    end
                    
                    integralByEpoch(i) = trapz(normalizedTrace)/sampleRate;
                    
                    %biggest positive peak and the time it occured
                    [peakPositive, peakPositiveTime] = max(normalizedTrace);
                    peakPositiveCurrentByEpoch(i) = peakPositive;
                    timeToPeak_peakPositiveCurrentByEpoch(i) = peakPositiveTime*1000/sampleRate; %convert to ms
                    
                    %biggest negative peak and the time it occured
                    [peakNegative, peakNegativeTime] = min(normalizedTrace);
                    peakNegativeCurrentByEpoch(i) = peakNegative;
                    timeToPeak_peakNegativeCurrentByEpoch(i) = peakNegativeTime*1000/sampleRate; %convert to ms              
                    
                    %all (low frequency) positive and negative peaks and
                    %the times they occured
                    [positivePeaks, negativePeaks] = findPeaks(normalizedTrace, sampleRate); %returns a structure for positive and negative peaks
                    allPositivePeaksByEpoch{i} = positivePeaks;
                    allNegativePeaksByEpoch{i} = negativePeaks;
                
                    
                    %append numSpikes to relevant position in
                    %responsesBySpeed cell array
                    indexToUse = find(cell2mat(tracesBySpeed(:,1)) == currentSpeed);
                    
                    if isempty(indexToUse) %if the current speed doesn't exist, add it to the bottom
                        tracesBySpeed{end + 1, 1} = currentSpeed;
                        epochNumsBySpeed{end + 1, 1} = currentSpeed;
                        tracesBySpeed{end, 2} = [];
                        epochNumsBySpeed{end, 2} = [];
                        indexToUse = find(cell2mat(tracesBySpeed(:,1)) == currentSpeed);
                        allSpeeds = [allSpeeds, currentSpeed];
                    end
                    
                    tracesBySpeed{indexToUse, 2} = [tracesBySpeed{indexToUse, 2}; normalizedTrace];
                    epochNumsBySpeed{indexToUse, 2} = [epochNumsBySpeed{indexToUse, 2}, i];
                    processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).allStimTimes(i) = stimTime;
                end
   
                %get mean and std traces for each direction
                downSampleRate = 10;
                meanTracesBySpeed = struct();
                meanTracesBySpeed.speedOrder = allSpeeds;
                
                meanTraces = cell(1, numel(allSpeeds));
                stdTraces = cell(1, numel(allSpeeds));
                for i = 1:numel(allSpeeds)
                    speed_i = allSpeeds(i);
                    indx_i = find(cell2mat(tracesBySpeed(:, 1)) == speed_i);
                    meanTrace = mean(tracesBySpeed{indx_i, 2}, 1);
                    stdTrace = std(tracesBySpeed{indx_i, 2}, 1);
                    smoothedMeanTrace = movmean(meanTrace, downSampleRate, 2);
                    smoothedSTDTrace = movmean(stdTrace, downSampleRate, 2);
                    meanReduced = smoothedMeanTrace(:, 1:downSampleRate:end);
                    stdReduced = smoothedSTDTrace(:, 1:downSampleRate:end);
                    meanTraces{i} = meanReduced;
                    stdTraces{i} = stdReduced;
                end

                
                %save to a structure
                meanTracesBySpeed.meanTraces = meanTraces;
                meanTracesBySpeed.stdTraces = stdTraces;
                meanTracesBySpeed.sampleRate = sampleRate/downSampleRate;
                meanTracesBySpeed.downSampleRate = downSampleRate;
                
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).barWidth = barWidth;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).barHeight = barHeight;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).speedByEpoch = speedByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).epochNumsBySpeed = epochNumsBySpeed;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).Speed = allSpeeds;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).Orientation = orientation;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).TotalChargeByEpoch = integralByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).maxPositivePeakByEpoch = peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).maxPositivePeakByEpoch_timesToPeak = timeToPeak_peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).maxNegativePeakByEpoch = peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).maxNegativePeakByEpoch_timesToPeak = timeToPeak_peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).allPositivePeaksByEpoch = allPositivePeaksByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).allNegativePeaksByEpoch = allNegativePeaksByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).holdingCurrentByEpoch = holdingCurrentByEpoch; 
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).meanTracesBySpeed = meanTracesBySpeed; 
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentSpeed'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar_Speed_VarStimTime.(keyword).meta = editedMeta;
                
                %% create analysis figure
                analysisFigure1 = figure();
                title([obj.cellID ' Mean Total Charge By Speed : ' keyword])
                hold on
                xlabel('speed (deg/s)')
                ylabel('pA*s')
                labels = {};
                charges = zeros(numel(allSpeeds), 1);
                errs = zeros(size(charges));
                for i = 1:numel(allSpeeds)
                    speed_i = allSpeeds(i);
                    epochs_i = speedByEpoch == speed_i;
                    charges(i) = mean(integralByEpoch(epochs_i));
                    errs(i) = std(integralByEpoch(epochs_i)/sqrt(sum(epochs_i)));
                end
                errorbar(allSpeeds, charges, errs);
            end
            

            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';

            obj.processedData = processedDataStruct;
        end

        
    end
end


