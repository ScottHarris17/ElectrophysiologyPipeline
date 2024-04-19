classdef MovingBar_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            %% Analysis for moving bar stim
            processedDataStruct = struct();

            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')

                %create a Nx2 cell array to hold responses by orientation
                %The first column will hold a single number that corresponds to the orientation
                %The second column will hold a 1xM array that contains the
                %responses at that orientation. N corresponds to the number of
                %orientations (usually 8), and M corresponds to the number of
                %epochs at each orientation (often 5).
                allOrientations = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %in degrees, 1xN vector of all orientations used
                allOrientations = convertToRetinaAngle_PP(allOrientations, obj.recordingDate); %convert angles based on how projector is flipped
                responsesByOrientation = cell(numel(allOrientations), 2); %initialize the Nx2 cell array        
                responsesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)

                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second        
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth;
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight;

                processedDataStruct.Moving_Bar.Extracellular.allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    

                orientationByEpoch = []; %record which epoch had which orientation.
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %convert angles based on how projector is flipped
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    orientationByEpoch = [orientationByEpoch, currentOrientation];

                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);                     
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    processedDataStruct.Moving_Bar.Extracellular.allSpikeTimes{i} = spikeTimes;

                    %count spikes that happen during the stim
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime));
                    numSpikes = numel(stimSpikeIndx);

                    %append numSpikes to relevant position in
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(responsesByOrientation(:,1)) == currentOrientation);

                    if isempty(indexToUse) %if the current orienatation doesn't exist, add it to the bottom
                        responsesByOrientation{end + 1, 1} = currentOrientation;
                        responsesByOrientation{end, 2} = [];
                        indexToUse = find(cell2mat(responsesByOrientation(:,1)) == currentOrientation);
                        allOrientations = [allOrientations, currentOrientation];
                    end

                    responsesByOrientation{indexToUse, 2} = [responsesByOrientation{indexToUse, 2}, numSpikes];
                end

                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar.Extracellular.preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar.Extracellular.stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Bar.Extracellular.tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar.Extracellular.barWidth = barWidth;
                processedDataStruct.Moving_Bar.Extracellular.barHeight = barHeight;
                processedDataStruct.Moving_Bar.Extracellular.barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar.Extracellular.centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar.Extracellular.orientationByEpoch = orientationByEpoch;

                %calculate mean and standard deviation spike number for each direction
                meanByOrientation = [];
                stdByOrientation = [];
                for i = 1:numel(allOrientations)
                    meanByOrientation = [meanByOrientation mean(responsesByOrientation{i,2})];
                    stdByOrientation = [stdByOrientation std(responsesByOrientation{i, 2})];
                end

                %calculate mean vector
                allOrientationsRad = deg2rad(allOrientations);
                [x,y] = pol2cart(allOrientationsRad, meanByOrientation);
                xSUM = sum(x);
                ySUM = sum(y);
                [meanTheta, meanRho] = cart2pol(xSUM, ySUM);
                meanTheta = rad2deg(meanTheta);

                %calculate DSI... DSI = length of preferred vector/sum(response in
                %all directions).
                totalSum = sum(meanByOrientation); %sum from all directions
                DSI = meanRho/totalSum; %vector length over sum of all the directions

                %add to processed data struct
                processedDataStruct.Moving_Bar.Extracellular.EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar.Extracellular.Orientation = allOrientations;
                processedDataStruct.Moving_Bar.Extracellular.Speed = speed;
                processedDataStruct.Moving_Bar.Extracellular.spikesByOrientation = responsesByOrientation;
                processedDataStruct.Moving_Bar.Extracellular.mean_spikesByOrientation = meanByOrientation;
                processedDataStruct.Moving_Bar.Extracellular.std_spikesByOrientation = stdByOrientation;
                processedDataStruct.Moving_Bar.Extracellular.PreferredDirection = meanTheta;
                processedDataStruct.Moving_Bar.Extracellular.MeanVectorLength = meanRho;
                processedDataStruct.Moving_Bar.Extracellular.DSI = DSI;

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentOrientation'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar.Extracellular.meta = editedMeta;
                
                meanByOrientationHz = meanByOrientation./(stimTime/1000);
                
                %% create analysis figure
                analysisFigure1 = figure();
                polarwitherrorbar(deg2rad(allOrientations), meanByOrientationHz, stdByOrientation./(stimTime/1000));
                hold on
                polarplot([0 deg2rad(meanTheta)],[0 meanRho/(stimTime/1000)], '-k', 'LineWidth', 2);
                title(strcat(obj.cellID, ' Moving Bar'));
                caption = ['Speed = ' num2str(round(speed, 2))...
                    '; Preferred Angle = ' num2str(round(meanTheta, 1)) '; Vector Length = ' num2str(round(meanRho, 2))...
                    '; DSI = ' num2str(round(DSI, 3))];
                a = annotation('textbox',[0.02 0.06 0 0], 'String',caption,'FitBoxToText','on');
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
                
                allOrientations = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %in degrees, 1xN vector of all orientations used
                allOrientations = convertToRetinaAngle_PP(allOrientations, obj.recordingDate); %convert angles based on how projector is flipped
                
                tracesByOrientation = cell(numel(allOrientations), 2); %initialize the Nx2 cell array        
                tracesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)
                
                epochNumsByOrientation = tracesByOrientation; %initialize Nx2 cell array. This one lists which epochs were which orientations
                
                %create arrays to hold each parameter epoch by epoch. Also
                %write down the orientation of each epoch.
                integralByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %default is a -1234.5678 --> a number that should probably never occur organically. This way you know if there's a bug
                peakPositiveCurrentByEpoch =  zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakPositiveCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                holdingCurrentByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                
                %cell arrays to keep track of data with indeterminate
                %number of peaks
                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth;
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight;
                                
                orientationByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %record which epoch had which orientation.
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    %Pull out the recording trace
                    trace = branch_i.epoch;
                    
                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %convert angles based on how projector is flipped
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    tailTime = branch_i.meta.tailTime; %ms
                    totalTime = preTime+stimTime+tailTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    orientationByEpoch(i) = currentOrientation;
                    
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
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(tracesByOrientation(:,1)) == currentOrientation);
                    
                    if isempty(indexToUse) %if the current orienatation doesn't exist, add it to the bottom
                        tracesByOrientation{end + 1, 1} = currentOrientation;
                        epochNumsByOrientation{end + 1, 1} = currentOrientation;
                        tracesByOrientation{end, 2} = [];
                        epochNumsByOrientation{end, 2} = [];
                        indexToUse = find(cell2mat(tracesByOrientation(:,1)) == currentOrientation);
                        allOrientations = [allOrientations, currentOrientation];
                    end
                    
                    tracesByOrientation{indexToUse, 2} = [tracesByOrientation{indexToUse, 2}; normalizedTrace];
                    epochNumsByOrientation{indexToUse, 2} = [epochNumsByOrientation{indexToUse, 2}, i];
                end
                
                %get mean and std traces for each direction
                downSampleRate = 10;
                probeSpot = tracesByOrientation{indexToUse, 2};
                meanTraces = zeros(size(tracesByOrientation, 1), size(probeSpot, 2));
                stdTraces = zeros(size(tracesByOrientation, 1), size(probeSpot, 2));
                meanTracesByOrientation = struct();
                meanTracesByOrientation.orientationOrder = allOrientations;
                for i = 1:numel(allOrientations)
                    orientation_i = allOrientations(i);
                    for j = 1:size(tracesByOrientation, 1)
                        orientation_j = tracesByOrientation{j, 1};
                        if orientation_i == orientation_j
                            traces_i = tracesByOrientation{j, 2};
                            break
                        end
                    end
                    meanTraces(i, :) = mean(traces_i);
                    stdTraces(i, :) = std(traces_i);
                end
                %a bit of smoothing and downsampling
                smoothedMeanTraces = movmean(meanTraces, downSampleRate, 2);
                smoothedSTDTraces = movmean(stdTraces, downSampleRate, 2);
                meanReduced = smoothedMeanTraces(:, 1:downSampleRate:end);
                stdReduced = smoothedSTDTraces(:, 1:downSampleRate:end);
                
                %save to a structure
                meanTracesByOrientation.meanTraces = meanReduced;
                meanTracesByOrientation.stdTraces = stdReduced;
                meanTracesByOrientation.sampleRate = sampleRate/downSampleRate;
                meanTracesByOrientation.downSampleRate = downSampleRate;
                
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar.(keyword).preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar.(keyword).stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Bar.(keyword).tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar.(keyword).sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar.(keyword).barWidth = barWidth;
                processedDataStruct.Moving_Bar.(keyword).barHeight = barHeight;
                processedDataStruct.Moving_Bar.(keyword).barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar.(keyword).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar.(keyword).centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar.(keyword).orientationByEpoch = orientationByEpoch;
                processedDataStruct.Moving_Bar.(keyword).epochNumsByOrientation = epochNumsByOrientation;
                processedDataStruct.Moving_Bar.(keyword).EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar.(keyword).Orientation = allOrientations;
                processedDataStruct.Moving_Bar.(keyword).Speed = speed;
                processedDataStruct.Moving_Bar.(keyword).TotalChargeByEpoch = integralByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxPositivePeakByEpoch = peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxPositivePeakByEpoch_timesToPeak = timeToPeak_peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxNegativePeakByEpoch = peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxNegativePeakByEpoch_timesToPeak = timeToPeak_peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar.(keyword).allPositivePeaksByEpoch = allPositivePeaksByEpoch;
                processedDataStruct.Moving_Bar.(keyword).allNegativePeaksByEpoch = allNegativePeaksByEpoch;
                processedDataStruct.Moving_Bar.(keyword).holdingCurrentByEpoch = holdingCurrentByEpoch; 
                %processedDataStruct.Moving_Bar.(keyword).meanTracesByOrientation = meanTracesByOrientation; 
                processedDataStruct.Moving_Bar.(keyword).meanTracesByOrientation = 'exists'; %changed to 'exists' 20221201
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentOrientation'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar.(keyword).meta = editedMeta;
                
                
                %% create analysis figure
                analysisFigure1 = figure();
                c = colororder;
                c = [c;0.4 0.4 0.4]; %add an 8th color to the colororder
                colororder(c);
                title([obj.cellID ' Mean Traces By Direction : ' keyword])
                hold on
                xlabel('time (ms)')
                ylabel('pA')
                labels = {};
                xpoints = linspace(0, totalTime, (totalTime/1000)*sampleRate/downSampleRate);
                for i = 1:size(meanTracesByOrientation.meanTraces, 1)
                    trace_i = meanTracesByOrientation.meanTraces(i, :);
                    plot(xpoints, trace_i)
                    labels = [labels {[ num2str(allOrientations(i)) ' degrees']}];
                end
                lgd = legend(labels);
                lgd.Location = 'best';
            end
            
            
            
            
            %% Intracellular Current Clamp Recordings
            if strcmp(obj.recordingType, 'Current Clamp (K+ Spikes)')
                
                switch obj.recordingType
                    case 'Current Clamp (K+ Spikes)'
                        keyword = 'CurrentClamp_PotassiumSpikes';
                end
                
                
                allOrientations = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %in degrees, 1xN vector of all orientations used
                allOrientations = convertToRetinaAngle_PP(allOrientations, obj.recordingDate); %convert angles based on how projector is flipped
                
                responsesByOrientation = cell(numel(allOrientations), 2); %initialize the Nx2 cell array        
                responsesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)

                epochNumsByOrientation = responsesByOrientation; %initialize Nx2 cell array. This one lists which epochs were which orientations
                restingMembranePotentialByEpoch = zeros(1, numel(obj.epochsSelected)) - 1234.5678; %The trace will be normalized by subtracting off the mean value of the first 1000 points in order to calculate the integral. This number says what that offset is so that you can get back to the original trace by subtracting it from the normalized one.
                
                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth;
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight;
                
                orientationByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %record which epoch had which orientation.
                allSpikeTimes = cell(1, numel(obj.epochsSelected)); %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    

                 %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    %Pull out the recording trace
                    trace = branch_i.epoch;
                    
                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %convert angles based on how projector is flipped
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    tailTime = branch_i.meta.tailTime; %ms
                    totalTime = preTime+stimTime+tailTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    %get resting Vm
                    restingMembranePotential = mean(trace(1:(preTime*sampleRate/1000)));
                    restingMembranePotentialByEpoch(i) = restingMembranePotential;
                    
                    orientationByEpoch(i) = currentOrientation;
                     %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    allSpikeTimes{i} = spikeTimes;

                    %count spikes that happen during the stim
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime));
                    numSpikes = numel(stimSpikeIndx);

                    %append numSpikes to relevant position in
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(responsesByOrientation(:,1)) == currentOrientation);

                    if isempty(indexToUse) %if the current orienatation doesn't exist, add it to the bottom
                        responsesByOrientation{end + 1, 1} = currentOrientation;
                        epochNumsByOrientation{end + 1, 1} = currentOrientation;
                        responsesByOrientation{end, 2} = [];
                        epochNumsByOrientation{end, 2} = [];
                        indexToUse = find(cell2mat(responsesByOrientation(:,1)) == currentOrientation);
                        allOrientations = [allOrientations, currentOrientation];
                        epochNumsByOrientation{indexToUse, 2} = [epochNumsByOrientation{indexToUse, 2}, i];
                    end
                    responsesByOrientation{indexToUse, 2} = [responsesByOrientation{indexToUse, 2}, numSpikes];
                end
                

                %calculate mean and standard deviation spike number for each direction
                meanByOrientation = [];
                stdByOrientation = [];
                for i = 1:numel(allOrientations)
                    meanByOrientation = [meanByOrientation mean(responsesByOrientation{i,2})];
                    stdByOrientation = [stdByOrientation std(responsesByOrientation{i, 2})];
                end

                %calculate mean vector
                allOrientationsRad = deg2rad(allOrientations);
                [x,y] = pol2cart(allOrientationsRad, meanByOrientation);
                xSUM = sum(x);
                ySUM = sum(y);
                [meanTheta, meanRho] = cart2pol(xSUM, ySUM);
                meanTheta = rad2deg(meanTheta);

                %calculate DSI... DSI = length of preferred vector/sum(response in
                %all directions).
                totalSum = sum(meanByOrientation); %sum from all directions
                DSI = meanRho/totalSum; %vector length over sum of all the directions

                %add to processed data struct
                processedDataStruct.Moving_Bar.(keyword).allSpikeTimes = allSpikeTimes; %row vector of spike times for each epoch
                processedDataStruct.Moving_Bar.(keyword).preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar.(keyword).stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Bar.(keyword).tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar.(keyword).sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar.(keyword).barWidth = barWidth;
                processedDataStruct.Moving_Bar.(keyword).barHeight = barHeight;
                processedDataStruct.Moving_Bar.(keyword).barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar.(keyword).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar.(keyword).centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar.(keyword).orientationByEpoch = orientationByEpoch;
                processedDataStruct.Moving_Bar.(keyword).allSpikeTimes = allSpikeTimes;
                processedDataStruct.Moving_Bar.(keyword).EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar.(keyword).Orientation = allOrientations;
                processedDataStruct.Moving_Bar.(keyword).Speed = speed;
                processedDataStruct.Moving_Bar.(keyword).spikesByOrientation = responsesByOrientation;
                processedDataStruct.Moving_Bar.(keyword).mean_spikesByOrientation = meanByOrientation;
                processedDataStruct.Moving_Bar.(keyword).std_spikesByOrientation = stdByOrientation;
                processedDataStruct.Moving_Bar.(keyword).PreferredDirection = meanTheta;
                processedDataStruct.Moving_Bar.(keyword).MeanVectorLength = meanRho;
                processedDataStruct.Moving_Bar.(keyword).DSI = DSI;
                processedDataStruct.Moving_Bar.(keyword).restingMembranePotentialByEpoch = restingMembranePotentialByEpoch;
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentOrientation'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar.(keyword).meta = editedMeta;
                
                meanByOrientationHz = meanByOrientation./(stimTime/1000);
                
                
                %% create analysis figure
                analysisFigure1 = figure();
                polarwitherrorbar(deg2rad(allOrientations), meanByOrientationHz, stdByOrientation./(stimTime/1000));
                hold on
                polarplot([0 deg2rad(meanTheta)],[0 meanRho/(stimTime/1000)], '-k', 'LineWidth', 2);
                title(strcat(obj.cellID, ' Moving Bar Current Clamp Spikes'));
                caption = ['Speed = ' num2str(round(speed, 2))...
                    '; Preferred Angle = ' num2str(round(meanTheta, 1)) '; Vector Length = ' num2str(round(meanRho, 2))...
                    '; DSI = ' num2str(round(DSI, 3))];
                a = annotation('textbox',[0.02 0.06 0 0], 'String',caption,'FitBoxToText','on');
                a.FontSize = 9;
                hold off
            end
            
            
            
                
            if strcmp(obj.recordingType, 'Current Clamp (Cesium)')
                
                switch obj.recordingType
                    case 'Current Clamp (Cesium)'
                        keyword = 'CurrentClamp_Cesium';
                end
                
                
                allOrientations = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %in degrees, 1xN vector of all orientations used
                allOrientations = convertToRetinaAngle_PP(allOrientations, obj.recordingDate); %convert angles based on how projector is flipped
                
                tracesByOrientation = cell(numel(allOrientations), 2); %initialize the Nx2 cell array
                tracesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)
                
                epochNumsByOrientation = tracesByOrientation; %initialize Nx2 cell array. This one lists which epochs were which orientations
                
                %create arrays to hold each parameter epoch by epoch. Also
                %write down the orientation of each epoch.
                integralByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %default is a -1234.5678 --> a number that should probably never occur organically. This way you know if there's a bug
                peakPositiveByEpoch =  zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakPositiveByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                peakNegativeByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                timeToPeak_peakNegativeByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678;
                restingMembranePotentialByEpoch = zeros(1, numel(obj.epochsSelected)) - 1234.5678; %The trace will be normalized by subtracting off the mean value of the first 1000 points in order to calculate the integral. This number says what that offset is so that you can get back to the original trace by subtracting it from the normalized one.
                
                %cell arrays to keep track of data with indeterminate
                %number of peaks
                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth;
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight;
                                
                orientationByEpoch = zeros(1, numel(obj.epochsSelected))-1234.5678; %record which epoch had which orientation.
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    %Pull out the recording trace
                    trace = branch_i.epoch;
                    
                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %convert angles based on how projector is flipped
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    tailTime = branch_i.meta.tailTime; %ms
                    totalTime = preTime+stimTime+tailTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    orientationByEpoch(i) = currentOrientation;
                                        
                    %get offset value for normalized trace
                    restingMembranePotential = mean(trace(1:1000));
                    restingMembranePotentialByEpoch(i) = restingMembranePotential;
                    
                    normalizedTrace = trace - restingMembranePotential;
                    integralByEpoch(i) = trapz(normalizedTrace)/sampleRate;
                    
                    %biggest positive peak and the time it occured
                    [peakPositive, peakPositiveTime] = max(trace);
                    peakPositiveByEpoch(i) = peakPositive;
                    timeToPeak_peakPositiveByEpoch(i) = peakPositiveTime*1000/sampleRate; %convert to ms
                    
                    %biggest negative peak and the time it occured
                    [peakNegative, peakNegativeTime] = min(trace);
                    peakNegativeByEpoch(i) = peakNegative;
                    timeToPeak_peakNegativeByEpoch(i) = peakNegativeTime*1000/sampleRate; %convert to ms              
                    
                    %all positive and negative peaks and
                    %the times they occured
                    [positivePeaks, negativePeaks] = findPeaks(trace, sampleRate); %returns a structure for positive and negative peaks
                    allPositivePeaksByEpoch{i} = positivePeaks;
                    allNegativePeaksByEpoch{i} = negativePeaks;
                    
            
                    %append numSpikes to relevant position in
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(tracesByOrientation(:,1)) == currentOrientation);
                    
                    if isempty(indexToUse) %if the current orienatation doesn't exist, add it to the bottom
                        tracesByOrientation{end + 1, 1} = currentOrientation;
                        epochNumsByOrientation{end + 1, 1} = currentOrientation;
                        tracesByOrientation{end, 2} = [];
                        epochNumsByOrientation{end, 2} = [];
                        indexToUse = find(cell2mat(tracesByOrientation(:,1)) == currentOrientation);
                        allOrientations = [allOrientations, currentOrientation];
                    end
                    
                    tracesByOrientation{indexToUse, 2} = [tracesByOrientation{indexToUse, 2}; trace];
                    epochNumsByOrientation{indexToUse, 2} = [epochNumsByOrientation{indexToUse, 2}, i];
                end
                
                %get mean and std traces for each direction
                downSampleRate = 10;
                probeSpot = tracesByOrientation{indexToUse, 2};
                meanTraces = zeros(size(tracesByOrientation, 1), size(probeSpot, 2));
                stdTraces = zeros(size(tracesByOrientation, 1), size(probeSpot, 2));
                meanTracesByOrientation = struct();
                meanTracesByOrientation.orientationOrder = allOrientations;
                for i = 1:numel(allOrientations)
                    orientation_i = allOrientations(i);
                    for j = 1:size(tracesByOrientation, 1)
                        orientation_j = tracesByOrientation{j, 1};
                        if orientation_i == orientation_j
                            traces_i = tracesByOrientation{j, 2};
                            break
                        end
                    end
                    meanTraces(i, :) = mean(traces_i);
                    stdTraces(i, :) = std(traces_i);
                end
                %a bit of smoothing and downsampling
                smoothedMeanTraces = movmean(meanTraces, downSampleRate, 2);
                smoothedSTDTraces = movmean(stdTraces, downSampleRate, 2);
                meanReduced = smoothedMeanTraces(:, 1:downSampleRate:end);
                stdReduced = smoothedSTDTraces(:, 1:downSampleRate:end);
                
                %save to a structure
                meanTracesByOrientation.meanTraces = meanReduced;
                meanTracesByOrientation.stdTraces = stdReduced;
                meanTracesByOrientation.sampleRate = sampleRate/downSampleRate;
                meanTracesByOrientation.downSampleRate = downSampleRate;
                
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar.(keyword).preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar.(keyword).stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Bar.(keyword).tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar.(keyword).sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar.(keyword).barWidth = barWidth;
                processedDataStruct.Moving_Bar.(keyword).barHeight = barHeight;
                processedDataStruct.Moving_Bar.(keyword).barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar.(keyword).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar.(keyword).centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar.(keyword).orientationByEpoch = orientationByEpoch;
                processedDataStruct.Moving_Bar.(keyword).epochNumsByOrientation = epochNumsByOrientation;
                processedDataStruct.Moving_Bar.(keyword).EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar.(keyword).Orientation = allOrientations;
                processedDataStruct.Moving_Bar.(keyword).Speed = speed;
                processedDataStruct.Moving_Bar.(keyword).IntegralByEpoch = integralByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxPositivePeakByEpoch = peakPositiveByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxPositivePeakByEpoch_timesToPeak = timeToPeak_peakPositiveByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxNegativePeakByEpoch = peakNegativeByEpoch;
                processedDataStruct.Moving_Bar.(keyword).maxNegativePeakByEpoch_timesToPeak = timeToPeak_peakNegativeByEpoch;
                processedDataStruct.Moving_Bar.(keyword).allPositivePeaksByEpoch = allPositivePeaksByEpoch;
                processedDataStruct.Moving_Bar.(keyword).allNegativePeaksByEpoch = allNegativePeaksByEpoch;
                %processedDataStruct.Moving_Bar.(keyword).meanTracesByOrientation = meanTracesByOrientation; 
                processedDataStruct.Moving_Bar.(keyword).meanTracesByOrientation = 'exists';
                processedDataStruct.Moving_Bar.(keyword).restingMembranePotentialByEpoch = restingMembranePotentialByEpoch;
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentOrientation'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar.(keyword).meta = editedMeta;
                
                
                %% create analysis figure
                analysisFigure1 = figure();
                c = colororder;
                c = [c;0.4 0.4 0.4]; %add an 8th color to the colororder
                colororder(c);
                title([obj.cellID ' Mean Traces By Direction : ' keyword])
                hold on
                xlabel('time (ms)')
                ylabel('pA')
                labels = {};
                xpoints = linspace(0, totalTime, (totalTime/1000)*sampleRate/downSampleRate);
                for i = 1:size(meanTracesByOrientation.meanTraces, 1)
                    trace_i = meanTracesByOrientation.meanTraces(i, :);
                    plot(xpoints, trace_i)
                    labels = [labels {[ num2str(allOrientations(i)) ' degrees']}];
                end
                lgd = legend(labels);
                lgd.Location = 'best';
            end
            
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            
            obj.processedData = processedDataStruct;
        end
    end
end