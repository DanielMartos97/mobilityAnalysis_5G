% data=csvread('214.csv',1,1);
clear
clc
lat_max=;
lat_min=;
lon_max=;
lon_min=;
data=readtable('214.csv');
radio=table2array(data(:,1));
lat=table2array(data(:,8));
lon=table2array(data(:,7));
mnc=table2array(data(:,3));



radio2=strfind(radio,'LTE');
radio3 = find(not(cellfun('isempty',radio2)));
indice=radio3(find(lat(radio3)<lat_max&lat(radio3)>lat_min));
indice2=indice(find(lon(indice)<lon_max&lon(indice)>lon_min));
indice3=indice2(find(mnc(indice2)==3));