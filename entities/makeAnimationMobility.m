function []=makeAnimationMobility(steps)

%https://es.mathworks.com/help/matlab/import_export/convert-between-image-sequences-and-video.html

%Nombres de ficheros a generar
outputVideo = VideoWriter(fullfile(pwd,'RxTxData.avi'));
outputVideo2 = VideoWriter(fullfile(pwd,'SiteViewer.avi'));

%Frame de cada animación
outputVideo.FrameRate = 0.3;
outputVideo2.FrameRate = 0.3;

open(outputVideo)
open(outputVideo2)

%Directorio donde se obtener las capturas de pantalla
imageNames = dir(fullfile(pwd,'Scenes','*.jpg'));
imageNames2 = dir(fullfile(pwd,'SiteViewer','*.jpg'));
%Ordenamos las capturas almacenadas en los directorios
[~,index1] = sortrows({imageNames.date}.'); imageNames = imageNames(index1); clear index1
[~,index12] = sortrows({imageNames2.date}.'); imageNames2 = imageNames2(index12); clear index12
imageNames = {imageNames.name}';
imageNames2 = {imageNames2.name}';
%Se cogen las capturas pertenecientes a la última ejecución del programa
imageNames = imageNames((length(imageNames)-steps):length(imageNames));
imageNames2 = imageNames2((length(imageNames2)-steps):length(imageNames2));

%Se generan las animaciones 
for ii = 1:length(imageNames),    
   img = imread(fullfile(pwd,'Scenes',imageNames{ii}));
   writeVideo(outputVideo,img)
end

for ii = 1:length(imageNames2),    
   img2 = imread(fullfile(pwd,'SiteViewer',imageNames2{ii}));
   writeVideo(outputVideo2,img2)
end

close(outputVideo)
close(outputVideo2)
end