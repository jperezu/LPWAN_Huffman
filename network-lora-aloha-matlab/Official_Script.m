
clfall;
showProgressBar = 0;

measure_table = readtable('../csv-intermedio/measures.csv', 'HeaderLines', 0);
measures = table2array(measure_table);
%measures = readmatrix('../csv-intermedio/measures.csv');
input_width = 1;
input_height = 2;
input_bytes = 3;
compression_time = 4;
entropy = 5;
out_width = 6;
out_height = 7;
scale = 8;
out_bytes = 9;
decompression_time = 10;
compression_ratio = 11;
resolution = 14;
num_samples = 17;
res_ids = zeros(resolution, 1);
average_sample = zeros(14, compression_ratio);
packetsize = zeros(2,1);
i = 0;
ratio = 0;
compress_sample = 0;
decompress_sample = 0;

for sample = 1:size(measures,1)
    if (measures(sample, scale) <= 1)
        idx = floor(measures(sample, scale) * 10);
    else
        idx = floor(measures(sample, scale) + 9);
    end
    for attr = input_width:compression_ratio
        if (sample == 1)
            average_sample(idx, attr) = measures(sample, attr);
        else
            average_sample(idx, attr) = average_sample(idx, attr) + measures(idx, attr);
        end

        if (sample > ((size(measures,1)-resolution)))
            average_sample(idx, attr) = average_sample(idx, attr) / num_samples;
            res_ids(idx) = average_sample(idx, scale);
        end
    end
    if ((sample == 1) || ((sample > 1) && (measures(sample, compression_ratio) > measures(sample, compression_ratio))))
        packetsize(1) = 25; %escenario sin compresion
        ratio = measures(sample, compression_ratio);
        packetsize(2) = floor(packetsize(1)/ratio); %escenario con compresion
        compress_sample = measures(sample, compression_time);
        decompress_sample = measures(sample, decompression_time);
    end
end

disp(ratio);

timespan = 60*1000; % ms
timeinterval = 10; % ms
nrofslots = timespan / timeinterval;

freqspan = 125e3; % Hz: 125 kHz
freqinterval = 100; % Hz

start_channel = 1;
end_channel = 6;
nrofchannels = end_channel;
fiveperc = 0;

maxnrofdevices = 1000;
devicestepsize = 1;
nrofdevices = devicestepsize:devicestepsize:maxnrofdevices;
nrofpackets = 1;

bytesize = 8;
SFnum = 7;
SFsim = SFnum;
SFvals = [12 11 10 9 8 7 6];
lora_bitrate = [293 547 976 1757 3125 5468 9375];
lora_duration = [SFvals(1) lora_bitrate(1) 0; 
                 SFvals(2) lora_bitrate(2) 0;
                 SFvals(3) lora_bitrate(3) 0;
                 SFvals(4) lora_bitrate(4) 0;
                 SFvals(5) lora_bitrate(5) 0;
                 SFvals(6) lora_bitrate(6) 0;
                 SFvals(7) lora_bitrate(7) 0];
packetduration = zeros(SFnum, 1);

