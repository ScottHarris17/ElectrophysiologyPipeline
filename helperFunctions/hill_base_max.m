function [fit] = hill_base_max(beta, x)

fit = beta(1) + (((beta(2)-beta(1))) ./ (1 + (beta(3) ./ x).^beta(4)));
%fit = log10((beta(1) + (beta(2)-beta(1))) ./ (1 + (beta(3) ./ x).^beta(4)));
%fit = log10(1.0 ./ (1 + (beta(1) ./ x).^beta(2)));