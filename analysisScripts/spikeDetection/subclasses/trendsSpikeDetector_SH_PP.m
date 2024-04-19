classdef trendsSpikeDetector_SH_PP < spikeDetectors
    %TRENDSSPIKEDETECTOR_SH_PP Spike detector for current clamp recordings
    %   Detailed explanation goes here
    
    properties
        zThresh = 4; 
        refractoryPeriod = 4; %ms
    end
    
    methods
        function spikes = detectSpikes(obj, trace)
            %Use for current clamp
            %Inputs
            %   trace       : raw trace
            %Outputs
            %   spikeTimes  : structure with field .sp specifying times of detected
            %                 spikes in ms
            
            obj.zThresh = 4; %zscore to threshold spikes
            obj.refractoryPeriod = 4; %ms
            
            refractoryPeriodSR = (obj.refractoryPeriod/1000) * obj.SR; %change to units of sample rate
            
            %take derivative of trace
            d = diff(trace);
            
            m = mean(d);
            er = std(d);
            
            %take only changes above threshold
            peaks = (abs(d) > m+obj.zThresh*er) & (trace(2:end) > -30); %logic after the '&' can be helpful for CurrentClamp recordings
            peaks([1:obj.SR/100, numel(peaks)-obj.SR/100:end]) = 0;
            i = 1;
            %get rid of refractory violations
            zerofill = zeros(1, refractoryPeriodSR);
            while i < numel(peaks)%(there's probably a more clever way of doing this)
                if peaks(i) == 1
                    peaks(i+1:i+refractoryPeriodSR) = zerofill;
                    i = i+refractoryPeriodSR;
                    continue
                end
                i = i + 1;
            end
            spikes = struct();
            
            spikes.sp = find(peaks);
        end
        
    end
end

