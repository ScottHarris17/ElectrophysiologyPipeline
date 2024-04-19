classdef OscillatingGrating_PP < analysisSuperClass_PP
    %OscillatingGrating_OKR_PHYSIOLOGY grating that oscllates sinusoidally
    
    properties
    end
    
    methods
        function obj = analysis(obj)            
            %% Analysis for oscillating grating
            processedDataStruct = struct();
      
            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')
               
                %get epoch numbers
                processedDataStruct.OscillatingGrating.Extracellular.EpochNumbers = obj.epochsSelected;
                allSpikeTimes = cell(1, numel(obj.epochsSelected)); %will be filled with arrays containing time stamps of spike times on each epoch.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    %Pull out the recording trace
                    trace = branch_i.epoch;       
                    sampleRate = branch_i.meta.sampleRate; %observations per second
                   
                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);                     
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;

                    allSpikeTimes{i} = spikeTimes;     
                end
                %basic properties about the oscillation
                period = branch_i.meta.motionPeriod; %seconds
                period_ms = period*1000; %ms
                numCycles = branch_i.meta.numCyclesPerEpoch;
                stimLength = period_ms*numCycles; %ms
                cycleStartTimes = 0:period_ms:stimLength-period_ms; %ms - time at which the oscillation cycle restarts
                
                amplitude = branch_i.meta.motionAmplitude; %deg
                phaseShift = branch_i.meta.motionPhaseShift; %deg
                try
                    spatialShift = branch_i.meta.gratingPhase; %deg
                catch
                    disp('No spatial shift parameter, setting to 0')
                    spatialShift = 0;
                end
                %fill these fields once... they'll take the value from the last
                %epoch but really it should be the same across epochs
                processedDataStruct.OscillatingGrating.Extracellular.sampleRate = sampleRate; %observations per second
                processedDataStruct.OscillatingGrating.Extracellular.allSpikeTimes = allSpikeTimes;
                processedDataStruct.OscillatingGrating.Extracellular.cycleStartTimes = cycleStartTimes; %ms - start times of each oscillation cycle relative to the start of an epoch
                processedDataStruct.OscillatingGrating.Extracellular.numCyclesPerEpoch = numCycles;
                processedDataStruct.OscillatingGrating.Extracellular.motionPeriod = period;
                processedDataStruct.OscillatingGrating.Extracellular.sampleRate = sampleRate;
                processedDataStruct.OscillatingGrating.Extracellular.backgroundIntensity = branch_i.meta.backgroundIntensity;
                processedDataStruct.OscillatingGrating.Extracellular.gratingMeanIntensity = branch_i.meta.meanIntensity;
                processedDataStruct.OscillatingGrating.Extracellular.orientation = convertToRetinaAngle_PP(branch_i.meta.orientation, obj.recordingDate);
                processedDataStruct.OscillatingGrating.Extracellular.spatialFrequency = branch_i.meta.spatialFrequency;
                processedDataStruct.OscillatingGrating.Extracellular.gratingIntensityAmplitude = branch_i.meta.intensityAmplitude;
                processedDataStruct.OscillatingGrating.Extracellular.angleOffset = branch_i.meta.angleOffset;
                processedDataStruct.OscillatingGrating.Extracellular.motionAmplitude = amplitude;
                processedDataStruct.OscillatingGrating.Extracellular.motionPhaseShift = phaseShift;
                processedDataStruct.OscillatingGrating.Extracellular.spatialPhaseShift = spatialShift;
                %alphabetize the structure:
                processedDataStruct = orderfields(processedDataStruct);
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.OscillatingGrating.Extracellular.meta = editedMeta;
                
                %% Build analysis figure
                binWidth = 40; %ms
                numBins = stimLength/binWidth;
                allPSTH = zeros(size(allSpikeTimes, 2), numBins);
                for i = 1:size(allSpikeTimes, 2)
                    spikes_i = allSpikeTimes(i); %cell array
                    allPSTH(i, :) = obj.buildPSTH(spikes_i, binWidth, 0, stimLength)./(binWidth*1e-3); %hz
                end
                meanPSTH = mean(allPSTH, 1);
                smoothedPSTH = movmean(meanPSTH, 12);
                xvals = linspace(0, stimLength/1000, numel(smoothedPSTH));
                hold on
                %recreate the position of the stimulus
                periodTerm = 2*pi/period;
                shiftTerm = deg2rad(phaseShift);
                %calculates stimulus position ON THE RETINA (not in visual
                %coordinates)
                stimulusPositionFunc = @(time, shift) cos(periodTerm*time + shift)/periodTerm;
                stimulusPosition = stimulusPositionFunc(xvals, shiftTerm);
                scaledStimulusPosition = 4*stimulusPosition + max(smoothedPSTH)*1.2;

                analysisFigure1 = figure();
                title('Mean PSTH')
                hold on
                plot(xvals, smoothedPSTH, 'k', 'LineWidth', 2)
                plot(xvals, scaledStimulusPosition, 'r', 'LineWidth', 2);
                xlabel('Time (s)')
                ylabel('spike/s')
                legend('PSTH', 'Stimulus Position')
                
                binsPerCycle = period_ms/binWidth;
                binStart = 1; binEnd = binsPerCycle;
                singleCyclePSTH = zeros(numCycles, binsPerCycle);
                for i = 1:numCycles
                    singleCyclePSTH(i, :) = smoothedPSTH(binStart:binEnd);
                    binStart = binStart + binsPerCycle;
                    binEnd = binEnd + binsPerCycle;
                end
                meanSingleCyclePSTH = mean(singleCyclePSTH, 1);
                
                %adjust for the motion phase shift if necessary
                phaseShiftBins = round(mod(phaseShift, 360)*binsPerCycle/360);
                if phaseShiftBins ~= 0
                    newStartBin = numel(meanSingleCyclePSTH)-phaseShiftBins;
                    meanSingleCyclePSTH = [meanSingleCyclePSTH(newStartBin:end)...
                        meanSingleCyclePSTH(1:newStartBin -1)];
                end
                xvals = linspace(0, period, binsPerCycle);
                stimulusPositionSingleCycle = stimulusPositionFunc(xvals, 0);
                scaledStimulusPositionSingleCycle = 4*stimulusPositionSingleCycle +...
                    1.2*max(meanSingleCyclePSTH);
               
                analysisFigure2 = figure();
                title('Mean PSTH Over A Single Cycle')
                hold on
                plot(xvals, meanSingleCyclePSTH, 'k', 'LineWidth', 2)
                plot(xvals, scaledStimulusPositionSingleCycle, 'r', 'LineWidth', 2);
                xlabel('Time (s)')
                ylabel('spike/s')
                legend('PSTH', 'Stimulus Position')
                
            %% Voltage clamp analysis:
            elseif strcmp(obj.recordingType, 'Excitation (Intracellular)') ||...
                    strcmp(obj.recordingType, 'Inhibition (Intracellular)')
                
                switch obj.recordingType
                    case 'Excitation (Intracellular)'
                        keyword = 'Intracellular_Excitation';
                    case 'Inhibition (Intracellular)'
                        keyword = 'Intracellular_Inhibition';
                end
            end
            
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '_FullPSTH';
            obj.analysisFigures(2) = analysisFigure2;
            obj.analysisFigureExtensions{2} = '_SingleCyclePSTH';
            obj.processedData = processedDataStruct;
        end
        
    end
end