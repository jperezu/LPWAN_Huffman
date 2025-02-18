import logging
import csv
import os
from PIL import Image
import numpy as np
import matplotlib.pyplot as plt

from adaptive_huffman_coding import compress, extract
from adaptive_huffman_coding.utils import show_raw_img


logging.basicConfig(level=logging.INFO)


def main():
    alphabet_range = (0, 255)
    dpcm = False
    code = 'L'
    num_samples = 17
    num_scale = 10
    dataset_path = "results/dataset/data"
    file_name = "/preview/quick-look.png"
    metadata_name = "/annotation/rfi/metadata.xml"
    measures_file = "../csv-intermedio/measures.csv"

    try:
        os.remove(measures_file)
    except OSError:
        pass
    csv_file = open(measures_file, 'w', newline='')
    writer = csv.writer(csv_file)
    header = "input_width,input_height,input_bytes,compression_time,entropy,out_width,out_height,scale,out_bytes,decompression_time,compression_ratio\n"
    csv_file.write(header)
    
    for idx in range(1, num_samples+1):
        raw_metadata = dataset_path + str(idx) + metadata_name
        raw_picture = dataset_path + str(idx) + file_name
        in_picture = "results/data"+ str(idx) + "_in.png"
        in_metadata = "results/metadata"+ str(idx) + "_in.xml"
        processed_picture = "results/data"+ str(idx) + "_processed.raw"
        processed_stream = "results/data"+ str(idx) + "_processed"
        compressed_packet = "results/packet"+ str(idx) + "_compressed"
        extracted_stream = "results/data"+ str(idx) + "_extracted.raw"
        out_picture = "results/data"+ str(idx) + "_out.png"
        out_metadata = "results/metadata"+ str(idx) + "_out.xml"

        #print("Buscando escala óptima...")
        max_ratio = 1
        for i in range(num_scale):
            scale = 0.1 * (i+1)
            img = Image.open(raw_picture).convert(code)
            #print(f"Escala: {scale}")
            #print(f"Dimensiones Originales: {img.size[0]}x{img.size[1]}")
            wsize = int(scale * float(img.size[0]))
            hsize = int((float(img.size[1]) * scale))
            img = img.resize((wsize, hsize), Image.Resampling.LANCZOS)
            array_imagen = np.array(img)
            array_imagen.tofile(processed_picture)
            #print(f"Dimensiones Procesadas: {wsize}x{hsize}")

            original_size,_,ratio,entropy = compress(processed_picture, compressed_packet, True,
                        alphabet_range=alphabet_range, dpcm=dpcm)
            print(f'bytes {original_size} | scale {scale} | ratio {ratio} | entropy {entropy}')
            if (ratio > max_ratio):
                max_scale = scale
                max_ratio = ratio

        print(f"[{idx}/{num_samples}] Comenzando simulación...")
        scale = max_scale
        img = Image.open(raw_picture).convert(code)
        #print(f"Escala: {scale}")
        wsize_raw = img.size[0]
        hsize_raw = img.size[1]
        #print(f"Dimensiones Originales: {wsize_raw}x{hsize_raw}")
        wsize = int(scale * float(img.size[0]))
        hsize = int((float(img.size[1]) * scale))
        img = img.resize((wsize, hsize), Image.Resampling.LANCZOS)
        #print(f"Dimensiones Procesadas: {wsize}x{hsize}")
        np.array(img).tofile(processed_picture)

        with open(raw_metadata, "rb") as xml_file:
            xml_raw_data = xml_file.read()        
        array_imagen = img.tobytes()
        data_stream = array_imagen + xml_raw_data
        with open(processed_stream, "wb") as combined_file:
            combined_file.write(data_stream)
        with open(in_metadata, "wb") as xml_file:
            xml_file.write(xml_raw_data)  
       
        original_size, compression_time, compression_ratio, entropy = compress(processed_stream, compressed_packet,
                True, alphabet_range=alphabet_range, dpcm=dpcm)
        compressed_size, compression_ratio, decompression_time = extract(compressed_packet, extracted_stream,
                alphabet_range=alphabet_range, dpcm=dpcm)
        
        print(f"Results: Input - {wsize_raw} Ancho, {hsize_raw} Alto, {original_size} bytes, {compression_time} seconds, entropy {entropy}")
        print(f"Results: Output - {wsize} Ancho, {hsize} Alto, {scale} escala, {compressed_size} bytes, {decompression_time} seconds, ratio {compression_ratio}")

        
        entries = [[wsize_raw, hsize_raw, original_size, compression_time, entropy, wsize, hsize, scale, compressed_size, decompression_time, compression_ratio]]
        writer.writerows(entries)

        with open(extracted_stream, "rb") as combined_file:
            combined_raw_data = combined_file.read()
        separator = b'<?xml' 
        split_index = combined_raw_data.find(separator) + len(separator)
        xml_data = combined_raw_data[split_index:]
        png_raw_data = combined_raw_data[:split_index]

        with open(out_metadata, "wb") as xml_file:
            xml_file.write(xml_data)
        
        Image.frombytes('L', (wsize, hsize), png_raw_data).save(out_picture)
        Image.open(raw_picture).save(in_picture)
        #show_raw_img(processed_picture, out_picture, code, size=(wsize, hsize))
    csv_file.close()

if __name__ == '__main__':
    main()
