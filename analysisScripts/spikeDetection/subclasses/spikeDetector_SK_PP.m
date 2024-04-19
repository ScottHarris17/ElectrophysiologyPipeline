classdef spikeDetector_SK_PP < spikeDetectors
    %SPIKEDETECTOR_SK_PP Spike detector that is used by symphony
    %   Simply copied and pasted
    properties
    end
    
    methods
        function results = detectSpikes(D)
            
            %altered to use 3 clusters in k-means analysis (to detect strongly adapted
            %spikes), but still not perfect Dec 2011 SPK
            HighPassCut_drift = 70; %Hz, in order to remove drift and 60Hz noise
            HighPassCut_spikes = 500; %Hz, in order to remove everything but spikes
            SampleInterval = 1E-4;
            ref_period = 2E-3; %s
            searchInterval = 1E-3; %s
            noise_cutoff = 12; %pA, used to select correct spike cluster(s); fix to make this an input parameter
            %make parameter for direction detection, or try both if not too slow (12)
            
            results = [];
            
            %thres = 25; %stds
            ref_period_points = round(ref_period./SampleInterval);
            searchInterval_points = round(searchInterval./SampleInterval);
            
            [Ntraces,L] = size(D);
            D_noSpikes = BandPassFilter(D,HighPassCut_drift,HighPassCut_spikes,SampleInterval);
            Dhighpass = HighPassFilter(D,HighPassCut_spikes,SampleInterval);
            
            sp = cell(Ntraces,1);
            spikeAmps = cell(Ntraces,1);
            violation_ind = cell(Ntraces,1);
            minSpikePeakInd = zeros(Ntraces,1);
            maxNoisePeakTime = zeros(Ntraces,1);
            
            for i=1:Ntraces
                %get the trace and noise_std
                trace = Dhighpass(i,:);
                trace(1:20) = D(i,1:20) - mean(D(i,1:20));
                %     plot(trace);
                %     pause;
                trace_noise = D_noSpikes(i,:);
                noise_std = std(trace_noise);
                
                %get peaks
                [peaks,peak_times] = getPeaks(trace,-1); %-1 for negative peaks
                peak_times = peak_times(peaks<0); %only negative deflections
                peaks = trace(peak_times);
                
                %basically another filtering step:
                %remove single sample peaks, don't know if this helps
                trace_res_even = trace(2:2:end);
                trace_res_odd = trace(1:2:end);
                [null,peak_times_res_even] = getPeaks(trace_res_even,-1);
                [null,peak_times_res_odd] = getPeaks(trace_res_odd,-1);
                peak_times_res_even = peak_times_res_even*2;
                peak_times_res_odd = 2*peak_times_res_odd-1;
                peak_times = intersect(peak_times,[peak_times_res_even,peak_times_res_odd]);
                peaks = trace(peak_times);
                
                %add a check for rebounds on the other side
                r = getRebounds(peak_times,trace,searchInterval_points);
                peaks = abs(peaks);
                peakAmps = peaks+r;
                
                if ~isempty(peaks) && max(D(i,:)) > min(D(i,:)) %make sure we don't have bad/empty trace
                    
                    options = statset('MaxIter',10000);
                    [Ind,centroid_amps] = kmeans(peakAmps',3,'start',[median(peakAmps); max(peakAmps)/2; max(peakAmps)], 'emptyaction', 'drop','Options',options);
                    
                    %other clustering approaches that I dedcided not to use
                    %[Ind,centroid_amps] = kmeans(sqrt(peakAmps),2,'start',sqrt([median(peakAmps);maxpeak]),'Options',options);
                    %obj = gmdistribution.fit(sqrt(peakAmps'),2,'Options',options);
                    %Ind = cluster(obj,sqrt(peakAmps'));
                    
                    %if don't have next block, will have trouble detecting real spikes when SNR of spikes is small (due to the no spikes check block that follows)
                    if  length(find(centroid_amps > noise_cutoff)) > 1 %for two spike clusters (define noise_cutoff above)
                        [m,noise_ind] = min(centroid_amps);
                        spike_ind_log = (Ind~=noise_ind);
                    else
                        [m,m_ind] = max(centroid_amps); %for one or zero spike clusters
                        spike_ind_log = (Ind==m_ind);
                    end
                    
                    %keyboard
                    
                    %temp reverse this logic for multiple spike peaks
                    %[m,noise_ind] = min(centroid_amps);
                    %spike_ind_log = (Ind~=noise_ind);
                    %keyboard;
                    %[m,m_ind] = max(centroid_amps);
                    %spike_ind_log = (Ind==m_ind);
                    %spike_ind_log is logical, length of peaks
                    
                    %distribution separation check
                    spike_peaks = peakAmps(spike_ind_log);
                    nonspike_peaks = peakAmps(~spike_ind_log);
                    nonspike_Ind = find(~spike_ind_log);
                    spike_Ind = find(spike_ind_log);
                    [m,sigma,m_ci,sigma_ci] = normfit(sqrt(nonspike_peaks));
                    mistakes = find(sqrt(nonspike_peaks)>m+5*sigma);
                    
                    
                    %no spikes check - still not real happy with how sensitive this is
                    if mean(sqrt(spike_peaks)) < mean(sqrt(nonspike_peaks)) + 4*sigma %no spikes
                        sp{i} = [];
                        spikeAmps{i} = [];
                        
                    else %spikes found
                        overlaps = length(find(spike_peaks < max(nonspike_peaks)));%this check will not do anything
                        sp{i} = peak_times(spike_ind_log);
                        spikeAmps{i} = peakAmps(spike_ind_log)./noise_std;
                        
                        [minSpikePeak,minSpikePeakInd(i)] = min(spike_peaks);
                        [maxNoisePeak,maxNoisePeakInd] = max(nonspike_peaks);
                        maxNoisePeakTime(i) = peak_times(nonspike_Ind(maxNoisePeakInd));
                        
                        %check for violations again, just for warning this time
                        violation_ind{i} = find(diff(sp{i})<ref_period_points) + 1;
                        ref_violations = length(violation_ind{i});
                        
                    end %if spikes found
                end %end if not bad trace
            end
            
            if length(sp) == 1 %return vector not cell array if only 1 trial
                sp = sp{1};
                spikeAmps = spikeAmps{1};
                violation_ind = violation_ind{1};
            end
            
            results.sp = sp;
            results.spikeAmps = spikeAmps;
            results.minSpikePeakInd = minSpikePeakInd;
            results.maxNoisePeakTime = maxNoisePeakTime;
            results.violation_ind = violation_ind;
        end

    end
end

