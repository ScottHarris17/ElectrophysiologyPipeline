function [positivePeaks, negativePeaks] = findPeaks(trace, sampleRate, varargin)
%finds index and values of local minima and maxima

%optional first parameter sets the smooth window size. Optional second parameter
%sets the majority vote threshold

%Returns structures for positive and negative peaks that contain the peak
%values, the absolute time of the peak (in ms) and the rise time of the
%peak (rise time is the time between the start of an upwards trend and the
%peak value of that trend, for example).


smoothSize = sampleRate/5;
majorityVote = 0.95;

if nargin > 2
    smoothSize = varargin{1};
end
if nargin > 3
    majorityVote = varargin{2};
end

%smooth the trace
smoothed = movmean(trace, smoothSize);
i = 1;
posPeakInfo = zeros(0, 3); %store info about positive peaks
negPeakInfo = zeros(0, 3); %store info about negative peaks

while i < numel(smoothed) %work your way through the trace
    if i == 1 %on the first iteration, check to see whether a positive or negative peak is going to come first
        upTrend = findTrend(smoothed, majorityVote, 1);
        downTrend = findTrend(smoothed, majorityVote, -1);
        if upTrend < downTrend
            lookingFor = 1; %expecting a positive peak first
        else
            lookingFor = -1; %expecting a negative peak first
        end
    end
    
    startIndex = findTrend(smoothed(i:end), majorityVote, lookingFor)+i; %find the onset of the first peak (i.e. when the trace starts trending up or down significantly)
    stopIndex = findTrend(smoothed(startIndex:end), majorityVote, lookingFor*-1)+startIndex; %bookend the back end of the peak. This is an index that comes after the current peak because the trend has flipped directions
    
    if startIndex == 0 || stopIndex == startIndex
        break %if either start or stop did not find a trend then there is no peak to report. Quit the loop
    end
    
    if lookingFor == 1 %if looking for a positive peak, take the max value in between the start and stop indices
        [p, ip] = max(smoothed(startIndex:stopIndex));
        posPeakInfo = [posPeakInfo;1000*(ip+startIndex)/sampleRate, p, ip*1000/sampleRate]; %each peak is a new row: [Peak Value, Peak Index, rise time of the peak relative to the beginning of the trend]
    else %if looking for a negative peak, take the min value between start and stop indices
        [p, ip] = min(smoothed(startIndex:stopIndex));
        negPeakInfo = [negPeakInfo;1000*(ip+startIndex)/sampleRate, p, ip*1000/sampleRate];
    end
    lookingFor = lookingFor*-1;
    i = ip+startIndex+1;
end
positivePeaks.peakValues = posPeakInfo(:, 1);
positivePeaks.peakTimes = posPeakInfo(:, 2);
positivePeaks.riseTimes = posPeakInfo(:, 3);

negativePeaks.peakValues = negPeakInfo(:, 1);
negativePeaks.peakTimes = negPeakInfo(:, 2);
negativePeaks.riseTimes = negPeakInfo(:, 3);
end

    