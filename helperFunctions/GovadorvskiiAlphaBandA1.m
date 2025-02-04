function [fit] = GovadorvskiiAlphaBandA1(beta, wavelength)

% fit = GovadorvskiiAlphaBandA1(beta, wavelength) 
% fit=1./(exp(A.*(a-(beta(1)./wavelength)))+exp(B.*(b-(beta(1)./wavelength)))+exp(C.*(c-(beta(1)./wavelength)))+D);
% Based on Govadorvskii et al., 2000
% Created Dec_2010  Angueyra

A=69.7;
a=0.88;
B=28.0;
b=0.922;
C=-14.9;
c=1.104;
D=0.674;

fit=1./(exp(A.*(a-(beta(1)./wavelength)))+exp(B.*(b-(beta(1)./wavelength)))+exp(C.*(c-(beta(1)./wavelength)))+D);

