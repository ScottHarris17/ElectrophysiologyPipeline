function updateACell_PP(rootPath, cellListFName)
%% Use this file to make changes to CellList and to the CellParameters Structure of a cell you've already analyzed.
%(along with the corresponding entry in cellList).
%Possible actions include: 
%-Remove a field
%-Add a field and value
%-Rename a field
%-Reassign a value
%-Update coordinates
%-Add or remove a tag
%-Sync cell list
%-Delete the cell from cellList entirely

%% Select the cell that you would like to change
cd(changePathSlashesUnix(fullfile(rootPath, '/recordings')))
[fname, fpath] = uigetfile('*.mat', 'Select the cell analysis structure you would like to edit');

%check that the user input an _Analysis File
if ~contains(fname, '_Analysis.mat')
    disp('Edit aborted. You must select an "_Analysis.mat" file')
    return
end

%load the CellParameters and Batch files
load(fullfile(fpath, fname)) %load CellParameters structure for this cell to the workspace
load(changePathSlashesUnix(cellListFName)) %load cellList structure to the workspace
cellName = CellParameters.cellID;

%% Query the operation that user would like to perform
operations = {'Remove a Field', 'Add a Field and Value',...
    'Rename a field', 'Reassign a Value', 'Update Coordinates', 'Add or Remove A Tag',...
    'Sync cellList', 'Delete From Cell List'};

[selectionIndex, tf] = listdlg('ListString', operations ,...
    'Name', 'Select an operation', 'ListSize', [300 300], 'SelectionMode', 'single');

if ~tf
    disp('Edit aborted')
    return
end

% find where this cell is in cellListIndex
cellListIndex = NaN;
for i = 1:size(cellList, 1)
    if strcmp(cellList{i, 1}, cellName)
        cellListIndex = i;
        break
    end
end

if isnan(cellListIndex)
    disp('Edit aborted. This cell is not associated with the loaded project')
    return
end


