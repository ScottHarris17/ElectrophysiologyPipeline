function hillParams = hillFit(x, y)
% beta(1) x1/2
% beta(2) exponent
% beta(3) base
% beta(4) max

I = floor(log10(min(x)) / log10(2)):ceil(log10(max(x)) / log10(2));
b1 = 2.^median(I);
b2 = 2;
b3 = 0;
b4 = max(y);


fit = @(b, x) (b(3) + (b(4) - b(3)) ./ (1 + (b(1) ./ x).^b(2)));  % Function to fit
fcn = @(b) sum((fit(b,x) - y).^2);                              % Least-Squares cost function
fitParams = fminsearch(fcn, [b1;  b2;  b3; b4]);                       % Minimise Least-Squares

xValues = linspace(min(x),max(x));
fitValues = fit(fitParams, xValues);
figure(1)
plot(x,y,'b',  xValues,fitValues, 'r')
legend('Data', 'Fit')

hillParams.I_OneHalf = fitParams(1);
hillParams.exponent = fitParams(2);
hillParams.minimum = fitParams(3);
hillParams.maximum = fitParams(4);
end
