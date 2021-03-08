function []=makeAnimationMobility(steps)

%https://es.mathworks.com/help/matlab/import_export/convert-between-image-sequences-and-video.html

outputVideo = VideoWriter(fullfile(pwd,'Resumen_movilidad.avi'));
% outputVideo.FrameRate = shuttleVideo.FrameRate;
outputVideo.FrameRate = 0.3;

open(outputVideo)

imageNames = dir(fullfile(pwd,'Scenes','*.jpg'));
[~,index1] = sortrows({imageNames.date}.'); imageNames = imageNames(index1); clear index1
imageNames = {imageNames.name}';
imageNames = imageNames((length(imageNames)-steps-1):length(imageNames));

for ii = 1:length(imageNames),    %Tengo que coger también mainScene.jpg para el video
   img = imread(fullfile(pwd,'Scenes',imageNames{ii}));
   writeVideo(outputVideo,img)
end

close(outputVideo)
end