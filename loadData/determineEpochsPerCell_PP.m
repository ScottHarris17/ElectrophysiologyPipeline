%Takes data structure from runPhysiologyPipeline and adds subfields for
%each cell that includes an array of Epoch groups run on them and the
%indexes of physiology events to use for each one


%% CHANGE values listed in "splitOnTheseParameters"
%If you would like to split up epoch groups based on a certain parameter,
%simply add it to the "splitOnTheseParameters" list. 
splitOnTheseParameters = {'displayName', 'epochGroupLabel', 'onlineAnalysis',...
    'preTime', 'stimTime', 'tailTime', 'numChecksX', 'numChecksY', 'stixelSize'...
    'randomLabel'};

cells = fieldnames(data);
for i = 1:size(cells, 1)
    cell_i = cells{i, 1};
    
    if ~strcmp(cell_i, 'centerData') %one field is centerData, don't want to look at this one now
        
        epochLog = {};
        
        %fill a cell array with all the parameters the user wants to split
        %on
        lastEpochParameters = cell(size(splitOnTheseParameters));
        for j = 1:numel(splitOnTheseParameters)
            p = splitOnTheseParameters{j};
            try
                lastEpochParameters{j} = data.(cell_i).epochs(1).meta.(p);
            catch
                %warning([p ' does not exist for all epochs in ' cell_i])
                lastEpochParameters{j} = 'unknown'; %won't split on two adjacent epochs with unknowns b/c they both have "unknown" as the value
            end
        end
        
        lastEpoch_Index = 1;
        
        %% loop through each epoch in the structure for the current cell
        for j = 2:numel(data.(cell_i).epochs)
            currentEpochParameters = cell(size(splitOnTheseParameters));
            
            for k = 1:numel(splitOnTheseParameters)
                p = splitOnTheseParameters{k};
                try
                    currentEpochParameters{k} = data.(cell_i).epochs(j).meta.(p);
                catch
                    %warning([p ' does not exist for all epochs in ' cell_i])
                    currentEpochParameters{k} = 'unknown'; %won't split on two adjacent epochs with unknowns b/c they both have "unknown" as the value
                end
            end
            
            maxEpochsRemainingInGroup = double(data.(cell_i).epochs(j).meta.numberOfAverages)... 
            - (j - lastEpoch_Index)-1;
        
        
            switch data.(cell_i).epochs(j).meta.displayName %'numberOfAverages' has a different meaning for some stimuli so adjust accordingly
                case 'Led Pulse Family'
                   maxEpochsRemainingInGroup = double(data.(cell_i).epochs(j).meta.numberOfAverages)*...
                       double(data.(cell_i).epochs(j).meta.pulsesInFamily) - (j - lastEpoch_Index)-1;
                case 'Pulse Family'
                    maxEpochsRemainingInGroup = double(data.(cell_i).epochs(j).meta.numberOfAverages)*...
                        double(data.(cell_i).epochs(j).meta.pulsesInFamily) - (j - lastEpoch_Index)-1;
            end
            
            isLast = j == numel(data.(cell_i).epochs);
            %add to epochLog each time a new group is found and at the end
            %of the experiment
            
            %check to see if any of the last and current are different - if
            %so, you'll want to split
            LastAndCurrentParametersAreDifferent = 0;
            for k = 1:numel(splitOnTheseParameters)
                par = currentEpochParameters{k};
                %compare the current and last parameters in different ways
                %(strcmp or == ) based on their data class
                if isa(par, 'char')
                    if ~strcmp(par, lastEpochParameters{k})
                        LastAndCurrentParametersAreDifferent = 1; %update value if discrepency found
                        break
                    end
                elseif isa(par,'double')
                    try
                        if par ~= lastEpochParameters{k}
                            LastAndCurrentParametersAreDifferent = 1;
                            break
                        end
                    catch
                        LastAndCurrentParametersAreDifferent = 1;
                        break
                    end
                end
            end
            
            
            %% Add to epoch log if a new group was found
            if LastAndCurrentParametersAreDifferent || isLast || maxEpochsRemainingInGroup < 0
                %row 1 of the epoch log gives the name of the protocol
                displayName = data.(cell_i).epochs(j-1).meta.displayName;
                displayName = strrep(displayName, '  ', ' '); %get rid of double spaces (not sure why these occur but have seen them for some display names before)
                epochLog{1, end+1} = displayName;
                %row 2 gives the indexes of the responses for that protocol
                if ~isLast
                    epochLog{2, end} = [lastEpoch_Index, j-1];
                    
                    %update for next run
                    lastEpochParameters = currentEpochParameters;
                    lastEpoch_Index = j;
                    
                    
                
                else %on last, check whether last epoch is same as second to last epoch
                    
                    %simple copy and paste of above code to compare all the
                    %last and current parameters specified by user
                    LastAndCurrentParametersAreDifferent = 0;
                    for k = 1:numel(splitOnTheseParameters)
                        par = currentEpochParameters{k};
                        %compare the current and last parameters in different ways
                        %(strcmp or == ) based on their data class
                        if isa(par, 'char')
                            if ~strcmp(par, lastEpochParameters{k})
                                LastAndCurrentParametersAreDifferent = 1; %update value if discrepency found
                                break
                            end
                        elseif isa(par,'double')
                            if par ~= lastEpochParameters{k}
                                LastAndCurrentParametersAreDifferent = 1;
                                break
                            end
                        end
                    end    
                    
                    if LastAndCurrentParametersAreDifferent
                        epochLog{2, end} = [lastEpoch_Index, j-1];    
                        epochLog{1, end+1} = data.(cell_i).epochs(j).meta.displayName; %last epoch != second to last epoch
                        epochLog{2, end} = [j, j];
                    else %if different, you need to add two enteries to the epoch log
                        epochLog{2, end} = [lastEpoch_Index, j]; %if same, last index is j
                    end

                end
                
            end
        end
        
        %% add the epochLog to data for the current cell
        data.(cell_i).('epochLog') = epochLog;
          
    end
end

clear cell_i cells epochLog epochsRemainingInGroup i isLast...
    j k cells clarinetExportIndex lastEpochParameters...
    p splitOnTheseParameters lastEpoch_Index maxEpochsRemainingInGroup...
    LastAndCurrentParametersAreDifferent clarinetExportIndex par...
    currentEpochParameters
        
