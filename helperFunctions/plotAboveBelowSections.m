function plotAboveBelowSections(normalizedTrace, pointsBelow, pointsAbove, ON_totalNegativeCharge, ON_totalPositiveCharge, index)
    
    time = 1:size(normalizedTrace,2);
    
    d = diff([false, pointsAbove, false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1; 
    
    for k = 1:length(starts)
        x_chunk = time(starts(k):ends(k));
        y_chunk = normalizedTrace(starts(k):ends(k));
        area(x_chunk, y_chunk, 'FaceColor', 'green', 'FaceAlpha', 0.3)
    end
    
    d = diff([false, pointsBelow, false]);
    starts = find(d == 1);
    ends = find(d == -1) - 1;
    
    for k = 1:length(starts)
        x_chunk = time(starts(k):ends(k));
        y_chunk = normalizedTrace(starts(k):ends(k));
        area(x_chunk, y_chunk, 'FaceColor', 'red', 'FaceAlpha', 0.3)
    end
    
    
    plot(time, normalizedTrace, 'black', 'LineWidth', 1.5);
    plot(time(pointsAbove), normalizedTrace(pointsAbove), '--g', 'LineWidth',.8);
    plot(time(pointsBelow), normalizedTrace(pointsBelow), '--r', 'LineWidth', .8);
    text(5, -10, ['Area above is ', num2str(ON_totalNegativeCharge)])
    text(5, 10, ['Area above is ', num2str(ON_totalPositiveCharge)])
    title(['Plotting charge above, below baseline for trial ' int2str(index)]);
end