if exist('showProgressBar','var') && showProgressBar == 1
    showProgressBar = 1;
    progressBar = waitbar(0,'Generating traffic...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(progressBar,'canceling',0);
else
    showProgressBar = 0;
end

fiveperc_sum = zeros(1, length(packetsize));
sum_fails = zeros(maxnrofdevices / devicestepsize, length(packetsize));

for sim = 1:length(packetsize)
    
    for i = 1:SFnum
        lora_duration(i, 3) = floor((packetsize(sim) * bytesize * 1e3) / lora_bitrate(i));
        %optimo SF: habilitar para simulación óptima
        %lora_duration(i, 3) = floor((packetsize(sim) * bytesize * 1e3) / lora_bitrate(SFnum));
    end
    
    packetduration = lora_duration(:, 3);

    results = zeros(maxnrofdevices / devicestepsize, 2);
    throughput = zeros(maxnrofdevices / devicestepsize, 1);
    meanDelay = zeros(maxnrofdevices / devicestepsize, 1);
    trafficOffered = zeros(maxnrofdevices / devicestepsize, 1);
    packetCollisionProb = zeros(maxnrofdevices / devicestepsize, 1);
    sum_ft1 = zeros(nrofslots, nrofchannels, maxnrofdevices / devicestepsize);

    for nrIdx = 1:length(nrofdevices)
        nr = nrofdevices(nrIdx);
        ft1 = zeros(nrofslots, nrofchannels);
        ft = zeros(nrofslots, nrofchannels);
        ft2 = zeros(nrofslots, nrofchannels);
        colission1 = zeros(nr, nrofpackets);
        colission = zeros(nr, nrofpackets);
    
        sf = randi([start_channel end_channel], [nr nrofpackets]);
        imax = floor(nrofslots - (packetduration(SFsim)*nrofpackets)/timeinterval);
        time_rand = randi([1 imax], [nr 1]);

        delays = zeros(nr, 1);
        ackdPacketCount = 0;
        collisionCount = 0;
        transmissionAttempts = 0;
        duration_cumulative = 0;
        
        for i = 1:nr
            rnd_offset = time_rand(i, 1);
            time_offset = floor((nrofslots - (packetduration(sf(i)) * nrofpackets) / timeinterval) * rand(1, 1));
            duration_cumulative = duration_cumulative + time_offset;
            
            for p = 1:nrofpackets
                for k = -1:1:1
                    if (sf(i, p)+k<1) | (sf(i, p)+k>nrofchannels)
                        continue
                    end
                    duration = lora_duration(sf(i, p),3);
                    for j1 = 1:ceil(duration/timeinterval)
                       %freq(i, 1)
                       if j1+rnd_offset > nrofslots
                           continue
                       end
                       if  ft1(j1+rnd_offset, sf(i, p)+k) == 0
                           ft1(j1+rnd_offset, sf(i, p)+k) = 1;
                       else
                            ft1(j1+rnd_offset, sf(i, p)+k) = 2;
                            colission1(i, p) = 1;
                       end
                    end        
                end

                transmissionAttempts = transmissionAttempts + 1;
                duration = lora_duration(sf(i, p), 3);
                success = true;
                for j = 1:duration / timeinterval
                    if j + time_offset > nrofslots
                        continue;
                    end
    
                    if ft(j + time_offset, sf(i, p)) == 0
                        ft(j + time_offset, sf(i, p)) = 1;
                        ft2(j + time_offset, sf(i, p)) = i;
                    else
                        ft(j + time_offset, sf(i, p)) = ft(j + time_offset, sf(i, p)) + 1;
                        colission(i) = 1;
                        colission(ft2(j + time_offset, sf(i, p))) = 1;
                        success = false;
                    end
                end
                
                if success
                    delays(i) = delays(i) + duration_cumulative;
                    duration_cumulative = 0;
                    ackdPacketCount = ackdPacketCount + 1;
                else
                    collisionCount = collisionCount + 1;
                end
    
                time_offset = ceil(time_offset + duration / timeinterval);
                rnd_offset = rnd_offset + duration/timeinterval;
            end
        end
        
        trafficOffered(nrIdx) = transmissionAttempts / nrofslots;
        if ackdPacketCount == 0
            meanDelay(nrIdx) = duration_cumulative; % theoretically, if packets collide continously, the delay tends to infinity
        else
            meanDelay(nrIdx) = mean(delays(delays > 0));
        end
        throughput(nrIdx) = ackdPacketCount/ nrofslots; %(ackdPacketCount * packetsize(sim)) / (nrofslots*timeinterval);
        packetCollisionProb(nrIdx) = (collisionCount / transmissionAttempts)*100;
    
        results(nrIdx, 1) = sum(sum(colission));
        results(nrIdx, 2) = 100 * sum(sum(colission)) / nr;
        
        %Num dispositivos colisiones inferiores a cinco
        if results(nrIdx, 2) < 5
            fiveperc = nr;
        end

         if showProgressBar == 1
            if getappdata(progressBar,'canceling')
                delete(progressBar);
                fprintf('\nWarning: terminated by user!\n');
                return
            end
                waitbar((sim*nrIdx) / (maxnrofdevices*length(packetsize)),progressBar,sprintf('[%u/%u] Packets sent: %u; packets acknowledged: %u.', ...
                    sim,length(packetsize), transmissionAttempts,ackdPacketCount));
         end

         %colission
        fail = sum(colission1, 2) == nrofpackets;
        fails = sum(fail);
        sum_fails(nr,sim) = fails;
        
        ft1(1,1) = 1;
        ft1(1,2) = 2;
        sum_ft1(:,:,nr) = ft1;

    end
    
    fiveperc_sum(sim) = fiveperc;
   
    prefix = ["Sin" "Con"];
    figure(1);
    subplot(ceil(length(packetsize)/2),2,sim);
    sum_ft1 = [sum_ft1 ones(6000,1,maxnrofdevices / devicestepsize)];
    media_ft1 = mean(sum_ft1, 3);
    dev_ft1 = sum_ft1(:,:,maxnrofdevices / devicestepsize);
    pcolor(dev_ft1);

    map2 = [0 0 0;  0 1 0 ;0 0.9 0; 0.9 0 0;];
    colormap(map2);
    shading flat;

    %Lora packet collision simulation withing 125 kH with %d devices \ntransmitting randomly within 60 seconds
    suptitlestring = sprintf('Collisions for %d devices', nr);
    titlestring = sprintf('%s compresión', prefix(sim));

    sgtitle(suptitlestring);
    title(titlestring);
    xlabel('Canal lógico (Factor de expansión)') % x-axis label
    ylabel('Tiempo (10 ms)') % y-axis label
    ax = gca;
    set(gca,'XTickLabel',{'12','11','10','9','8','7',''});

    figure(2);
    hold on;
    title("Number of Fails per numdevices");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, results(:, 1), 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', results(:, 1), 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(3);
    hold on;
    title("Packet error rate (%) per numdevices");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, results(:, 2), 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', results(:, 2), 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(4);
    hold on;
    title("Mean Delay per numdevices");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, meanDelay, 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', meanDelay, 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(5);
    hold on;
    title("Packet Collision Probability");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, packetCollisionProb, 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', packetCollisionProb, 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(6);
    hold on;
    title("Throughput");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, throughput, 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', throughput, 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(7);
    hold on;
    title("Number of Collisions");
    refname = sprintf('%s compresión', prefix(sim));
    valor=plot(nrofdevices, sum_fails(:,sim), 'DisplayName', refname);
    ajuste=plot(polyval(polyfit(nrofdevices', sum_fails(:,sim), 3), nrofdevices'), ...
        'HandleVisibility','off','LineWidth',2);
    ajuste.SeriesIndex = valor.SeriesIndex;
    legend( 'show', 'interpreter', 'none', 'location', 'best' );

    figure(8);
    hold on;
    title("Five Percent");
    refname = sprintf('%s compresión', prefix(sim));
    bar(sim, fiveperc_sum(sim), 'DisplayName', refname);
    legend( 'show', 'interpreter', 'none', 'location', 'best' );
end


if showProgressBar == 1
    delete(progressBar);
end

figure(9);
hold on;
title("Latencia Compresion/decompresion");
refname = sprintf( 'Numero dispositivos');
bar(1, compress_sample, 'DisplayName', refname);
bar(2, decompress_sample, 'DisplayName', refname);
legend( 'show', 'interpreter', 'none', 'location', 'best' );


% Evalua compresion
measure_table_mix = readtable('../csv-intermedio/measures_concat_normal.csv', 'HeaderLines', 0);
measure_table_xml = readtable('../csv-intermedio/measures_concat_xmls.csv', 'HeaderLines', 0);
measure_table_img = readtable('../csv-intermedio/measures_concat_img.csv', 'HeaderLines', 0);

ratio_huff = zeros(size(measure_table_mix,1), 3);
ratio_huff(:,1) = table2array(measure_table_mix(:,compression_ratio));
ratio_huff(:,2) = table2array(measure_table_xml(:,compression_ratio));
ratio_huff(:,3) = table2array(measure_table_img(:,compression_ratio));

latency_huff = zeros(size(measure_table_mix,1), 3);
latency_huff(:,1) = table2array(measure_table_mix(:,compression_time));
latency_huff(:,2) = table2array(measure_table_xml(:,compression_time));
latency_huff(:,3) = table2array(measure_table_img(:,compression_time));

entropy_huff = zeros(size(measure_table_mix,1), 3);
entropy_huff(:,1) = table2array(measure_table_mix(:,entropy));
entropy_huff(:,2) = table2array(measure_table_xml(:,entropy));
entropy_huff(:,3) = table2array(measure_table_img(:,entropy));

figure(10);
hold on;
title("Ratio de compresión");
refname = sprintf( 'Híbrido');
plot(1:1:size(measure_table_mix,1), ratio_huff(:,1), 'DisplayName', refname);
refname = sprintf( 'Datos');
plot(1:1:size(measure_table_mix,1), ratio_huff(:,2), 'DisplayName', refname);
refname = sprintf( 'Imagen');
plot(1:1:size(measure_table_mix,1), ratio_huff(:,3), 'DisplayName', refname);
legend( 'show', 'interpreter', 'none', 'location', 'best' );

figure(11);
hold on;
title("Tiempo de compresión");
refname = sprintf( 'Híbrido');
plot(1:1:size(measure_table_mix,1), latency_huff(:,1), 'DisplayName', refname);
refname = sprintf( 'Datos');
plot(1:1:size(measure_table_mix,1), latency_huff(:,2), 'DisplayName', refname);
refname = sprintf( 'Imagen');
plot(1:1:size(measure_table_mix,1), latency_huff(:,3), 'DisplayName', refname);
legend( 'show', 'interpreter', 'none', 'location', 'best' );

figure(12);
hold on;
title("Entropia");
refname = sprintf( 'Híbrido');
plot(1:1:size(measure_table_mix,1), entropy_huff(:,1), 'DisplayName', refname);
refname = sprintf( 'Datos');
plot(1:1:size(measure_table_mix,1), entropy_huff(:,2), 'DisplayName', refname);
refname = sprintf( 'Imagen');
plot(1:1:size(measure_table_mix,1), entropy_huff(:,3), 'DisplayName', refname);
legend( 'show', 'interpreter', 'none', 'location', 'best' );

figure(13);
plot(res_ids, average_sample(:,compression_ratio));

%%%%%%%%%%%%%%%%%%%%
function clfall
FigList = findall(groot, 'Type', 'figure');
for iFig = 1:numel(FigList)
    try
        clf(FigList(iFig));
    catch
        % Nothing to do
    end
end
end