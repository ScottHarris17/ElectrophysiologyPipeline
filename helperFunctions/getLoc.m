function [loc, pass, analysisName] = getLoc(struct_i, priorityOrder_1, mustHave_1, cantHave_1, priorityOrder_2, mustHave_2, cantHave_2, rigMandates)
%this function finds and returns the location of the substructure for the
%analysis type that is desired. It is used to filter cells during batch
%analysis.
    
    %% set defaults for the two return values
    loc = struct(); %defualt
    pass = 1; %default - this value only changes to 0 if you make it to the end of the function without returning early
    analysisName = ''; %default. This value takes the name of analysisToUse_2 used when pass = 0

    %% parse for analyses that meet the critera set out by priority orders and avoid orders
    analyses = fieldnames(struct_i.Analyses_Completed);
    
    analysisToUse_1 = findAnalysisToUse(priorityOrder_1, analyses, mustHave_1, cantHave_1);
    switch analysisToUse_1
        case 'NoneFound'
            return
    end
    
    analysisToUse_2 = findAnalysisToUse(priorityOrder_2, fieldnames(struct_i.Analyses_Completed.(analysisToUse_1)), mustHave_2, cantHave_2);
    switch analysisToUse_2
        case 'NoneFound'
            return
    end
    
    %% check that there is no AVOID tag on this analysis
    loc = struct_i.Analyses_Completed.(analysisToUse_1).(analysisToUse_2);
    if isfield(loc.meta, 'AVOID') && loc.meta.AVOID == 1 %avoid tag for the particular analysis
        return
    end
    %% Check that the rig configuration meets the requirements
    if ~isempty(rigMandates)
        try
            recordingDate = loc.meta.epochTime; %first get the date that the recording happened on
        catch
            slashes = find(struct_i.fileLocation == '\');
            recordingDate = datetime(struct_i.fileLocation(slashes(end-2)+1:slashes(end-1)-1), 'InputFormat', 'yyyyMMdd');
        end
        
        mandates = rigMandates(:, 1); %next get a list of all the rig settings that must meet a particular requirement for this batch analysis
        mandateVals = rigMandates(:, 2); %get a comparable list of the values that each of the settings must be at in order to use this data

        load('C:\Users\mrsco\Box\DataAndAnalysis\labData\OKR\physiology\matlabCode\Info\rigChanges.mat'); %load the rig information

        for i = 1:numel(mandates) %go through each setting that has a certain requirement
            entries = rig.(mandates{i}); %get a list of all the times this particular setting has been updated on the rig
            targetVal = mandateVals{i}; %write down the value that you want this setting to be in order to use the data from this analysis

            %get a vector of date times that correspond to each time this
            %setting was updated on the rig
            dateNames = fieldnames(entries); 
            changeDates = NaT(1, numel(dateNames));
            for j = 1:numel(changeDates)
                s = dateNames{j};
                s = datetime(s(2:end), 'InputFormat', 'yyyyMMdd');
                changeDates(j) = s;
            end
            changeDates = sort(changeDates); %sort the datetime vector so that it's in order of oldest to newest

            %go through the date times vector one by one. If the date of the
            %recording is after the datetime of the current setting change, then continue
            %onwards. Break the loop the first time the date of the recording is
            %before the date of the current setting change. rigVal will be set to the
            %last setting update that occured before the recording
            for j = 1:numel(changeDates)
                if recordingDate >= changeDates(j)
                    rigVal = rig.(mandates{i}).(dateNames{j});
                else
                    break
                end
            end

            %check if the value of the rig setting on the recording date is the
            %same as the target value. If it is not, then you wont want to use
            %this cell for the batch analysis.
            if rigVal ~= targetVal
                return
            end
        end
    end
    analysisName = analysisToUse_2;
    %%
    pass = 0; %if you made it this far without returning, then pass = 0 and the analysis is usable
    
end
