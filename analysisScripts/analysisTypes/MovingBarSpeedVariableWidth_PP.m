classdef MovingBarSpeedVariableWidth_PP < analysisSuperClass_PP
    %MOVINGBARSPEEDVARIABLESWIDTH_OKR_PHYSIOLOGY moving bar that changes
    %speed and width on every epoch.
    % - this is the most complex stimulus yet. Parameters that can vary on
    % each epoch are: bar speed, bar width, bar direction, and stim time.
    % The bar width is a function of bar speed, such that barWidth/barSpeed
    % is equal to a constant dwell time. Stim time also changes as a
    % function of bar speed (faster bars = shorter stim time). Bar
    % direction is arbitrarily long. Every combination of bar speeds and
    % directions are generated during the stimulus presentation.
    
    properties
    end
    
    methods
        function obj = analysis(obj)            
            %% Analysis for moving bar variable stim time
            processedDataStruct = struct();
            
            %There are an arbitrary number of speeds
            allSpeeds = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %in degrees/s, 1xN vector of all speeds used
            allOrientations_uncorrected = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %stimulus directions in degrees
            allOrientations = convertToRetinaAngle_PP(allOrientations_uncorrected, obj.recordingDate);
            
            sortedOrientations = sort(allOrientations);
            sortedSpeeds = sort(allSpeeds);
           
            %The first thing to do is simply make a list of all the
            %possible speed and direction combinations. This is just
            %for reference and isn't actually used for much, but it is
            %good to document:
            
            %Generate an 2xN matrix, the first row of which is the stimulus
            %direction, and the second row of which is the stimulus speed. Each
            %possible combination is listed once.
            speedAndOrientationCombos = zeros(2, numel(allSpeeds)*numel(allOrientations));
            count = 0;
            for i = 1:numel(sortedOrientations)
                for j = 1:numel(sortedSpeeds)
                    count = count +1;
                    speedAndOrientationCombos(1, count) = sortedOrientations(i);
                    speedAndOrientationCombos(2, count) = sortedSpeeds(j);
                end
            end
                
            %a bit more work before entering the main loop:
            barWidthAtSP10 = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidthAtSP10; %um - width of the bar when the speed is 10. This defines the dwell time.
            barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight; %um
            dwellTime = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.dwellTime; %s - the dwell time is the amount of time that the bar spends over an infinitely small point in space. This is constant across speeds and determines the bar width on each epoch.
            
            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')
               
                %save properties that don't change on each epoch
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.speeds = sortedSpeeds;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.orientations = sortedOrientations;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.barWidthAtSP10 = barWidthAtSP10;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.barHeight = barHeight;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.dwellTime = dwellTime;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.speedAndOrientationCombos = speedAndOrientationCombos;
                
                allSpikeTimes = cell(1, numel(obj.epochsSelected)); %will be filled with arrays containing time stamps of spike times on each epoch.
                numSpikesDuringStimTime = zeros(1, numel(obj.epochsSelected)); %total number of spikes during the stim time on each epoch
                stimTimeByEpoch = zeros(1, numel(obj.epochsSelected)); %initialize to save stim time for each epoch
                speedByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which speed.
                orientationByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which speed.
                barWidthByEpoch_deg = zeros(1, numel(obj.epochsSelected)); %width of the bar on each epoch in degrees
                maxFiringRateByEpoch = zeros(1, numel(obj.epochsSelected)); %maximum firing rate on each epoch
                comboIndexByEpoch = zeros(1, numel(obj.epochsSelected)); %tells you which index of speedAndOrientation combo each epoch matches
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentSpeed = branch_i.meta.currentSpeed;%deg
                    currentOrientation = convertToRetinaAngle_PP(branch_i.meta.currentOrientation, obj.recordingDate);
                    
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.currentStimTime; %ms - this changes with the currentSpeed
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    stimTimeByEpoch(i) = stimTime;
                    speedByEpoch(i) = currentSpeed;
                    orientationByEpoch(i) = currentOrientation;
                    barWidthByEpoch_deg(i) = branch_i.meta.currentBarWidthDeg;
                    found = 0;
                    for j = 1:size(speedAndOrientationCombos, 2)
                        if isequal(speedAndOrientationCombos(:, j), [currentOrientation; currentSpeed])
                            found = 1;
                            break
                        end
                    end
                    if found
                        comboIndexByEpoch(i) = j;
                    else
                        warning(['Something went wrong! There was an unexpected speed and direction combination on epoch number ' num2str(i)])
                    end
                    
                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    allSpikeTimes{i} = spikeTimes;
                    
                    relevantSpikeTimes = spikeTimes(spikeTimes>preTime & spikeTimes < (preTime + stimTime));
                    numSpikesDuringStimTime(i) = numel(relevantSpikeTimes);
                    maxFiringRateByEpoch(i) = obj.maxFiringRate(relevantSpikeTimes); %hz
                end
                
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.stimTimeByEpoch = stimTimeByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.speedByEpoch = speedByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.orientationByEpoch = orientationByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.barWidthByEpoch = barWidthByEpoch_deg;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.speedAndOrientationComboIndexByEpoch = comboIndexByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.allSpikeTimes = allSpikeTimes;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.numSpikesDuringStimTime = numSpikesDuringStimTime;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.maxFiringRateByEpoch = maxFiringRateByEpoch;
                
                %alphabetize the structure:
                processedDataStruct = orderfields(processedDataStruct);
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentSpeed', 'currentOrientation', 'currentStimTime', 'currentBarWidthDeg', 'currentBarWidthMicrons'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.meta = editedMeta;
                
                %% Build analysis figure
                
                %the figure will contain speed tuning curves. One line per
                %stimulus directon
                mean_ResponseByCombo = zeros(1, size(speedAndOrientationCombos,2));
                SEM_ResponseByCombo = zeros(1, size(speedAndOrientationCombos,2));
                colorMat = [1 0 0; 0 0 1; 1 0 1; 1 1 0; 0 1 1; 0 1 0; 0.5 1 0.5; 1 0.5 0.5];
               
                analysisFigure1 = figure();
                title(strcat(obj.cellID, ' Moving Bar Speed (VBW)'));
                hold on
                lgndStrings = cell(1, numel(sortedOrientations));
                for i = 1:numel(sortedOrientations)
                    currentOrientation = sortedOrientations(i);
                    lgndStrings{i} = num2str(currentOrientation);
                    meanResponses_i = zeros(1, numel(sortedSpeeds));
                    SEMResponses_i = zeros(1, numel(sortedSpeeds));
                    for j = 1:numel(sortedSpeeds)
                        currentSpeed = sortedSpeeds(j);
                        relevantIndices = (orientationByEpoch == currentOrientation...
                            & speedByEpoch == currentSpeed);
                        totalSpikes = numSpikesDuringStimTime(relevantIndices);
                        meanResponses_i(j) = mean(totalSpikes);
                        SEMResponses_i(j) = std(totalSpikes)/sqrt(numel(totalSpikes));
                        %fill out the combo matrix because will want to
                        %save this
                        for n = 1:size(speedAndOrientationCombos, 2)
                            if isequal(speedAndOrientationCombos(:, n), [currentOrientation; currentSpeed])
                                mean_ResponseByCombo(n) = meanResponses_i(j);
                                SEM_ResponseByCombo(n) = SEMResponses_i(j);                
                                break
                            end
                        end
                    end
                    %plot the line for this orientation
                    shadedErrorBar(sortedSpeeds, meanResponses_i, SEMResponses_i, 'lineprops', {'color', colorMat(i, :), 'linewidth', 3})
                end
                xlabel('stimulus speed (deg/s)')
                ylabel('number of spikes')
                legend(lgndStrings, 'Location', 'best')
                hold off
                
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.mean_ResponseByComboIndex = mean_ResponseByCombo;
                processedDataStruct.Moving_Bar_Speed_VarWidth.Extracellular.SEM_ResponseByComboIndex = SEM_ResponseByCombo;    
            
                
                
            %% Voltage clamp analysis:
            elseif strcmp(obj.recordingType, 'Excitation (Intracellular)') ||...
                    strcmp(obj.recordingType, 'Inhibition (Intracellular)')
                
                switch obj.recordingType
                    case 'Excitation (Intracellular)'
                        keyword = 'Intracellular_Excitation';
                    case 'Inhibition (Intracellular)'
                        keyword = 'Intracellular_Inhibition';
                end
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).speeds = sortedSpeeds;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).orientations = sortedOrientations;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).barWidthAtSP10 = barWidthAtSP10;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).barHeight = barHeight;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).dwellTime = dwellTime;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).speedAndOrientationCombos = speedAndOrientationCombos;
                
                
                %Initialize data holders
                peakPositiveCurrentByEpoch = zeros(1, numel(obj.epochsSelected));
                peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected));
                timeToPeak_peakPositiveCurrentByEpoch = zeros(1, numel(obj.epochsSelected));
                timeToPeak_peakNegativeCurrentByEpoch = zeros(1, numel(obj.epochsSelected));
                integralByEpoch = zeros(1, numel(obj.epochsSelected));
                holdingCurrentByEpoch = zeros(1, numel(obj.epochsSelected));
                allPositivePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the inward peaks values for each epoch
                allNegativePeaksByEpoch = cell(numel(obj.epochsSelected), 1); %timepoint (ms) and magnitude of all the outward peaks for each epoch
                
                %initialize stimulus info holders
                stimTimeByEpoch = zeros(1, numel(obj.epochsSelected)); %initialize to save stim time for each epoch
                speedByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which speed.
                orientationByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which speed.
                barWidthByEpoch_deg = zeros(1, numel(obj.epochsSelected)); %width of the bar on each epoch in degrees
                comboIndexByEpoch = zeros(1, numel(obj.epochsSelected)); %tells you which index of speedAndOrientation combo each epoch matches
               
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentSpeed = branch_i.meta.currentSpeed;%deg
                    currentOrientation = convertToRetinaAngle_PP(branch_i.meta.currentOrientation, obj.recordingDate);
                    
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.currentStimTime; %ms - this changes with the currentSpeed
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                    
                    stimTimeByEpoch(i) = stimTime;
                    speedByEpoch(i) = currentSpeed;
                    orientationByEpoch(i) = currentOrientation;
                    barWidthByEpoch_deg(i) = branch_i.meta.currentBarWidthDeg;
                    found = 0;
                    for j = 1:size(speedAndOrientationCombos, 2)
                        if isequal(speedAndOrientationCombos(:, j), [currentOrientation; currentSpeed])
                            found = 1;
                            break
                        end
                    end
                    if found
                        comboIndexByEpoch(i) = j;
                    else
                        warning(['Something went wrong! There was an unexpected speed and direction combination on epoch number ' num2str(i)])
                    end
                    
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
                end
                %fill in data
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).stimTimeByEpoch = stimTimeByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).barIntensity = branch_i.meta.barIntensity; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).speedByEpoch = speedByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).orientationByEpoch = orientationByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).barWidthByEpoch = barWidthByEpoch_deg;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).speedAndOrientationComboIndexByEpoch = comboIndexByEpoch;
                
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).maxPositivePeakByEpoch = peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).maxNegativePeakByEpoch = peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).maxPositivePeakByEpoch_timesToPeak = timeToPeak_peakPositiveCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).maxNegativePeakByEpoch_timesToPeak = timeToPeak_peakNegativeCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).TotalChargeByEpoch = integralByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).holdingCurrentByEpoch = holdingCurrentByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).allPositivePeaksByEpoch = allPositivePeaksByEpoch;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).allNegativePeaksByEpoch = allNegativePeaksByEpoch;
               
                %alphabetize the structure:
                processedDataStruct = orderfields(processedDataStruct);
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentSpeed', 'currentOrientation', 'currentStimTime', 'currentBarWidthDeg', 'currentBarWidthMicrons'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).meta = editedMeta;
                
                %% Build analysis figure
                
                %the figure will contain speed tuning curves. One line per
                %stimulus directon. One plot for peak, one plot for charge.
                mean_PeakByCombo = zeros(1, size(speedAndOrientationCombos,2));
                SEM_PeakByCombo = zeros(1, size(speedAndOrientationCombos,2));
                mean_ChargeByCombo = zeros(1, size(speedAndOrientationCombos,2));
                SEM_ChargeByCombo = zeros(1, size(speedAndOrientationCombos,2));
                colorMat = [1 0 0; 0 0 1; 1 0 1; 1 1 0; 0 1 1; 0 1 0; 0.5 1 0.5; 1 0.5 0.5];
                
                analysisFigure1 = figure();
                title(strcat(obj.cellID, ' Moving Bar Speed (VBW) - ', keyword));
                hold on
                lgndStrings = cell(1, numel(sortedOrientations));
                for i = 1:numel(sortedOrientations)
                    currentOrientation = sortedOrientations(i);
                    lgndStrings{i} = num2str(currentOrientation);
                    meanPeak_i = zeros(1, numel(sortedSpeeds));
                    SEMPeak_i = zeros(1, numel(sortedSpeeds));
                    meanCharge_i = zeros(1, numel(sortedSpeeds));
                    SEMCharge_i = zeros(1, numel(sortedSpeeds));
                    for j = 1:numel(sortedSpeeds)
                        currentSpeed = sortedSpeeds(j);
                        relevantIndices = (orientationByEpoch == currentOrientation...
                            & speedByEpoch == currentSpeed);
                       
                        switch keyword
                           case 'Intracellular_Inhibition'
                               peaks = peakPositiveCurrentByEpoch(relevantIndices);
                               charges = integralByEpoch(relevantIndices);
                           case 'Intracellular_Excitation'
                               peaks = -peakNegativeCurrentByEpoch(relevantIndices);
                               charges = -integralByEpoch(relevantIndices);
                       end
                       
                        meanPeak_i(j) = mean(peaks);
                        SEMPeak_i(j) = std(peaks)/sqrt(numel(peaks));
                        meanCharge_i(j) = mean(charges);
                        SEMCharge_i(j) = std(charges)/sqrt(numel(charges));
                        %fill out the combo matrix because will want to
                        %save this
                        for n = 1:size(speedAndOrientationCombos, 2)
                            if isequal(speedAndOrientationCombos(:, n), [currentOrientation; currentSpeed])
                                mean_PeakByCombo(n) = meanPeak_i(j); %positive vs negative changes for excitation and inhibition
                                SEM_PeakByCombo(n) = SEMPeak_i(j);
                                mean_ChargeByCombo(n) = meanCharge_i(j);
                                SEM_ChargeByCombo(n) = SEMCharge_i(j);
                                break
                            end
                        end
                    end
                    %plot the line for this orientation
                    subplot(2, 1, 1)
                    shadedErrorBar(sortedSpeeds, meanPeak_i, SEMPeak_i, 'lineprops', {'color', colorMat(i, :), 'linewidth', 3})
                    subplot(2, 1, 2)
                    shadedErrorBar(sortedSpeeds, meanCharge_i, SEMCharge_i, 'lineprops', {'color', colorMat(i, :), 'linewidth', 3})

                end
                subplot(2, 1, 1)
                title('Peak Current')
                xlabel('stimulus speed (deg/s)')
                ylabel('|pA|')
                ylim([0 inf])
                legend(lgndStrings, 'Location', 'best')

                subplot(2, 1, 2)
                title('Total Charge')
                xlabel('stimulus speed (deg/s)')
                ylabel('|pC|')
                ylim([0 inf])
                legend(lgndStrings, 'Location', 'best')
                hold off
                
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).mean_PeakByComboIndex = mean_PeakByCombo;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).SEM_PeakByComboIndex = SEM_PeakByCombo;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).mean_ChargeByComboIndex = mean_ChargeByCombo;
                processedDataStruct.Moving_Bar_Speed_VarWidth.(keyword).SEM_ChargeByComboIndex = SEM_ChargeByCombo;
            end
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            obj.processedData = processedDataStruct;
        end
        
    end
end
