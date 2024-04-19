function newPath = changePathSlashesUnix(oldPath)
% This function converts path names to be usable on mac/linux by flipping the
% direction of slashes
% INPUTS:
%     - oldPath: string - old path name
% OUTPUTS:
%     - newPath: string - new path name with slashes flipped if operating system is a mac

if ispc
    newPath = oldPath;
elseif isunix
    newPath = replace(oldPath, '\', '/');
end

end
