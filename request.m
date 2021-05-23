function [] = request(parameters)
addpath('entities', 'connectors', 'use_cases', 'repositories');

timer=createTimer;
start(timer)  %Start Timer;

%% Parameters

%INPUT PARAMETERS-COMPANIES AND USERS
FILTER_CELLS_BY_COMPANY = parameters.filter_by_company;
%Se elige y se filtra por cada país
COUNTRY_ID = str2double(parameters.country); % Spain = 214; Australia = 505 (MCC)
if COUNTRY_ID==214
    COMPANY_ID = str2double(parameters.companySpain); % Vodafone = 1; Orange = 3; Telefonica = 7 (ver MNC wikipedia)
else
    COMPANY_ID = str2double(parameters.companyAustralia); % Telstra = 1; Optus = 2; Vodafone = 3 (ver MNC wikipedia)
end
NUMBER_OF_RECEIVERS = parameters.number_of_receivers;
BW = parameters.individual_bw; % MHz
%Random Distribution Receivers
distributionReceivers=parameters.distributionReceivers;

%INPUT PARAMETERS-TX MODELS
UMA_TX_POWER = parameters.uma_power; % Watts = 44 dBm
UMI_COVERAGE_TX_POWER = parameters.umi_coverage_power;
UMI_HOTSPOT_TX_POWER = parameters.umi_hotspot_power;
UMI_BLIND_SPOT_TX_POWER = parameters.umi_blind_power;
UMI_ISD = parameters.umi_coverage_isd; % meters

UMA_FREQUENCY = parameters.uma_frequency;
UMI_COVERAGE_FREQUENCY = parameters.umi_coverage_frequency;
UMI_HOTSPOT_FREQUENCY = parameters.umi_hotspot_frequency;
UMI_BLIND_SPOT_FREQUENCY = parameters.umi_blind_frequency;

%INPUT PARAMETERS-MAP AND MODE
lat_min = parameters.minimum_latitude;
lon_min = parameters.minimum_longitude;
lat_max = parameters.maximum_latitude;
lon_max = parameters.maximum_longitude;
IS_COVERAGE_MODE = parameters.coverage;
MAX_NUMBER_OF_ATTEMPTS = parameters.max_attempts;
DOWNLOAD_MAP = parameters.download_map_file;

%INPUT PARAMETERS-MOBILITY ANALYSIS
total_time=parameters.total_time;
step=parameters.step;
if step==0,
    step=1; %Matlab no nos permite que un índice sea 0
end

%INPUT PARAMETERS-SIMULATION RX
filename=parameters.filename;

%Se identifica la extension del archivo subido
if ~isempty(filename),
    file_extension=split(filename,'.');
    if strcmp(file_extension{2},'xlsx')
       data_file=xlsread(filename);
       format long;
       if size(data_file,2)>2
            data_file(:,2:4)=[];data_file(:,23)=[];
       end
    elseif strcmp(file_extension{2},'csv')
       data_file=readtable(filename);
       format long;
       if size(data_file,2)>2
            data_file(:,2:4)=[];data_file(:,23)=[];
            data_file=table2array(data_file);
       else
            data_file=table2array(data_file);
       end
    end
end

networkcellinfo=parameters.networkcellinfo;  %Se indica si el archivo tiene un formato igual al devuelto por la app móvil

direction_duration=parameters.duration;
direction_speed=parameters.speed;
direction_distance=parameters.distance;
if direction_duration==0,
    direction_duration=direction_distance/direction_speed;
elseif direction_speed==0,
    direction_speed=direction_distance/direction_duration;
elseif direction_distance==0,
    direction_distance=direction_duration*direction_speed;
end

%INPUT PARAMETERS-DEPLOYMENT
UMA_ANALYSIS=parameters.uma;
UMI_GRID=parameters.grid;
UMI_HOTSPOT=parameters.hotspot;
UMI_BLIND=parameters.blind;

%INPUT PARAMETERS-PROPAGATION MODEL 
if parameters.longley_rice
    PROPAGATION_MODEL = 'longley-rice';
else
    PROPAGATION_MODEL = 'raytracing-image-method';
end

%% Constants
UMA_NAME = 'UMA';
UMI_COVERAGE_NAME = 'UMI cov';
UMI_HOTSPOT_NAME = 'UMI h';
UMI_BLIND_SPOT_NAME = 'UMI bs';
UMA_ANTENNA = 'sector';
UMI_ANTENNA = 'isotropic';
UMA_HEIGHT = 25; % meters
UMI_HEIGHT = 10; % meters
uma_tx_model = tx_model(UMA_FREQUENCY, UMA_TX_POWER, UMA_ANTENNA, UMA_HEIGHT, UMA_NAME);
umi_coverage_model = tx_model(UMI_COVERAGE_FREQUENCY, UMI_COVERAGE_TX_POWER, UMI_ANTENNA, UMI_HEIGHT, UMI_COVERAGE_NAME);
umi_hotspot_model = tx_model(UMI_HOTSPOT_FREQUENCY, UMI_HOTSPOT_TX_POWER, UMI_ANTENNA, UMI_HEIGHT, UMI_HOTSPOT_NAME);
umi_blind_spot_model = tx_model(UMI_BLIND_SPOT_FREQUENCY, UMI_BLIND_SPOT_TX_POWER, UMI_ANTENNA, UMI_HEIGHT, UMI_BLIND_SPOT_NAME);

