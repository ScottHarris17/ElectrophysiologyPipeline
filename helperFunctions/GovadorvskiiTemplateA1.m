function [fit] = GovadorvskiiTemplateA1(beta, x)

% fit=1./(e(A.*(a-(beta./x)))+e(B.*(b-(beta./x)))+e(C.*(c-(beta./x)))+D);
% Trying to fit LambdaMax(beta) to wavelength (x)

% Created by Angueyra Dec_2010
% (based on Govadorvskii et al., 2000)

A=69.7;
a=0.88;
B=28.0;
b=0.922;
C=-14.9;
c=1.104;
D=0.674;

fit=1./(exp(A.*(a-(beta(1)./x)))+exp(B.*(b-(beta(1)./x)))+exp(C.*(c-(beta(1)./x)))+D);
end