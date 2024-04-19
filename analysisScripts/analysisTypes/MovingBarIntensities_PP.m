classdef MovingBarIntensities_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            %% Analysis for moving bar intensities stim
            processedDataStruct = struct();
            
            firstBranch = obj.data.(obj.cellID).epochs(obj.epochsSelected(1));
            obj.rigInformation = obj.getRigInfo; %from analysis super class methods
            Light_Calibrations = obj.selectLightCalibration('Projector'); %from analysisSuperClass methods

            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')

                %create a Nx2 cell array to hold responses by intensity
                %The first column will hold a single number that
                %corresponds to the intensity
                %The second column will hold a 1xM array that contains the
                %responses at that intenisty. N corresponds to the number of
                %intensities and M corresponds to the number of
                %epochs at each intensity (often 5).
                allIntensities = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barIntensities; %in degrees, 1xN vector of all intensities used
                
                barOrientation = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barOrientation;
                barOrientation = convertToRetinaAngle_PP(barOrientation, obj.recordingDate); %convert angles based on how projector is flipped
                responsesByIntensity = cell(numel(allIntensities), 2); %initialize the Nx2 cell array        
                responsesByIntensity(:, 1) = num2cell(allIntensities');%fill the first column of the cell array with all intensities (in terms of the numbers entered into symphony)

                speed = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.speed; %degrees/second        
                barWidth = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barWidth;
                barHeight = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.barHeight;
                backgroundIntensity = obj.data.(obj.cellID).epochs(obj.epochsSelected(1)).meta.backgroundIntensity;
                
                
                
                processedDataStruct.Moving_Bar_Intensities.Extracellular.allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    

                intensityByEpoch = []; %record which epoch had which intensity.
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %get relevant parameters
                    currentIntensity = branch_i.meta.currentIntensity;%deg
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    intensityByEpoch = [intensityByEpoch, currentIntensity];

                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    processedDataStruct.Moving_Bar_Intensities.Extracellular.allSpikeTimes{i} = spikeTimes;

                    %count spikes that happen during the stim
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime));
                    numSpikes = numel(stimSpikeIndx);

                    %append numSpikes to relevant position in
                    %responsesByIntensity cell array
                    indexToUse = find(cell2mat(responsesByIntensity(:,1)) == currentIntensity);

                    if isempty(indexToUse) %if the current intensity doesn't exist, add it to the bottom
                        responsesByIntensity{end + 1, 1} = currentIntensity;
                        responsesByIntensity{end, 2} = [];
                        indexToUse = find(cell2mat(responsesByIntensity(:,1)) == currentIntensity);
                        allIntensities = [allIntensities, currentIntensity];
                    end

                    responsesByIntensity{indexToUse, 2} = [responsesByIntensity{indexToUse, 2}, numSpikes];
                end

                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.Moving_Bar_Intensities.Extracellular.preTime = preTime; %time before stimulus onset
                processedDataStruct.Moving_Bar_Intensities.Extracellular.stimTime = stimTime; %time of stimulus
                processedDataStruct.Moving_Bar_Intensities.Extracellular.tailTime = branch_i.meta.tailTime; %time after stimulus offset
                processedDataStruct.Moving_Bar_Intensities.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.Moving_Bar_Intensities.Extracellular.barWidth = barWidth;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.barHeight = barHeight;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.allIntensities = allIntensities;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.orientation = barOrientation;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity; %background intensity that occurs during pre and tail time
                processedDataStruct.Moving_Bar_Intensities.Extracellular.centerOffset = branch_i.meta.centerOffset;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.intensityByEpoch = intensityByEpoch;

                %calculate mean and standard deviation spike number for
                %each bar intensity
                meanByIntensity = [];
                stdByIntensity = [];
                for i = 1:numel(allIntensities)
                    meanByIntensity = [meanByIntensity mean(responsesByIntensity{i,2})];
                    stdByIntensity = [stdByIntensity std(responsesByIntensity{i, 2})];
                end

                %add to processed data struct
                processedDataStruct.Moving_Bar_Intensities.Extracellular.EpochNumbers = obj.epochsSelected;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.speed = speed;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.spikesByIntensity = responsesByIntensity;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.mean_spikesByIntensity = meanByIntensity;
                processedDataStruct.Moving_Bar_Intensities.Extracellular.std_spikesByIntensity = stdByIntensity;

                %Cant put in full photoisomerizations conversion yet
                %because I don't have spectrum for the projector:
                %11/19/2021
                lightCalibrations.MeasuredValues_watts = Light_Calibrations;
                lightCalibrations.rigInformation = obj.rigInformation;
                
                processedDataStruct.Moving_Bar_Intensities.Extracellular.lightCalibrations = lightCalibrations;
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','currentIntensity'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.Moving_Bar_Intensities.Extracellular.meta = editedMeta;
                
                
                %% create analysis figure
                analysisFigure1 = figure();
                hold on
                title(strcat(obj.cellID, ' Moving Bar Intensities Extracellular'));
                plot(allIntensities, meanByIntensity, '-o')
                xlabel('Bar Intensity')
                ylabel('Number of Spikes')

                
            end
            
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            
            obj.processedData = processedDataStruct;
        end
    end
end