classdef localSpikeDetector_SH_PP < spikeDetectors
    %LOCALSPIKEDETECTOR_SH_PP Spike detector for extracellular recordings
    %   Fast spike detector for extracellular recordings
    
    properties
        absoluteThreshold = 6.8; %std below the local mean
        zThresh = 1.4; %zscore to threshold spikes against local diff mean
        localWindow = 5.5; %ms
        zPercentageGood = 0.5;
        medianZGood = 1.3;
        maxSpikeWidth = 1.3; %ms
        refractoryPeriod = 4; %ms
    end
    
    methods
        function spikes = detectSpikes(obj, trace)
            spikeWidthSR = (obj.maxSpikeWidth/1000) * obj.SR;
            refractoryPeriodSR = (obj.refractoryPeriod/1000) * obj.SR; %change to units of sample rate
            localWindowSR = (obj.localWindow/1000) * obj.SR;
            
            peaks = zeros(size(trace));
            for i = localWindowSR:numel(trace)
                localTrace = trace(i-localWindowSR+1:i-spikeWidthSR);
                localDiffs = abs(diff(localTrace));
                myVals = trace(i-spikeWidthSR:i);
                theseDiffs = diff(myVals);
                
                %work backwards. The spike will end with the nearest N positive
                %differences in a row (overshoots are not counted).
                streakSizeNeeded = 2; %N
                numPositive = 0;
                spikeEnd = 0;
                foundEnd = 0;
                for j = numel(theseDiffs):-1:1 %look from back to front this time
                    if theseDiffs(j) >= 0
                        numPositive = numPositive + 1;
                    else
                        numPositive = 0;
                    end
                    
                    if numPositive == streakSizeNeeded
                        foundEnd = 1;
                        spikeEnd = j+streakSizeNeeded;
                        break
                    end
                end
                
                if ~foundEnd
                    continue
                end
                
                spikeStart = 0;
                numNegative = 0;
                foundStart = 0;
                %now look for the nearest N negative differences in a row to mark the
                %spike start
                streakSizeNeeded = 2; %N
                firstMiss = 0; %allow for 1 miss
                for j = spikeEnd-1:-1:1
                    if theseDiffs(j) <= 0
                        numNegative = numNegative + 1;
                    else
                        if firstMiss %allows for 1 positive change in between negative changes
                            firstMiss = 0;
                            numNegative = 0;
                        else
                            firstMiss = 1;
                        end
                    end
                    
                    if numNegative == streakSizeNeeded
                        foundStart = 1;
                        spikeStart = j;
                        break
                    end
                end
                
                if ~foundStart
                    continue
                end
                
                spikeVals = myVals(spikeStart:spikeEnd);
                [spikePeak, spikePeakIndex] = min(spikeVals);
                peakZ = (spikePeak - mean(localTrace))/std(localTrace);
                spikeDiffs = diff(spikeVals);
                spikeDiffZs = (spikeDiffs - mean(localDiffs))/std(localDiffs);
                percentDiffZsGood = sum(abs(spikeDiffZs) > obj.zThresh)/numel(spikeDiffs);
                if (percentDiffZsGood >= obj.zPercentageGood || median(abs(spikeDiffZs)) >=obj.medianZGood) && - peakZ > obj.absoluteThreshold
                    peaks(round(i - spikeWidthSR + spikeStart + spikePeakIndex - 3)) = 1;
                end
            end
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

