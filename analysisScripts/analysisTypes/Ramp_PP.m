classdef Ramp_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            %% Analysis for ramp stim
            processedDataStruct = struct();
            if strcmp(obj.recordingType, 'Current Clamp (K+ Spikes)')
                
                switch obj.recordingType
                    case 'Current Clamp (K+ Spikes)'
                        keyword = 'CurrentClamp_PotassiumSpikes';
                end
                
                allSpikeTimes = cell(1, numel(obj.epochsSelected)); %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch    
                thresholdByEpoch = zeros(1, numel(obj.epochsSelected));
                restingMembranePotentialByEpoch = zeros(1, numel(obj.epochsSelected));
                
                 for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    sampleRate = branch_i.meta.sampleRate;
                    
                    preTime = branch_i.meta.preTime; %ms
                    stimTime = branch_i.meta.stimTime; %ms
                    tailTime = branch_i.meta.tailTime;
                    interpulseInterval = branch_i.meta.interpulseInterval;
                                        
                    onsetTime = preTime*sampleRate/1000;
                    offsetTime = onsetTime + stimTime*sampleRate/1000;
                    
                    %Pull out the recording trace
                    trace = branch_i.epoch;
                    restingMembranePotential = mean(trace(1:onsetTime));
                    restingMembranePotentialByEpoch(i) = restingMembranePotential;
                    
                    
                    %get spike times
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;
                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;
                    firstSpike = spikeTimes_SR(1);
                                        
                    allSpikeTimes{i} = spikeTimes;
                    
                    deriv = diff(trace);
                    growthRate = mean(deriv(onsetTime:round(firstSpike-40*sampleRate/1000))); %get growth rate leading up to the spike time
                    
                    thresholdPotential = restingMembranePotential + growthRate * (firstSpike-onsetTime);
                    thresholdByEpoch(i) = thresholdPotential;
                 end
                 
                 averageThreshold = mean(thresholdByEpoch);
                 stdThreshold = std(thresholdByEpoch);
                 
                 %fill processedDataStruct with data
                 processedDataStruct.Ramp.(keyword).EpochNumbers = obj.epochsSelected;
                 processedDataStruct.Ramp.(keyword).allSpikeTimes = allSpikeTimes; %row vector of spike times for each epoch
                 processedDataStruct.Ramp.(keyword).preTime = preTime; %time before stimulus onset
                 processedDataStruct.Ramp.(keyword).stimTime = stimTime; %time of stimulus
                 processedDataStruct.Ramp.(keyword).tailTime = tailTime; %time after stimulus offset
                 processedDataStruct.Ramp.(keyword).interpulseInterval = interpulseInterval; %time between epochs
                 processedDataStruct.Ramp.(keyword).sampleRate = sampleRate; %observations per second
                 processedDataStruct.Ramp.(keyword).thresholdByEpoch = thresholdByEpoch; %observations per second
                 processedDataStruct.Ramp.(keyword).restingMembranePotentialByEpoch = restingMembranePotentialByEpoch; %mV - average Vm during pretime
                 processedDataStruct.Ramp.(keyword).averageThreshold = averageThreshold; %mV
                 processedDataStruct.Ramp.(keyword).stdThreshold = stdThreshold; %mV
                 processedDataStruct.Ramp.(keyword).rampAmplitude = branch_i.meta.rampAmplitude; %pA - amount of current injected through the whole trace
                 
                 
                 %add metadata from last epoch to the structure, but remove
                 %irrelivent fields.
                 irreliventFields = {'epochNum'};
                 metaToAdd = branch_i.meta;
                 editedMeta = rmfield(metaToAdd, irreliventFields);
                 processedDataStruct.Ramp.(keyword).meta = editedMeta;
                 
                 %make figure
                 analysisFigure1 = figure();
                 title('Spike Threshold By Epoch');
                 hold on
                 plot(thresholdByEpoch)
                 xlabel('Epoch Number')
                 ylabel('mV')
                 hold off
            end
            
            %wrap up by saving figure and data
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '';
            
            obj.processedData = processedDataStruct;
        end
    end
end

        
                