%% SiteViewer
disp("Generating map...");
coordinates_bbox = location_bbox(lat_min, lat_max, lon_min, lon_max);

bbox_map = coordinates_bbox.get_maps_bbox_string();
if (DOWNLOAD_MAP)
    download_buildings_from_openstreetmap(bbox_map);
end
map = siteviewer('Buildings', 'map.osm');   %Abre el mapa
% close(map)
disp("Downloading existing cells location...");
bbox_cells = coordinates_bbox.get_cells_bbox_string();  %Coordenadas del área.

%% Filter cells if needed
%Además de filtrar por compañía se filtrará por país obteniendo varías
%compañías para cada país
if networkcellinfo==0,     %Si no se ha subido un fichero desde Network Cell Info
    if (FILTER_CELLS_BY_COMPANY)
        %En este caso, se filtrará por país y compañía
        selected_phone_cells=get_cells_from_opensignal(bbox_cells,COUNTRY_ID,COMPANY_ID,0); 
    else
        phone_cells=get_cells_from_opensignal(bbox_cells);
    end
else                       %Si se ha subido un fichero desde Network Cell Info
     uma_cellid=data_file(:,8);
     uma_cellid = deduplicate_transmitters_from_cellid(uma_cellid); %Se obtiene el listado de cellID que recorre el receptor
     %En este caso, se filtrará por país, compañía y cellID
     selected_phone_cells=get_cells_from_opensignal(bbox_cells,COUNTRY_ID,COMPANY_ID,uma_cellid); 

end

%% Users - receivers
disp("Generating receivers...");
if DOWNLOAD_MAP
    social_attractors_coordinates = coordinates_bbox.get_social_attractors_bbox_string();
    system('python main.py ' + social_attractors_coordinates);
else
    system('python main.py');
end

[social_attractors_latitudes, social_attractors_longitudes, ...
    social_attractors_weighting] = read_buildings_file();

if isempty(filename)    %Si no se ha subido un fichero con las coordenadas de los receptores
    if distributionReceivers==0,   %Si no está seleccionada la opción de distribución aleatoria de Rx
    
        [receivers_latitudes, receivers_longitudes] = generate_receivers_from_social_attractors(...
            social_attractors_latitudes, social_attractors_longitudes, ...
            social_attractors_weighting, NUMBER_OF_RECEIVERS, coordinates_bbox);
        receivers = rxsite(...
        'Latitude', receivers_latitudes, ...
        'Longitude', receivers_longitudes, ...
        'AntennaHeight', 1.5);
    else                            %Si está seleccionada la opción de distribución aleatoria de Rx
        %Se generan las coordenadas aleatorias de los receptores dentro del
        %área indicada.
        %Latitud
        receivers_latitudes=(lat_max-lat_min).*rand(NUMBER_OF_RECEIVERS,1)+lat_min;
        %Longitud
        receivers_longitudes=(lon_max-lon_min).*rand(NUMBER_OF_RECEIVERS,1)+lon_min;
        receivers = rxsite(...
        'Latitude', receivers_latitudes, ...
        'Longitude', receivers_longitudes, ...
        'AntennaHeight', 1.5);
    end
else     %Si se ha subido un fichero con las coordenadas de los receptores
    if networkcellinfo==1,  %En este caso, el fichero proviene de la app Network Cell Info
        receivers = rxsite(...
            'Latitude', data_file(1,15), ...
            'Longitude', data_file(1,16), ...
            'AntennaHeight', 1.5);
    else                    %En este caso, el fichero solamente incorporará dos columnas (Latitud y longitud)
        receivers = rxsite(...
            'Latitude', data_file(1,1), ...
            'Longitude', data_file(1,2), ...
            'AntennaHeight', 1.5);
    end    
end

