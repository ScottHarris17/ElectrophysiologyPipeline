classdef analysisSuperClass_PP
    properties
        data %structure containing cell's data
        spikeDetector %
        recordingType %from dataviewer app
        analysisType %from dataviewer app
        cellID 
        epochsSelected %array from dataviewer app
        analysisFigures = gobjects(0)%gobjects array
        analysisFigureExtensions = {};%file name extension for each figure in analysisFigures
        processedData %struct to be returned after analysis
        maxFiringRateWindow = 50 %ms; sliding window width for maxfiringrate method
        recordingRig %name of the rig that the experiment was run on, inherited from dataViewer app
        rigInformation = struct(); %structure with rig and light calibration information
        recordingDate %datetime, when the cell was recorded
    end
    
    methods (Hidden = true)
                %think about how to put a series of functions for raw
                %traces here
    end
    
    
    methods %general methods that can be performed on traces independent of their analysis by a speific analysis type
        
        function maxFiringRate = maxFiringRate(obj, spikeTimes)
            %spikeTimes is a 1xN vector where each entry is the time of the
            %ith spike in ms
            if numel(spikeTimes) == 0
                maxFiringRate = 0;
                return
            end
            
            window = obj.maxFiringRateWindow; %ms

            if numel(spikeTimes) == 1
                maxFiringRate = 1/(window/1000);
                return
            end
            
            spikeTimes = round(spikeTimes - spikeTimes(1) + 1); %zero everything so that times are relative to the first spike
            timeSeries = zeros(1, ceil(max(spikeTimes))-floor(min(spikeTimes)+1));
            timeSeries(spikeTimes) = 1;
            maxSpikes = 0;
            for i = 1:numel(timeSeries)-window
                numSpikes = sum(timeSeries(i:i+window));
                if numSpikes > maxSpikes
                    maxSpikes = numSpikes;
                end
            end
            maxFiringRate = maxSpikes/(window/1000); %convert to hz
        end
        
        
        function obj = lowpassfilter(obj, threshold)
            %low pass filter each epoch
            switch nargin
                case 1
                    threshold = 500; %hz
            end
            
            for i = 1:numel(obj.epochsSelected)
                obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).epoch =...
                    lowpass(obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).epoch, threshold,...
                    obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).meta.sampleRate);
            end   
        end
        
        
        function obj = highpassfilter(obj, threshold)
            %high pass filter each epoch
            switch nargin
                case 1
                    threshold = 50; %hz
            end
            
            for i = 1:numel(obj.epochsSelected)
                obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).epoch =...
                    highpass(obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).epoch, threshold,...
                    obj.data.(obj.cellID).epochs(obj.epochsSelected(i)).meta.sampleRate);
            end   
        end
       
        
        %Build a psth
        function psth = buildPSTH(obj, spikes, binSize, startTime, endTime)
            numBins = ceil((endTime - startTime)/binSize);

            fullMatr = zeros(numel(spikes), numBins);

            for i = 1:numel(spikes)
                spikes_i = spikes{i};
                for j = 1:numel(spikes_i)
                    binNum = floor((spikes_i(j)-startTime)/binSize)+1; if binNum > numBins; binNum = numBins; end
                    fullMatr(i, binNum) = fullMatr(i, binNum) + 1;
                end
            end
            psth = mean(fullMatr, 1);
        end

        %rb
        function [freqs, power] = buildPowerSpectrum(obj, timeseries, duration, stepsize)
            % Adpated from "An Introduction to Field Analysis Techniques: The Power Spectrum and Coherence" by Mark A. Kramer, PhD
            xf = fft(timeseries); %1. Compute the Fourier transform.
            Sxx = 2*stepsize^2/duration * xf.*conj(xf); %2. Compute the power spectrum.
            power = Sxx(1:length(timeseries)/2+1); %3. Ignore negative frequencies.
            %powerDB = mag2db(power);%convert to decibels (logscale)
            df = 1/duration; %4. Determine the frequency resolution.
            fNQ=1/stepsize/2; %5. Determine the Nyquistfrequency.
            freqs = (0:df:fNQ); %6. Construct the frequency axis.

            %remove 0 frequency
            freqs = freqs(2:end);
            power = power(2:end);
        end
        
        
        %light calibration methods
        function rigInformation = getRigInfo(obj)
            %This function grabs information about the recording rig from
            %the file called rigInformation.txt. The grabbed data is stored
            %in a structure called rigInformation. It can then be
            %accessed for use for things like light calibration analyses.
            %To ensure you're grabbing data from the correct rig, make sure
            %the obj.recordingRig property is set to the proper identified
            %(e.g. 'E' or 'F').
            dataPath = obj.data.(obj.cellID).fileLocation;
            pathToPipeline = dataPath(1:strfind(dataPath, 'physiologyPipeline')-1);
            rigInformationFilePath = 'physiologyPipeline/appData/rigInformation_PP.txt';
            fID = fullfile(pathToPipeline, rigInformationFilePath);
           
            lookUpFile = fopen(fID, 'r');

            info = fscanf(lookUpFile, '%s');
            fclose('all');
            
            bookendIndices = strfind(info, ['$$', obj.recordingRig]);
            rigInfo = info(bookendIndices(1):bookendIndices(2));
            
            
            lightCalibrationSheetID_bookends = strfind(rigInfo, 'lightCalibrationSheetID');
            lightCalibrationSheetID = rigInfo(lightCalibrationSheetID_bookends(1)+numel('lightCalibrationSheetID:'):...
                lightCalibrationSheetID_bookends(2)-2);
            
            LEDSpotDiameter_bookends = strfind(rigInfo, 'LEDSpotDiameter');
            LEDSpotDiameter = str2num(rigInfo(LEDSpotDiameter_bookends(1) + numel('LEDSpotDiameter:'):LEDSpotDiameter_bookends(2)-2));
            
            wavelength_bookends = strfind(rigInfo, 'Wavelength');
            wavelength = str2num(rigInfo(wavelength_bookends(1)+numel('wavelength:'):wavelength_bookends(2)-2));
            
            UVSpectrum_bookends = strfind(rigInfo, 'UVSpectrum');
            UVSpectrum = str2num(rigInfo(UVSpectrum_bookends(1)+numel('UVSpectrum:'):UVSpectrum_bookends(2)-2));
            
            BlueSpectrum_bookends = strfind(rigInfo, 'BlueSpectrum');
            BlueSpectrum = str2num(rigInfo(BlueSpectrum_bookends(1)+numel('BlueSpectrum:'):BlueSpectrum_bookends(2)-2));
            
            try 
                DarkSpectrum_bookends = strfind(rigInfo, 'DarkSpectrum');
                DarkSpectrum = str2num(rigInfo(DarkSpectrum_bookends(1)+numel('DarkSpectrum:'):DarkSpectrum_bookends(2)-2));
                
                UVSpectrum = UVSpectrum - DarkSpectrum;
                BlueSpectrum = BlueSpectrum - DarkSpectrum;
                rigInformation.DarkSpectrum = DarkSpectrum;
            end
            
            rigInformation.lightCalibrationSheetID = lightCalibrationSheetID;
            rigInformation.LEDSpotDiameter = LEDSpotDiameter;
            rigInformation.rigName = obj.recordingRig;
            rigInformation.wavelength = wavelength;
            rigInformation.UVSpectrum = UVSpectrum;
            rigInformation.BlueSpectrum = BlueSpectrum;
        end
        
        %grab light calibration measures from the google sheet
        function calibrationMeasurements = selectLightCalibration(obj, lightSource)
            % This function grabs light calibration values from google sheets specified
            % by the id that is found in obj.rigInformation.lightCalibrationSheetID as a string.
            % lightSource is a string indicating which light source you
            % would like to grab the values from (e.g. 'UV_Led');

            spreadSheet = GetGoogleSpreadsheet(obj.rigInformation.lightCalibrationSheetID);
            dates = spreadSheet(:, 1);
                                
            %determine the light source to draw from and store the
            %column numbers of the spreadsheet that store the
            %corresponding data
            switch lightSource
                case 'UV_LED'
                    columns = [4, 5];
                case 'Blue_LED'
                    columns = [8, 9];
                case 'Green_LED'
                    columns = [12, 13];
                case 'Projector'
                    columns = [17:19];
                otherwise
                    errordlg('Unknown light source selected for calibration')
                    error('Unknown light source selected for calibration')
            end
                
            selectedDate = 0; %YYYYMMDD
            recordingDate = yyyymmdd(obj.recordingDate);
            valueFound = 0;
            failCounts = 0;
            
            while ~valueFound
                
                %pick the nearest date that occured before the recording
                for i = 2:numel(dates)
                    date_i = dates{i};
                    
                    if numel(date_i) ~= 8 %skip if the entered date is in the wrong format
                        continue
                    end
                        
                    try %skip if the entered date is not a number
                        date_i = str2double(date_i);
                        if isnan(date_i)
                            error('date is not a number, skipping it')
                        end
                        
                    catch
                        continue
                    end
                    
                    if date_i > recordingDate
                        break
                    end
                    selectedDate = date_i;
                end
                
                calibrationVals = spreadSheet(i, columns);
                
                %check that there are enough calibration values for this
                %date for the desired light source. If not, reloop and find
                %another
                skipDate = 0;
                for j = 1:numel(calibrationVals)
                    if isempty(calibrationVals{j}) %don't use this date
                        recordingDate = selectedDate -0.1; %subtract 0.1 so you'll get an earlier selectedDate next time through the while loop
                        skipDate = 1;
                    end
                end
                
                %skip the date if there aren't calibration values for it
                if skipDate
                    failCounts = failCounts + 1;
                    if failCounts < 100
                        continue
                    end
                    %if you've failed to find calibrations for too long
                    %send an error and stop execution
                    errordlg('No appropriate light calibration could be found for this recording date')
                    error('No appropriate light calibration could be found for this recording date')
                end
                
                %If you've gotten this far there are enough calibration
                %values. Calibration values should have numbers and units
                %(units should be two characters, e.g. nW).
                
                calibrationMeasurements = zeros(1, numel(calibrationVals));
                for k = 1:numel(calibrationVals)
                    val_k = calibrationVals{k};
                    numbers = str2num(val_k(1:end-2));
                    units = lower(val_k(end-1:end));
                    switch units
                        case 'mw'
                            calibrationMeasurements(k) = numbers *10^-3;
                        case 'uw'
                            calibrationMeasurements(k) = numbers*10^-6;
                        case 'nw'
                            calibrationMeasurements(k) = numbers*10^-9;
                        case 'pw'
                            calibrationMeasurements(k) = numbers*10^-12;
                        otherwise
                            errordlg(['Unknown Units for light calibration: ', units])
                            error(['Unknown Units for light calibration: ', units])
                    end
                end
                valueFound = 1;
            end
        end
        
    end
    
end