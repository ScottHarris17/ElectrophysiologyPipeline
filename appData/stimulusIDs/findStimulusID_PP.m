function [found, stimulusID] = findStimulusID_PP(stimulusIDs, metaStruct)
%FINDSTIMULUSID determines the stimulus ID for a given meta data structure
% inputs:
%     - stimulusIDs: structure containing information about all the stimulus IDs
%     - metaStruct: the meta data associated with a given epoch in a clarinet export file
% outputs:
%     - found: evaluates to 1 if the function successfully found the approprate stimulus ID and 0 if not
%     - stimulusID: A string. Will return as much as is known about the stimulus ID. Even if the full ID was not found
%                 this variable may return as a portion of the full ID

%load the structure containing stimulus IDs (loads a variable called stimulusIDs)
stimType = metaStruct.displayName;
stimType(strfind(stimType, ' ')) = ''; %remove spaces

goodIndices = [];
if isfield(stimulusIDs.displayNameCodes, stimType)
    prefix = ['ID', stimulusIDs.displayNameCodes.(stimType)];
    %loop through the list of stimulus IDs and pick out only the ones with
    %the appropriate starting ID
    for i = 1:size(stimulusIDs.fullList, 1)
        id_i = stimulusIDs.fullList{i, 1};
        if contains(id_i, prefix)
            goodIndices(end + 1) = i;
        end
    end
end

%return with no results if there is no chance of finding a correct stimulus
%ID
if isempty(goodIndices) % this will be true if either the stimType did not exist in displayNameCodes, or if there were no matching stimulusIDs in fullList
found = 0;
stimulusID = 'ID...';
return
end

%search through the candidates to see if there is match
myFields = fieldnames(metaStruct); %cell array of all fieldnames in the meta data structure
for i = 1:numel(goodIndices)
    index_i = goodIndices(i);
    struct_i = stimulusIDs.fullList{index_i, 2};
    fieldsToCheck = fieldnames(struct_i);
    rightStimulus = 1;
    for j = 1:size(fieldsToCheck, 1)
        field_j = fieldsToCheck{j};
        
         %first check to see if myFields even has the current field
        if sum(ismember(myFields, field_j)) == 0
            rightStimulus = 0;
            break % wrong stimulus so move onto the next one
        end
        %now check for equality
        if ~isequal(struct_i.(field_j), metaStruct.(field_j)) 
            rightStimulus = 0;
            break
        end
    end
    
    %check if the recording happened outside of the correct date range
    if rightStimulus && (metaStruct.epochTime < stimulusIDs.fullList{index_i, 3}...
            || metaStruct.epochTime > stimulusIDs.fullList{index_i, 4})
        rightStimulus = 0;
    end
    
    %if you've made it this far and rightStimulus == 1 then you've found
    %your answer. If not, continue looping until you run out of options.
    if rightStimulus == 1
        found = 1;
        stimulusID = stimulusIDs.fullList{index_i, 1};
        return
    end
end

%if you've made it this far it means you didn't find an appropriate
%stimulus, but you did find a plausible prefix for the ID. Return this
%information
found = 0;
stimulusID = [prefix, '...'];
end

