classdef MovingGratingDirection_PP < analysisSuperClass_PP
    
    properties %properties inherited from super class
    end
        
    methods
              
        
        function obj = analysis(obj)
            %contains both extracellular and intracellular moving grating
            %direction analyses
            
            processedDataStruct = struct();
            speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second
            spatialFrequency = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.spatialFrequency;%degrees/cycle
            temporalFrequency = speed*spatialFrequency;
            allOrientations = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %in degrees, 1xN vector of all orientations used
            allOrientations = sort(convertToRetinaAngle_PP(allOrientations, obj.recordingDate)); %convert angles based on how projector is flipped
            phaseOffsets = zeros(1, numel(obj.epochsSelected));
            
            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')

                keyW = 'Extracellular';
                %create a Nx2 cell array to hold responses oreintation by orientation
                %The first column will hold a single integer that corresponds to the orientation
                %The second column will hold a 1xM array that contains the
                %responses at that oreintation. N corresponds to the number of
                %orientations (usually 8), and M corresponds to the number of
                %epochs at each orientation (often 5).
                responsesByOrientation = cell(numel(allOrientations), 2); %initialize the Nx2 cell array        
                responsesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)

                allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    

                orientationByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which orientation.
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %Convert to retinal coordinates because projector often flips image 

                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    orientationByEpoch(i) = currentOrientation;

                    try phaseOffsets(i) = branch_i.meta.randomPhaseOffset;catch; phaseOffsets(i) = 0;end

                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);            
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    allSpikeTimes{i} = spikeTimes;

                    %count spikes that happen during the stim
                    stimSpikeIndx = find(spikeTimes > preTime & spikeTimes < (preTime + stimTime));
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


                %% Directional Analysis
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
                DSI = meanRho/sum(meanByOrientation);

                %add to processed data struct
                processedDataStruct.Moving_Grating_Direction.(keyW).spikesByOrientation = responsesByOrientation;
                processedDataStruct.Moving_Grating_Direction.(keyW).mean_spikesByOrientation = meanByOrientation;
                processedDataStruct.Moving_Grating_Direction.(keyW).std_spikesByOrientation = stdByOrientation;
                processedDataStruct.Moving_Grating_Direction.(keyW).allSpikeTimes = allSpikeTimes; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    


                %% PSTH over all trials, but create a separate one for each direction. Also adjust for phase offsets
                binSize = 25; %in ms
                prePSTHs = []; stimPSTHs = []; %save psth data here

                analysisFigure3 = figure('Position', [300, 100, 1000, 600]);
                sgtitle(['MG Direction, SF = ' num2str(spatialFrequency), ' SP = ' num2str(speed), ' Bin Size = ' num2str(binSize), 'ms'])
                for i = 1:numel(allOrientations)
                    orientation_i = allOrientations(i);
                    epochIndices_i = find(orientationByEpoch == orientation_i);
                    spikeTimes_i = cell(numel(epochIndices_i),2); %column 1 is baseline spikes, column 2 is stim spikes
                    for j = 1:numel(epochIndices_i)
                        spikeTimes = processedDataStruct.Moving_Grating_Direction.(keyW).allSpikeTimes{epochIndices_i(j)};
                        %in total you'll trim off 1 cycle's worth of time (i.e.
                        %1/tf). Trim off the random offset from the front of the
                        %stim spikes, and trim off the rest from the tail end.
                        phaseOffset_j = phaseOffsets(epochIndices_i(j)); %in degrees
                        timeLag = 1000*phaseOffset_j/(temporalFrequency*360); %in ms
                        baselineSpikes = spikeTimes(spikeTimes < preTime); %just the baseline spikes
                        stimSpikes = spikeTimes((spikeTimes > preTime) & (spikeTimes < preTime + stimTime)); %just spikes that happened during the stim    
                        stimSpikes = stimSpikes - timeLag; %shift leftwards based on the timeLag
                        stimSpikes = stimSpikes(stimSpikes > preTime); %Trim off excess to align the left side
                        stimSpikes = stimSpikes(stimSpikes < preTime+stimTime - 1000/temporalFrequency); %trim off remainder from the back end such that 1/tf total amount of time has been taken off the epoch
                        spikeTimes_i{j, 1} = baselineSpikes; %save spike times to a cell array that will hold data for every epoch that has the current orientation
                        spikeTimes_i{j, 2} = stimSpikes;
                    end

                    %use buildPSTH helper function (written below within this .m
                    %file) to generate PSTH
                    psthPre = obj.buildPSTH(spikeTimes_i(:, 1), binSize, 0, preTime); %calls buildPSTH helper function with spike times and binsize
                    psthStim = obj.buildPSTH(spikeTimes_i(:, 2), binSize, preTime, preTime + stimTime - 1000/temporalFrequency); %calls buildPSTH helper function with spiketimes and binsize

                    prePSTHs = [prePSTHs; psthPre];
                    stimPSTHs = [stimPSTHs; psthStim];        
                end

                maxPSTH_val = max(max(max(prePSTHs)), max(max(stimPSTHs)));
                if maxPSTH_val == 0; maxPSTH_val = 0.1; end
                for i = 1:numel(allOrientations)
                    orientation_i = allOrientations(i);
                    fullPSTH = [prePSTHs(i, :), stimPSTHs(i, :)];

                    subplot(2, ceil(numel(allOrientations)/2), i);
                    title(['PSTH - Orientation = ' num2str(orientation_i)])
                    hold on
                    bar(0:binSize:(numel(fullPSTH)-1)*binSize, fullPSTH, 'k')
                    box off
                    xlabel('time (ms)')
                    ylabel('spikes')
                    plot([preTime, preTime], [0, maxPSTH_val], '-r')
                    ylim([0, maxPSTH_val])
                    hold off
                end

                analysisFigure2 = figure('Position', [500, 300, 1000, 600]);
                sgtitle(['MG Direction, SF = ' num2str(spatialFrequency), ' SP = ' num2str(speed), ' Bin Size = ' num2str(binSize), 'ms'])
                for i = 1:numel(allOrientations)
                    orientation_i = allOrientations(i);
                    [preFreqs, prePower] = obj.buildPowerSpectrum(prePSTHs(i,:), preTime/1000, binSize/1000);
                    [stimFreqs, stimPower] = obj.buildPowerSpectrum(stimPSTHs(i,:), (stimTime-1000/temporalFrequency)/1000, binSize/1000);

                    subplot(4, ceil(numel(allOrientations)/2), i*2-1)
                    title(['Baseline, Orientation = ', num2str(orientation_i)])
                    hold on
                    plot(preFreqs, prePower)
                    xlim([0 max(preFreqs)]) 
                    xlabel('Frequency (Hz)');
                    ylabel('Power')
                    hold off

                    subplot(4, ceil(numel(allOrientations)/2), i*2)
                    title(['Stimulus, Orientation = ', num2str(orientation_i)])
                    hold on
                    plot(stimFreqs, stimPower) 
                    xlim([0 max(stimFreqs)]) 
                    xlabel('Frequency (Hz)');
                    ylabel('Power')
                    hold off
                end


        %#########################################################################
            elseif strcmp(obj.recordingType, 'Excitation (Intracellular)') ||...
                    strcmp(obj.recordingType, 'Inhibition (Intracellular)')

                %fill response by orientation with the following: column 1 =
                %integer value of each orientation. column 2 = max peak. column 3 =
                %tpeak, column 4 = total charge, column 5 = frequencies, column 6 =
                %power
                responsesByOrientation = cell(numel(allOrientations), 7); %initialize the Nx5 cell array        
                responsesByOrientation(:, 1) = num2cell(allOrientations');%fill the first column of the cell array with all orientations (in degrees)

                orientationByEpoch = zeros(1, numel(obj.epochsSelected)); %record which epoch had which orientation.
                alignedTraces = cell(numel(allOrientations), 1);
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentOrientation = branch_i.meta.currentOrientation;%deg
                    currentOrientation = convertToRetinaAngle_PP(currentOrientation, obj.recordingDate); %Convert to retinal coordinates because projector often flips image 

                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    orientationByEpoch(i) = currentOrientation;


                    baselineTrace = trace(1:(preTime/1000)*sampleRate);
                    trace = trace - mean(baselineTrace); %subtract out offset

                    %lowpass filter
                    lowpassCutoff = 60; %in hz, cutoff for lowpass filter
                    filteredTrace = lowpass(trace, lowpassCutoff, sampleRate);

                    stimTraceFiltered = filteredTrace((preTime/1000)*sampleRate:((preTime+stimTime)/1000)*sampleRate);
                    inwardpeak = abs(min(stimTraceFiltered)); %maximum inward current
                    outwardpeak = abs(max(stimTraceFiltered));%maximum outward current
                    [frequencies, power] = obj.buildPowerSpectrum(stimTraceFiltered, stimTime/1000, 1/sampleRate);



                    %use abbreviated and aligned traces for total charge
                    try phaseOffsets(i) = branch_i.meta.randomPhaseOffset;catch; phaseOffsets(i) = 0;end
                    timeLag = 1000*phaseOffsets(i)/(temporalFrequency*360); %in ms

                    stimTraceUnfiltered = trace((preTime/1000)*sampleRate:((preTime+stimTime)/1000)*sampleRate);
                    alignedTrace = stimTraceUnfiltered(floor((timeLag/1000)*sampleRate+1):end-sampleRate*(temporalFrequency-timeLag/1000));
                    alignedFiltered = lowpass(alignedTrace, lowpassCutoff, sampleRate);
                    totalCharge = -trapz(alignedFiltered);

                    toAdd = {inwardpeak, outwardpeak, totalCharge, {frequencies}, {power}};

                    indexToUse = find(cell2mat(responsesByOrientation(:,1)) == currentOrientation);
                    for j = 1:numel(toAdd)
                        responsesByOrientation{indexToUse, j+1} = [responsesByOrientation{indexToUse, j+1}, toAdd{j}];
                    end
                    alignedTraces{indexToUse, 1} = [alignedTraces{indexToUse, 1}; alignedFiltered];
                end

                if strcmp(obj.recordingType, 'Excitation (Intracellular)')
                    keyW = 'Intracellular_Excitation';
                    peakNum = 1;
                elseif strcmp(obj.recordingType, 'Inhibition (Intracellular)')
                    keyW = 'Intracellular_Inhibition';
                    peakNum = 2;
                else
                    keyW = 'Intracellular';
                    peakNum = 1;
                end


                %% build polar plot based on max peaks in each direction
                meanByOrientation = [];
                stdByOrientation = [];
                for i = 1:numel(allOrientations)
        %            meanByOrientation = [meanByOrientation mean(responsesByOrientation{i,peakNum+1})];
        %            stdByOrientation = [stdByOrientation std(responsesByOrientation{i, peakNum+1})];
                    meanByOrientation = [meanByOrientation abs(mean(responsesByOrientation{i,4}))]; %based on absolute value of total charge
                    stdByOrientation = [stdByOrientation std(responsesByOrientation{i, 4})]; %based on total charge
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
                DSI = meanRho/sum(meanByOrientation);

                %% Mean Power Spectra
                freqs = responsesByOrientation{1, 5}{1}; %frequencies should be the same for all epochs
                meanPowers = cell(numel(allOrientations), 1);
                analysisFigure2 = figure('Position', [300, 400, 800, 500]);
                sgtitle(['MG Direction - Mean Spectra - SP=' num2str(speed), ' SF=' num2str(spatialFrequency) ' ' obj.recordingType]);
                for i = 1:numel(allOrientations)
                     power_i = responsesByOrientation{i, 6};
                     holdPowers = zeros(numel(power_i), numel(freqs));
                     for j = 1:numel(power_i)
                         holdPowers(j, :) = power_i{j};
                     end
                     meanPowers{i} = mean(holdPowers);
                     subplot(2, ceil(numel(allOrientations)/2), i)
                     plot(freqs, mean(holdPowers))
                     title(num2str(allOrientations(i)))
                     xlabel('Frequency (hz)'); ylabel('Power');
                     xlim([0, 10])
                end

                %save intracellular specific parameters
                processedDataStruct.Moving_Grating_Direction.(keyW).inwardPeakByOrientation = {responsesByOrientation{:, 2}};
                processedDataStruct.Moving_Grating_Direction.(keyW).outwardPeakByOrientation = {responsesByOrientation{:, 3}};
                processedDataStruct.Moving_Grating_Direction.(keyW).totalChargeByOrientation = {responsesByOrientation{:, 4}};
                processedDataStruct.Moving_Grating_Direction.(keyW).powerSpectrumFrequencies = freqs;
                processedDataStruct.Moving_Grating_Direction.(keyW).powerSpectrumMeanPowers = meanPowers;
                processedDataStruct.Moving_Grating_Direction.(keyW).lowpassCuttoff = lowpassCutoff;
            end

            %save common parameters
            processedDataStruct.Moving_Grating_Direction.(keyW).EpochNumbers = obj.epochsSelected;
            processedDataStruct.Moving_Grating_Direction.(keyW).preTime = preTime; %time before stimulus onset
            processedDataStruct.Moving_Grating_Direction.(keyW).stimTime = stimTime; %time of stimulus
            processedDataStruct.Moving_Grating_Direction.(keyW).tailTime = branch_i.meta.tailTime; %time after stimulus offset
            processedDataStruct.Moving_Grating_Direction.(keyW).sampleRate = sampleRate; %observations per second
            processedDataStruct.Moving_Grating_Direction.(keyW).meanIntensity = branch_i.meta.meanIntensity; %mean intensity of the grating
            processedDataStruct.Moving_Grating_Direction.(keyW).amplitude = branch_i.meta.amplitude; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
            processedDataStruct.Moving_Grating_Direction.(keyW).backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
            processedDataStruct.Moving_Grating_Direction.(keyW).orientationByEpoch = orientationByEpoch;
            processedDataStruct.Moving_Grating_Direction.(keyW).Orientation = allOrientations;
            processedDataStruct.Moving_Grating_Direction.(keyW).Speed = speed;
            processedDataStruct.Moving_Grating_Direction.(keyW).SpatialFrequency = spatialFrequency;   
            processedDataStruct.Moving_Grating_Direction.(keyW).DSI = DSI;
            processedDataStruct.Moving_Grating_Direction.(keyW).PreferredDirection = meanTheta;
            processedDataStruct.Moving_Grating_Direction.(keyW).MeanVectorLength = meanRho;

            %add metadata from last epoch to the structure, but remove
            %irrelivent fields.
            irreliventFields = {'bathTemperature', 'epochNum','currentOrientation'};
            metaToAdd = branch_i.meta;
            editedMeta = rmfield(metaToAdd, irreliventFields);
            processedDataStruct.Moving_Grating_Direction.(keyW).meta = editedMeta;

            %% create analysis figure (same for all recording types)
            analysisFigure1 = figure();
            polarwitherrorbar(deg2rad(allOrientations), meanByOrientation, stdByOrientation);
            hold on
            polarplot([0 deg2rad(meanTheta)],[0 meanRho], '-k', 'LineWidth', 2);
            title(strcat(obj.cellID, '-MG Direction-', obj.recordingType));
            caption = ['Speed = ' num2str(round(speed, 2)) '; Spatial Frequency = ' num2str(round(spatialFrequency, 2))...
                '; Preferred Angle = ' num2str(round(meanTheta, 1)) '; Vector Length = ' num2str(round(meanRho, 2))...
                '; DSI = ' num2str(round(DSI, 3))];
            a = annotation('textbox',[0.02 0.06 0 0], 'String', caption,'FitBoxToText','on');
            a.FontSize = 9;
            hold off
            
            obj.analysisFigures(1:2) = [analysisFigure1, analysisFigure2];
            obj.analysisFigureExtensions{1} = ''; 
            obj.analysisFigureExtensions{2} = '_spectra';
            
            if exist('analysisFigure3')
                obj.analysisFigures(3) = analysisFigure3;
                obj.analysisFigureExtensions{3} = '_psth';
            end
           

            obj.processedData = processedDataStruct;
         end




    end
end