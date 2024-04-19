classdef simpleSpikeDetector_SH_PP < spikeDetectors
    %SIMPLESPIKEDETECTOR_SH_PP Thresholding spike detector
    %   High and low pass filtering + thresholding to detect spikes. Good
    %   for extracellular recordings
    
    properties
        zThresh = 4.8; %zscore to threshold spikes
        refractoryPeriod = 4; %ms
        absoluteThreshold = 1; %std below the mean on the actual trace
        highPass = 50;
        lowPass = 300;
    end
    
    methods
        function spikes = detectSpikes(obj, trace)
            %Inputs
            %   trace       : raw trace
            %Outputs
            %   spikeTimes  : structure with field .sp specifying times of detected
            %                 spikes in ms            
           
            refractoryPeriodSR = (obj.refractoryPeriod/1000) * obj.SR; %change to units of sample rate
            
            %filter noise
            if 1
                lp = lowpass(trace, obj.lowPass, obj.SR);
                hp = highpass(lp, obj.highPass, obj.SR);
            else
                hp = trace;
            end
            
            %take derivative of trace
            d = diff(hp);
            
            m = mean(d);
            er = std(d);
            
            %take only changes above threshold
            peaks = (abs(d) > m+obj.zThresh*er) & trace(2:end) <...
                mean(trace(2:end))- obj.absoluteThreshold*std(trace(2:1000)); %logic after the '&' can be helpful but unnecessary
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

