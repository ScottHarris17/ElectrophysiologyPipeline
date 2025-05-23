function plotAboveBelowPoints(normalizedTrace, pointMin, timeMin, pointMax, timeMax)

    time = 1:size(normalizedTrace,2);
    plot(timeMin, pointMin, '.', 'MarkerSize', 20, 'Color', 'r');
    plot(timeMax, pointMax, '.', 'MarkerSize', 20, 'Color', 'g');
end