%% UMA and UMI Transmitters generation
%Dependiendo de las opciones marcadas en la interfaz del usuario se
%generarán unos u otros transmisores
umi_transmitters=[];
tx_analysis=[];
if (UMA_ANALYSIS==1)
    if networkcellinfo==1,    %Si se ha subido un fichero desde Network Cell Info
        disp("Generating UMa layer...");
        selected_phone_cells=struct2table(selected_phone_cells);
        %Coordenadas de las estaciones base devueltas por la API de
        %OpenCellID
        uma_latitudes=selected_phone_cells(:,1).lat;
        uma_longitudes=selected_phone_cells(:,2).lon;
        uma_transmitters = get_transmitters_from_coordinates(uma_latitudes, uma_longitudes, uma_tx_model);
        [data_latitudes, data_longitudes, uma_grid_size, uma_sinr_data] = calculate_sinr_values_map(uma_transmitters, coordinates_bbox, PROPAGATION_MODEL);

        tx_analysis=[tx_analysis uma_transmitters];   %Se añaden las estaciones base encontradas
    else                     %Si no se ha subido un fichero desde Network Cell Info
        disp("Generating UMa layer...");
        [uma_latitudes, uma_longitudes] = get_coordinates_from_cells(selected_phone_cells);
        uma_transmitters = get_transmitters_from_coordinates(uma_latitudes, uma_longitudes, uma_tx_model);
        [data_latitudes, data_longitudes, uma_grid_size, uma_sinr_data] = calculate_sinr_values_map(uma_transmitters, coordinates_bbox, PROPAGATION_MODEL);

        tx_analysis=[tx_analysis uma_transmitters];   %Se añaden las estaciones base encontradas
    end
end
if (UMI_HOTSPOT==1)
    % UMI capacity - Social attractors
    disp("Generating UMi close to social attractors");
    [umi_cell_latitudes, umi_cell_longitudes] =  calculate_small_cells_from_social_attractors(social_attractors_latitudes, social_attractors_longitudes, social_attractors_weighting);
    if ~isempty(umi_cell_latitudes)   %Si se encuentran puntos de gran afluencia donde colocar este tipo de estaciones base
        [umi_cell_latitudes, umi_cell_longitudes] = deduplicate_transmitters_from_coordinates(umi_cell_latitudes, umi_cell_longitudes);
        umi_transmitters_hotspot = get_transmitters_from_coordinates(umi_cell_latitudes, umi_cell_longitudes, umi_hotspot_model);
        
        tx_analysis=[tx_analysis umi_transmitters_hotspot];   %Se añaden las nuevas estaciones al resto
        umi_transmitters=[umi_transmitters umi_transmitters_hotspot];   %Se añaden las nuevas estaciones al grupo de UMIs
        [umi_data_latitudes, umi_data_longitudes, best_umi_grid_size, umi_sinr_data] = calculate_sinr_values_map(umi_transmitters, coordinates_bbox, PROPAGATION_MODEL);
    end
end
if (UMI_GRID==1)
    % UMI capacity - hexagons
    disp("Generating UMi distributed layer");
    [distributed_latitudes, distributed_longitudes] = distribute_umi_cells_among_box(coordinates_bbox, UMI_ISD);
    umi_transmitters_grid = get_transmitters_from_coordinates(distributed_latitudes, distributed_longitudes, umi_coverage_model);
    tx_analysis=[tx_analysis umi_transmitters_grid];         %Se añaden las nuevas estaciones al resto
    umi_transmitters=[umi_transmitters umi_transmitters_grid];      %Se añaden las nuevas estaciones al grupo de UMIs
    [umi_data_latitudes, umi_data_longitudes, best_umi_grid_size, umi_sinr_data] = calculate_sinr_values_map(umi_transmitters, coordinates_bbox, PROPAGATION_MODEL);

end
if (UMI_BLIND==1)
    % UMI coverage - blind points
    disp("Generating UMi to cover blind points");
    [merged_latitudes, merged_longitudes, merged_grid_size, best_sinr_data] = calculate_sinr_values_map(tx_analysis, coordinates_bbox, PROPAGATION_MODEL);
    [new_umi_cell_latitudes, new_umi_cell_longitudes] = ...
        calculate_small_cells_coordinates_from_sinr(best_sinr_data, ...
        data_latitudes, data_longitudes);
    umi_transmitters_blind = get_transmitters_from_coordinates(new_umi_cell_latitudes, new_umi_cell_longitudes, umi_blind_spot_model);
    
    tx_analysis=[tx_analysis umi_transmitters_blind];       %Se añaden las nuevas estaciones al resto
    umi_transmitters=[umi_transmitters umi_transmitters_blind];          %Se añaden las nuevas estaciones al grupo de UMIs
    [umi_data_latitudes, umi_data_longitudes, best_umi_grid_size, umi_sinr_data] = calculate_sinr_values_map(umi_transmitters, coordinates_bbox, PROPAGATION_MODEL);

end

