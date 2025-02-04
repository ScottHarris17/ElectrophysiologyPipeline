classdef LedPulseFamily_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        function   obj = analysis(obj)
            %This function processes data from an LED pulse family stimulus. 
            %It is called if the user has chosen to analyze LED Pulse
            %Family epochs from the dataViewer gui.
            
            processedDataStruct = struct();
            
            obj.rigInformation = obj.getRigInfo; %from analysis super class methods
            firstBranch = obj.data.(obj.cellID).epochs(obj.epochsSelected(1));
            numberOfFlashStrengths = firstBranch.meta.pulsesInFamily;
            LED = firstBranch.meta.led;
            BlueBackground = firstBranch.meta.BlueBackground;
            obj.recordingDate = firstBranch.meta.epochTime; %must specify the recordingDate to use the selectLightCalibrations method
            LED_Calibrations = obj.selectLightCalibration(LED); %from analysisSuperClass methods
            Background_Calibrations = obj.selectLightCalibration('Blue_LED');
        
            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')

                %initialize processed data structure;
                processedDataStruct.LedPulseFamily.Extracellular.EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                processedDataStruct.LedPulseFamily.Extracellular.allSpikeTimes = {}; %contains a row vector for each epoch which shows the time (in ms) of each spike occurance during that epoch
                processedDataStruct.LedPulseFamily.Extracellular.LED = LED;
                processedDataStruct.LedPulseFamily.Extracellular.baseline_firingRates = []; %stores baseline firing rate for each epoch
                processedDataStruct.LedPulseFamily.Extracellular.ON_firingRates = []; %ON response firing rate for each epoch
                processedDataStruct.LedPulseFamily.Extracellular.OFF_firingRates = []; %OFF response firing rate for each epoch
                    
                allFlashIntensities = []; %all LED voltages probed
                numSpikesByFlashIntensity = {}; %total number of spikes for each epoch organized by the flash intensity
                flashResponseByIntensity = {}; %firing rate during the light step minus firing rate during baseline (pretime)
                flashIntensityByEpoch = []; %LED voltages for each epoch
                %Loop through the selected epochs one at a time.
                for i = 1:numel(obj.epochsSelected)
                    branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    
                    flashIntensity_i = branch_i.meta.lightAmplitude;
                    

                    %Pull out the recording trace
                    trace = branch_i.epoch;

                    %Pull out the relevant metadata for analysis
                    preTime = branch_i.meta.preTime; %in ms
                    stimTime = branch_i.meta.stimTime; %in ms
                    tailTime = branch_i.meta.tailTime; %in ms
                    sampleRate = branch_i.meta.sampleRate; %observations per second

                    %Extract spikes using desired spikeDetector
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);                     
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;

                    spikeTimes = (spikeTimes_SR./sampleRate)*1000; %convert to ms;
                    processedDataStruct.LedPulseFamily.Extracellular.allSpikeTimes{i} = spikeTimes; %add to struct
                    
                    lagTime = 100; %ms - lag time to start counting off response after stimulus offset
                    preSpikeIndx = find(spikeTimes < preTime);
                    stimSpikeIndx = find(spikeTimes > preTime &...
                        spikeTimes < (preTime + stimTime + lagTime)); %100ms lag time after stim offset
                    tailSpikeIndx = find(spikeTimes > (preTime + stimTime + lagTime));
                    
                    %compute firing rates for each segment
                    baselineFR = numel(preSpikeIndx)/(preTime/1000); %firing rate in hz;
                    ON_FR = numel(stimSpikeIndx)/((stimTime+lagTime)/1000);
                    OFF_FR = numel(tailSpikeIndx)/(tailTime/1000);
                    
                    flashResponse = ON_FR - baselineFR; %hz
                    
                    if ~ismember(flashIntensity_i, allFlashIntensities)
                        allFlashIntensities(end+1) = flashIntensity_i;
                        numSpikesByFlashIntensity{end+1, 2} = numel(spikeTimes);
                        flashResponseByIntensity{end+1, 2} = flashResponse;
                    else
                        position = find(allFlashIntensities == flashIntensity_i);
                        numSpikesByFlashIntensity{position, 2} = [numSpikesByFlashIntensity{position, 2};numel(spikeTimes)];
                        flashResponseByIntensity{position, 2} = [flashResponseByIntensity{position, 2};flashResponse];
                    end
                    flashIntensityByEpoch = [flashIntensityByEpoch, flashIntensity_i];
                    
                    
                    processedDataStruct.LedPulseFamily.Extracellular.baseline_firingRates = [processedDataStruct.LedPulseFamily.Extracellular.baseline_firingRates; baselineFR];
                    processedDataStruct.LedPulseFamily.Extracellular.ON_firingRates = [processedDataStruct.LedPulseFamily.Extracellular.ON_firingRates; ON_FR];
                    processedDataStruct.LedPulseFamily.Extracellular.OFF_firingRates = [processedDataStruct.LedPulseFamily.Extracellular.OFF_firingRates; OFF_FR];
                    
                end
                numSpikesByFlashIntensity(:, 1) = mat2cell(allFlashIntensities', ones(numel(allFlashIntensities), 1), 1);
                flashResponseByIntensity(:, 1) = mat2cell(allFlashIntensities', ones(numel(allFlashIntensities), 1), 1);
                
                processedDataStruct.LedPulseFamily.Extracellular.preTime = preTime;
                processedDataStruct.LedPulseFamily.Extracellular.stimTime = stimTime;
                processedDataStruct.LedPulseFamily.Extracellular.tailTime = tailTime;
                processedDataStruct.LedPulseFamily.Extracellular.flashIntensityByEpoch = flashIntensityByEpoch;
                processedDataStruct.LedPulseFamily.Extracellular.allFlashIntensities = allFlashIntensities;
                processedDataStruct.LedPulseFamily.Extracellular.numSpikesByFlashIntensity = numSpikesByFlashIntensity;
                processedDataStruct.LedPulseFamily.Extracellular.flashResponseByIntensity = flashResponseByIntensity;


                
                %% calculate means and standard deviations for each light intensity
                lightCalibrations.LED = LED;
                lightCalibrations.MeasuredValues_watts = LED_Calibrations;
                lightCalibrations.rigInformation = obj.rigInformation;
                lightCalibrations.PhotoisomerizationsByStimStrength = cell(numel(allFlashIntensities), 2);
                photonsPerSqmmPerS = zeros(1, numel(allFlashIntensities));
                
                photoisomerizationsPerMconePerSqmmPerS = zeros(1, numel(allFlashIntensities));
                photoisomerizationsPerSconePerSqmmPerS = zeros(1, numel(allFlashIntensities));
                photoisomerizationsPerRodPerSqmmPerS = zeros(1, numel(allFlashIntensities));
                meanResponse_hz = zeros(1, numel(allFlashIntensities));
                SEResponse_hz = zeros(1, numel(allFlashIntensities));
                for i = 1:numel(allFlashIntensities)
                    intensity_i = allFlashIntensities(i);
                    lightCalibrations_i = calVoltsToPhotoisomerizationsAndPhotons(LED, intensity_i, LED_Calibrations(1), obj.rigInformation);
                    lightCalibrations.PhotoisomerizationsByStimStrength{i, 1} = intensity_i;
                    lightCalibrations.PhotoisomerizationsByStimStrength{i, 2} = lightCalibrations_i;
                    
                    photonsPerSqmmPerS(i) = lightCalibrations_i.Photons_per_sqmm_per_second;
                    photoisomerizationsPerMconePerSqmmPerS(i) = lightCalibrations_i.Photoisomerizations_per_Mcone_per_umsq_per_second;
                    photoisomerizationsPerSconePerSqmmPerS(i) = lightCalibrations_i.Photoisomerizations_per_Scone_per_umsq_per_second;
                    photoisomerizationsPerRodPerSqmmPerS(i) = lightCalibrations_i.Photoisomerizations_per_Rod_per_umsq_per_second;
                    
                    meanResponse_hz(i) = mean(flashResponseByIntensity{i, 2});
                    SEResponse_hz(i) = std(flashResponseByIntensity{i, 2})/sqrt(numel(flashResponseByIntensity{i, 2}));
                end
                processedDataStruct.LedPulseFamily.Extracellular.lightCalibrations = lightCalibrations;

                processedDataStruct.LedPulseFamily.Extracellular.PhotonsPerSqmmPerS = photonsPerSqmmPerS;
                processedDataStruct.LedPulseFamily.Extracellular.PhotoisomerizationsPerMConePerSqmmPerS = photoisomerizationsPerMconePerSqmmPerS;
                processedDataStruct.LedPulseFamily.Extracellular.PhotoisomerizationsPerSConePerSqmmPerS = photoisomerizationsPerSconePerSqmmPerS;
                processedDataStruct.LedPulseFamily.Extracellular.PhotoisomerizationsPerRodPerSqmmPerS = photoisomerizationsPerRodPerSqmmPerS;
                
                processedDataStruct.meanFiringRateByFlashIntensity = meanResponse_hz;
                processedDataStruct.StandardErrorFiringRateByFlashIntensity = SEResponse_hz;
                %hill fits
                photonHillFit = hillFit(photonsPerSqmmPerS, meanResponse_hz);
                MConeHillFit = hillFit(photoisomerizationsPerMconePerSqmmPerS, meanResponse_hz);
                SConeHillFit = hillFit(photoisomerizationsPerSconePerSqmmPerS, meanResponse_hz);
                RodHillFit = hillFit(photoisomerizationsPerRodPerSqmmPerS, meanResponse_hz);

                processedDataStruct.LedPulseFamily.Extracellular.photonHillFit = photonHillFit;
                processedDataStruct.LedPulseFamily.Extracellular.MConeHillFit = MConeHillFit;
                processedDataStruct.LedPulseFamily.Extracellular.SConeHillFit = SConeHillFit;
                processedDataStruct.LedPulseFamily.Extracellular.RodHillFit = RodHillFit;
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'lightAmplitude', 'epochNum', 'epochTime', 'epochStartTime'};
                metaToAdd = branch_i.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.LedPulseFamily.Extracellular.meta = editedMeta;


                %% Create analysis figure. It is the hill fit using the photons hill params
                analysisFigure1 = figure();
                x = photonsPerSqmmPerS;
                y = meanResponse_hz;
                b = [photonHillFit.I_OneHalf; photonHillFit.exponent; photonHillFit.minimum; photonHillFit.maximum];
                
                xValues = linspace(min(x),max(x));
                hill = @(b, x) ((b(3) + (b(4) - b(3))) ./ (1 + (b(1) ./ x).^b(2)));  % Function to fit
                fitValues = hill(b, xValues);
                
                plot(log10(x), y)
                hold on
                title('LED Pulse Family - Intensity Response - Extracellular')
                plot(log10(xValues), fitValues)
                lgd = legend('Data', 'Fit');
                lgd.Location = 'best';
                box off
                xlabel('log_1_0(photons per mm^2 per second)')
                ylabel('firing rate (hz)')

            end
            obj.analysisFigures(1) = analysisFigure1;
            obj.analysisFigureExtensions{1} = '_photonHillFit';

            obj.processedData = processedDataStruct;
        end
        

    end
end
