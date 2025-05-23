function [preferredDirectionResponsesSuperior, nullDirectionResponsesSuperior,...
    preferredDirectionResponsesInferior, nullDirectionResponsesInferior] = getAverageResponsesRoboSlit(genotype, cellList, stimInfo)

preferredDirectionResponsesSuperior = [];
nullDirectionResponsesSuperior = [];
preferredDirectionResponsesInferior = [];
nullDirectionResponsesInferior = [];
for i = 1:size(cellList, 1)
    struct_i = cellList{i, 2};
    cellName = cellList{i, 1};
    if ~contains(cellName, genotype)
        continue
    end
    [loc, pass] = getLoc(struct_i, stimInfo.priorityOrder_1, stimInfo.mustHave_1, stimInfo.cantHave_1, ...
        stimInfo.priorityOrder_2, stimInfo.mustHave_2, stimInfo.cantHave_2, stimInfo.rigMandates);
    if pass
        continue
    end

    PD = mod(loc.Analysis_Results.PreferredDirection, 360);
    ND = mod(PD+180, 360);

    %average tuning curve:
    [stimDirections, leaf] = sort(loc.Analysis_Results.Orientation);
    averageNumSpikes = loc.Analysis_Results.mean_spikesByOrientation(leaf);

    PDResponse = interp1([stimDirections, stimDirections(1)+360], [averageNumSpikes, averageNumSpikes(1)],...
        PD);
    NDResponse = interp1([stimDirections, stimDirections(1)+360], [averageNumSpikes, averageNumSpikes(1)],...
        ND);

    %PLEASE ENSURE THIS IS CORRECT WITH THE STIMULUS DIRECTION FLIPS ETC
    if PD > 30 && PD < 150
        preferredDirectionResponsesInferior(end+1) = PDResponse;
        nullDirectionResponsesInferior(end+1) = NDResponse;
    elseif PD > 210 && PD < 330
        preferredDirectionResponsesSuperior(end+1) = PDResponse;
        nullDirectionResponsesSuperior(end+1) = NDResponse;
    else
        disp(['Cell With Name ' cellName ' cannot be classified as either Superior or Inferior. Preferred direction was ' num2str(PD), '. Skipping cell.'])
        continue
    end
end

end