%% Results
disp("Showing final map...");
%% Captura de escenario con código JAVA
import java.awt.*;
import java.awt.event.*;
%Create a Robot-object to do the key-pressing
%Commands for pressing keys:
[merged_latitudes, merged_longitudes, merged_grid_size, best_sinr_data] = calculate_sinr_values_map(tx_analysis, coordinates_bbox, PROPAGATION_MODEL);
show(receivers, 'Icon', 'pins/receiver.png', 'IconSize', [18 18],'Animation','none');
plot_values_map(tx_analysis, merged_latitudes, merged_longitudes, merged_grid_size, best_sinr_data);
rob=Robot;
rob.keyPress(KeyEvent.VK_WINDOWS);
rob.keyPress(KeyEvent.VK_UP);
rob.keyRelease(KeyEvent.VK_UP);
rob.keyRelease(KeyEvent.VK_WINDOWS);
pause(5);
show_legend(map);
close(map);
%% UMI Backhaul
if ~isempty(umi_transmitters)
    disp("Computing backhaul...");
    all_the_transmitters = [umi_transmitters uma_transmitters];
    backhaul_matrix = get_backhaul_relation(uma_transmitters, umi_transmitters);

    for i = 1:length(backhaul_matrix)
        current_uma = backhaul_matrix(i);
        if current_uma ~= 0
            los(uma_transmitters(current_uma), umi_transmitters(i));
        end
    end
end

%% Directions Receivers
disp("Generating coordenates for each receiver.");
if isempty(filename) %Si no se ha subido un fichero con las coordenadas de los receptores
    if total_time~=0 && step~=1, %Si se quiere estudiar la movilidad de los receptores
        %Latitud
        latitudes_aleatorias=(lat_max-lat_min).*rand(NUMBER_OF_RECEIVERS,1)+lat_min;
        %Longitud
        longitudes_aleatorias=(lon_max-lon_min).*rand(NUMBER_OF_RECEIVERS,1)+lon_min;

        %Genero una matriz de modos aleatorios para los receptores
        modos_transporte=randi([0 2],1,NUMBER_OF_RECEIVERS);

        api_key='-NqbbgbdNAjen1jTPULtFaTkiCuW8gX3ZdFa1cuWY5o';   %API KEY Here maps

        for rx=1:NUMBER_OF_RECEIVERS,

            coordinates_start=num2str(receivers_latitudes(rx),10)+","+num2str(receivers_longitudes(rx),10);   %Coordenada inicial de la ruta
            coordinates_end=num2str(latitudes_aleatorias(rx),10)+","+num2str(longitudes_aleatorias(rx),10);   %Coordenada final de la ruta
            mode=modos_transporte(rx);
            get_directions_receivers(mode,api_key,coordinates_start,coordinates_end);
            fichero=jsondecode(fileread('polyline.json'));
            if isempty(fichero.routes)  %La API no ha encontrado una ruta adecuada para los datos indicados
                coordinates=strsplit(coordinates_start,',');
                users(rx).latOut=coordinates(1);
                users(rx).lonOut=coordinates(2);
                users(rx).duration=0;
                users(rx).distance=0;
                users(rx).speed=0;
                users(rx).step=1;  %segundos/coordenada
            else                        %La API ha encontrado una ruta adecuada para los datos indicados
                users(rx).polyline=fichero.routes.sections.polyline;
                system(['python decoder_flexpolyline.py ' users(rx).polyline]);
                users(rx).latOut=importdata('latitudes.txt');
                users(rx).lonOut=importdata('longitudes.txt');
                fichero2=jsondecode(fileread('summary.json'));
                users(rx).duration=fichero2.routes.sections.summary.duration;
                users(rx).distance=fichero2.routes.sections.summary.length;
                users(rx).speed=users(rx).distance/users(rx).duration;
                users(rx).step=users(rx).distance/length(users(rx).latOut);  %segundos/coordenada
            end    
        end
    else    %Si no se quiere estudiar la movilidad de los receptores
        for rx=1:NUMBER_OF_RECEIVERS,
            users(rx).latOut=receivers_latitudes(rx);
            users(rx).lonOut=receivers_longitudes(rx);
            users(rx).speed=0;  %m/s
            users(rx).distance=0;
            users(rx).step=1;
        end
        
    end
else     %Si se ha subido un fichero con las coordenadas de los receptores
    if networkcellinfo==1    %En este caso, el fichero proviene de la app Network Cell Info
        users.latOut=data_file(:,15);
        users.lonOut=data_file(:,16);
        users.speed=direction_speed;  %m/s
        users.distance=direction_distance;
        users.step=users.distance/length(users.latOut);
        NUMBER_OF_RECEIVERS=1;  %Inicializamos la variable a 1 para evitar errores
    else                    %En este caso, el fichero solamente incorporará dos columnas (Latitud y longitud)
        users.latOut=data_file(:,1);
        users.lonOut=data_file(:,2);
        users.speed=direction_speed;  %m/s
        users.distance=direction_distance;
        users.step=users.distance/length(users.latOut);
        NUMBER_OF_RECEIVERS=1;  %Inicializamos la variable a 1 para evitar errores
    end
end

%% Mobility analysis