if selectionIndex < numel(operations) - 1 %last two operations don't work with this section
    
    if ismember(selectionIndex, 1:4)
        allFields = fieldnamesr(CellParameters, 'full'); %generates cellArray of all fieldnames in structure
        allFields{end+1, 1} = 'CellParameters';
        
        %if removing a field, select the field to remove. If Adding a field,
        %select the field under which you'd like to add. To rename a field,
        %select the field to rename. To Reassign a value, select the field
        %underwhich the value is located. If adding or removing a tag skip
        [fieldIndex, tf] = listdlg('ListString', allFields,...
            'Name', 'Select the field', 'ListSize', [600 600], 'SelectionMode', 'single');
        
        if ~tf
            disp('Aborting edit. No field selected')
            return
        end
        
        fieldName = allFields{fieldIndex};
    
        if strcmp(fieldName, 'CellParameters')
            %make fieldName a blank string if they want to edit the first level
            %of the structure. This makes indexing to it easier (so I don't
            %have to repeat the words "CellParameters" multiple times in the
            %code).
            fieldName = '';
        end
    end
    
    if selectionIndex == 1
        %% Removing a field
        if numel(strfind(fieldName, '.')) > 0 %not a top level field
            
            %find index of last '.'
            reversedName = reverse(fieldName);
            lastDotIndex = numel(fieldName) - strfind(reversedName, '.') + 1;
            
            %grab names
            beforeDot = fieldName(1:lastDotIndex-1);
            afterDot = fieldName(lastDotIndex+1:end);
            
            %remove the field
            eval(strcat('CellParameters.', beforeDot,...
                '= rmfield(CellParameters.', beforeDot,',"', afterDot,'")'));
        
        else %top level field
           CellParameters = rmfield(CellParameters, fieldName);
        end
        
    elseif selectionIndex == 2 
        %% Add a field and its value below the selected field

        fieldAndValue = inputdlg({'Enter Field Name', 'Enter Value'}, 'Input');
        fieldToAdd = fieldAndValue{1};
        valueToAdd = fieldAndValue{2};
        
        if numel(fieldName) > 0 
            %Add a dot to the field name for proper indexing UNLESS the
            %user selected to edit in the top level of the structure (in
            %which case fieldName == '').
            fieldNameAdjusted = [fieldName, '.'];
        else
            fieldNameAdjusted = fieldName;
        end
                
        %if the value to add is not a string, change it to a double
        dType = questdlg('Select data type of value', 'Select Data Type', 'Num', 'String', 'String');
        switch dType
            case 'Num'
                accessString = strcat('CellParameters.', fieldNameAdjusted, fieldToAdd,...
                '=',valueToAdd);            
            
            otherwise   %value is a string (difference is "" around valueToAdd)
                accessString = strcat('CellParameters.', fieldNameAdjusted, fieldToAdd,...
                '= "',valueToAdd, '"');
        end
        
        eval(accessString);
        
    elseif selectionIndex == 3
        %% Rename a field      
        reversedName = reverse(fieldName);
        lastDotIndex = numel(fieldName) - strfind(reversedName, '.') + 1;

        %grab names
        beforeDot = fieldName(1:lastDotIndex-1);
        afterDot = fieldName(lastDotIndex+1:end);

        newFieldName = inputdlg('Enter new field name (must be valid matlab fieldname)', 'New Name', [1 50], {afterDot});
        newFieldName = newFieldName{1}; %grab string value       
        
        if numel(strfind(fieldName, '.')) > 0 %not a top level field

            %add a new field with that's a copy of the field it will
            %replace
            eval(strcat('CellParameters.', beforeDot, '.', newFieldName,...
                '= CellParameters.', fieldName));
            
            %Now remove the field with the old name
            eval(strcat('CellParameters.', beforeDot,...
                '= rmfield(CellParameters.', beforeDot,',"', afterDot,'")'));
            
        else %top levelfield
           CellParameters.newFieldName = CellParameters.fieldName;
           CellParameters = rmfield(CellParameters, fieldName);
        end
        
        
    elseif selectionIndex == 4
        %% Reassign a value
        newVal = inputdlg('Enter the new value to be assigned to your field');
        newVal = newVal{1};
        
        dType = questdlg('Select data type of value', 'Select Data Type', 'Num', 'String', 'String');
        
        switch dType
            case 'Num'
                accessString = strcat('CellParameters.', fieldName, '=', newVal);
            otherwise
                accessString = strcat('CellParameters.', fieldName, '= "', newVal, '"');
        end
        
        eval(accessString);

    elseif selectionIndex == 5
        %% Update coordinates
        [fCenter, pCenter] = uigetfile('*.mat', 'Select the center data file for this recording');
        load(fullfile(pCenter, fCenter)); %loads center data
        if exist('sizeData', 'var') ~=1
            disp('Incorrect file selected to update coordinates. You must select a center data file. Restart and try again')
            return
        end

        %Ask the user to enter the data
        XandYCoords = inputdlg({'Enter X Coordinate', 'Enter Y Coordinate'}, 'Input');
        xCoord = XandYCoords{1};
        yCoord = XandYCoords{2};
        
        if isnan(str2double(xCoord)) || isnan(str2double(yCoord)) %check user entries are numeric
            disp('Could not update coordinates. Please try again entering only numeric values for the X and Y coordinates')
            return
        end

        mockData = struct(); %you're going to create a "mock" data structure to mimic how the data is formatted when first loaded in the physiology pipeline
        mockData.centerData = sizeData;
        mockData.thisCell.epochs(1).meta.coordinates = [xCoord, ', ', yCoord];
        
        computedMockData = computeCoordinates_PP(mockData);

        CellParameters.coordinates = computedMockData.thisCell.coordinates;
        disp(CellParameters.coordinates)

    elseif selectionIndex == 6
        %% Add or remove a tag
        if isfield(CellParameters, 'Tags')
            currentTags = CellParameters.Tags;
        else
            currentTags = {};
        end
        
        addOrRemove = questdlg('Add or Remove a Tag', 'Select', 'Add', 'Remove', 'Cancel', 'Cancel');
        currentTags = CellParameters.Tags;
        
        if strcmp(addOrRemove, 'Add')
            tag = inputdlg('Enter New Tag');
            currentTags(end + 1) = tag;
            CellParameters.Tags = currentTags;
        elseif strcmp(addOrRemove, 'Remove')
            if ~isempty(currentTags)
                m = listdlg('ListString', currentTags);
                currentTags(m) = [];
                CellParameters.Tags = currentTags;
            end
        end
            
    end
    
end


%% update cell list: executes for everything but deleting a cell entirely
if selectionIndex < numel(operations)
    if isnan(cellListIndex)
        cellListIndex = size(cellList, 1) +1;
        cellList{cellListIndex, 1} = cellName;
    end
    
    cellList{cellListIndex, 2} = CellParameters; %syncs cellList with CellParameters
    
    %save CellParameters and cellList
    save(fullfile(fpath, fname), 'CellParameters');
    save(cellListFName, 'cellList');
    disp('Successfully updated the cell and saved the project batch list')
    clear CellParameters cellList
end

%% executes if user wants to delete the cell entirely
if selectionIndex == numel(operations)
    cellList = [cellList(1:cellListIndex-1, :); cellList(cellListIndex+1:end, :)];
    save(cellListFName, 'cellList')
    warndlg(['PERMINENTLY deleted ', cellName, ' from ' cellListFName])
end
    
end

    
    