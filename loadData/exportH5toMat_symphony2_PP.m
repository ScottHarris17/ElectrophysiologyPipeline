%This script automates the job of exporting .h5 files to a clarinet export.
%exports are saved as .mat files with the cell name + extension
%'_ClarinetExport' to the same folder as the .h5 file. This script uses code
%that is installed with clarinet.

%20221202 - SH
%% User selects .h5 file
function exportH5toMat_symphony2_PP(fName, PathName, numDevices)
fName = fullfile(PathName, [fName, '.h5']);

%% import h5 file
cells = [];
import parsers.*
version = SymphonyParser.getVersion(fName);
if version == 2
    ref = SymphonyV2Parser(fName);
else
    ref = SymphonyV1Parser(fName);  
end
ref.parse;
data = ref.getResult;

cells = [];
for j = 1:numel(data)
  if isempty(cells)
      cells = data{j};
  else
      cells(end+1) = data{j};
  end
end

%% Two Separate saving protocols for 1 Amp versus 2 Amp Experiments
% save a .mat file for each cell in the h5 file
if numDevices == 1 %for 1 amp recordings
    for j = 1:numel(cells)
        disp(['Saving data for cell #', num2str(j)])
        
        FileName = cells(j).get('h5File');
        CellName = cells(j).get('label');
        if iscell(CellName)
            CellName = [CellName{:}];
        end
        for i = 1:numel(cells(j).epochs)
            epoch = cells(j).epochs(i);
            meta = epoch.toStructure;
            device = epoch.get('devices'); %change this if you ever use anything other than Amp_Ch1
            response = epoch.getResponse(device{1});
            epochs(i).epoch = response.quantity'; % Retrieve epoch data
            epochs(i).meta  = meta;
        end
        [~, f] = fileparts(FileName);
        retinaName = f(strfind(f, '_')+1:end);
        cname = [retinaName 'c' CellName(2:end)];
        savename = [cname '_ClarinetExport'];
        save(fullfile(PathName, savename), 'epochs');
        clear epochs
    end
    
%for 2 amp recordings
elseif numDevices == 2
    for j = 1:numel(cells)

        FileName = cells(j).get('h5File');
        PairName = cells(j).get('label');
        if iscell(PairName)
            PairName = [PairName{:}];
        end

        %SOMETHING WEIRD HAPPENS WITH HOW CLARINET READS THE 2 AMPLIFIER
        %RIG SETUP: the cell labels (cell(j).get('label') are not organized
        %in the order that they were recorded. Instead, they get organized
        %in alphabetical order based on the label name (as a string, not a
        %number). So P1, P10, P11, P2, P3.... I solved this by converting the 
        %label given on symphony manually (get rid of the first character
        %in the string, which should be a P for a two amp recording, by
        %convention). I am chopping off the P in the line below, and then
        %converting the remainder of the name to a number. Then the cell
        %numbers are inferred as the PairNumber *2 -1 and PairNumber * 2.
        %If you have the fortitude to improve this (or go back to clarinet
        %and make it export the cells in the correct order), please do!
        %SH20230928
        PairNum = str2num(PairName(2:end));
        
        %first amp
        for i = 1:numel(cells(j).epochs)
            epoch = cells(j).epochs(i);
            meta = epoch.toStructure;
            device = epoch.get('devices'); %change this if you ever use anything other than Amp_Ch1
            response = epoch.getResponse(device{1});
            epochs(i).epoch = response.quantity'; % Retrieve epoch data
            epochs(i).meta  = meta;
            epochs(i).meta.PairName = PairName;
        end
        cellNum = PairNum * 2 - 1;
        disp(['Saving data for pair #', num2str(PairNum), ', cell #' num2str(cellNum)])
        [~, f] = fileparts(FileName);
        retinaName = f(strfind(f, '_')+1:end);
        cname = [retinaName 'c' num2str(cellNum)];
        savename = [cname '_ClarinetExport'];
        save(fullfile(PathName, savename), 'epochs');
        clear epochs

        %second amp
        for i = 1:numel(cells(j).epochs)
            epoch = cells(j).epochs(i);
            meta = epoch.toStructure;
            device = epoch.get('devices'); %change this if you ever use anything other than Amp_Ch1
            response = epoch.getResponse(device{2});
            epochs(i).epoch = response.quantity'; % Retrieve epoch data
            epochs(i).meta  = meta;
            epochs(i).meta.PairName = PairName;
        end
        cellNum = PairNum * 2;
        disp(['Saving data for pair #', num2str(PairNum), ', cell #' num2str(cellNum)])
        [~, f] = fileparts(FileName);
        retinaName = f(strfind(f, '_')+1:end);
        cname = [retinaName 'c' num2str(cellNum)];
        savename = [cname '_ClarinetExport'];
        save(fullfile(PathName, savename), 'epochs');
        clear epochs
    end
end
end



