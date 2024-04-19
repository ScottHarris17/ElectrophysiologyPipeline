classdef MovingGratingSpatialFrequency_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            
            processedDataStruct = struct();

            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')

                %create a Nx2 cell array to hold responses spatial frequency by
                %spatial frequency
                %The first column will hold a single number that corresponds to the
                %spatial frequency. The second column will hold a 1xM array that contains the
                %responses at each spatial frequency. N corresponds to the number of
                %spatial frequencies, and M corresponds to the number of
                %epochs at each spatial frequency (usually 5).
                allSFs = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.spatialFrequency; %in cycles/deg, 1xN vector of all speeds used
                responsesBySF = cell(numel(allSFs), 2); %initialize the Nx2 cell array        
                responsesBySF(:, 1) = num2cell(allSFs');%fill the first column of the cell array with all spatial frequencies (cycles/degree)

                orientation = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.orientation; %degrees
                orientation = convertToRetinaAngle_PP(orientation, obj.recordingDate); %convert angles based on how projector is flipped
                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed;%degrees/s

                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    

                spatialFrequencyByEpoch = [];

                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentSF = branch_i.meta.currentSpatialFrequency;%deg/s
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    spatialFrequencyByEpoch = [spatialFrequencyByEpoch, currentSF];

                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.allSpikeTimes{i} = spikeTimes;


                    %count spikes that happen during the stim
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime));
                    numSpikes = numel(stimSpikeIndx);

                    %append numSpikes to relevant position in
                    %responsesByOrientation cell array
                    indexToUse = find(cell2mat(responsesBySF(:,1)) == currentSF);

                    if isempty(indexToUse) %if the current SF doesn't exist, add it to the bottom
                        responsesBySF{end + 1, 1} = currentSF;
                        responsesBySF{end, 2} = [];
                        indexToUse = find(cell2mat(responsesBySF(:,1)) == currentSF);
                        allSFs = [allSFs, currentSF];
                    end

                    responsesBySF{indexToUse, 2} = [responsesBySF{indexToUse, 2}, numSpikes];
                end

                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.meanIntensity = branch_i.meta.meanIntensity; %mean intensity of the grating
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.amplitude = branch_i.meta.amplitude; %amplitude of the grating (normalized by maximum possible based on meanIntensity)
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.spatialFrequencyByEpoch = spatialFrequencyByEpoch;

                %% calculate mean and standard deviation spike number for each speed
                meanBySF = [];
                stdBySF= [];
                for i = 1:numel(allSFs)
                    meanBySF= [meanBySF mean(responsesBySF{i,2})];
                    stdBySF= [stdBySF std(responsesBySF{i, 2})];
                end


                %add to processed data struct
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.SpatialFrequency = allSFs;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.Orientation = orientation;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.Speed = speed;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.spikesBySpatialFrequency = responsesBySF;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.mean_spikesBySpatialFrequency = meanBySF;
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.std_spikesBySpatialFrequency = stdBySF;

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentSpatialFrequency'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Grating_SpatialFrequency.Extracellular.meta = editedMeta;

                %% Build analysis figure
                X = allSFs;
                Y = meanBySF;
                errorTop = Y + stdBySF;
                errorBottom = Y - stdBySF;

                analysisFigure1 = figure();
                bar(X, Y)
                hold on
                erPlot = errorbar(X, Y, errorBottom, errorTop);
                erPlot.LineStyle = 'none';
                title(strcat(obj.cellID, 'Moving Grating Spatial Frequency'));
                xlabel('spatial frequency (cycles/s)')
                ylabel('Mean Response (# spikes)');
                caption = ['Orientation = ' num2str(orientation) '; Speed = ' num2str(round(speed, 2))];
                a = annotation('textbox',[0.5 0.65 0 0], 'String',caption,'FitBoxToText','on');
                a.FontSize = 9;
                hold off
            end
            
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            
            obj.processedData = processedDataStruct;
        end
        
    end
end