%Inicialización de variables
sinr_receivers=[];
rsnr=[];
time=1;
connect_user=[];

for t=1:step:total_time+1  %segundos
    disp(['Computing results of mobility - ' num2str(t-1) 's']);
    %Escojo la coordenada en la que va a estar cada rx en cada instante de
    %tiempo
    for rx=1:NUMBER_OF_RECEIVERS,
        m=(t-1)*users(rx).speed;   %m/s --> m
        if users(rx).step~=0   %En este caso, se estudiará la movilidad a lo largo de unos instantes de tiempo
            indice=round(m/users(rx).step)+1;
        else                    %En este caso, no se estudiará la movilidad 
            indice=1;
        end
        if indice>length(users(rx).latOut)
            indice=length(users(rx).latOut);
        end
        receivers_latitudes(rx)=users(rx).latOut(indice);       %Coordenadas del Rx en un instante de tiempo
        receivers_longitudes(rx)=users(rx).lonOut(indice);
    end
    
    %Coordenadas de los receptores
    receivers = rxsite(...
    'Latitude', receivers_latitudes, ...
    'Longitude', receivers_longitudes, ...
    'AntennaHeight', 1.5);
    %Coordendas de referencia para centrar la vista del SiteViewer
    margen=0.0025;
    siteViewer_references=rxsite(...
    'Latitude', [lat_max lat_min], ...
    'Longitude', [lon_max lon_min], ...
    'AntennaHeight', 1.5);
    
    %Visualización de la escena en un instante de tiempo
    map = siteviewer('Buildings', 'map.osm');   %Abre el mapa
    show(receivers, 'Icon', 'pins/receiver.png', 'IconSize', [18 18],'Animation','none');
    plot_values_map(tx_analysis, merged_latitudes, merged_longitudes, merged_grid_size, best_sinr_data);
    pause(2);
    rob.keyPress(KeyEvent.VK_WINDOWS);  %Maximizo la ventana
    rob.keyPress(KeyEvent.VK_UP);
    rob.keyRelease(KeyEvent.VK_UP);
    rob.keyRelease(KeyEvent.VK_WINDOWS);
    pause(2);
    show(siteViewer_references, 'IconSize', [1 1],'Animation','zoom');
    pause(2);
    show_legend(map);
    pause(2);
    disp("Generating screenshot of SiteViewer");
    %La captura se guardará en la carpeta SiteViewer
    filename=['SiteViewer/SiteViewer_' num2str(t-1) 's.jpg'];
    
    %Commands for pressing keys:
    %Screen capture
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    rectangle = java.awt.Rectangle(toolkit.getScreenSize());
    image = rob.createScreenCapture(rectangle);
    filehandle = java.io.File(filename);
    javax.imageio.ImageIO.write(image,'jpg',filehandle);
    close(map);  %Cierro la ventana del Site Viewer
    
    %Calculo la sinr que hay en la posición de cada receptor
    rx_gain = 2.1;
    sinr_data = sinr(receivers, tx_analysis, ...
        'PropagationModel', PROPAGATION_MODEL, ...
        'ReceiverGain', rx_gain);
    %Calculo el nivel de señal que hay en la posición de cada receptor
    signal_strength_data = sigstrength(receivers, tx_analysis, ...
        'PropagationModel', PROPAGATION_MODEL);
    %Guardo los resultados para cada Rx en un instante de tiempo determinado
    sinr_receivers(time,:)=sinr_data';
    signal_receivers(time,:)=min(signal_strength_data);
    %Si el archivo subido proviene de Network Cell Info, se almacenarán los
    %resultados de sinr y señal recibida obtenidos por la app para su
    %posterior comparación
    if networkcellinfo==1
       rsnr(time,:)=data_file(indice,24);   %Network Cell Info
       signal(time,:)=data_file(indice,14);   %Network Cell Info
    end
      
    % Results
    disp("Generating SINR matrix for all the receivers");
    sinr_matrix = get_sinr_matrix_for_all_the_transmitters(receivers, tx_analysis);
    count = 0;
    for i = 1:length(sinr_matrix(1, :))
        contains1 = false;
        for j = 1:length(sinr_matrix(:, 1))
            if sinr_matrix(j, i) > 0
                contains1 = true;
            end
        end
        if contains1
            count = count + 1;  %Indica los receptores tienen al menos un valor de SINR positivo
        end
    end
    sinr_matrix(sinr_matrix < 0) = 0;
    capacity_matrix = BW * log2(1 + sinr_matrix);

    disp("Computing pairing...");
    pairing_capacity = zeros(1, NUMBER_OF_RECEIVERS);
    pairing_matrix = zeros(1, NUMBER_OF_RECEIVERS);
    pairing_names = cellstr('');
    total_capacity = zeros(1, length(tx_analysis));
    for i = 1:NUMBER_OF_RECEIVERS
        [value, index] = max(capacity_matrix(:, i));

        pairing_matrix(i) = index;
        pairing_names(i) = cellstr(string(tx_analysis(index).Name));
        pairing_capacity(i) = value;
        total_capacity(index) = total_capacity(index) + value;
    end
    if ~isempty(umi_transmitters)
        traffic_uma = zeros(1, length(uma_transmitters));
        for i = 1:length(traffic_uma)
            linked_umi = find(backhaul_matrix == i);
            for j = 1:length(linked_umi)
                traffic_uma(i) = traffic_uma(i) + total_capacity(linked_umi(j));
            end
        end
    end
    
    %Creamos la etiquetas para receptores y transmisores 
    label_rx={};  %Creamos el cell array de etiquetas
    label_tx={};
    rx_names=strings(1,length(receivers));
    tx_names=strings(1,length(tx_analysis));

    cont=1; %Inicializamos contador

    %Label Rx
    for i=1:length(receivers),
         label_rx{i}={['RX' num2str(i) '^{' num2str(sinr_data(i)) 'dB}_{' pairing_names{i} '}']};
         rx_names(i)=['Rx' num2str(i)];
    end

    %Label Tx
    u=0;
    for k=1:3:length(uma_transmitters)    %Obtengo los datos de UMA
        tx_name=strsplit(tx_analysis(k).Name);
        if networkcellinfo==1
            label_tx{cont}={[tx_name{1} tx_name{2} '^{' num2str(length(find(pairing_matrix == k | pairing_matrix == k+1 | pairing_matrix == k+2))) '}_{' num2str(uma_cellid(k-u)) '}']};
        else
            label_tx{cont}={[tx_name{1} tx_name{2} '^{' num2str(length(find(pairing_matrix == k | pairing_matrix == k+1 | pairing_matrix == k+2))) '}']};
        end
        tx_names(cont)=[tx_name{1} tx_name{2}];
        tx_latitudes(cont)=tx_analysis(k).Latitude;
        tx_longitudes(cont)=tx_analysis(k).Longitude;
        cont=cont+1;
        u=u+2;
    end
    
    for k=(length(uma_transmitters)+1):length(tx_analysis),        %Obtengo los datos de UMI
        tx_latitudes(cont)=tx_analysis(k).Latitude;
        tx_longitudes(cont)=tx_analysis(k).Longitude;
        tx_names(cont)=tx_analysis(k).Name;
        label_tx{cont}={[tx_analysis(k).Name '^{' num2str(length(find(pairing_matrix == k))) '}']};
        cont=cont+1;
    end
    
    tx_names=tx_names(1:cont-1);
    
    disp("Showing SINR of each receiver...");
    %Represento los valores de sinr de cada rx
    figure();
    plot(receivers_longitudes, receivers_latitudes, 'ks','MarkerSize',2,'MarkerFaceColor','r');
    margen2=0.0035;
    ylim([lat_min-margen2 lat_max+margen2])
    xlim([lon_min-margen2 lon_max+margen2])
    title(['Time: ' num2str(t-1) 's.']);
