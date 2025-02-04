function calibrationStructure = calVoltsToPhotoisomerizationsAndPhotons(lightsource, lightIntensity, lightSourceCalibration, rigInformation)
% inputs:
%   lightsource - string corresponding to the light source (e.g 'UV_Led')
%   lightIntensity - in Volts
%   lightSourceCalibration - the 0.1 volt calibration in watts
%   rigInformation - structure containing spectra etc. for the rig, built
%   in superclass methods
% outputs:
%   calibrationStructure - structure containing photoisomerizations/s and
%   photons/s for the stimulus

spotDiameter = rigInformation.LEDSpotDiameter; %in um
spotArea_mm = pi*(((spotDiameter*1e-3)/2)^2); %in mm^2
spotArea_um = pi*(((spotDiameter)/2)^2); %in um^2

h = 6.63e-34; %Planck's constant (J*sec)
c = 299792458; %speed of light (m/sec)
wavelength = rigInformation.wavelength;

switch lightsource
    case 'UV_LED'
        spectrum = 'UVSpectrum';
    case 'Blue_LED'
        spectrum = 'BlueSpectrum';
    case 'Green_LED'
        spectrum = 'GreenSpectrum';
    otherwise
        error('No spectrum found for the light source')
end


spectrum = rigInformation.(spectrum);

ConeCollectingArea = 0.2; %in um^2
RodCollectingArea = 0.5; % in um^2


LambdaMaxS = 360; %from Nikonov et al., 2006
BetaBandScaling = 0.26; %scaling set to value suggested by Govardovskii et al. 2000; note that have no idea whether this is actually the value for Mopsin (or Sopsin)
SconeSpectrum = GovadorvskiiTemplateA1([LambdaMaxS,BetaBandScaling],wavelength);  
        
LambdaMaxM = 508; %from Nikonov et al., 2006
MconeSpectrum = GovadorvskiiTemplateA1([LambdaMaxM,BetaBandScaling],wavelength);

LambdaMaxRod = 493.3022; %these are still from Baylor primate recordings
BetaBandScalingRod=0.1233;
RodSpectrum=GovadorvskiiTemplateA1([LambdaMaxRod,BetaBandScalingRod],wavelength);

normSpectrum = spectrum / (sum(spectrum)*(wavelength(2)-wavelength(1))); %note that have to multiply by spectrum step (0.5 nm) to integrate
photonSpec = normSpectrum.*(wavelength*1e-9)/(h*c);

%convert LED energy spectra to photon flux (since normalized, units in photons/J; once multiply by calibration
%values (W = J/s), will be in units of photons/s)
%photonUV2spec = normUV2spec .* (wavelength*1e-9) / (h*c);

Scone = sum(photonSpec .* SconeSpectrum);
Mcone = sum(photonSpec .* MconeSpectrum);
Rod = sum(photonSpec .* RodSpectrum);

LEDwatts = lightSourceCalibration * lightIntensity/0.1; %normalize for 0.1v delivered;
LEDwatts_perArea = LEDwatts/spotArea_mm; %W/mm^2

LEDphotons = sum(LEDwatts*photonSpec);
LEDphotonsPerAreaPerSecond = LEDphotons/spotArea_mm; %photons/s/mm^2

Photoisomerizations_Mcone = sum(LEDwatts*Mcone);
Photoisomerizations_Scone = sum(LEDwatts*Scone);
Photoisomerizations_Rod = sum(LEDwatts*Rod);

PhotoisomerizationsPerArea_Mcone = ConeCollectingArea*Photoisomerizations_Mcone/spotArea_um; %photons/um^2
PhotoisomerizationsPerArea_Scone = ConeCollectingArea*Photoisomerizations_Scone/spotArea_um; %photons/um^2
PhotoiosomerizationsPerArea_Rod = RodCollectingArea*Photoisomerizations_Rod/spotArea_um; %photons/um^2
Photoisomerizations_MSR = [PhotoisomerizationsPerArea_Mcone, PhotoisomerizationsPerArea_Scone, PhotoiosomerizationsPerArea_Rod];

calibrationStructure.Watts_per_sqmm_per_s = LEDwatts_perArea;
calibrationStructure.Photons_per_sqmm_per_second = LEDphotonsPerAreaPerSecond;
calibrationStructure.Photoisomerizations_per_Mcone_per_second = Photoisomerizations_Mcone;
calibrationStructure.Photoisomerizations_per_Scone_per_second = Photoisomerizations_Scone;
calibrationStructure.Photoisomerizations_per_Rod_per_second = Photoisomerizations_Rod;
calibrationStructure.Photoisomerizations_per_Mcone_per_umsq_per_second = PhotoisomerizationsPerArea_Mcone;
calibrationStructure.Photoisomerizations_per_Scone_per_umsq_per_second = PhotoisomerizationsPerArea_Scone;
calibrationStructure.Photoisomerizations_per_Rod_per_umsq_per_second = PhotoiosomerizationsPerArea_Rod;

end
