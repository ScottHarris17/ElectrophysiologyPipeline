%Loads data for master_OKR_Physiology

%Data should be coming in from Symphony2 DataCurator. Cells' file names are in
%form CellName_ClarinetExport.mat. When loaded they add a structure called
%"epochs" to the workspace. Here we'll load each cell that will be analyzed 
%and save its data to one structure to work with for the analysis.
cd(rootPath)

%User chooses cells (.mat files) to work with, they should all be located in one
%directory
[fnames, commonPath] = uigetfile({'*.h5;*.mat','Supported formats (*.h5, *.mat)'; '*.h5','Symphony files (*.h5)';'*.mat','Matlab Exports (*.mat)'}, 'Select cells and center data or select symphony .h5 file', 'MultiSelect', 'on');

[p, f, ext] = fileparts([commonPath, fnames]);

%export .h5 file if user selects it, then give them the option to select
%clarinet exports again
if strcmp(ext, '.h5')
    exportH5toMat_symphony2_PP(f, p);
    [fnames, commonPath] = uigetfile('*.mat', 'Select cells and center data to analyze', 'MultiSelect', 'on');
end
    
%initialize the data structure
data = struct();

%load files one at a time, adding them the data structure where the
%subfield is the retina name + cell number, eg data.SH13Lc3
successfulAdds = 0;
foundCenter = 0;
for i = 1:size(fnames,2)
    try
        fileName = fnames{1,i};
    catch
        fileName = fnames;
    end

    %first check if the file is data from a cell
    isCell = regexp(fileName, '^.*(L|R)c\d{1,2}_ClarinetExport.mat$');
    isCenterData = regexp(fileName, '^centerData.*(L|R).mat$');
    
    fullPath = strcat(commonPath, fileName);
    if isCell %will be 1 if file name matches the format for a cell, otherwise 0
        load(fullPath) %loads epochs structure for the cell
        
        cellNameIndex = regexp(fnames{1, i}, '^.*(L|R)c\d{1,2}');%regexp for "__L/Rc##"
        clarinetExportIndex = regexp(fnames{1, i}, '_ClarinetExport.mat');
        cellName = fileName(cellNameIndex:clarinetExportIndex-1);
         
        if exist('epochs', 'var')%if epochs is a varaible in the workspace (it should be)
            
            %!!!!-----------------------------------------------!!!!!!!
            %Clarinet has a bug where it doesn't export the epochs in the
            %same order that they were recorded. Temporary fix is to sort
            %epochs by epoch number here, but should go back and tell Luca
            %about this bug so a permanent fix can be applied. This fix only
            %works if clarinet data is exported cell by cell, which I do
            %anyways.
            sortedEpochs = struct();
            for j = 1:numel(epochs)
                for k = 1:numel(epochs)
                    if epochs(k).meta.epochNum == j
                        sortedEpochs(j).epoch = epochs(k).epoch;
                        sortedEpochs(j).meta = epochs(k).meta;
                        break
                    end
                end
            end
            epochs = sortedEpochs; clear sortedEpochs;
            %!!!!!!!!!!-----------------------------------------!!!!!!!!!
            
            data.(cellName).epochs = epochs;%add cell data to the data structure
            data.(cellName).fileLocation = commonPath;
            disp(['Found data for ' fileName])
            clear('epochs')
            successfulAdds = successfulAdds + 1;
            
        else %Notify user if epochs does not exist for some reason.
            warning(['Could not access recording data for ' fullPath...
                'because the file does not contain a matlab variable named epochs'])
            warndlg(['Could not access recording data for ' fullPath...
                'because the file does not contain a matlab variable named epochs'])
        end
            
    elseif isCenterData
        if foundCenter %executes if more than one centerData file was selected
            warning(['More than one center data file was found.' newline...
                fullPath ' was NOT ADDED to the data structure'])
            warndlg(['More than one center data file was found.' newline...
                fullPath ' was NOT ADDED to the data structure' newline...
                'Remember to analyze only one recording at a time.'])
        else
            load(fullPath)
            data.('centerData') = sizeData; %add sizeData to the data structure in field 'centerData'
            clear('sizeData')
            foundCenter = 1;
            disp(['Found center data ' fileName])
        end
    else
        warning(['Did not grab data from ', fullPath,...
            ' because this file was not identified as a cell or centerData']);
    end
end

if foundCenter && successfulAdds > 0
    disp(['Success! Added data from ' num2str(successfulAdds) ' cells'])
elseif foundCenter == 0 && successfulAdds > 0
    data.('centerData') = struct;
    warning('center data is empty for this cell')
else
    error('Improper files selected. Either no cells or no centerData was selected. Check the cell file name fits the regular expression "^SH\d{2,4}(L|R)c\d{1,2}_ClarinetExport.mat$"')
end

clear p f ext i cellName cellNameIndex commonPath fileName fnames foundCenter fullPath isCell isCenterData successfulAdds j k clarinetExportIndex

