classdef MiniPostSynapticCurrents_PP < analysisSuperClass_PP
    %MINIPOSTSYNAPTICCURRENTS_PP Voltage clamp recordings for
    %mini PSCs
    
    properties
    end
    
    methods
          function   obj = analysis(obj)
            %This function processes data from a Mini post synaptic currents stimulus
            
            processedDataStruct = struct();
            
             if strcmp(obj.recordingType, 'Excitation (Intracellular)') || strcmp(obj.recordingType,  'Inhibition (Intracellular)')
                
                 switch obj.recordingType
                     case 'Excitation (Intracellular)'
                         keyword = 'Excitation';
                     case 'Inhibition (Intracellular)'
                         keyword = 'Inhibition';
                 end
                 
                 
                 restingMembranePotentialByEpoch = zeros(1, numel(obj.epochsSelected)) + 1234.5678;
                 branch = obj.data.(obj.cellID).epochs(obj.epochsSelected(1));
                 preTime = branch.meta.preTime;
                 stimTime = branch.meta.stimTime;
                 tailTime = branch.meta.tailTime;
                 totalTime = preTime + stimTime + tailTime;                 
                 
                 
                 processedDataStruct.MiniPSCs.(keyword).EpochNumbers = obj.epochsSelected;%epochs analyzed in this analysis run
                 processedDataStruct.MiniPSCs.(keyword).preTime = preTime;%epochs analyzed in this analysis run
                 processedDataStruct.MiniPSCs.(keyword).stimTime = stimTime;%epochs analyzed in this analysis run
                 processedDataStruct.MiniPSCs.(keyword).tailTime = tailTime;%epochs analyzed in this analysis run
                 processedDataStruct.MiniPSCs.(keyword).totalTime = totalTime;%epochs analyzed in this analysis run
                 %add metadata from last epoch to the structure, but remove
                 %irrelivent fields.
                 irreliventFields = {'bathTemperature', 'epochNum'};
                 metaToAdd = branch.meta;
                 editedMeta = rmfield(metaToAdd, irreliventFields);
                 processedDataStruct.MiniPSCs.(keyword).meta = editedMeta;
                 
                 
                 %make figure
                 highCuttoff = 100; %100hz cuttoff
                 responseMagnitudes = zeros(1, numel(obj.epochsSelected));
                 preTimeVariances = zeros(1, numel(obj.epochsSelected));
                 for i = 1:numel(obj.epochsSelected)
                     branch_i = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                     
                     %Pull out the recording trace
                     trace = branch_i.epoch;
                     preTime = branch_i.meta.preTime; %in ms
                     sampleRate = branch_i.meta.sampleRate; %observations per second
                     baseline = trace(1:preTime*sampleRate/1000);
                     normalizedTrace = trace - mean(baseline);
                     
                     preTimeVariances(i) = var(baseline);
                     
                     lp = lowpass(normalizedTrace, highCuttoff, sampleRate);
                     responseMagnitudes(i) = max(abs(lp(1, preTime*sampleRate/1000:end)));
                 end
                 normalizedResponseMagnitudes = responseMagnitudes./max(responseMagnitudes);
                 
                 %have user select appropriate epochs to use
                 openApp = miniAnalysisThresholding(obj.epochsSelected, normalizedResponseMagnitudes, preTimeVariances);
                 disp('Set threshold values for mini analysis')
                 while openApp.running == 1
                     pause(0.1); %wait for the gui to close, it should send a variable called 'thresholdingResults' to the workspace when it does
                 end
                 appOutput = openApp.thresholdingResults;
                 openApp.closeApp(); %close the app using public method
                 
                 processedDataStruct.MiniPSCs.(keyword).thresholdingResults = appOutput;
                 
                 analysisFigure1 = figure();
                 subplot(1, 2, 1)
                 title('Normalized Response Magnitude By Epoch')
                 hold on
                 plot(appOutput.usableEpochNumbers, appOutput.evokedResponseMagnitudes, 'k')
                 xlabel('Epoch Number')
                 ylabel('Evoked Response Amplitude (pA)')
                 hold off
                 
                 subplot(1, 2, 2)
                 title('Pretime Variance By Epoch')
                 hold on
                 plot(appOutput.usableEpochNumbers, appOutput.pretimeVariances, 'k')
                 xlabel('Epoch Number')
                 ylabel('Variance (pA^2)')
                 hold off
                 
                 sgtitle(['Mini PSCs ' keyword])
                 
             end
             
             obj.analysisFigures(1) = analysisFigure1;
             obj.analysisFigureExtensions{1} = '';
             obj.processedData = processedDataStruct;
             
          end
          
    end
end