%   plot_openstreetmap('Alpha', 0.5, 'Scale', 2, 'BaseUrl', "https://a.tile.openstreetmap.org");
    plot_openstreetmap('Alpha', 0.5, 'Scale', 2, 'BaseUrl', "http://a.tile.openstreetmap.fr/hot");
    rob.keyPress(KeyEvent.VK_WINDOWS);  %Muevo la ventana a la derecha
    rob.keyPress(KeyEvent.VK_RIGHT);
    rob.keyRelease(KeyEvent.VK_RIGHT);
    rob.keyRelease(KeyEvent.VK_WINDOWS);
    pause(2);
    set(gca, 'LooseInset', [0,0,0,0]);
    label_rx=text(receivers_longitudes,receivers_latitudes,string(label_rx),'HorizontalAlignment','center','FontSize',12);
    
    disp("Showing users connected...");
    %Represento los valores de usuarios conectados de cada tx
    figure();
    plot(tx_longitudes, tx_latitudes, 'ks','MarkerSize',2,'MarkerFaceColor','r');
    ylim([lat_min-margen lat_max+margen])
    xlim([lon_min-margen lon_max+margen])
    title(['Time: ' num2str(t-1) 's.']);
    plot_openstreetmap('Alpha', 0.5, 'Scale', 2, 'BaseUrl', "http://a.tile.openstreetmap.fr/hot");
    rob.keyPress(KeyEvent.VK_WINDOWS);  %Muevo la ventana a la izquierda
    rob.keyPress(KeyEvent.VK_LEFT);
    rob.keyRelease(KeyEvent.VK_LEFT);
    rob.keyRelease(KeyEvent.VK_WINDOWS);
    pause(2);
    set(gca, 'LooseInset', [0,0,0,0]);
    label_tx=text(tx_longitudes,tx_latitudes,label_tx,'HorizontalAlignment','center','FontSize',12);
    %Indico con colores el tipo de red al que se conecta cada RX
    for i=1:NUMBER_OF_RECEIVERS,
        if contains(pairing_names(i),"cell"),
            label_rx(i).Color='red';
        elseif contains(pairing_names(i), "cov"),
            label_rx(i).Color='blue';
        elseif contains(pairing_names(i), "b"),
            label_rx(i).Color=[6 171 8]/255;
        elseif contains(pairing_names(i), "h")
            label_rx(i).Color=[1 0.56 0];
        end
    end
    %Indico con colores el tipo de Tx 
    for i=1:length(label_tx),
        if contains(label_tx(i).String,"Tx"),
            label_tx(i).Color='red';
        elseif contains(label_tx(i).String, "cov"),
            label_tx(i).Color='blue';
        elseif contains(label_tx(i).String, "b"),
            label_tx(i).Color=[6 171 8]/255;
        elseif contains(label_tx(i).String, "h")
            label_tx(i).Color=[1 0.56 0];
        end
    end
    
    %La captura se guardará en la carpeta Scene
    filename=['Scenes/Scene_' num2str(t-1) 's.jpg'];
    
    %Commands for pressing keys:
    %Screen capture
    pause(2)
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    rectangle = java.awt.Rectangle(toolkit.getScreenSize());
    image = rob.createScreenCapture(rectangle);
    filehandle = java.io.File(filename);
    javax.imageio.ImageIO.write(image,'jpg',filehandle);
    close all

    
    tx_user=[];
    %% Results for uma
    disp("Saving results...");
    filename=['Summary/summary' num2str(t-1) 's.txt'];
    file_id = fopen(filename,'w');
    for i = 1:3:length(uma_transmitters)-2
        transmitter_offset = length(umi_transmitters);
        name = "Name: " + uma_transmitters(i).Name;
        location = " - Location: " + uma_transmitters(i).Latitude + " , " + uma_transmitters(i).Longitude;
        power = " - Power: " + uma_transmitters(i).TransmitterPower + " W";
        frequency = " - Frequency: " + uma_transmitters(i).TransmitterFrequency/1e9 + " GHz";
        angles = " - Sector angles: " + uma_transmitters(i).AntennaAngle + " " + uma_transmitters(i+1).AntennaAngle + " " + uma_transmitters(i+2).AntennaAngle;
        connected_users = " - Connected users: " + length(find(pairing_matrix == i + transmitter_offset | pairing_matrix == i+1 + transmitter_offset | pairing_matrix == i+2 + transmitter_offset));
        if length(find(pairing_matrix == i + transmitter_offset | pairing_matrix == i+1 + transmitter_offset | pairing_matrix == i+2 + transmitter_offset))==0
            tx_user= [tx_user -0.25];   %Aquellas estaciones que no tengan usuarios conectados aparecerán con un valor negativo en su barra
        else
            tx_user= [tx_user length(find(pairing_matrix == i + transmitter_offset | pairing_matrix == i+1 + transmitter_offset | pairing_matrix == i+2 + transmitter_offset))];
        end
        users_traffic = " - Traffic demanded by users: " + sum(total_capacity(transmitter_offset+i : transmitter_offset+i+2)) + " Mbps";
        if ~isempty(umi_transmitters)
            umi_traffic = " - Traffic demanded by UMis: " + sum(traffic_uma(i:i+2)) + " Mbps";
            fprintf(file_id, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n', name, location, power, frequency, angles, connected_users, users_traffic, umi_traffic);
        else
            fprintf(file_id, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n', name, location, power, frequency, angles, connected_users, users_traffic);
        end
    end

    %% Results for umi
    if ~isempty(umi_transmitters)    %En el caso, de que existan en el escenario estudiado UMIs
        for i = 1:length(umi_transmitters)
            name = "Name: " + umi_transmitters(i).Name;
            location = " - Location: " + umi_transmitters(i).Latitude + " , " + umi_transmitters(i).Longitude;
            power = " - Power: " + umi_transmitters(i).TransmitterPower + " W";
            frequency = " - Frequency: " + umi_transmitters(i).TransmitterFrequency/1e9 + " GHz";
            connected_users = " - Connected users: " + length(find(pairing_matrix == i));
            if length(find(pairing_matrix==i))==0,
                tx_user= [tx_user -0.25];    %Aquellas estaciones que no tengan usuarios conectados aparecerán con un valor negativo en su barra
            else
                tx_user= [tx_user length(find(pairing_matrix == i))];
            end

            users_traffic = " - Traffic demanded by users: " + sum(total_capacity(i)) + " Mbps";
            connected_to = " - Backhaul to: " + uma_transmitters(backhaul_matrix(i)).Name;
            pointing_to = " - Backhaul to coordinates: " + uma_transmitters(backhaul_matrix(i)).Latitude + " , " + uma_transmitters(backhaul_matrix(i)).Longitude;
            fprintf(file_id, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n', name, location, power, frequency, connected_users, users_traffic, connected_to, pointing_to);
        end
        umi_coverage = length(find(umi_sinr_data > 0))/length(umi_sinr_data)*100;
        umi_coverage_message = " - UMi layer coverage: " + umi_coverage + " %";
        total_umi = " - Total number of UMi: " + length(umi_transmitters);

    end
    %% Summary
    a = txsite("Latitude", lat_max, "Longitude", lon_max);
    b = txsite("Latitude", lat_min, "Longitude", lon_max);
    c = txsite("Latitude", lat_min, "Longitude", lon_min);
    height = distance(a, b)/1000; % km
    wide = distance(b, c)/1000; % km
    area = height*wide; % km^2

    coverage = length(find(best_sinr_data > 0))/length(best_sinr_data)*100;
    uma_coverage = length(find(uma_sinr_data > 0))/length(uma_sinr_data)*100;
    users_coverage = NUMBER_OF_RECEIVERS - count;
    traffic = sum(total_capacity)/NUMBER_OF_RECEIVERS;
    traffic_area = sum(total_capacity)/area;

    coverage_message = " - Total coverage (UMa + UMi): " + coverage + " % (area with SINR > 0 dB)"; 
    uma_coverage_message = " - UMa layer coverage: " + uma_coverage + " %";
    users_coverage_message = " - Users whose SINR < 0 dB: " + users_coverage + " out of " + NUMBER_OF_RECEIVERS;
    total_network_traffic = " - Total Network traffic: " + sum(total_capacity) + " Mbps";
    mean_traffic = " - Mean traffic per user: " + traffic + " Mbps";
    traffic_area_message = " - Traffic / area: " + traffic_area + " Mbps/Km^2";
    total_uma = " - Total number of UMa: " + length(uma_transmitters);

    fprintf(file_id, '\n------- SUMMARY ------- \n');
    if ~isempty(umi_transmitters)  %Si no se considera desplegar UMIs no se tendrá en cuenta en el informe final
        fprintf(file_id, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n', coverage_message, uma_coverage_message, umi_coverage_message, users_coverage_message, total_network_traffic, mean_traffic, traffic_area_message, total_uma, total_umi);
        fclose(file_id);
        disp("Finished! You can check the summary openning summary.txt");
    else
        fprintf(file_id, '%s\n%s\n%s\n%s\n%s\n%s\n%s\n', coverage_message, uma_coverage_message, users_coverage_message, total_network_traffic, mean_traffic, traffic_area_message, total_uma);
        fclose(file_id);
        disp("Finished! You can check the summary openning summary.txt");
    end

connect_user(time,:)=tx_user;  %Usuarios conectados a cada Tx en cada instante de tiempo
time=time+1;  %Incremento del instante de tiempo en cada iteración

end

if total_time~=0,       %Siempre que se estudie la movilidad...
    if NUMBER_OF_RECEIVERS<=8   %Siempre que el número de Rx sea menor o igual a 8...
        figure();
        plot(1:step:total_time+1,sinr_receivers);  %Representación de valores SINR para cada Rx en cada instante de tiempo
        legend(rx_names);
        title('SINR DATA RECEIVERS');xlabel('Time (s)');ylabel('SINR (dB)');
        if networkcellinfo==1      %Si el archivo subido proviene de Network Cell Info, se realizará una comparación
            indices=find(rsnr<-50);
            rsnr(indices)=0;      %Los outlayers obtenidos por la app móvil se convertirán a valores nulos
            hold on
            plot(1:step:total_time+1,rsnr);
            legend('Result Urban 5GRX','Result Network Cell Info');
        end
        figure();
        plot(1:step:total_time+1,signal_receivers);
        legend(rx_names);
        title('SIGNAL DATA RECEIVERS');xlabel('Time (s)');ylabel('SIGNAL (dBm)');
        if networkcellinfo==1    %Si el archivo subido proviene de Network Cell Info, se realizará una comparación
            hold on
            plot(1:step:total_time+1,signal);
            legend('Result Urban 5GRX','Result Network Cell Info');
        end
    end
    if length(tx_longitudes)<=8          %Siempre que el número de Tx sea menor o igual a 8...
        figure();
        bar(0:step:total_time,connect_user);   %Representación de usuarios conectados a cada Tx en cada instante de tiempo
        legend(tx_names);
        title('CONNECTED USERS');xlabel('Time (s)');ylabel('CONNECTED USERS');ylim([-0.5 Inf]);
    end
    %% Animation Mobility
    disp("Generating Animation...");
    frames=total_time/step;
    makeAnimationMobility(frames);
end
stop(timer)  %Stop Timer
end