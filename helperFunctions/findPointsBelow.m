function pointsBelow = findPointsBelow(normalizedData,thresholdPastZero, frame, preTime, stimTime, tailTime, sampleRate)

preTimeInPoints = preTime * sampleRate/1000;
stimTimeInPoints = stimTime * sampleRate/1000;

smoothedNormalizedTrace = slidingsmooth(normalizedData, frame, 'median');
pointsBelow = smoothedNormalizedTrace < -1 * thresholdPastZero;
pointsBelow(1:preTimeInPoints) = 0;

changeInCrossings = diff(pointsBelow);
indexOfCrossings = find(changeInCrossings == 1);
% if(size(indexOfCrossings, 2) > 1)
%     pointsBelow(indexOfCrossings(2):end) = 0;
% end
end