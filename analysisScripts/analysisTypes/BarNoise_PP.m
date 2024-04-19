classdef BarNoise_PP < analysisSuperClass_PP
    
    properties %properties inherited from superclass
    end
        
    methods
              
        
        function   obj = analysis(obj)
            %% Analysis script for bar noise stimulus
            % This script can handle either horizontal or vertical bar noise as well as
            % checkerboard noise - so long as it's run by the bar noise script on
            % symphony. However, trying to analyze multiple of these stim types together
            % will throw an error
            processedDataStruct = struct();

            %% Extracellular (spikes) analysis
            if strcmp(obj.recordingType, 'Extracellular')
                %compute spike triggered average once for each epoch
                %All epochs run individually and then the average is plotted
                responseByEpoch = [];
                lastStimType = ''; %error will throw if stim types aren't the same
                for i = 1:numel(obj.epochsSelected)
                    thisEpoch = obj.data.(obj.cellID).epochs(obj.epochsSelected(i));
                    response = thisEpoch.epoch;
                    preTime = thisEpoch.meta.preTime; %ms
                    stimTime = thisEpoch.meta.stimTime; %ms
                    tailTime = thisEpoch.meta.tailTime; %ms
                    sampleRate = thisEpoch.meta.sampleRate; %hz (1/s)
                    
                    %stimResponse is the response of the cell just during the time
                    %when the stimulus was on (i.e. you're cutting off the response
                    %during the preTime and tailTime).
                    stimResponse = response((preTime/1000)*sampleRate+1:...
                        numel(response) - ((tailTime/1000)*sampleRate));
                                            
                    %get the spike times that occured when the stimulus was on
                    obj.spikeDetector.SR = sampleRate;
                    spikeData = obj.spikeDetector.detectSpikes(trace);
                    spikeTimes_SR = spikeData.sp; %times in units of sampleRate;

                    %skip the epoch if there were no spikes
                    if numel(spikeTimes_SR) == 0
                        continue
                    end

                    %Now that you have the spike times, it's time to recreate the
                    %stimulus
                    seed = thisEpoch.meta.noiseSeed;
                    meanIntensity = 0.500; %This parameter is not specified in symphony but is usually 0.5
                    monitorFrameRate = 60;%/thisEpoch.meta.frameDwell; %frame rate of monitor used to deliver stimulus
                    numFrames = (numel(stimResponse)/sampleRate)*monitorFrameRate;
                    binary = thisEpoch.meta.binaryNoise;

                    %figure out what type of stimulus was presented
                    stixelSize = thisEpoch.meta.stixelSize_X; %um width of bars
                    if thisEpoch.meta.numChecksY == 1
                        numBars = thisEpoch.meta.numChecksX; %see note above about numChecksY
                        vert = 'horizontal';
                        stimType = 'Bar_NoiseX';
                        check = 0;
                    elseif thisEpoch.meta.numChecksX == 1
                        numBars = thisEpoch.meta.numChecksY;
                        vert = 'vertical';
                        stimType = 'Bar_NoiseY';
                        check = 0;
                    else %checkerboard condition
                        numBarsX = thisEpoch.meta.numChecksX;
                        numBarsY = thisEpoch.meta.numChecksY;
                        vert = 0;
                        stimType = 'Checkerboard';
                        check = 1;
                    end

                    %You can't analyze multiple epochs together that are of
                    %differnt stimTypes
                    if ~strcmp(stimType, lastStimType) && ~strcmp(lastStimType, '')
                        errordlg('Multiple epochs are not of the same stimulus type')
                        error('Analysis unworkable, cannot analyze selected epochs together')
                    end
                    lastStimType = stimType;

                    noiseStream = RandStream('mt19937ar', 'Seed', seed);
                    %Create stimulus: an nxm array where n is the number of bars
                    %in the stimulus and m is the number of frames that are
                    %recreated. Each value (n, m) is the intensity value of bar n
                    %at time j.
                    if binary %for binary stimuli
                        if ~check %for noncheckerboard stimuli
                            stimulus =(255.*2*meanIntensity.* (noiseStream.rand(numBars,numFrames)>0.5));
                        else %checkerboard stimuli
                            stimulus = (255.*2*meanIntensity.*(noiseStream.rand(numBarsY, numBarsX, numFrames)>0.5));
                        end

                    else %for gaussian stimuli
                        %contrast = thisEpoch.meta.noiseStdv;
                        contrast = thisEpoch.meta.contrast;
                        if ~check
                            stimulus =(255.*(meanIntensity + (meanIntensity*contrast) * (obj.noiseStream.randn(numBars,numFrames))));
                        else
                            stimulus =(255.*(meanIntensity + (meanIntensity*contrast) * (obj.noiseStream.randn(numBarsY, numBarsX, numFrames))));
                        end
                    end

                    %Now you have all that you need to create the receptive field:
                    %the times at which the cell spiked (relative to the onset of
                    %the bar noise part of the stimulus) and the stimulus itself.

                    %First get the units to match up: change spike times (currently
                    %in units of sampleRate) to be in terms of units of the monitor
                    %frame rate
                    spikeTimes_S = spikeTimes_SR/sampleRate;
                    spikeTimes_FR = spikeTimes_S*monitorFrameRate;

                    %now iterate over the spike times and grab the stimulus that
                    %occurs just before it and just after it
                    windowPre = 0.5; %in seconds, the length of time to grab data about the stimulus prior to a spike
                    windowPost = 0.2; %in seconds, then amount of data to grab following the spike (as control usually)

                    windowPre_FR = windowPre*monitorFrameRate;
                    windowPost_FR = windowPost*monitorFrameRate;

                    %stimulusMatr is an NxMxO array. N is the number of bars. M is
                    %the number of frames of stimulus to grab with M = 1 occuring at
                    %the time of the spike. O separates data
                    %from each spike

                    if ~check
                        stimulusMatr = zeros(numBars,windowPre_FR+windowPost_FR+1,...
                            numel(spikeTimes_FR))+ thisEpoch.meta.backgroundIntensity*255; %initialize with the background from the preTime

                        %fill stimulusMatr with values for each spike
                        for j = 1:numel(spikeTimes_FR)
                            spikeFrameNum = round(spikeTimes_FR(j)); %get the nearest frame of the spike

                            %Check if spike happened before a full windowlength after
                            %the start of the stimulus. If so, take as many frames as
                            %you can. The rest will be filled with the background
                            %intensity of the preTime.
                            if spikeFrameNum-windowPre_FR <= 0
                                pull = stimulus(:, 1:spikeFrameNum+windowPost_FR);
                                missing = 1-(spikeFrameNum-windowPre_FR);
                                stimulusMatr(:, missing+1:missing+spikeFrameNum+windowPost_FR, j) = pull;
                                continue
                            end

                            if spikeFrameNum+windowPost_FR > length(stimulus)
                                pull = stimulus(:, spikeFrameNum-windowPre_FR:end);
                                stimulusMatr(:, 1:size(pull,2)) = pull;
                                continue
                            end

                            pull = stimulus(:, spikeFrameNum-windowPre_FR:spikeFrameNum+windowPost_FR);                
                            stimulusMatr(:, :, j) = pull;
                        end

                        meanStimulusMatr = mean(stimulusMatr, 3);
                        responseByEpoch(:, :, end+1) = meanStimulusMatr;
                        
                    else %checkerboard stimulus
                        windowPost = 0; %can't have window post here because don't want post spike info in collapsed RF figure
                        stimulusMatr = zeros(numBarsY, numBarsX, windowPre_FR+windowPost_FR+1,...
                            numel(spikeTimes_FR))+ thisEpoch.meta.backgroundIntensity*255; %initialize with the background from the preTime
                        for j = 1:numel(spikeTimes_FR)
                            spikeFrameNum = round(spikeTimes_FR(j)); %get the nearest frame of the spike

                            if spikeFrameNum-windowPre_FR <= 0                
                                pull = stimulus(:, :, 1:spikeFrameNum+windowPost_FR);
                                missing = 1-(spikeFrameNum-windowPre_FR);
                                stimulusMatr(:, :, missing+1:missing+spikeFrameNum+windowPost_FR, j) = pull;
                                continue
                            end

                            if spikeFrameNum+windowPost_FR > length(stimulus)
                                pull = stimulus(:, :, spikeFrameNum-windowPre_FR:end);
                                stimulusMatr(:, :, 1:size(pull,3), j) = pull;
                                continue
                            end
                            pull = stimulus(:, :, spikeFrameNum-windowPre_FR:spikeFrameNum+windowPost_FR);
                            stimulusMatr(:, :, :, j) = pull; %x, y, time, spike #
                        end
                        
                        meanStimulusMatr = mean(stimulusMatr, 4);
                        responseByEpoch(:, :, :, end+1) = meanStimulusMatr; %x, y, time, epoch #
                        
                    end                          
                end

                %% Make the figure
                analysisFigure1 = figure();
                hold on
                title(strcat(obj.cellID, '- Bar Noise ', stimType, 'Receptive Field'));

                if ~check
                    totalMean = mean(responseByEpoch, 3); %no time component here
                    imagesc(totalMean./255)
                    colorbar
                    xlabel('Time (ms)')
                    xticks(0:5:windowPre_FR + windowPost_FR+1)
                    lbs = {};
                    for j = -windowPre_FR:5:windowPost_FR+1
                        lb = num2str(round(j*1000/monitorFrameRate));
                        lbs(1, end+1) = {lb};
                    end
                    xticklabels(lbs)
                    ylabel('Space (um)')
                    lbsY = {};
                    for j = 3:stixelSize*3:stixelSize*numBars
                        lbsY(1, end+1) = {j};
                    end
                    yticks(3:3:numBars)
                    yticklabels(lbsY)
                    plot([windowPre_FR+1, windowPre_FR+1], [0, size(totalMean,1)], '--r', 'LineWidth', 3)
                    hold off

                else %figure for checkerboard stim
                    totalMean = (mean(responseByEpoch, 4));
                        u = totalMean;
                        u = u/max(u(:));
                        vid = VideoWriter('receptiveField.avi');
                        vid.FrameRate = 5;
                        open(vid);
                        for v = 1:size(u, 3)
                            imagesc(u(:, :, v).*255);
                            frame = getframe;
                            writeVideo(vid,frame);
                        end
                        close(vid);
                        
                        xMean = squeeze(mean(u, 1));
                        imagesc(xMean)
                        imagesc(squeeze(mean(u, 2)))
                    imagesc(totalMean./255)
                    colorbar
                    xlabel('Space (um)')
                    lbsX = {};
                    for j = 3:stixelSize*3:stixelSize*numBarsX
                        lbsX(1, end+1) = {j};
                    end
                    xticks(3:3:numBarsX)
                    xticklabels(lbsX)
                    ylabel('Space (um)')
                    lbsY = {};
                    for j = 3:stixelSize*3:stixelSize*numBarsY
                        lbsY(1, end+1) = {j};
                    end
                    yticks(3:3:numBarsY)
                    yticklabels(lbsY)
                    hold off
                end
                
                obj.analysisFigures(1) = analysisFigure1;
                obj.analysisFigureExtensions{1} = '';

                %Fill processed data struct
                processedDataStruct.(stimType).Extracellular.stimTime = stimTime;
                processedDataStruct.(stimType).Extracellular.windowPre = windowPre;
                processedDataStruct.(stimType).Extracellular.windowPost = windowPost;
                processedDataStruct.(stimType).Extracellular.backgroundIntensity = thisEpoch.meta.backgroundIntensity;
                processedDataStruct.(stimType).Extracellular.binary = binary;
                processedDataStruct.(stimType).Extracellular.monitorFrameRate = monitorFrameRate;
                processedDataStruct.(stimType).Extracellular.sampleRate = sampleRate;
                processedDataStruct.(stimType).Extracellular.ReceptiveFieldMatrix = totalMean;
                processedDataStruct.(stimType).Extracellular.responsesByEpoch = responseByEpoch;
                if ~check
                    processedDataStruct.(stimType).Extracellular.numberOfBars = numBars;
                    processedDataStruct.(stimType).Extracellular.orientation = vert;
                else
                    processedDataStruct.(stimType).Extracellular.numberOfBarsX = numBarsX;
                    processedDataStruct.(stimType).Extracellular.numberOfBarsY = numBarsY;
                end
                
                %add metadata from last epoch to the structure, but remove
                %irrelivent fields.
                irreliventFields = {'bathTemperature', 'epochNum','epochStartTime', 'epochTime','noiseSeed'};
                metaToAdd = thisEpoch.meta;
                editedMeta = rmfield(metaToAdd, irreliventFields);
                processedDataStruct.(stimType).Extracellular.meta = editedMeta;

            end
            
            obj.processedData = processedDataStruct;                    
        end
        
        
    end
end