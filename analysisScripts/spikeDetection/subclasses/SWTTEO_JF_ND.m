classdef SWTTEO_JF_ND < spikeDetectors
    %SWTTEO_JF_ND Spike detector for extracellular recordings
    %   Not super fast, but very accurate spike detector for extracellular recordings
    %   Adapted from F. Lieb, Feburary 2016 
    %   https://github.com/flieb/SpikeDetection-Toolbox
    
    properties
        global_factor = 300; % Param to change overall sensitivity of spike detection (lower = more sensitive)
        refractory_period = 1; % ms
        filter = 1; % 1 for filter on and 0 for filter off
        smoothing = 1; % 1 for smoothing on and 0 for smoothing off
    end
    
    methods
        function spikes = detectSpikes(obj, s)
            %SWTTEO_JF_ND Detects Spikes Location using a modified WTEO approach
            %   Input parameters:
            %       obj: Input structure which contains
            %               global_factor: Sensitivity of spike
            %                   detection (larger = less sensitive)
            %               refractory_period: Minimimum distance (in ms)
            %                   between spikes
            %               filter: Set to 1 to pre-filter the trace;
            %                   removes LFP 
            %               smoothing: Set to 1 to smooth the trace
            %   Output parameters:
            %       spikes: Timestamps of the detected spikes stored columnwise
            %
            %   Description:
            %       swtteo(obj, s) computes the location of action potentials. 
            %       This method is based on the work of N. Nabar and K. 
            %       Rajgopal "A Wavelet based Teager Engergy Operator for
            %       Spike Detection in Microelectrode Array Recordings". The algorithm
            %       therein was further improved by using a stationary wavelet
            %       transform and a different thresholding concept.
            %
            %       For an unsupervised usage the sensitivity of the algorithm can be
            %       adapted by changing the value of the variable global_factor. 
            %       A larger value results in fewer detected spikes but also the
            %       number of false positives decrease. Decreasing this factor makes it
            %       more sensitive to detect spikes. 
            %       
            %       Originally made to detect noisy action potentials in
            %       MEA recordings, adapted for use in noisy cell-attached
            %       recordings. 
            %
            %   Author: F. Lieb, February 2016
            %   Adapted by Naomi Donovan, March 2024
            %
            
            % Set up parameters
            wavLevel = 2;
            wavelet = 'sym5';
            winlength = ceil(1.3e-3*obj.SR); %1.3
            normalize_smoothingwindow = 0;
            params = struct();
         
            TEO = @(x,k) (x.^2 - myTEOcircshift(x,[-k, 0]).*myTEOcircshift(x,[k, 0]));
            [L,c] = size(s);
            if L==1
                s = s';
                L = c;
                c = 1;
            end
            
            %do zero padding if the L is not divisible by a power of two
            pow = 2^wavLevel;
            if rem(L,pow) > 0
                Lok = ceil(L/pow)*pow;
                Ldiff = Lok - L;
                s = [s; zeros(Ldiff,c)];
            end
            
            %prefilter signal
            if obj.filter == 1
                if ~isfield(params,'F1')
                    params.Fstop = 100;
                    params.Fpass = 200;
                    Apass = 0.2;
                    Astop = 80;
                    params.F1 = designfilt(   'highpassiir',...
                                              'StopbandFrequency',params.Fstop ,...
                                              'PassbandFrequency',params.Fpass,...
                                              'StopbandAttenuation',Astop, ...
                                              'PassbandRipple',Apass,...
                                              'SampleRate',obj.SR,...
                                              'DesignMethod','butter');
                end
                f = filtfilt(params.F1,s);
            else
                f = s;
            end
            
            %vectorized version:
            lo_D = wfilters(wavelet);
            out_ = zeros(size(s));
            ss = f;
            for k=1:wavLevel
                % Extension
                lf = length(lo_D);
                ss = obj.extendswt(ss,lf);
                % Convolution
                swa = conv2(ss,lo_D','valid');
                swa = swa(2:end,:); %even number of filter coeffcients
                %apply teo to swt output
                
                temp = abs(TEO(swa,1));
            
                if obj.smoothing == 1
                    wind = hamming(winlength);
                    if normalize_smoothingwindow == 1
                        wind = wind./(sqrt(3*sum(wind.^2) + sum(wind)^2));
                    end
                    temp2 = conv2(temp,wind','same');
                else
                    temp2 = temp;
                end
                    
                out_ = out_ + temp2;
                
                %dyadic upscaling of filter coefficients
                lo_D = dyadup(lo_D,0,1);
                %updates
                ss = swa;
            end
            
            %non-vectorized version to extract spikes...
            if c == 1
                [CC,LL] = wavedec(s,5,'sym5');
                lambda = obj.global_factor*wnoisest(CC,LL,1);
                thout = wthresh(out_,'h',lambda);
                spikes_pos = getSpikePositions(thout,obj.SR,s,obj);
            else
                spikes_pos = cell(c,1);
                for jj=1:c
                    [CC,LL] = wavedec(s(:,jj),5,'sym5');
                    lambda = global_fac*wnoisest(CC,LL,1);
                    thout = wthresh(out_(:,jj),'h',lambda);
                    spikes_pos{jj}=getSpikePositions(thout,obj.SR,s(:,jj),obj);
                end
            end

            %get rid of refractory violations
            isi_array = diff(spikes_pos) / 10; % divide by 10 to convert to ms
            temp_vec = find(isi_array < obj.refractory_period);
            while (temp_vec)
                spikes_pos(temp_vec(1)) = [];
                isi_array = diff(spikes_pos) / 10;
                temp_vec = find(isi_array < obj.refractory_period);
            end

            spikes = struct();
            spikes.sp = spikes_pos;
        end
            
        %internal functions:
        %--------------------------------------------------------------------------


        function y = extendswt(obj, x,lf)
            %EXTENDSWT extends the signal periodically at the boundaries
            [r,c] = size(x);
            y = zeros(r+lf,c);
            y(1:lf/2,:) = x(end-lf/2+1:end,:);
            y(lf/2+1:lf/2+r,:) = x;
            y(end-lf/2+1:end,:) = x(1:lf/2,:);
        end
    end
end