classdef input_parameters
    properties
        uma_frequency;
        uma_power;
        umi_coverage_power;
        umi_coverage_frequency;
        umi_hotspot_power;
        umi_hotspot_frequency;
        umi_blind_power;
        umi_blind_frequency;
        minimum_latitude;
        maximum_latitude;
        minimum_longitude;
        maximum_longitude;
        capacity;
        coverage;
        max_attempts;
        download_map_file;
        filter_by_company;
        country;
        companySpain;
        companyAustralia;
        number_of_receivers;
        longley_rice;
        ray_tracing;
        umi_coverage_isd;
        individual_bw;
        total_time;
        step;
        distance;
        duration;
        speed;
        filename;
        uma;
        grid;
        hotspot;
        blind;
        distributionReceivers;
        networkcellinfo;
    end
    
    methods
        function obj = input_parameters()
        end
    end
end

