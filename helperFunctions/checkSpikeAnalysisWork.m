load(fullfile('C:\Users\mrsco\Box\Dunn Lab\Users\Lab\AnalysisPipelines\physiologyPipeline\projects\RoboSlit_physiologyBatch', 'RoboSlit_physiologyBatch.mat'))

priorityOrder_1 = {'Moving_Bar'}; %first field name should be one of these. Priority is in given order
priorityOrder_2 = {'Extracellular'}; %child field name should be one of these. Priority is in given order
mustHave_1 = [];
mustHave_2 = {'_ID1005'};
cantHave_1 = {};
cantHave_2 = {}; %avoid anything with these tags
rigMandates = []; %

pipelinePath = fileparts(which('physiologyPipeline.mlapp'));

terminate = 0;
for i = 1:size(cellList, 1)
    cellName = cellList{i, 1};
    
    a = questdlg(['Examine cell ' cellName]);
    if ~strcmp(a, 'Yes')
        disp(['Skipping cell ' cellName])
        continue
    end

    struct_i = cellList{i, 2};
    [loc, pass] = getLoc(struct_i, priorityOrder_1, mustHave_1, cantHave_1, priorityOrder_2, mustHave_2, cantHave_2, rigMandates);
    if pass
        disp(['Analsysis does not exist for ' cellName ' ...Skipping'])
        continue
    end
    disp(['Pulling analysis for ' cellName])
    clarinetExportPath = fullfile(pipelinePath, struct_i.relativePathFromPipeline);
    cellName = [struct_i.cellID '_ClarinetExport.mat'];
    load(fullfile(clarinetExportPath, cellName));
    spikeTimes = loc.Analysis_Results.allSpikeTimes;
    epochNums = loc.Analysis_Results.EpochNumbers;
    f = figure();
    for j = 1:numel(epochNums)
        fig = uifigure;
        fig.Position = [200 200 400 200];
        a2 = uiconfirm(fig, 'View Next Epoch or Skip Cell', 'Select Next', 'Options', {'View Next Epoch', 'Skip to Next Cell',  'End All'}, 'DefaultOption', 1);
        close(f)
        close(fig)
        if strcmp(a2, 'Skip to Next Cell')
            disp('...skipping any remaining epochs')
            break
        end
        if strcmp(a2, 'End All')
            disp('Terminating')
            terminate = 1;
            break
        end

        e_j = epochNums(j);
        s_j = spikeTimes{j};
        spikeTimes_SR = s_j*10;

        trace = epochs(e_j).epoch;
        spikeHeight = max(trace) + std(trace);
        ys = zeros(1, numel(s_j)) + spikeHeight;
        
        f = figure();
        f.Position(2) = f.Position(2) * 0.7;
        f.Position(3) = f.Position(3) * 1.4;
        f.Position(4) = f.Position(4) * 1.4;
        title(['Cell: ' cellName ' Epoch #' num2str(e_j) ' (' num2str(j) ' of ' num2str(numel(epochNums))])
        hold on
        plot(trace)
        scatter(spikeTimes_SR, spikeHeight, 'kd')
        hold off
    end
    if terminate
        break
    end
    clear epochs
end