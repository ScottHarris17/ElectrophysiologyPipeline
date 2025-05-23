% function hillParams = hillFit(x, y)
%     beta(1) x1/2
%     beta(2) exponent
%     beta(3) base
%     beta(4) max
%     x: photonsPerSqmmPerS
%     y: meanResponse_hz
% 
%     I = floor(log10(min(x)) / log10(2)):ceil(log10(max(x)) / log10(2));
%     b1 = 2.^median(I);
%     b2 = 2;
%     b3 = 0;
%     b4 = max(y);
%     % Ihalf, rate, min, max
% 
%     fit = @(b, x) (b(3) + (b(4) - b(3)) ./ (1 + (b(1) ./ x).^b(2)));  % Function to fit
%     fcn = @(b) sum((fit(b,x) - y).^2);                              % Least-Squares cost function
%     fitParams = fminsearch(fcn, [b1;  b2;  b3; b4]);                       % Minimise Least-Squares
% 
%     xValues = linspace(min(x),max(x));
%     fitValues = fit(fitParams, xValues);
%     figure(1)
%     plot(x,y,'b',  xValues,fitValues, 'r')
%     legend('Data', 'Fit')
%     waitforbuttonpress;
% 
%     hillParams.I_OneHalf = fitParams(1);
%     hillParams.exponent = fitParams(2);
%     hillParams.minimum = fitParams(3);
%     hillParams.maximum = fitParams(4);
% end

% 
% 
% Jeff
% function hillParams = hillFit(x, y)
%     % x: photoisommerizations
%     % y: meanresponseperhz
%   % try using fit instead of hill_base_max to see what that would change
%     I = 2.^(floor(log2(min(x))) : 0.1 : ceil(log2(max(x))));
%     coef0 = [min(y), max(y), median(x), 2.0];
% 
%     min, max, half, rate
%     fitParams = nlinfit(x, y, @hill_base_max, coef0);
%     fitValues = hill_base_max(fitParams, I);
% 
%     figure(1)
% 
%     plot(log10(I), fitValues, 'r')
%     legend('Data')
% 
%     waitforbuttonpress;
% 
%     hillParams.I_OneHalf = fitValues(1);
%     hillParams.exponent = fitValues(2);
%     hillParams.minimum = fitValues(3);
%     hillParams.maximum = fitValues(4);
% end

% 20250429 JL
function hillParams = hillFit(x, y)
    % beta(1) x1/2
    % beta(2) exponent
    % beta(3) base
    % beta(4) max
    % x: photonsPerSqmmPerS
    % y: meanResponse_hz
    
    I = floor(log10(min(x)) / log10(2)):ceil(log10(max(x)) / log10(2));
    b1 = median(x); % getting the median of x as an estimate of I1/2
    b2 = 2;
    b3 = 0;
    b4 = max(abs(y)); % for negative peaks
    y = abs(y); % for negative peaks
    
    initParams = [b1; b2; b3; b4];
    hillFn = @(b, x) (b(3) + (b(4) - b(3)) ./ (1 + (b(1) ./ x).^b(2)));
    fitParams = nlinfit(x, y, hillFn, initParams);

%     xValues = linspace(min(x), max(x), 200);
%     fitValues = hillFn(fitParams, xValues);
%     figure(1)
%     plot(x,y,'b',  xValues,fitValues, 'r')
%     title('from hillFit.m')
%     legend('Data', 'Fit')
%     waitforbuttonpress;

    hillParams.I_OneHalf = fitParams(1);
    hillParams.exponent = fitParams(2);
    hillParams.minimum = fitParams(3);
    hillParams.maximum = fitParams(4);
end