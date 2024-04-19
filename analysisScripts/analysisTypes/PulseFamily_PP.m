classdef PulseFamily_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
        recordingDate
    end
        
    methods
              
        function   obj = analysis(obj)
            %This function processes data from an LED pulse family stimulus. 
            %It is called if the user has chosen to analyze LED Pulse
            %Family epochs from the dataViewer gui.
            
            processedDataStruct = struct();
            
            obj.rigInformation = obj.getRigInfo; %from analysis super class methods
            firstBranch = obj.data.(obj.cellID).epochs(obj.epochsSelected(1));
            numberOfPulses = firstBranch.meta.pulsesInFamily;
            firstPulse = firstBranch.meta.firstPulseSignal;
            pulseInterval = firstBranch.meta.incrementPerPulse;
            pulseSequence = [firstPulse:pulseInterval:double((firstPulse+pulseInterval*(numberOfPulses-1)))];
            
            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Current Clamp (K+ Spikes)')
                keyword = 'CurrentClamp_PotassiumSpikes';
                %initialize processed data structure;
                processedDataStruct.PulseFamily.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                processedDataStruct.PulseFamily.(keyword).allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch
                processedDataStruct.PulseFamily.(keyword).numberOfPulsesPerFamily = numberOfPulses;
                processedDataStruct.PulseFamily.(keyword).firstPulseValue = firstPulse;
                processedDataStruct.PulseFamily.(keyword).pulseInterval = pulseInterval;
                processedDataStruct.PulseFamily.(keyword).pulseSequence = pulseSequence;
                
                %before looping through epochs, set parameters for membrane
                %potential extraction
                allEpochs_struct = obj.data.(obj.cellID).epochs(obj.epochsSelected);
                allEpochs = zeros(numel(allEpochs_struct(1).epoch), numel(allEpochs_struct));
                for i = 1:size(allEpochs, 2)
                    allEpochs(:, i) = allEpochs_struct(i).epoch;
                end
                %user will set params for spike removal
                m = MembranePotentialExtraction_CurrentClamp(allEpochs);
                waitfor(m, 'readyToProceed', 1)
                extractedTraces = m.extractedTraces;
                extractionParams = m.extractionParams;
                close(m.UIFigure)

                numSpikesInStimTimeByEpoch = zeros(1, numel(obj.epochsSelected)); %number of spikes occuring during the stim time
                numSpikesTotalByEpoch = zeros(1, numel(obj.epochsSelected)); %number of spikes occuring during the tail time
                %initialize data holders
                baselineVmByEpoch = zeros(1, numel(obj.epochsSelected)); %resting membrane potential during the pretime on each epoch
                steadyStateResponseVmByEpoch = zeros(1, numel(obj.epochsSelected)); %steady state after current injection on each epoch
                pulseSizeByEpoch = zeros(1, numel(obj.epochsSelected)); %size of the current injection for each epoch
                inputResistanceByEpoch = zeros(1, numel(obj.epochsSelected)); %R = V/I for each epoch (in Ohms, assumes mV and pA units)
                responseMagnitudeByPulseSize = cell(numberOfPulses, 2); %nx2 array: column 1 = pulse size, column 2 = array of all of the change in Vm between pretime and steady state stim time
                for i = 1:numberOfPulses
                    responseMagnitudeByPulseSize{i, 1} = pulseSequence(i);
                end
                
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    pulseSize = branch_i.meta.pulseSignal;
                    pulseSizeByEpoch(i) = pulseSize;

                    %Pull out the recording trace
                    trace_spikes = branch_i.epoch;

                    %Pull out the relevant metadata for analysis
                    preTime = branch_i.meta.preTime; %in ms
                    stimTime = branch_i.meta.stimTime; %in ms
                    tailTime = branch_i.meta.tailTime; %in ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    %Extract spikes using desired spikeDetector
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);                     
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;

                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;
                    processedDataStruct.PulseFamily.(keyword).allSpikeTimes{i} = spikeTimes; %add to struct
                    numSpikesInStimTimeByEpoch(i) = sum(spikeTimes > preTime & spikeTimes < stimTime+tailTime);
                    numSpikesTotalByEpoch(i) = numel(spikeTimes);
                    
                    trace_noSpikes = extractedTraces(:, i);
                    preTime_SR = sampleRate*preTime/1000;
                    %now extract the spikes out of the trace
                    baselineVm = mean(trace_noSpikes(1:preTime_SR));
                    stimTime_SR = sampleRate*stimTime/1000;
                    steadyStateVm = mean(trace_noSpikes(preTime_SR+stimTime_SR*0.5:preTime_SR+stimTime_SR*0.9)); %take second half of stim time as an easy way to get steady state
                    
                    vMChange = steadyStateVm - baselineVm;
                    vMChange_volts = vMChange/1000; %assuming units were milli Volts for Vm
                    pulseSize_Amps = pulseSize*10^-12;
                    
                    inputResistance_Ohms = vMChange_volts/pulseSize_Amps;
                    
                    baselineVmByEpoch(i) = baselineVm;
                    steadyStateResponseVmByEpoch(i) = steadyStateVm;
                    inputResistanceByEpoch(i) = inputResistance_Ohms;
                    
                    pulseIndex = find(pulseSequence == pulseSize);
                    pulseArray = responseMagnitudeByPulseSize{pulseIndex, 2};
                    pulseArray(end+1) = vMChange;
                    responseMagnitudeByPulseSize{pulseIndex, 2} = pulseArray;
                    
                end
                processedDataStruct.PulseFamily.(keyword).preTime = preTime;
                processedDataStruct.PulseFamily.(keyword).stimTime = stimTime;
                processedDataStruct.PulseFamily.(keyword).tailTime = tailTime;
                processedDataStruct.PulseFamily.(keyword).pulseSizeByEpoch = pulseSizeByEpoch;
                processedDataStruct.PulseFamily.(keyword).baselineVmByEpoch = baselineVmByEpoch;
                processedDataStruct.PulseFamily.(keyword).steadyStateResponseVmByEpoch = steadyStateResponseVmByEpoch;
                processedDataStruct.PulseFamily.(keyword).inputResistanceByEpoch = inputResistanceByEpoch;
                processedDataStruct.PulseFamily.(keyword).responseMagnitudeByPulseSize = responseMagnitudeByPulseSize;
                processedDataStruct.PulseFamily.(keyword).numSpikesInStimTimeByEpoch = numSpikesInStimTimeByEpoch;
                processedDataStruct.PulseFamily.(keyword).numSpikesTotalByEpoch = numSpikesTotalByEpoch;
                processedDataStruct.PulseFamily.(keyword).extractionParams = extractionParams;
                
                %% calculate means and standard deviations for each pulse intensity
                meanResponseMagnitudeByPulseSize = zeros(1, numel(pulseSequence));
                stdResponseMagnitudeByPulseSize = zeros(1, numel(pulseSequence));
                for i = 1:numel(pulseSequence)
                    allResponses = responseMagnitudeByPulseSize{i, 2};
                    meanResponseMagnitudeByPulseSize(i) = mean(allResponses);
                    stdResponseMagnitudeByPulseSize(i) = std(allResponses);
                end
                processedDataStruct.PulseFamily.(keyword).meanResponseMagnitudeByPulseSize = meanResponseMagnitudeByPulseSize;
                processedDataStruct.PulseFamily.(keyword).stdResponseMagnitudeByPulseSize = stdResponseMagnitudeByPulseSize;
                

                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature','pulseSignal', 'epochNum', 'epochTime', 'epochStartTime'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.PulseFamily.(keyword).meta = editedMeta;


                %% Create analysis figure. It is the hill fit using the photons hill params
                analysisFigure1 = figure();
                errorbar(pulseSequence, meanResponseMagnitudeByPulseSize, stdResponseMagnitudeByPulseSize, 'k');
                hold on
                title(['Impulse Response Function - ', obj.cellID])
                xlabel('Current Amplitude (pA)')
                ylabel('Response Magnitude (mV)')
                box off
            end
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '_impulseResponse';

            obj.processedData = processedDataStruct;
        end

    end
end