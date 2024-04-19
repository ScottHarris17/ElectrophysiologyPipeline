function index = findTrend(trace, trendThreshold, direction)
    %finds index of first trend in the data for which the derivative is
    %continuously in one direction. Returns 0 if no trend can be found that
    %meets the criteria
    changes = diff(trace);
    last = zeros(1, 1000); %second number sets window to look in
    for i = 1:numel(changes)
        d = changes(i);
        sign =  2*((d > 0)-.5); %takes 1 or -1
        last = [last(2:end), sign]; %update the last n derivative signs
        trend = mean(last);
        
        if (trend*direction) > trendThreshold %direction specifies whether you're looking for a positive or negative trend
            index = i;
            return
        end
    end
    index = 0; %index = 0 if no trend found that meets the criteria.
end

