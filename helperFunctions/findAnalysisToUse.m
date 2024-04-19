function toUse = findAnalysisToUse(priorityOrder, analyses, mustHave, cantHave)
%Filters available analyses for batch analysis based on the inputs.
    toUse = 'NoneFound';
    for p = 1:numel(priorityOrder) %for each possible analysis name that fits the criteria
        for f = 1:numel(analyses) %for each analysis in this cell
            
            if contains(analyses{f}, priorityOrder{p}) %if the analysis in this cell contains the substring specified by the possible analysis
                potentialAdd = 1; %mark it as possibly good
                
                for a = 1:numel(cantHave) %for each analysis that you should avoid
                    if contains(analyses{f}, cantHave{a}) %if the analysis in this cell contains the avoid substring
                        potentialAdd = 0; %mark this analysis as no good
                        break
                    end
                end
                
                for m = 1:numel(mustHave) %for each substring that the analysis name must have, check here
                    if ~contains(analyses{f}, mustHave{m})
                        potentialAdd = 0;
                        break
                    end
                end
                
                if potentialAdd %if it's still a good add
                    toUse = analyses{f}; %return the analysis name
                    return %exit the function
                end
            end
        end
    end
end