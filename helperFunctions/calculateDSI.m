function [DSI, meanVector] = calculateDSI(thetas, rhos, varargin)
%calculates direction selectivity index and mean vector response (angle and
%magnitude) given a vector of polar responses.

if numel(varargin) > 0
    angleUnits = varargin{1};
else
    angleUnits = 'degrees';
end

if numel(thetas) ~= numel(rhos)
    warning('You must enter an equal number of theta and rhos')
    return
end

switch angleUnits
    case 'degrees'
        thetas = deg2rad(thetas);
    case 'radians'
        %good to go, don't need to do anything
end

[x, y] = pol2cart(thetas, rhos);
xSum = sum(x);
ySum = sum(y);

[meanTheta, meanRho] = cart2pol(xSum, ySum);

switch angleUnits
    case 'degrees'
        meanTheta = rad2deg(meanTheta);
end


DSI = meanRho/sum(rhos);
meanVector = [meanTheta, meanRho];
end